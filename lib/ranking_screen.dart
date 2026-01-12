import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'player_profile_screen.dart';

/// Pantalla de Clasificación (Leaderboard).
///
/// Responsable de calcular y visualizar el ranking en tiempo real de una liga específica.
/// Implementa una estrategia de agregación en cliente (Client-side Aggregation) para
/// calcular los puntajes totales a partir del stream de actividades crudas.
///
/// Nota de Arquitectura: Para ligas con miles de usuarios, esta lógica debería
/// migrarse a Cloud Functions para mantener una colección desnormalizada de 'scores'.
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
    // Recuperamos la lista base de participantes para asegurar que todos aparezcan en la tabla,
    // incluso si tienen 0 puntos (Scoreboard inclusivo).
    final List<dynamic> participants = leagueData['participantes'] ?? [];

    return Scaffold(
      appBar: AppBar(
        title: Text(leagueData['nombre'] ?? 'Ranking'),
        backgroundColor: Colors.blueAccent,
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<QuerySnapshot>(
        // Suscripción reactiva a la colección de actividades filtrada por tenant (leagueId).
        stream: FirebaseFirestore.instance
            .collection('activities')
            .where('leagueId', isEqualTo: leagueId)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return const Center(child: Text("Error de sincronización de datos"));
          }

          final activities = snapshot.data?.docs ?? [];

          // Motor de Cálculo de Puntuaciones (In-Memory Aggregation)
          // Complejidad: O(N) donde N es el número de actividades.
          Map<String, int> scores = {};

          // Paso 1: Inicialización (Zero-filling)
          for (var uid in participants) {
            scores[uid.toString()] = 0;
          }

          // Paso 2: Acumulación (Reduce)
          for (var doc in activities) {
            final data = doc.data() as Map<String, dynamic>;
            final uid = data['userId'];
            final points = (data['puntosGanados'] as num?)?.toInt() ?? 0;

            if (scores.containsKey(uid)) {
              scores[uid] = scores[uid]! + points;
            } else {
              // Manejo de consistencia eventual: Si un usuario sale de la liga pero sus actividades persisten.
              scores[uid] = points;
            }
          }

          // Paso 3: Ordenación (Sort)
          // Orden descendente por valor (puntos).
          List<MapEntry<String, int>> sortedRanking = scores.entries.toList()
            ..sort((a, b) => b.value.compareTo(a.value)); 

          if (sortedRanking.isEmpty) {
            return const Center(child: Text("Esperando a los primeros corredores..."));
          }

          // Renderizado de Lista Optimizada
          return ListView.builder(
            itemCount: sortedRanking.length,
            padding: const EdgeInsets.all(16),
            itemBuilder: (context, index) {
              final uid = sortedRanking[index].key;
              final points = sortedRanking[index].value;
              final position = index + 1;

              // Delegamos el renderizado de cada fila a un widget especializado
              // que maneja la carga asíncrona de los perfiles de usuario.
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

/// Widget de fila de ranking con carga perezosa de metadatos de usuario.
/// Utiliza un FutureBuilder interno para resolver el nombre y avatar solo cuando es visible.
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
    // Lógica de Gamificación Visual (Podio)
    Color? badgeColor;
    double scale = 1.0;
    
    if (position == 1) {
      badgeColor = const Color(0xFFFFD700); // Oro
      scale = 1.05; // Resaltado sutil del líder
    } else if (position == 2) {
      badgeColor = const Color(0xFFC0C0C0); // Plata
    } else if (position == 3) {
      badgeColor = const Color(0xFFCD7F32); // Bronce
    } else {
      badgeColor = Colors.grey[200]; 
    }

    return FutureBuilder<DocumentSnapshot>(
      // Caché implícita de Firestore optimiza estas lecturas repetitivas
      future: FirebaseFirestore.instance.collection('users').doc(uid).get(),
      builder: (context, snapshot) {
        String displayName = "Cargando..."; 
        String? avatarUrl;

        if (snapshot.hasData && snapshot.data!.exists) {
          final data = snapshot.data!.data() as Map<String, dynamic>?;
          // Estrategia de Fallback para el nombre visual
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
              // Navegación Drill-down al perfil detallado
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