import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart'; // Importamos el mapa
import 'package:latlong2/latlong.dart'; // Importamos coordenadas

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

class MapScreen extends StatelessWidget {
  const MapScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Running League'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      // AQUÍ ESTÁ LA MAGIA: Sustituimos el texto por el Mapa
      body: FlutterMap(
        options: const MapOptions(
          // Coordenadas iniciales (Ejemplo: Puerta del Sol, Madrid)
          // Puedes cambiarlas por las de tu ciudad
          initialCenter: LatLng(40.4168, -3.7038),
          initialZoom: 15.0,
        ),
        children: [
          TileLayer(
            // Usamos los mapas gratuitos de OpenStreetMap
            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
            userAgentPackageName: 'com.running.league',
          ),
          // Aquí en el futuro añadiremos la línea roja de tu ruta (PolylineLayer)
        ],
      ),
    );
  }
}