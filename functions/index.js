const functions = require("firebase-functions");
const admin = require("firebase-admin");

admin.initializeApp();

// ==========================================
// ÁRBITRO 1: BONUS SEMANAL (Domingos 23:59)
// ==========================================
exports.repartirBonusSemanal = functions.pubsub
  .schedule("59 23 * * 0")
  .timeZone("Europe/Madrid")
  .onRun(async (context) => {
    
    const db = admin.firestore();
    const ahora = admin.firestore.Timestamp.now();
    
    // Calcular hace 7 días
    const fechaInicio = new Date();
    fechaInicio.setDate(fechaInicio.getDate() - 7);
    const timestampInicio = admin.firestore.Timestamp.fromDate(fechaInicio);

    console.log("🏆 SEMANAL: Iniciando reparto...");

    const ligasSnapshot = await db.collection("leagues").get();

    for (const ligaDoc of ligasSnapshot.docs) {
      await procesarGanador(db, ligaDoc, timestampInicio, 500, "🏆 CAMPEÓN SEMANAL (+500)");
    }

    console.log("✅ SEMANAL: Finalizado.");
    return null;
  });

// ==========================================
// ÁRBITRO 2: BONUS MENSUAL (Día 1 a las 00:00)
// ==========================================
exports.repartirBonusMensual = functions.pubsub
  .schedule("0 0 1 * *")
  .timeZone("Europe/Madrid")
  .onRun(async (context) => {
    
    const db = admin.firestore();
    
    const fechaInicio = new Date();
    fechaInicio.setMonth(fechaInicio.getMonth() - 1); 
    fechaInicio.setDate(1);
    fechaInicio.setHours(0, 0, 0, 0);
    
    const timestampInicio = admin.firestore.Timestamp.fromDate(fechaInicio);

    console.log("🌟 MENSUAL: Iniciando reparto...");

    const ligasSnapshot = await db.collection("leagues").get();

    for (const ligaDoc of ligasSnapshot.docs) {
      await procesarGanador(db, ligaDoc, timestampInicio, 2000, "🌟 CAMPEÓN MENSUAL (+2000)");
    }

    console.log("✅ MENSUAL: Finalizado.");
    return null;
  });


// --- FUNCIÓN AUXILIAR ---
async function procesarGanador(db, ligaDoc, fechaInicio, puntosPremio, tituloPremio) {
  const ligaId = ligaDoc.id;
  const nombreLiga = ligaDoc.data().nombre;
  const ahora = admin.firestore.Timestamp.now();

  const actividadesSnapshot = await db.collection("activities")
    .where("leagueId", "==", ligaId)
    .where("fecha", ">=", fechaInicio)
    .get();

  if (actividadesSnapshot.empty) return;

  let ranking = {}; 
  actividadesSnapshot.forEach(doc => {
    const data = doc.data();
    if (!data.esBonus) {
        const uid = data.userId;
        const dist = data.distanciaKm || 0;
        if (!ranking[uid]) ranking[uid] = 0;
        ranking[uid] += dist;
    }
  });

  let ganadorId = null;
  let maxDistancia = -1;

  for (const [uid, dist] of Object.entries(ranking)) {
    if (dist > maxDistancia) {
      maxDistancia = dist;
      ganadorId = uid;
    }
  }

  if (ganadorId && maxDistancia > 0) {
    console.log(`Ganador en ${nombreLiga}: ${ganadorId} -> ${tituloPremio}`);
    
    await db.collection("activities").add({
      userId: ganadorId,
      leagueId: ligaId,
      fecha: ahora,
      distanciaKm: 0,
      tiempoSegundos: 0,
      puntosGanados: puntosPremio,
      desglosePuntos: [tituloPremio],
      esBonus: true
    });
  }
}