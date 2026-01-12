/// Motor de reglas de negocio para la gamificación.
///
/// Esta clase encapsula la lógica pura de cálculo de puntuaciones.
/// Es estática y determinista (Pure Function): para una misma entrada (distancia + config),
/// siempre devuelve el mismo resultado, lo que facilita los Tests Unitarios.
class ScoreCalculator {
  
  /// Calcula el puntaje total y genera la traza de auditoría (desglose)
  /// aplicando las estrategias definidas en la configuración de la liga.
  static Map<String, dynamic> calculate({
    required double distanceKm,
    required Map<String, dynamic> leagueConfig, 
  }) {
    double points = 0;
    List<String> breakdown = [];
    
    String mode = leagueConfig['modo'] ?? 'FIJO';

    // --- 1. CÁLCULO BASE (CORE SCORING) ---
    
    if (mode == 'FIJO') {
      // Estrategia Lineal (Flat Rate).
      // Recompensa constante para incentivar volumen base sin complejidad.
      double base = distanceKm * 10;
      points += base;
      breakdown.add("Base Fija (${base.toStringAsFixed(0)})");
    } 
    else if (mode == 'HORQUILLAS') {
      // Algoritmo Progresivo (Tiered System).
      // Diseñado para incentivar la resistencia (Endurance): el valor marginal
      // de cada km aumenta a medida que la distancia total crece.
      
      double remainingDist = distanceKm;
      double currentPoints = 0;
      int multiplier = 5; // Multiplicador base inicial

      // Procesamiento iterativo por bloques de distancia
      while (remainingDist > 0) {
        // Determinamos el tamaño del bloque actual (Max 5km por tier)
        double distInThisBlock = (remainingDist > 5) ? 5 : remainingDist;

        // Acumulación de puntos ponderados
        currentPoints += distInThisBlock * multiplier;

        remainingDist -= distInThisBlock;

        // Escaldado del multiplicador para el siguiente tier.
        // Implementa una saturación (Cap) en 100 puntos/km para evitar inflación descontrolada.
        if (multiplier < 100) {
          multiplier += 5;
        }
      }

      points += currentPoints;
      breakdown.add("Base Horquillas (${currentPoints.toStringAsFixed(0)})");
    }

    // --- 2. SISTEMA DE LOGROS (MILESTONES) ---
    // Bonificaciones estáticas por alcanzar umbrales estándar del atletismo.
    
    // Half Marathon Threshold
    if (distanceKm >= 21) {
      points += 50;
      breakdown.add("Bonus Media Maratón (+50)");
    }

    // Marathon Threshold
    if (distanceKm >= 42) {
      points += 100;
      breakdown.add("Bonus Maratón (+100)");
      
      // Incentivo adicional para usuarios en modo Progresivo
      if (mode == 'HORQUILLAS') {
        points += 100;
        breakdown.add("Extra Horquillas Maratón (+100)");
      }
    }

    return {
      "totalPoints": points.round(),
      "breakdown": breakdown,
    };
  }
}