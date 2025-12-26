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
import 'nickname_screen.dart';
import 'db_helper.dart'; 
import 'history_screen.dart';
import 'login_screen.dart'; 

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
      // --- PORTERO AUTOMÁTICO MEJORADO ---
      home: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(body: Center(child: CircularProgressIndicator()));
          }
          
          // Si hay usuario logueado...
          if (snapshot.hasData) {
            final user = snapshot.data!;
            
            // ... Y ADEMÁS tiene el correo verificado: Pasamos al Mapa
            if (user.emailVerified) {
               return const MapScreen(); 
            }
            // Si está logueado pero NO verificado, no le dejamos pasar.
            // Se quedará viendo el LoginScreen (y tu lógica del Login le mostrará el error rojo)
          }
          
          // Si no hay usuario o no está verificado, mostramos Login
          return const LoginScreen();
        },
      ),
    );
  }
}

// --------------------------------------------------------
// A PARTIR DE AQUÍ EL RESTO ES IGUAL (MapScreen, etc...)
// Solo asegúrate de no borrar la clase MapScreen que tienes debajo
// --------------------------------------------------------

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final MapController _mapController = MapController();
  final FlutterTts _flutterTts = FlutterTts();
  
  bool _voiceEnabled = true;

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

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkIfNewGoogleUser();
    });
  }
void _checkIfNewGoogleUser() {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null && user.metadata.creationTime != null) {
      
      // 1. ¿Es usuario de Google? (Para no molestar a los de email que ya pusieron nombre)
      bool isGoogleUser = user.providerData.any((info) => info.providerId == 'google.com');

      // 2. ¿La cuenta es "fresca"? (Creada hace menos de 30 segundos)
      // Si borras el usuario en Firebase y entras, la fecha de creación se resetea a AHORA.
      final difference = DateTime.now().difference(user.metadata.creationTime!);
      bool isRecent = difference.inSeconds < 15;

      if (isGoogleUser && isRecent) {
        // ¡Eres nuevo! Vamos a ponerte nombre.
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
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return;

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return;
    }

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
                // 1. OBTENEMOS EL USUARIO 
                final user = FirebaseAuth.instance.currentUser;
                
                if (user == null) {
                   ScaffoldMessenger.of(context).showSnackBar(
                     const SnackBar(content: Text("⚠️ Error: No hay usuario identificado")),
                   );
                   return;
                }

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

                _resetCarrera();
                if (context.mounted) {
                   Navigator.of(context).pop();
                   ScaffoldMessenger.of(context).showSnackBar(
                     const SnackBar(content: Text("✅ ¡Carrera guardada en TU cuenta!")),
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
            tooltip: _voiceEnabled ? "Silenciar Voz" : "Activar Voz",
            icon: Icon(
              _voiceEnabled ? Icons.volume_up : Icons.volume_off, 
              color: _voiceEnabled ? Colors.blue : Colors.grey
            ),
            onPressed: () {
              setState(() {
                _voiceEnabled = !_voiceEnabled;
                if (_voiceEnabled) _speak("Voz activada");
              });
              
              ScaffoldMessenger.of(context).clearSnackBars();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(_voiceEnabled ? "🔊 Entrenador de voz ACTIVADO" : "🔇 Entrenador de voz SILENCIADO"),
                  duration: const Duration(seconds: 1),
                )
              );
            },
          ),
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
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.redAccent),
            tooltip: "Cerrar Sesión",
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
            },
          ),
          const SizedBox(width: 8),
        ],
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