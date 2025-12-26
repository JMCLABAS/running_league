import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'score_calculator.dart'; // Importa el archivo anterior

class RunningService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Esta función se llama UNA vez al terminar de correr.
  /// Guarda el resultado en TODAS las ligas del usuario.
  Future<void> saveRunToAllLeagues({
    required double distanceKm,
    required int durationSeconds,
  }) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception("Usuario no logueado");

    // 1. Buscar en qué ligas participa el usuario
    //    Esto es muy rápido en Firestore gracias a los índices.
    final leaguesSnapshot = await _db
        .collection('leagues')
        .where('participantes', arrayContains: user.uid)
        .get();

    if (leaguesSnapshot.docs.isEmpty) {
      print("El usuario corrió pero no está en ninguna liga.");
      // Opcional: Guardar en un historial personal sin liga
      return;
    }

    // 2. Iniciar un "Batch" (Lote)
    //    El Batch asegura que se guarden TODAS o NINGUNA. 
    //    Si falla una liga, no queremos datos corruptos.
    WriteBatch batch = _db.batch();

    // 3. Iterar por cada liga encontrada
    for (var leagueDoc in leaguesSnapshot.docs) {
      final leagueData = leagueDoc.data();
      final String leagueId = leagueDoc.id;
      final config = leagueData['configuracionPuntos'] as Map<String, dynamic>;

      // 4. Calcular puntos SEGÚN LAS REGLAS DE ESA LIGA
      final result = ScoreCalculator.calculate(
        distanceKm: distanceKm,
        leagueConfig: config,
      );

      // 5. Crear el documento de actividad para esa liga
      //    Usamos .doc() vacío para generar un ID automático
      DocumentReference newActivityRef = _db.collection('activities').doc();

      batch.set(newActivityRef, {
        "userId": user.uid,
        "leagueId": leagueId, // Importante para filtrar luego
        "fecha": FieldValue.serverTimestamp(),
        "distanciaKm": distanceKm,
        "tiempoSegundos": durationSeconds,
        "ritmoMinKm": (durationSeconds / 60) / distanceKm, // Ritmo medio
        
        // Los puntos calculados específicamente para esta liga
        "puntosGanados": result['totalPoints'],
        "desglosePuntos": result['breakdown'],
      });
      
      // Opcional: Actualizar un contador total dentro del documento del usuario en la liga
      // (Para esto necesitaríamos una estructura de 'members' más compleja, 
      //  por ahora lo dejamos en guardar la actividad).
    }

    // 6. Ejecutar el guardado masivo
    await batch.commit();
  }
}