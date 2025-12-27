import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class PlayerProfileScreen extends StatelessWidget {
  final String userId;
  final String userName; // Pasamos el nombre para mostrarlo mientras carga

  const PlayerProfileScreen({
    super.key,
    required this.userId,
    required this.userName,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text("Perfil de Corredor"),
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
      ),
      body: FutureBuilder<QuerySnapshot>(
        // Buscamos TODAS las actividades de este usuario (en cualquier liga)
        future: FirebaseFirestore.instance
            .collection('activities')
            .where('userId', isEqualTo: userId)
            .get(), // Traemos todas para calcular totales
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return _buildEmptyProfile();
          }

          // --- CÁLCULO DE ESTADÍSTICAS ---
          final docs = snapshot.data!.docs;
          
          // Ordenamos por fecha (de más reciente a más antigua)
          // Lo hacemos aquí en Dart para evitar crear índices complejos en Firestore ahora mismo
          docs.sort((a, b) {
            Timestamp tA = a['fecha'];
            Timestamp tB = b['fecha'];
            return tB.compareTo(tA); // Descendente
          });

          double totalKm = 0;
          double totalSeconds = 0;
          int totalRuns = docs.length;

          for (var doc in docs) {
            totalKm += (doc['distanciaKm'] as num).toDouble();
            totalSeconds += (doc['tiempoSegundos'] as num).toDouble();
          }

          // Ritmo medio histórico (min/km)
          String avgPace = "0:00";
          if (totalKm > 0) {
            double paceDecimal = (totalSeconds / 60) / totalKm;
            int min = paceDecimal.floor();
            int sec = ((paceDecimal - min) * 60).round();
            avgPace = "$min:${sec.toString().padLeft(2, '0')}";
          }

          return SingleChildScrollView(
            child: Column(
              children: [
                const SizedBox(height: 20),
                // --- CABECERA ---
                CircleAvatar(
                  radius: 50,
                  backgroundColor: Colors.blueAccent,
                  child: Text(
                    userName.isNotEmpty ? userName[0].toUpperCase() : "?",
                    style: const TextStyle(fontSize: 40, color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  userName,
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                ),
                const Text(
                  "Runner",
                  style: TextStyle(color: Colors.grey),
                ),
                
                const SizedBox(height: 20),

                // --- TARJETAS DE ESTADÍSTICAS ---
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Row(
                    children: [
                      _StatCard(title: "Distancia", value: "${totalKm.toStringAsFixed(1)} km", color: Colors.blue),
                      const SizedBox(width: 10),
                      _StatCard(title: "Ritmo Medio", value: avgPace, label: "min/km", color: Colors.orange),
                      const SizedBox(width: 10),
                      _StatCard(title: "Salidas", value: "$totalRuns", color: Colors.green),
                    ],
                  ),
                ),

                const SizedBox(height: 30),
                
                // --- LISTA DE CARRERAS RECIENTES ---
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(30),
                      topRight: Radius.circular(30),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "Actividad Reciente",
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 10),
                      ListView.separated(
                        shrinkWrap: true, // Importante dentro de SingleChildScrollView
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: docs.length > 10 ? 10 : docs.length, // Mostrar solo las ultimas 10
                        separatorBuilder: (_, __) => const Divider(),
                        itemBuilder: (context, index) {
                          final data = docs[index].data() as Map<String, dynamic>;
                          final km = (data['distanciaKm'] as num).toDouble();
                          final points = data['puntosGanados'] ?? 0;
                          final date = (data['fecha'] as Timestamp).toDate();
                          final dateStr = DateFormat('dd MMM - HH:mm', 'es').format(date);

                          return ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: Colors.grey[100],
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(Icons.directions_run, color: Colors.blueGrey),
                            ),
                            title: Text("${km.toStringAsFixed(2)} km", style: const TextStyle(fontWeight: FontWeight.bold)),
                            subtitle: Text(dateStr),
                            trailing: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text("+$points pts", style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                              ],
                            ),
                          );
                        },
                      )
                    ],
                  ),
                )
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildEmptyProfile() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircleAvatar(
            radius: 40,
            backgroundColor: Colors.grey[300],
            child: Text(userName.isNotEmpty ? userName[0] : "?", style: const TextStyle(fontSize: 30, color: Colors.white)),
          ),
          const SizedBox(height: 20),
          Text(userName, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          const Text("Este usuario aún no ha corrido.", style: TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final String? label;
  final Color color;

  const _StatCard({required this.title, required this.value, this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(15),
        ),
        child: Column(
          children: [
            Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color)),
            if (label != null) Text(label!, style: TextStyle(fontSize: 10, color: color)),
            const SizedBox(height: 4),
            Text(title, style: TextStyle(fontSize: 12, color: color.withOpacity(0.8))),
          ],
        ),
      ),
    );
  }
}