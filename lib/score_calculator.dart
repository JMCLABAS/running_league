class ScoreCalculator {
  
  /// Calcula los puntos y genera el desglose para UNA liga específica
  static Map<String, dynamic> calculate({
    required double distanceKm,
    required Map<String, dynamic> leagueConfig, 
  }) {
    double points = 0;
    List<String> breakdown = [];
    
    String mode = leagueConfig['modo'] ?? 'FIJO';

    // --- 1. CÁLCULO BASE ---
    if (mode == 'FIJO') {
      // Sistema Fijo: 10 ptos por Km
      double base = distanceKm * 10;
      points += base;
      breakdown.add("Base Fija (${base.toStringAsFixed(0)})");
    } 
    else if (mode == 'HORQUILLAS') {
      // Sistema Horquillas AUTOMÁTICO (Hasta el infinito)
      double remainingDist = distanceKm;
      double currentPoints = 0;
      int multiplier = 5; // Empezamos valiendo 5 puntos

      // Mientras quede distancia por calcular...
      while (remainingDist > 0) {
        // Cogemos un bloque de 5km o lo que quede si es menos
        double distInThisBlock = (remainingDist > 5) ? 5 : remainingDist;

        // Sumamos puntos: Distancia del bloque * Multiplicador actual
        currentPoints += distInThisBlock * multiplier;

        // Restamos la distancia ya calculada
        remainingDist -= distInThisBlock;

        // Subimos el precio del km para la siguiente vuelta (Max 100)
        // Regla: Si el multiplicador es menor de 100, sube 5. Si ya es 100, se queda igual.
        if (multiplier < 100) {
          multiplier += 5;
        }
      }

      points += currentPoints;
      breakdown.add("Base Horquillas (${currentPoints.toStringAsFixed(0)})");
    }

    // --- 2. BONUS INSTANTÁNEOS ---
    
    // Media Maratón
    if (distanceKm >= 21) {
      points += 50;
      breakdown.add("Bonus Media Maratón (+50)");
    }

    // Maratón
    if (distanceKm >= 42) {
      points += 100;
      breakdown.add("Bonus Maratón (+100)");
      
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