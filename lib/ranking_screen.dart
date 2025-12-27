import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'player_profile_screen.dart'; // Asegúrate de que este archivo existe

class RankingScreen extends StatelessWidget {
  final String leagueId;
  final Map<String, dynamic> leagueData;

  const RankingScreen({
    super.key,
    required this.leagueId,
    required this.leagueData,
  });

  @override
  Widget build(BuildContext context) {
    // Lista de UIDs de los participantes
    final List<dynamic> participants = leagueData['participantes'] ?? [];

    return Scaffold(
      appBar: AppBar(
        title: Text(leagueData['nombre'] ?? 'Ranking'),
        backgroundColor: Colors.blueAccent,
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<QuerySnapshot>(
        // 1. Escuchamos TODAS las actividades de esta liga en tiempo real
        stream: FirebaseFirestore.instance
            .collection('activities')
            .where('leagueId', isEqualTo: leagueId)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return const Center(child: Text("Error cargando puntuaciones"));
          }

          final activities = snapshot.data?.docs ?? [];

          // 2. AGREGACIÓN DE PUNTOS EN MEMORIA
          // Mapa: { 'uid_usuario': 1500 puntos, 'otro_uid': 500 puntos }
          Map<String, int> scores = {};

          // Inicializamos a todos con 0 puntos para que aparezcan aunque no hayan corrido
          for (var uid in participants) {
            scores[uid.toString()] = 0;
          }

          // Sumamos los puntos de las actividades
          for (var doc in activities) {
            final data = doc.data() as Map<String, dynamic>;
            final uid = data['userId'];
            final points = (data['puntosGanados'] as num?)?.toInt() ?? 0;

            if (scores.containsKey(uid)) {
              scores[uid] = scores[uid]! + points;
            } else {
              // Si por error hay una actividad de alguien que ya no está en la liga
              scores[uid] = points;
            }
          }

          // 3. ORDENAR (De mayor a menor)
          // Convertimos el mapa a una lista para poder ordenarla
          List<MapEntry<String, int>> sortedRanking = scores.entries.toList()
            ..sort((a, b) => b.value.compareTo(a.value)); // b compareTo a = Descendente

          if (sortedRanking.isEmpty) {
            return const Center(child: Text("No hay participantes todavía."));
          }

          // 4. CONSTRUIR LA LISTA VISUAL
          return ListView.builder(
            itemCount: sortedRanking.length,
            padding: const EdgeInsets.all(16),
            itemBuilder: (context, index) {
              final uid = sortedRanking[index].key;
              final points = sortedRanking[index].value;
              final position = index + 1;

              // Widget especial para cargar el nombre del usuario
              return _UserRankingRow(
                uid: uid,
                points: points,
                position: position,
              );
            },
          );
        },
      ),
    );
  }
}

// --- WIDGET AUXILIAR PARA CARGAR EL NOMBRE DE CADA USUARIO ---
class _UserRankingRow extends StatelessWidget {
  final String uid;
  final int points;
  final int position;

  const _UserRankingRow({
    required this.uid,
    required this.points,
    required this.position,
  });

  @override
  Widget build(BuildContext context) {
    // Colores para el podio
    Color? badgeColor;
    double scale = 1.0;
    
    if (position == 1) {
      badgeColor = const Color(0xFFFFD700); // Oro
      scale = 1.1;
    } else if (position == 2) {
      badgeColor = const Color(0xFFC0C0C0); // Plata
    } else if (position == 3) {
      badgeColor = const Color(0xFFCD7F32); // Bronce
    } else {
      badgeColor = Colors.grey[200]; // Resto
    }

    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance.collection('users').doc(uid).get(),
      builder: (context, snapshot) {
        String displayName = "Cargando..."; 
        String? avatarUrl;

        if (snapshot.hasData && snapshot.data!.exists) {
          final data = snapshot.data!.data() as Map<String, dynamic>?;
          displayName = data?['displayName'] ?? data?['name'] ?? data?['nickname'] ?? "Corredor Desconocido";
          avatarUrl = data?['photoURL'];
        } else if (snapshot.connectionState == ConnectionState.done) {
            displayName = "Runner ${uid.substring(0, 5)}"; 
        }

        return Transform.scale(
          scale: scale,
          child: Card(
            elevation: position <= 3 ? 4 : 1,
            margin: const EdgeInsets.symmetric(vertical: 8),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(15),
              side: position == 1 ? const BorderSide(color: Color(0xFFFFD700), width: 2) : BorderSide.none
            ),
            child: ListTile(
              // --- NAVEGACIÓN AL PERFIL AL TOCAR ---
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => PlayerProfileScreen(
                      userId: uid,
                      userName: displayName,
                    ),
                  ),
                );
              },
              // -------------------------------------
              leading: CircleAvatar(
                backgroundColor: badgeColor,
                foregroundImage: avatarUrl != null ? NetworkImage(avatarUrl) : null,
                child: avatarUrl == null 
                  ? Text("#$position", style: TextStyle(color: position <= 3 ? Colors.white : Colors.black87, fontWeight: FontWeight.bold))
                  : null,
              ),
              title: Text(
                displayName,
                style: TextStyle(
                  fontWeight: position == 1 ? FontWeight.w900 : FontWeight.bold,
                  fontSize: position == 1 ? 18 : 16,
                ),
              ),
              trailing: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.blueAccent.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  "$points pts",
                  style: const TextStyle(
                    color: Colors.blueAccent,
                    fontWeight: FontWeight.w900,
                    fontSize: 16,
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}