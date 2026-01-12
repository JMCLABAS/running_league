import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

/// Pantalla de perfil público de un corredor.
/// Muestra estadísticas agregadas (distancia total, ritmo medio) y el historial
/// de actividades recientes del usuario seleccionado.
class PlayerProfileScreen extends StatelessWidget {
  final String userId;
  final String userName; // Nombre pasado por parámetro para visualización inmediata (Optimistic UI)

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
      // FutureBuilder para cargar los datos del perfil de forma asíncrona
      body: FutureBuilder<QuerySnapshot>(
        // Recuperamos el historial completo de actividades del usuario para calcular los totales.
        // Nota: En una aplicación a gran escala, sería recomendable mantener contadores
        // agregados en el documento del usuario para evitar leer toda la colección 'activities'.
        future: FirebaseFirestore.instance
            .collection('activities')
            .where('userId', isEqualTo: userId)
            .get(), 
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return _buildEmptyProfile();
          }

          // Procesamiento de datos en el cliente
          final docs = snapshot.data!.docs;
          
          // Ordenación en memoria por fecha descendente.
          // Esto evita la necesidad de un índice compuesto en Firestore para este prototipo.
          docs.sort((a, b) {
            Timestamp tA = a['fecha'];
            Timestamp tB = b['fecha'];
            return tB.compareTo(tA); 
          });

          double totalKm = 0;
          double totalSeconds = 0;
          int totalRuns = docs.length;

          for (var doc in docs) {
            totalKm += (doc['distanciaKm'] as num).toDouble();
            totalSeconds += (doc['tiempoSegundos'] as num).toDouble();
          }

          // Cálculo del ritmo medio histórico (min/km)
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
                // Avatar y Nombre del Usuario
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

                // Sección de Estadísticas Clave (KPIs)
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
                
                // Historial de Actividades Recientes
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
                        shrinkWrap: true, // Necesario para que el ListView funcione dentro de un SingleChildScrollView
                        physics: const NeverScrollableScrollPhysics(), // Desactiva el scroll propio del ListView
                        itemCount: docs.length > 10 ? 10 : docs.length, // Limitamos a las últimas 10 actividades
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

  /// Construye una vista para perfiles sin actividad registrada.
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

/// Widget interno para mostrar una tarjeta de estadística individual.
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