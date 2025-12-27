import 'package:flutter/material.dart';

class RunSummaryScreen extends StatelessWidget {
  final double distanceKm;
  final Duration duration;
  final List<Map<String, dynamic>> leagueResults;

  const RunSummaryScreen({
    super.key,
    required this.distanceKm,
    required this.duration,
    required this.leagueResults,
  });

  String _formatDuration(Duration d) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    return "${twoDigits(d.inHours)}:${twoDigits(d.inMinutes.remainder(60))}:${twoDigits(d.inSeconds.remainder(60))}";
  }

  @override
  Widget build(BuildContext context) {
    // Calculamos el total de puntos ganados hoy sumando todas las ligas
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
            // --- HEADER DE FELICITACIÓN ---
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
            
            // --- RESUMEN FÍSICO ---
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _statBadge("${distanceKm.toStringAsFixed(2)} km", "Distancia"),
                const SizedBox(width: 20),
                _statBadge(_formatDuration(duration), "Tiempo"),
              ],
            ),
            
            const SizedBox(height: 30),
            
            // --- LISTA DE PUNTOS POR LIGA ---
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
                      // BOTÓN DE CONTINUAR
                      SizedBox(
                        width: double.infinity,
                        height: 55,
                        child: ElevatedButton(
                          onPressed: () {
                            Navigator.pop(context); // Cierra esta pantalla y vuelve al mapa
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

  Widget _statBadge(String value, String label) {
    return Column(
      children: [
        Text(value, style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12)),
      ],
    );
  }
}