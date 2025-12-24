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
  final List<({double dist, Duration time})> _history = []; 
  Duration? _bestRolling1k;
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
      _bestRolling1k = null;
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

    // -----------------------------------------------------------------------
    // [CAMBIO REALIZADO] Configuración avanzada para segundo plano (Foreground Service)
    // -----------------------------------------------------------------------
    LocationSettings locationSettings;

    if (defaultTargetPlatform == TargetPlatform.android) {
      locationSettings = AndroidSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 3,
        forceLocationManager: true,
        intervalDuration: const Duration(seconds: 1),
        // Aquí está la magia que mantiene viva la app:
        foregroundNotificationConfig: const ForegroundNotificationConfig(
          notificationTitle: "Running League",
          notificationText: "Registrando tu carrera en segundo plano...",
          notificationIcon: AndroidResource(name: 'ic_launcher'),
          enableWakeLock: true, // Mantiene la CPU despierta
        ),
      );
    } else {
      locationSettings = const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 3,
      );
    }
    // -----------------------------------------------------------------------

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

        // --- ESTADÍSTICAS ---
        _history.add((dist: _totalDistance, time: _duration));

        for (var point in _history) {
          if (_totalDistance - point.dist >= 1000) { // 1000m para producción
            Duration tramoTime = _duration - point.time;
            if (_bestRolling1k == null || tramoTime < _bestRolling1k!) {
              _bestRolling1k = tramoTime;
            }
            break; 
          }
        }

        int currentKmIndex = _totalDistance ~/ 1000;
        if (currentKmIndex > _kmSplits.length) {
          Duration tiempoDeEsteKm = _duration - _lastSplitTime;
          _kmSplits.add(tiempoDeEsteKm);
          _lastSplitTime = _duration; 
          
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
                
                _buildStatRow(
                  "Mejor Km continuo:", 
                  _bestRolling1k != null ? _formatTime(_bestRolling1k!) : "--:--"
                ),

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