import 'dart:math' as math;

/// Fonction de saturation appliquée à la somme brute accumulée d'un
/// trait (avant IDF) — corrige la fréquence dans l'*historique* (l'IDF
/// corrige déjà la fréquence dans le *catalogue*, un axe différent).
/// Sans elle, un trait présent dans 22 œuvres sur 33 accumule
/// mécaniquement 22 fois plus de poids brut qu'un trait présent 1 seule
/// fois, quelle que soit sa rareté globale.
///
/// `none` existe pour isoler d'autres comportements en test (décroissance
/// temporelle, IDF) sans l'effet non linéaire de la saturation — ce
/// n'est pas un réglage recommandé en usage réel.
enum AccumulationSaturation {
  none,
  sqrt,
  log;

  /// Racine carrée ou logarithme de la magnitude, signe conservé —
  /// `sign(x) * f(|x|)`, jamais `f(x)` directement : un trait purement
  /// négatif (que des abandons précoces) doit rester négatif après
  /// saturation, pas changer de signe ni s'annuler par accident sur une
  /// magnitude proche de 0.
  double apply(double raw) {
    if (raw == 0) return 0;
    final sign = raw.isNegative ? -1.0 : 1.0;
    final magnitude = raw.abs();
    final saturated = switch (this) {
      AccumulationSaturation.none => magnitude,
      AccumulationSaturation.sqrt => math.sqrt(magnitude),
      // log1p (log(1+x)) : jamais négatif ni indéfini même pour une
      // magnitude proche de 0, contrairement à log(x) seul.
      AccumulationSaturation.log => math.log(1 + magnitude),
    };
    return sign * saturated;
  }
}
