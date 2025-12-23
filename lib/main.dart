import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart'; // Importamos el GPS

void main() {
  runApp(const RunningLeagueApp());
}

class RunningLeagueApp extends StatelessWidget {
  const RunningLeagueApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Running League',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const MapScreen(),
    );
  }
}

// CAMBIO IMPORTANTE: Ahora usamos StatefulWidget porque el mapa se va a mover
class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  // Este "controlador" es como el mando a distancia del mapa
  final MapController _mapController = MapController();
  
  // Variable para guardar dónde estamos (empieza siendo null)
  LatLng? _myLocation;

  // Función mágica para pedir permiso y obtener coordenadas
  Future<void> _getCurrentLocation() async {
    // 1. Verificar si los servicios de ubicación están activados
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return Future.error('El GPS está desactivado.');
    }

    // 2. Pedir permiso al usuario
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return Future.error('Permisos denegados');
      }
    }

    // 3. Obtener la posición actual
    Position position = await Geolocator.getCurrentPosition();
    
    // 4. Actualizar el estado de la app
    setState(() {
      _myLocation = LatLng(position.latitude, position.longitude);
    });

    // 5. Mover el mapa a tu posición
    _mapController.move(_myLocation!, 17.0); // 17 es mucho zoom
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Running League GPS')),
      body: FlutterMap(
        mapController: _mapController, // Conectamos el mando a distancia
        options: const MapOptions(
          initialCenter: LatLng(40.4168, -3.7038), // Madrid por defecto
          initialZoom: 15.0,
        ),
        children: [
          TileLayer(
            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
            userAgentPackageName: 'com.running.league',
          ),
          // Si tenemos ubicación, pintamos un marcador (un punto azul)
          if (_myLocation != null)
            MarkerLayer(
              markers: [
                Marker(
                  point: _myLocation!,
                  width: 80,
                  height: 80,
                  child: const Icon(
                    Icons.location_pin,
                    color: Colors.red,
                    size: 40,
                  ),
                ),
              ],
            ),
        ],
      ),
      // Botón flotante para activar el GPS
      floatingActionButton: FloatingActionButton(
        onPressed: _getCurrentLocation, // Al pulsar, llama a la función GPS
        child: const Icon(Icons.my_location),
      ),
    );
  }
}