import 'dart:async'; // Para manejar el stream del GPS
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart'; // Mapas
import 'package:latlong2/latlong.dart'; // Coordenadas
import 'package:geolocator/geolocator.dart'; // GPS

void main() {
  runApp(const RunningLeagueApp());
}

class RunningLeagueApp extends StatelessWidget {
  const RunningLeagueApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Running League',
      debugShowCheckedModeBanner: false, // Quitamos la etiqueta "Debug" fea
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
  
  // Lista para guardar la ruta (la serpiente)
  final List<LatLng> _routePoints = [];
  
  // Tu posición actual
  LatLng? _currentPosition;
  
  // El "tubo" de datos del GPS
  StreamSubscription<Position>? _positionStream;
  
  // Estado de grabación
  bool _isTracking = false;

  // --- FUNCIÓN PARA EMPEZAR A CORRER ---
  Future<void> _startTracking() async {
    // 1. Verificar GPS encendido
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('El GPS está desactivado')),
      );
      return;
    }

    // 2. Verificar Permisos
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return; // Permisos denegados
      }
    }

    // 3. Limpiar ruta anterior y cambiar estado
    setState(() {
      _isTracking = true;
      _routePoints.clear(); 
    });

    // 4. Suscribirse al GPS (Stream)
    const LocationSettings locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high, // Máxima precisión
      distanceFilter: 2, // Notificar cada 2 metros
    );

    _positionStream = Geolocator.getPositionStream(locationSettings: locationSettings)
        .listen((Position position) {
      
      // Convertir datos del GPS a coordenadas del mapa
      LatLng newPoint = LatLng(position.latitude, position.longitude);
      
      setState(() {
        _currentPosition = newPoint;
        _routePoints.add(newPoint); // Añadir punto a la línea
      });

      // Mover la cámara para seguirte
      _mapController.move(newPoint, 17.0);
    });
  }

  // --- FUNCIÓN PARA PARAR ---
  void _stopTracking() {
    _positionStream?.cancel(); // Cortar conexión con GPS
    setState(() {
      _isTracking = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isTracking ? 'GRABANDO RUTA... 🔴' : 'Running League'),
        backgroundColor: _isTracking ? Colors.redAccent : Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: FlutterMap(
        mapController: _mapController,
        options: const MapOptions(
          // SEVILLA (La Giralda) como punto de inicio
          initialCenter: LatLng(37.3862, -5.9926), 
          initialZoom: 16.0,
        ),
        children: [
          // CAPA 1: El Mapa base (OpenStreetMap)
          TileLayer(
            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
            userAgentPackageName: 'com.running.league',
          ),
          
          // CAPA 2: La Línea Roja (Ruta)
          // CORRECCIÓN: Solo la dibujamos si la lista NO está vacía
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

          // CAPA 3 : Tu ubicación (Muñeco/Punto)
          if (_currentPosition != null)
            MarkerLayer(
              markers: [
                Marker(
                  point: _currentPosition!,
                  width: 80,
                  height: 80,
                  child: const Icon(
                    Icons.directions_run, // Icono de corredor
                    color: Colors.blue,
                    size: 40,
                    shadows: [Shadow(blurRadius: 10, color: Colors.black)],
                  ),
                ),
              ],
            ),
        ],
      ),
      // Botón flotante Play/Stop
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _isTracking ? _stopTracking : _startTracking,
        backgroundColor: _isTracking ? Colors.red : Colors.green,
        icon: Icon(_isTracking ? Icons.stop : Icons.play_arrow),
        label: Text(_isTracking ? 'PARAR' : 'EMPEZAR'),
      ),
    );
  }
}