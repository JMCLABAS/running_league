import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'score_calculator.dart'; 

class RunningService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Guarda la carrera y devuelve un informe de los puntos ganados en cada liga.
  Future<List<Map<String, dynamic>>> saveRunToAllLeagues({
    required double distanceKm,
    required int durationSeconds,
  }) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception("Usuario no logueado");

    // 1. Buscar ligas
    final leaguesSnapshot = await _db
        .collection('leagues')
        .where('participantes', arrayContains: user.uid)
        .get();

    if (leaguesSnapshot.docs.isEmpty) {
      return []; // No participa en ninguna liga
    }

    WriteBatch batch = _db.batch();
    List<Map<String, dynamic>> summaryResults = []; // <--- AQUÍ GUARDAMOS EL INFORME

    // 2. Iterar ligas y calcular
    for (var leagueDoc in leaguesSnapshot.docs) {
      final leagueData = leagueDoc.data();
      final String leagueId = leagueDoc.id;
      final config = leagueData['configuracionPuntos'] as Map<String, dynamic>;

      // Calcular puntos
      final result = ScoreCalculator.calculate(
        distanceKm: distanceKm,
        leagueConfig: config,
      );

      // Preparar dato para Firestore
      DocumentReference newActivityRef = _db.collection('activities').doc();
      batch.set(newActivityRef, {
        "userId": user.uid,
        "leagueId": leagueId,
        "fecha": FieldValue.serverTimestamp(),
        "distanciaKm": distanceKm,
        "tiempoSegundos": durationSeconds,
        "ritmoMinKm": (durationSeconds / 60) / distanceKm, 
        "puntosGanados": result['totalPoints'],
        "desglosePuntos": result['breakdown'],
      });

      // Añadir al informe para la pantalla de resumen
      summaryResults.add({
        "leagueName": leagueData['nombre'] ?? "Liga sin nombre",
        "points": result['totalPoints'],
        "breakdown": result['breakdown'] // Lista de strings (razones)
      });
    }

    // 3. Guardar todo en la nube
    await batch.commit();

    // 4. Devolver el informe al UI
    return summaryResults;
  }
}