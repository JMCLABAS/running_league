const { onSchedule } = require("firebase-functions/v2/scheduler");
const admin = require("firebase-admin");

admin.initializeApp();

// ======================================================
// 1. BONUS SEMANAL (Se ejecuta Domingos a las 23:59)
// ======================================================
exports.repartirBonusSemanal = onSchedule(
    { schedule: "59 23 * * 0", timeZone: "Europe/Madrid" },
    async (event) => {
        console.log("🏆 SEMANAL: Iniciando reparto...");
        
        // Calculamos la fecha de hace 7 días exactos
        const fechaInicio = new Date();
        fechaInicio.setDate(fechaInicio.getDate() - 7);
        const timestampInicio = admin.firestore.Timestamp.fromDate(fechaInicio);

        await procesarReparto(timestampInicio, 500, "🏆 CAMPEÓN SEMANAL (+500)");
        
        console.log("✅ SEMANAL: Finalizado.");
    }
);

// ======================================================
// 2. BONUS MENSUAL (Se ejecuta día 1 de mes a las 00:00)
// ======================================================
exports.repartirBonusMensual = onSchedule(
    { schedule: "0 0 1 * *", timeZone: "Europe/Madrid" },
    async (event) => {
        console.log("🌟 MENSUAL: Iniciando reparto...");
        
        // Calculamos el inicio del mes ANTERIOR
        const fechaInicio = new Date();
        fechaInicio.setMonth(fechaInicio.getMonth() - 1); 
        fechaInicio.setDate(1); // Día 1
        fechaInicio.setHours(0, 0, 0, 0); // Hora 00:00
        
        const timestampInicio = admin.firestore.Timestamp.fromDate(fechaInicio);

        await procesarReparto(timestampInicio, 2000, "🌟 CAMPEÓN MENSUAL (+2000)");

        console.log("✅ MENSUAL: Finalizado.");
    }
);


// --- LÓGICA COMÚN (IGUAL QUE ANTES) ---
async function procesarReparto(fechaInicio, puntosPremio, tituloPremio) {
    const db = admin.firestore();
    const ahora = admin.firestore.Timestamp.now();

    // 1. Obtener todas las ligas
    const ligasSnapshot = await db.collection("leagues").get();

    // 2. Recorrer liga por liga
    for (const ligaDoc of ligasSnapshot.docs) {
        const ligaId = ligaDoc.id;
        const nombreLiga = ligaDoc.data().nombre;

        // 3. Buscar actividades
        const actividadesSnapshot = await db.collection("activities")
            .where("leagueId", "==", ligaId)
            .where("fecha", ">=", fechaInicio)
            .get();

        if (actividadesSnapshot.empty) continue;

        // 4. Sumar distancias (IGNORANDO actividades que sean bonus)
        let ranking = {}; 
        
        actividadesSnapshot.forEach(doc => {
            const data = doc.data();
            if (!data.esBonus && data.distanciaKm > 0) {
                const uid = data.userId;
                const dist = data.distanciaKm || 0;
                
                if (!ranking[uid]) ranking[uid] = 0;
                ranking[uid] += dist;
            }
        });

        // 5. Encontrar al ganador
        let ganadorId = null;
        let maxDistancia = -1;

        for (const [uid, dist] of Object.entries(ranking)) {
            if (dist > maxDistancia) {
                maxDistancia = dist;
                ganadorId = uid;
            }
        }

        // 6. Dar el premio
        if (ganadorId && maxDistancia > 0) {
            console.log(`Ganador en ${nombreLiga}: ${ganadorId} (${maxDistancia.toFixed(2)}km) -> ${tituloPremio}`);
            
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
}