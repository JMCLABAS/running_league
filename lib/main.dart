import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';

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
  
  // --- ESTADÍSTICAS AVANZADAS (NUEVO) ---
  // Historial para calcular el Rolling 1k (Mejor tramo de 1000m)
  // Guardamos tu distancia y tiempo en cada segundo
  final List<({double dist, Duration time})> _history = []; 
  Duration? _bestRolling1k; // El récord del mejor tramo continuo

  // Splits (Km Redondos: 0-1, 1-2...)
  List<Duration> _kmSplits = []; // Lista con los tiempos de cada km
  Duration _lastSplitTime = Duration.zero; // Cuándo terminamos el km anterior

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

    const LocationSettings locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 3,
    );

    _positionStream = Geolocator.getPositionStream(locationSettings: locationSettings)
        .listen((Position position) {
      
      LatLng newPoint = LatLng(position.latitude, position.longitude);
      
      setState(() {
        if (_routePoints.isNotEmpty) {
          // Sumamos la distancia recorrida en este paso
          double stepDistance = _distanceCalculator.as(LengthUnit.Meter, _routePoints.last, newPoint);
          _totalDistance += stepDistance;
        }
        
        _currentPosition = newPoint;
        _routePoints.add(newPoint);

        // --- CÁLCULO DE ESTADÍSTICAS EN TIEMPO REAL ---

        // 1. Guardar historial para el Rolling 1k
        _history.add((dist: _totalDistance, time: _duration));

        // 2. Calcular Mejor Kilómetro "Rolling" (El tramo más rápido)
        // Buscamos en el pasado el primer punto que esté a 1000m o más de distancia
        for (var point in _history) {
          if (_totalDistance - point.dist >= 1000) {
            // Hemos encontrado un tramo de 1km exacto (o casi) desde 'point' hasta 'ahora'
            Duration tramoTime = _duration - point.time;
            
            // Si es el primer km que completamos O es más rápido que el récord actual:
            if (_bestRolling1k == null || tramoTime < _bestRolling1k!) {
              _bestRolling1k = tramoTime;
            }
            // Importante: Rompemos el bucle porque queremos el tramo más reciente de 1km
            break; 
          }
        }

        // 3. Calcular Splits (Kilómetros Redondos: 1, 2, 3...)
        // Si hemos superado el siguiente km entero (ej: pasamos de 998m a 1002m)
        int currentKmIndex = _totalDistance ~/ 1000; // División entera (ej: 1500m -> 1)
        if (currentKmIndex > _kmSplits.length) {
          // Acabamos de completar un nuevo kilómetro
          Duration tiempoDeEsteKm = _duration - _lastSplitTime;
          _kmSplits.add(tiempoDeEsteKm);
          _lastSplitTime = _duration; // Guardamos la referencia para el siguiente
          
          // Opcional: Mostrar un mensajito rápido (SnackBar)
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

    // Buscamos el mejor split "redondo"
    Duration? bestSplit;
    if (_kmSplits.isNotEmpty) {
      // Ordenamos la lista para encontrar el menor tiempo
      // (Hacemos una copia para no desordenar la original)
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

                // Mejor Km Redondo (Split)
                _buildStatRow(
                  "Mejor Km Redondo:", 
                  bestSplit != null ? _formatTime(bestSplit) : "--:--"
                ),
                
                // Mostrar todos los splits si hay espacio
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

  // Pequeño widget para hacer filas de texto bonitas en el resumen
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