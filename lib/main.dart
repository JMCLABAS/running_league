import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // <--- AÑADIDO (Necesario para unirse a la liga)
import 'package:permission_handler/permission_handler.dart'; 
import 'package:app_links/app_links.dart'; 
import 'package:share_plus/share_plus.dart'; 

// --- IMPORTS DE PANTALLAS ---
import 'run_summary_screen.dart';
import 'leagues_screen.dart'; 
import 'nickname_screen.dart';
import 'db_helper.dart'; 
import 'history_screen.dart';
import 'login_screen.dart'; 
import 'settings_screen.dart';

// --- IMPORT DE SERVICIOS ---
import 'running_service.dart'; 

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('es', null); 
  await Firebase.initializeApp(); 
  runApp(const RunningLeagueApp());
}

class RunningLeagueApp extends StatelessWidget {
  const RunningLeagueApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Running League',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(body: Center(child: CircularProgressIndicator()));
          }
          
          if (snapshot.hasData) {
            final user = snapshot.data!;
            if (user.emailVerified) {
               return const MapScreen(); 
            }
          }
          
          return const LoginScreen();
        },
      ),
    );
  }
}

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final MapController _mapController = MapController();
  final FlutterTts _flutterTts = FlutterTts();
  
  // --- VARIABLES DEEP LINKS ---
  late AppLinks _appLinks;
  StreamSubscription<Uri>? _linkSubscription;
  // ---------------------------

  bool _voiceEnabled = true;
  bool _hasAskedBatteryInfo = false;

  final List<LatLng> _routePoints = [];
  LatLng? _currentPosition;
  double _totalDistance = 0.0;
  final Stopwatch _stopwatch = Stopwatch();
  Duration _duration = Duration.zero;
  
  final List<({double dist, Duration time})> _history = []; 
  
  Duration? _bestRolling1k;      
  String _bestRolling1kRange = ""; 
  
  List<Duration> _kmSplits = []; 
  Duration _lastSplitTime = Duration.zero; 

  StreamSubscription<Position>? _positionStream;
  Timer? _timer;
  final Distance _distanceCalculator = const Distance();
  bool _isTracking = false;

  @override
  void initState() {
    super.initState();
    _initTts();
    
    // Inicializar Deep Links
    initDeepLinks();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkIfNewGoogleUser();
    });
  }

  @override
  void dispose() {
    _linkSubscription?.cancel(); // Cancelar escucha de links
    _positionStream?.cancel();
    _timer?.cancel();
    super.dispose();
  }

  // --- LÓGICA DEEP LINKS ---
  Future<void> initDeepLinks() async {
    _appLinks = AppLinks();

    // Escuchar enlaces entrantes (incluso si la app estaba cerrada)
    _linkSubscription = _appLinks.uriLinkStream.listen((uri) {
      procesarEnlace(uri);
    });
  }

  void procesarEnlace(Uri uri) {
    // El enlace ahora es: http://running-league.app/unirse?id=CODIGO
    
    // Verificamos si el host coincide
if (uri.host == 'running-league-app.web.app' && uri.path.contains('unirse')) {      final leagueId = uri.queryParameters['id'];
      
      if (leagueId != null) {
        print("🔗 Enlace HTTP detectado para liga: $leagueId");
        _unirseAutomaticamente(leagueId);
      }
    }
    // Mantenemos compatibilidad con el antiguo por si acaso
    else if (uri.scheme == 'runningleague' && uri.host == 'unirse') {
      final leagueId = uri.queryParameters['id'];
      if (leagueId != null) _unirseAutomaticamente(leagueId);
    }
  }

  Future<void> _unirseAutomaticamente(String leagueId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return; 

    try {
      // 1. Verificar si la liga existe
      final ligaDoc = await FirebaseFirestore.instance.collection('leagues').doc(leagueId).get();
      
      if (!ligaDoc.exists) {
        if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('❌ Esa liga no existe')));
        }
        return;
      }

      // 2. Unirse (Añadir UID al array)
      await FirebaseFirestore.instance.collection('leagues').doc(leagueId).update({
        'participantes': FieldValue.arrayUnion([user.uid])
      });
      
      // 3. Avisar al usuario
      if (mounted) {
        showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
            title: const Text("¡Bienvenido! 🏃‍♂️"),
            content: Text("Te has unido correctamente a: ${ligaDoc.data()?['nombre']}"),
            actions: [
                TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text("GENIAL"),
                )
            ],
            ),
        );
      }

    } catch (e) {
      print("Error al unirse por link: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Error al intentar unirse a la liga')));
      }
    }
  }
  // -------------------------

  void _checkIfNewGoogleUser() {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null && user.metadata.creationTime != null) {
      bool isGoogleUser = user.providerData.any((info) => info.providerId == 'google.com');
      final difference = DateTime.now().difference(user.metadata.creationTime!);
      bool isRecent = difference.inSeconds < 15;

      String? googleName;
      for (var info in user.providerData) {
        if (info.providerId == 'google.com') {
          googleName = info.displayName;
          break;
        }
      }

      bool nameIsDefault = user.displayName == googleName || user.displayName == null || user.displayName!.isEmpty;

      if (isGoogleUser && isRecent && nameIsDefault) {
        Navigator.push(
          context, 
          MaterialPageRoute(builder: (_) => const NicknameScreen())
        );
      }
    }
  }

  Future<void> _initTts() async {
    await _flutterTts.setLanguage("es-ES");
    await _flutterTts.setSpeechRate(0.5);
    await _flutterTts.setVolume(1.0);
    await _flutterTts.setPitch(1.0);
  }

  Future<void> _speak(String text) async {
    if (!_voiceEnabled) return; 

    await _flutterTts.stop(); 
    if (text.isNotEmpty) {
      await _flutterTts.speak(text);
    }
  }

  String _calcularRitmo(Duration duracion, double distanciaEnMetros) {
    if (distanciaEnMetros <= 0) return "0:00";
    double distanciaEnKm = distanciaEnMetros / 1000;
    double minutosTotales = duracion.inSeconds / 60;
    double ritmoDecimal = minutosTotales / distanciaEnKm;
    int minutosRitmo = ritmoDecimal.floor();
    int segundosRitmo = ((ritmoDecimal - minutosRitmo) * 60).round();
    String segundosString = segundosRitmo.toString().padLeft(2, '0');
    if (minutosRitmo > 59) return "--:--";
    return "$minutosRitmo:$segundosString";
  }

  String _formatTime(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final hours = twoDigits(duration.inHours);
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return "$hours:$minutes:$seconds";
  }

  String _durationToSpeech(Duration d) {
    int min = d.inMinutes;
    int sec = d.inSeconds % 60;
    String texto = "";
    if (min > 0) texto += "$min minutos ";
    if (sec > 0 || min == 0) texto += "$sec segundos";
    return texto;
  }

  Future<void> _startTracking() async {
    // 1. Verificar servicios de ubicación
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
       if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("⚠️ Activa el GPS para empezar")),
        );
       }
       return;
    }

    // 2. Verificar permisos de ubicación
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return;
    }

    // -------------------------------------------------------------
    // 3. COMPROBACIÓN DE BATERÍA (SOLO UNA VEZ POR SESIÓN)
    // -------------------------------------------------------------
    
    // Solo preguntamos si NO hemos preguntado antes en esta sesión
    if (!_hasAskedBatteryInfo) {
      var batteryStatus = await Permission.ignoreBatteryOptimizations.status;
      
      // Si el sistema dice que NO tenemos permiso...
      if (!batteryStatus.isGranted) {
        if (mounted) {
          setState(() {
            _hasAskedBatteryInfo = true;
          });

          await showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text("⚠️ Ajuste Importante"),
              content: const Text(
                "Para grabar la ruta con la pantalla apagada, el móvil no debe restringir la batería.\n\n"
                "1. Toca 'Abrir Ajustes'.\n"
                "2. Busca 'Ahorro de batería' o 'Batería'.\n"
                "3. Selecciona 'Sin restricciones' o 'No optimizar'."
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text("Ahora no"),
                ),
                ElevatedButton(
                  onPressed: () async {
                    Navigator.pop(context);
                    await openAppSettings();
                  },
                  child: const Text("Abrir Ajustes"),
                ),
              ],
            ),
          );
        }
      } else {
        _hasAskedBatteryInfo = true;
      }
    }
    // -------------------------------------------------------------

    _speak("Iniciando carrera.");

    setState(() {
      _isTracking = true;
      _routePoints.clear();
      _totalDistance = 0.0;
      _duration = Duration.zero;
      _history.clear();
      _history.add((dist: 0, time: Duration.zero));
      _bestRolling1k = null;
      _bestRolling1kRange = "";
      _kmSplits.clear();
      _lastSplitTime = Duration.zero;
      _stopwatch.reset();
      _stopwatch.start();
    });

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        _duration = _stopwatch.elapsed;
      });
    });

    LocationSettings locationSettings;
    if (defaultTargetPlatform == TargetPlatform.android) {
      locationSettings = AndroidSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 3,
        forceLocationManager: true,
        intervalDuration: const Duration(seconds: 1),
        foregroundNotificationConfig: const ForegroundNotificationConfig(
          notificationTitle: "Running League",
          notificationText: "Grabando ruta...",
          notificationIcon: AndroidResource(name: 'ic_launcher'),
          enableWakeLock: true,
        ),
      );
    } else {
      locationSettings = const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 3,
      );
    }

    _positionStream = Geolocator.getPositionStream(locationSettings: locationSettings)
        .listen((Position position) {
      
      LatLng newPoint = LatLng(position.latitude, position.longitude);
      
      setState(() {
        if (_routePoints.isNotEmpty) {
          double stepDistance = _distanceCalculator.as(LengthUnit.Meter, _routePoints.last, newPoint);
          _totalDistance += stepDistance;
        }
        _currentPosition = newPoint;
        _routePoints.add(newPoint);
        _history.add((dist: _totalDistance, time: _stopwatch.elapsed));

        if (_totalDistance >= 1000) {
            double targetDist = _totalDistance - 1000;
            for (int i = _history.length - 1; i >= 0; i--) {
                var point = _history[i];
                if (point.dist <= targetDist) {
                    Duration tramoTime = _stopwatch.elapsed - point.time;
                    if (_bestRolling1k == null || tramoTime < _bestRolling1k!) {
                        _bestRolling1k = tramoTime;
                        double startKm = point.dist / 1000;
                        double endKm = _totalDistance / 1000;
                        _bestRolling1kRange = "Del km ${startKm.toStringAsFixed(2)} al ${endKm.toStringAsFixed(2)}";
                    }
                    break; 
                }
            }
        }

        int currentKmIndex = _totalDistance ~/ 1000;
        if (currentKmIndex > _kmSplits.length) {
          Duration tiempoDeEsteKm = _stopwatch.elapsed - _lastSplitTime;
          _kmSplits.add(tiempoDeEsteKm);
          _lastSplitTime = _stopwatch.elapsed; 
          
          ScaffoldMessenger.of(context).showSnackBar(
             SnackBar(content: Text("🏁 Km $currentKmIndex en ${_formatTime(tiempoDeEsteKm)}"), duration: const Duration(seconds: 2))
          );
          String speechText = "Kilómetro $currentKmIndex en ${_durationToSpeech(tiempoDeEsteKm)}";
          _speak(speechText);
        }
      });
      _mapController.move(newPoint, 17.0);
    });
  }

  void _stopTracking() {
    _positionStream?.cancel();
    _timer?.cancel();
    _stopwatch.stop();
    _speak("Entrenamiento finalizado.");

    setState(() {
      _isTracking = false;
    });

    Duration? bestSplit;
    String bestSplitRange = ""; 

    if (_kmSplits.isNotEmpty) {
      Duration minTime = _kmSplits.reduce((curr, next) => curr < next ? curr : next);
      bestSplit = minTime;
      int index = _kmSplits.indexOf(minTime);
      bestSplitRange = "Km ${index + 1}";
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          title: const Text('🏆 Resultados'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildStatRow("Distancia Total:", "${(_totalDistance / 1000).toStringAsFixed(2)} km"),
                _buildStatRow("Tiempo Total:", _formatTime(_duration)),
                _buildStatRow("Ritmo Medio:", "${_calcularRitmo(_duration, _totalDistance)} /km"),
                const Divider(),
                const Text("Récords de la sesión:", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue)),
                const SizedBox(height: 10),
                
                _buildStatRow(
                  "Mejor Km continuo:", 
                  _bestRolling1k != null ? _formatTime(_bestRolling1k!) : "--:--"
                ),
                if (_bestRolling1kRange.isNotEmpty)
                    Padding(
                        padding: const EdgeInsets.only(bottom: 8.0),
                        child: Text(
                            _bestRolling1kRange, 
                            style: TextStyle(fontSize: 11, color: Colors.grey[600], fontStyle: FontStyle.italic)
                        ),
                    ),

                _buildStatRow(
                  "Mejor Km Redondo:", 
                  bestSplit != null ? _formatTime(bestSplit) : "--:--"
                ),
                 if (bestSplitRange.isNotEmpty)
                    Padding(
                        padding: const EdgeInsets.only(bottom: 8.0),
                        child: Text(
                            bestSplitRange, 
                            style: TextStyle(fontSize: 11, color: Colors.grey[600], fontStyle: FontStyle.italic)
                        ),
                    ),
                
                if (_kmSplits.isNotEmpty) ...[
                   const SizedBox(height: 10),
                   const Text("Tus parciales:", style: TextStyle(fontSize: 12, color: Colors.grey)),
                   ..._kmSplits.asMap().entries.map((e) {
                     return Text("Km ${e.key + 1}: ${_formatTime(e.value)}", style: const TextStyle(fontSize: 12));
                   }),
                ]
              ],
            ),
          ),
          actions: [
            TextButton(
               onPressed: () {
                 _resetCarrera();
                 Navigator.of(context).pop();
               },
               child: const Text('DESCARTAR', style: TextStyle(color: Colors.grey)),
            ),
            
            ElevatedButton(
              onPressed: () async {
                final user = FirebaseAuth.instance.currentUser;
                if (user == null) {
                   ScaffoldMessenger.of(context).showSnackBar(
                     const SnackBar(content: Text("⚠️ Error: No hay usuario identificado")),
                   );
                   return;
                }

                // 1. Guardar en BD Local
                Map<String, dynamic> carreraParaGuardar = {
                  'userId': user.uid, 
                  'date': DateTime.now().toIso8601String(),
                  'duration': _duration.inSeconds,
                  'distance': _totalDistance,
                  'avgSpeed': _calcularRitmo(_duration, _totalDistance),
                  'bestSplitTime': bestSplit != null ? _formatTime(bestSplit) : "-",
                  'bestSplitRange': bestSplitRange.isNotEmpty ? bestSplitRange : "-",
                  'bestRollingTime': _bestRolling1k != null ? _formatTime(_bestRolling1k!) : "-",
                  'bestRollingRange': _bestRolling1kRange.isNotEmpty ? _bestRolling1kRange : "-",
                };

                await DBHelper().insertRun(carreraParaGuardar);

                // 2. Guardar en Ligas y Obtener Resultados
                List<Map<String, dynamic>> resultadosLigas = [];
                double finalDistKm = _totalDistance / 1000;
                Duration finalDuration = _duration; 

                try {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Procesando carrera... ☁️"), duration: Duration(seconds: 1)),
                  );
                  
                  resultadosLigas = await RunningService().saveRunToAllLeagues(
                    distanceKm: finalDistKm,
                    durationSeconds: finalDuration.inSeconds
                  );

                } catch (e) {
                  print("Error al sincronizar con ligas: $e");
                }

                // 3. Limpiar y Navegar
                _resetCarrera();
                
                if (context.mounted) {
                   Navigator.of(context).pop(); 
                   
                   Navigator.push(
                     context,
                     MaterialPageRoute(
                       builder: (context) => RunSummaryScreen(
                         distanceKm: finalDistKm,
                         duration: finalDuration,
                         leagueResults: resultadosLigas,
                       ),
                     ),
                   );
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, foregroundColor: Colors.white),
              child: const Text('GUARDAR'),
            ),
          ],
        );
      },
    );
  }

  void _resetCarrera() {
     setState(() {
       _routePoints.clear();
       _totalDistance = 0.0;
       _duration = Duration.zero;
       _currentPosition = null;
       _kmSplits.clear();
       _bestRolling1k = null;
       _bestRolling1kRange = "";
       _history.clear();
       _history.add((dist: 0, time: Duration.zero));
     });
  }

  Widget _buildStatRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.black87)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Running League', 
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blueAccent)
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0, 
        surfaceTintColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.history, color: Colors.black87),
            tooltip: "Ver Historial",
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const HistoryScreen()),
              );
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            const DrawerHeader(
              decoration: BoxDecoration(color: Colors.blueAccent),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Icon(Icons.directions_run, color: Colors.white, size: 50),
                  SizedBox(height: 10),
                  Text("Running League", style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
            ListTile(
              leading: const Icon(Icons.map),
              title: const Text('Mapa'),
              onTap: () => Navigator.pop(context), 
            ),
            ListTile(
              leading: const Icon(Icons.emoji_events),
              title: const Text('Mis Ligas'),
              onTap: () {
                Navigator.pop(context); 
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const LeaguesScreen()),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.settings),
              title: const Text('Ajustes'),
              onTap: () async {
                Navigator.pop(context);
                final bool? result = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => SettingsScreen(
                      currentVoiceEnabled: _voiceEnabled, 
                    ),
                  ),
                );

                if (result != null) {
                  setState(() {
                    _voiceEnabled = result;
                  });
                }
              },
            ),
          ],
        ),
      ),

      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: const MapOptions(
              initialCenter: LatLng(37.3862, -5.9926),
              initialZoom: 16.0,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.running.league',
              ),
              if (_routePoints.isNotEmpty)
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: _routePoints,
                      strokeWidth: 5.0,
                      color: Colors.red,
                    ),
                  ],
                ),
              if (_currentPosition != null)
                MarkerLayer(
                  markers: [
                    Marker(
                      point: _currentPosition!,
                      width: 80,
                      height: 80,
                      child: const Icon(
                        Icons.directions_run,
                        color: Colors.blue,
                        size: 40,
                        shadows: [Shadow(blurRadius: 10, color: Colors.black)],
                      ),
                    ),
                  ],
                ),
            ],
          ),

          Positioned(
            top: 15,
            left: 20,
            right: 20,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.95),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, 5)),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  Column(
                    children: [
                      const Text('TIEMPO', style: TextStyle(color: Colors.grey, fontSize: 10, fontWeight: FontWeight.bold)),
                      Text(_formatTime(_duration), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                    ],
                  ),
                  Column(
                    children: [
                      const Text('RITMO', style: TextStyle(color: Colors.grey, fontSize: 10, fontWeight: FontWeight.bold)),
                      Text(
                        _calcularRitmo(_duration, _totalDistance), 
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800, 
                          color: Colors.orange[800]
                        )
                      ),
                      const Text('min/km', style: TextStyle(fontSize: 8, color: Colors.grey)),
                    ],
                  ),
                  Column(
                    children: [
                      const Text('DISTANCIA', style: TextStyle(color: Colors.grey, fontSize: 10, fontWeight: FontWeight.bold)),
                      Text(
                        (_totalDistance / 1000).toStringAsFixed(2), 
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Colors.blue)
                      ),
                      const Text('km', style: TextStyle(fontSize: 8, color: Colors.grey)),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),

      floatingActionButton: FloatingActionButton.extended(
        onPressed: _isTracking ? _stopTracking : _startTracking,
        backgroundColor: _isTracking ? Colors.red : Colors.green,
        icon: Icon(_isTracking ? Icons.stop : Icons.play_arrow),
        label: Text(
          _isTracking ? 'PARAR' : 'EMPEZAR',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }
}