const { onSchedule } = require("firebase-functions/v2/scheduler");
const admin = require("firebase-admin");

admin.initializeApp();

/**
 * Cron Job: Cierre Semanal de Ligas.
 * Se ejecuta cada domingo a las 23:59 (Hora Madrid).
 * Objetivo: Calcular el volumen de km de los últimos 7 días y premiar al líder.
 */
exports.repartirBonusSemanal = onSchedule(
    { schedule: "59 23 * * 0", timeZone: "Europe/Madrid" },
    async (event) => {
        console.log("🏆 SEMANAL: Iniciando proceso de evaluación...");
        
        // Ventana de evaluación: Últimos 7 días naturales (Rolling window)
        const fechaInicio = new Date();
        fechaInicio.setDate(fechaInicio.getDate() - 7);
        const timestampInicio = admin.firestore.Timestamp.fromDate(fechaInicio);

        await procesarReparto(timestampInicio, 500, "🏆 CAMPEÓN SEMANAL (+500)");
        
        console.log("✅ SEMANAL: Proceso completado exitosamente.");
    }
);

/**
 * Cron Job: Cierre Mensual de Ligas.
 * Se ejecuta el día 1 de cada mes a las 00:00 (Hora Madrid).
 * Objetivo: Calcular el volumen del mes natural anterior completo.
 */
exports.repartirBonusMensual = onSchedule(
    { schedule: "0 0 1 * *", timeZone: "Europe/Madrid" },
    async (event) => {
        console.log("🌟 MENSUAL: Iniciando proceso de evaluación...");
        
        // Determinamos el rango del mes anterior completo (Día 1 00:00)
        const fechaInicio = new Date();
        fechaInicio.setMonth(fechaInicio.getMonth() - 1); 
        fechaInicio.setDate(1); 
        fechaInicio.setHours(0, 0, 0, 0); 
        
        const timestampInicio = admin.firestore.Timestamp.fromDate(fechaInicio);

        await procesarReparto(timestampInicio, 2000, "🌟 CAMPEÓN MENSUAL (+2000)");

        console.log("✅ MENSUAL: Proceso completado exitosamente.");
    }
);


/**
 * Lógica central de agregación y asignación de recompensas.
 * * Estrategia:
 * 1. Recupera actividades crudas en el rango de fechas.
 * 2. Realiza una agregación en memoria por `userId` (eficiente para el tamaño actual de las ligas).
 * 3. Aplica filtros de integridad (excluye bonus previos).
 * 4. Escribe el premio como una nueva transacción en el ledger de actividades.
 * * @param {admin.firestore.Timestamp} fechaInicio - Inicio del rango de evaluación.
 * @param {number} puntosPremio - Cantidad de puntos a otorgar.
 * @param {string} tituloPremio - Etiqueta para el desglose en UI.
 */
async function procesarReparto(fechaInicio, puntosPremio, tituloPremio) {
    const db = admin.firestore();
    const ahora = admin.firestore.Timestamp.now();

    const ligasSnapshot = await db.collection("leagues").get();

    // Procesamiento secuencial por liga para evitar condiciones de carrera en escrituras masivas
    for (const ligaDoc of ligasSnapshot.docs) {
        const ligaId = ligaDoc.id;
        const nombreLiga = ligaDoc.data().nombre;

        // Query optimizada con índice compuesto (leagueId + fecha)
        const actividadesSnapshot = await db.collection("activities")
            .where("leagueId", "==", ligaId)
            .where("fecha", ">=", fechaInicio)
            .get();

        if (actividadesSnapshot.empty) continue;

        let ranking = {}; 
        
        actividadesSnapshot.forEach(doc => {
            const data = doc.data();
            
            // FILTRO DE SEGURIDAD:
            // Excluimos registros con flag 'esBonus' para evitar bucles de retroalimentación
            // donde ganar un premio facilite ganar el siguiente. Solo cuenta el esfuerzo físico real.
            if (!data.esBonus && data.distanciaKm > 0) {
                const uid = data.userId;
                const dist = data.distanciaKm || 0;
                
                // Agregación (Sum)
                if (!ranking[uid]) ranking[uid] = 0;
                ranking[uid] += dist;
            }
        });

        // Determinación del ganador (Max)
        let ganadorId = null;
        let maxDistancia = -1;

        for (const [uid, dist] of Object.entries(ranking)) {
            if (dist > maxDistancia) {
                maxDistancia = dist;
                ganadorId = uid;
            }
        }

        // Commit del premio
        if (ganadorId && maxDistancia > 0) {
            console.log(`[AUDIT] Ganador en ${nombreLiga}: ${ganadorId} (${maxDistancia.toFixed(2)}km) -> ${tituloPremio}`);
            
            // Insertamos el bonus como una actividad sintética para mantener consistencia en el historial
            await db.collection("activities").add({
                userId: ganadorId,
                leagueId: ligaId,
                fecha: ahora,
                distanciaKm: 0,
                tiempoSegundos: 0,
                puntosGanados: puntosPremio,
                desglosePuntos: [tituloPremio],
                esBonus: true // Importante: Marcado para ser ignorado en futuros cálculos
            });
        }
    }
}