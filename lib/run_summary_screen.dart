import 'package:flutter/material.dart';

/// Pantalla de Recibo/Resumen Post-Entrenamiento.
///
/// Su objetivo es cerrar el ciclo de feedback (Gamification Loop) mostrando
/// inmediatamente la recompensa obtenida y las métricas físicas.
/// Actúa como confirmación visual de que los datos se han persistido correctamente.
class RunSummaryScreen extends StatelessWidget {
  final double distanceKm;
  final Duration duration;
  // Datos pre-calculados por el RunningService antes de la navegación
  final List<Map<String, dynamic>> leagueResults;

  const RunSummaryScreen({
    super.key,
    required this.distanceKm,
    required this.duration,
    required this.leagueResults,
  });

  /// Utilidad de formateo (HH:MM:SS) para consistencia en la presentación de métricas.
  String _formatDuration(Duration d) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    return "${twoDigits(d.inHours)}:${twoDigits(d.inMinutes.remainder(60))}:${twoDigits(d.inSeconds.remainder(60))}";
  }

  @override
  Widget build(BuildContext context) {
    // Agregación de puntos totales para feedback inmediato (Reward Header)
    int totalPointsToday = 0;
    for (var res in leagueResults) {
      totalPointsToday += (res['points'] as int);
    }

    return Scaffold(
      backgroundColor: Colors.blueAccent,
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 40),
            
            // Sección de Refuerzo Positivo (Gamification Reward)
            const Icon(Icons.emoji_events, size: 80, color: Colors.yellowAccent),
            const SizedBox(height: 10),
            const Text(
              "¡ENTRENAMIENTO COMPLETADO!",
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 20,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 20),
            
            // KPIs de la sesión (Métricas Físicas)
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _statBadge("${distanceKm.toStringAsFixed(2)} km", "Distancia"),
                const SizedBox(width: 20),
                _statBadge(_formatDuration(duration), "Tiempo"),
              ],
            ),
            
            const SizedBox(height: 30),
            
            // Contenedor principal de detalles (Patrón visual "Bottom Sheet" persistente)
            Expanded(
              child: Container(
                width: double.infinity,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(30),
                    topRight: Radius.circular(30),
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "Resultados de Ligas",
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey),
                      ),
                      const SizedBox(height: 10),
                      
                      // Manejo de Estado Vacío (Empty State) para UX
                      if (leagueResults.isEmpty)
                        const Center(
                          child: Padding(
                            padding: EdgeInsets.all(20.0),
                            child: Text("No estás en ninguna liga aún.\n¡Únete a una para ganar puntos!"),
                          ),
                        ),

                      Expanded(
                        child: ListView.builder(
                          itemCount: leagueResults.length,
                          itemBuilder: (context, index) {
                            final item = leagueResults[index];
                            final breakdown = item['breakdown'] as List<dynamic>;

                            return Card(
                              elevation: 2,
                              margin: const EdgeInsets.only(bottom: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                              // UI Tweak: Eliminamos los bordes por defecto del ExpansionTile para un look más limpio
                              child: Theme(
                                data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                                child: ExpansionTile(
                                  leading: const CircleAvatar(
                                    backgroundColor: Colors.blueAccent,
                                    child: Icon(Icons.star, color: Colors.white, size: 20),
                                  ),
                                  title: Text(
                                    item['leagueName'],
                                    style: const TextStyle(fontWeight: FontWeight.bold),
                                  ),
                                  trailing: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                    decoration: BoxDecoration(
                                      color: Colors.green[50],
                                      borderRadius: BorderRadius.circular(10)
                                    ),
                                    child: Text(
                                      "+${item['points']}",
                                      style: TextStyle(color: Colors.green[800], fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                  // Desglose de la lógica de puntuación (Auditoría para el usuario)
                                  children: breakdown.map((reason) => ListTile(
                                    dense: true,
                                    leading: const Icon(Icons.add_circle_outline, size: 16, color: Colors.green),
                                    title: Text(reason.toString(), style: TextStyle(color: Colors.grey[700])),
                                  )).toList(),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      
                      const SizedBox(height: 10),
                      
                      // Navegación de retorno al Hub principal
                      SizedBox(
                        width: double.infinity,
                        height: 55,
                        child: ElevatedButton(
                          onPressed: () {
                            Navigator.pop(context); 
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blueAccent,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                            elevation: 5,
                          ),
                          child: const Text("VOLVER AL MAPA", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        ),
                      )
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Componente reutilizable para métricas de cabecera.
  Widget _statBadge(String value, String label) {
    return Column(
      children: [
        Text(value, style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12)),
      ],
    );
  }
}