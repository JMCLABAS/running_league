import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'score_calculator.dart'; 

/// Servicio de Dominio: Gestión de Actividades.
///
/// Actúa como capa de orquestación entre la captura de datos físicos (sensores)
/// y la persistencia distribuida en la nube. Implementa el patrón "Fan-out on Write"
/// para replicar una única actividad física en múltiples contextos de juego (ligas).
class RunningService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Procesa y persiste una sesión de entrenamiento en todas las ligas activas del usuario.
  ///
  /// Utiliza una estrategia de escritura por lotes (Batch Write) para garantizar
  /// la atomicidad de la transacción: o se guardan los puntos en todas las ligas, o en ninguna.
  ///
  /// Retorna un resumen (DTO) para la visualización inmediata del "Recibo" en la UI.
  Future<List<Map<String, dynamic>>> saveRunToAllLeagues({
    required double distanceKm,
    required int durationSeconds,
  }) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception("Error de sesión: Usuario no autenticado");

    // Recuperación de suscripciones activas (Tenants del usuario)
    final leaguesSnapshot = await _db
        .collection('leagues')
        .where('participantes', arrayContains: user.uid)
        .get();

    if (leaguesSnapshot.docs.isEmpty) {
      return []; // Early return: Sin contexto de juego activo
    }

    // Iniciamos transacción atómica para minimizar RTT (Round Trip Time) y asegurar consistencia
    WriteBatch batch = _db.batch();
    List<Map<String, dynamic>> summaryResults = []; 

    // Patrón Fan-out: Iteramos sobre cada contexto de liga para aplicar sus reglas específicas
    for (var leagueDoc in leaguesSnapshot.docs) {
      final leagueData = leagueDoc.data();
      final String leagueId = leagueDoc.id;
      final config = leagueData['configuracionPuntos'] as Map<String, dynamic>;

      // Delegación de lógica de negocio pura a motor de cálculo (Strategy Pattern implícito)
      final result = ScoreCalculator.calculate(
        distanceKm: distanceKm,
        leagueConfig: config,
      );

      // Preparación del documento (Payload)
      DocumentReference newActivityRef = _db.collection('activities').doc();
      
      batch.set(newActivityRef, {
        "userId": user.uid,
        "leagueId": leagueId,
        "fecha": FieldValue.serverTimestamp(), // Timestamp canónico del servidor
        "distanciaKm": distanceKm,
        "tiempoSegundos": durationSeconds,
        "ritmoMinKm": (durationSeconds / 60) / distanceKm, // Métrica derivada para análisis
        "puntosGanados": result['totalPoints'],
        "desglosePuntos": result['breakdown'], // Traza de auditoría de los puntos
      });

      // Construcción del DTO de respuesta para la Capa de Presentación
      summaryResults.add({
        "leagueName": leagueData['nombre'] ?? "Liga sin nombre",
        "points": result['totalPoints'],
        "breakdown": result['breakdown']
      });
    }

    // Commit Atómico: Ejecuta todas las escrituras en una sola operación de red
    await batch.commit();

    return summaryResults;
  }
}