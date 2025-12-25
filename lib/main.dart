import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter/foundation.dart';

void main() {
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
      home: const MapScreen(),
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
  
  // --- DATOS BÁSICOS ---
  final List<LatLng> _routePoints = [];
  LatLng? _currentPosition;
  double _totalDistance = 0.0;
  final Stopwatch _stopwatch = Stopwatch();
  Duration _duration = Duration.zero;
  
  // --- ESTADÍSTICAS AVANZADAS ---
  // Historial: guardamos distancia y tiempo CADA VEZ que el GPS se mueve
  final List<({double dist, Duration time})> _history = []; 
  
  Duration? _bestRolling1k;      // El mejor tiempo
  String _bestRolling1kRange = ""; // El texto "Km 3.2 - 4.2"
  
  List<Duration> _kmSplits = []; 
  Duration _lastSplitTime = Duration.zero; 

  // --- HERRAMIENTAS ---
  StreamSubscription<Position>? _positionStream;
  Timer? _timer;
  final Distance _distanceCalculator = const Distance();
  bool _isTracking = false;

  // --- MATEMÁTICAS ---
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

  // --- EMPEZAR ---
  Future<void> _startTracking() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return;

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return;
    }

    setState(() {
      _isTracking = true;
      _routePoints.clear();
      _totalDistance = 0.0;
      _duration = Duration.zero;
      
      // Reiniciamos estadísticas
      _history.clear();
      _history.add((dist: 0, time: Duration.zero)); // Punto inicial

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
        distanceFilter: 3, // Actualiza cada 3 metros
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

        // --- LÓGICA CORREGIDA DE ESTADÍSTICAS ---
        
        // 1. Añadimos punto actual al historial
        _history.add((dist: _totalDistance, time: _stopwatch.elapsed));

        // 2. Calcular Mejor Kilómetro "Rolling" (Búsqueda inversa más precisa)
        // Buscamos hacia atrás el punto que esté MÁS CERCA de hace 1000 metros exactos
        if (_totalDistance >= 1000) {
            double targetDist = _totalDistance - 1000;
            
            // Recorremos la lista al revés para encontrar el punto más cercano a targetDist
            for (int i = _history.length - 1; i >= 0; i--) {
                var point = _history[i];
                
                // Si encontramos un punto que está detrás de nuestro objetivo de 1000m
                if (point.dist <= targetDist) {
                    // Calculamos el tiempo que ha pasado desde ese punto hasta ahora
                    Duration tramoTime = _stopwatch.elapsed - point.time;

                    // ¿Es récord?
                    if (_bestRolling1k == null || tramoTime < _bestRolling1k!) {
                        _bestRolling1k = tramoTime;
                        // Guardamos el rango formateado (ej: "3.45 - 4.45 km")
                        double startKm = point.dist / 1000;
                        double endKm = _totalDistance / 1000;
                        _bestRolling1kRange = "Del km ${startKm.toStringAsFixed(2)} al ${endKm.toStringAsFixed(2)}";
                    }
                    break; // Ya encontramos el punto de referencia, paramos de buscar
                }
            }
        }

        // 3. Calcular Splits (Kilómetros Redondos)
        int currentKmIndex = _totalDistance ~/ 1000;
        if (currentKmIndex > _kmSplits.length) {
          Duration tiempoDeEsteKm = _stopwatch.elapsed - _lastSplitTime;
          _kmSplits.add(tiempoDeEsteKm);
          _lastSplitTime = _stopwatch.elapsed; 
          
          ScaffoldMessenger.of(context).showSnackBar(
             SnackBar(content: Text("🏁 Km $currentKmIndex en ${_formatTime(tiempoDeEsteKm)}"), duration: const Duration(seconds: 2))
          );
        }
      });

      _mapController.move(newPoint, 17.0);
    });
  }

  // --- PARAR Y MOSTRAR RESUMEN ---
  void _stopTracking() {
    _positionStream?.cancel();
    _timer?.cancel();
    _stopwatch.stop();
    
    setState(() {
      _isTracking = false;
    });

    Duration? bestSplit;
    if (_kmSplits.isNotEmpty) {
      List<Duration> sortedSplits = List.from(_kmSplits);
      sortedSplits.sort();
      bestSplit = sortedSplits.first;
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
                
                // Mejor tramo de 1000m (Rolling)
                _buildStatRow(
                  "Mejor Km continuo:", 
                  _bestRolling1k != null ? _formatTime(_bestRolling1k!) : "--:--"
                ),
                // Mostramos el rango pequeño debajo
                if (_bestRolling1kRange.isNotEmpty)
                    Padding(
                        padding: const EdgeInsets.only(bottom: 8.0),
                        child: Text(
                            _bestRolling1kRange, 
                            style: TextStyle(fontSize: 11, color: Colors.grey[600], fontStyle: FontStyle.italic)
                        ),
                    ),

                // Mejor Km Redondo (Split)
                _buildStatRow(
                  "Mejor Km Redondo:", 
                  bestSplit != null ? _formatTime(bestSplit) : "--:--"
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
                setState(() {
                  _routePoints.clear();
                  _totalDistance = 0.0;
                  _duration = Duration.zero;
                  _currentPosition = null;
                  _kmSplits.clear();
                  _bestRolling1k = null;
                  _bestRolling1kRange = "";
                });
                Navigator.of(context).pop(); 
              },
              child: const Text('CERRAR'),
            ),
          ],
        );
      },
    );
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
      body: Stack(
        children: [
          // MAPA
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

          // DASHBOARD
          Positioned(
            top: 50,
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