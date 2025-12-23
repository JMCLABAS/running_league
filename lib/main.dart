import 'dart:async'; // Necesario para el Timer del reloj
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart'; // Para cálculos de distancia
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
  
  // --- VARIABLES DE DATOS ---
  final List<LatLng> _routePoints = []; // La ruta visual
  LatLng? _currentPosition; // Dónde estás ahora
  
  double _totalDistance = 0.0; // Distancia acumulada (en metros)
  final Stopwatch _stopwatch = Stopwatch(); // El motor del cronómetro
  Duration _duration = Duration.zero; // El tiempo que mostramos en pantalla
  
  // --- HERRAMIENTAS TÉCNICAS ---
  StreamSubscription<Position>? _positionStream;
  Timer? _timer; // Un temporizador para actualizar la pantalla cada segundo
  final Distance _distanceCalculator = const Distance(); // Calculadora geodésica

  bool _isTracking = false;

  // --- EMPEZAR CARRERA ---
  Future<void> _startTracking() async {
    // 1. Verificaciones de GPS (igual que antes)
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return;

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return;
    }

    // 2. Resetear todo a CERO
    setState(() {
      _isTracking = true;
      _routePoints.clear();
      _totalDistance = 0.0;
      _duration = Duration.zero;
      _stopwatch.reset();
      _stopwatch.start(); // Arranca el reloj interno
    });

    // 3. Arrancamos el Timer visual (actualiza la pantalla cada 1 segundo)
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        _duration = _stopwatch.elapsed;
      });
    });

    // 4. Suscribirse al GPS
    const LocationSettings locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 3, // Actualizar cada 3 metros
    );

    _positionStream = Geolocator.getPositionStream(locationSettings: locationSettings)
        .listen((Position position) {
      
      LatLng newPoint = LatLng(position.latitude, position.longitude);
      
      setState(() {
        // CÁLCULO MATEMÁTICO:
        // Si ya teníamos un punto anterior, sumamos la distancia hasta el nuevo
        if (_routePoints.isNotEmpty) {
          _totalDistance += _distanceCalculator.as(
            LengthUnit.Meter, 
            _routePoints.last, 
            newPoint
          );
        }

        _currentPosition = newPoint;
        _routePoints.add(newPoint);
      });

      _mapController.move(newPoint, 17.0);
    });
  }

  // --- PARAR CARRERA ---
  void _stopTracking() {
    _positionStream?.cancel();
    _timer?.cancel(); // Paramos el refresco de pantalla
    _stopwatch.stop(); // Paramos el reloj interno
    setState(() {
      _isTracking = false;
    });
  }

  // Helper para formatear el tiempo bonito (00:00:00)
  String _formatTime(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final hours = twoDigits(duration.inHours);
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return "$hours:$minutes:$seconds";
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Usamos un Stack para poner el panel ENCIMA del mapa
      body: Stack(
        children: [
          // CAPA 1: EL MAPA (Al fondo)
          FlutterMap(
            mapController: _mapController,
            options: const MapOptions(
              initialCenter: LatLng(37.3862, -5.9926), // Sevilla
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

          // CAPA 2: EL DASHBOARD (Panel flotante)
          Positioned(
            top: 50, // Separado de arriba
            left: 20,
            right: 20,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.95), // Fondo blanco casi opaco
                borderRadius: BorderRadius.circular(20), // Bordes redondeados
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 10,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  // Columna TIEMPO
                  Column(
                    children: [
                      const Text('TIEMPO', 
                        style: TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.bold)
                      ),
                      Text(
                        _formatTime(_duration),
                        style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
                      ),
                    ],
                  ),
                  // Columna DISTANCIA
                  Column(
                    children: [
                      const Text('DISTANCIA (km)', 
                        style: TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.bold)
                      ),
                      Text(
                        (_totalDistance / 1000).toStringAsFixed(2), // Metros a KM (2 decimales)
                        style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: Colors.blue),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),

      // Botón flotante
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