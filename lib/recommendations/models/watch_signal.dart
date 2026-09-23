/// Signal tiré d'un visionnage — cf. `TasteProfileBuilder` pour comment
/// il se transforme en poids de trait (amortissement temporel puis
/// pondération IDF).
enum WatchSignal {
  /// Revu au moins une fois (playCount > 1) — le signal le plus fiable :
  /// on ne revoit pas ce qu'on n'a pas aimé.
  rewatched,

  /// Terminé et marqué favori.
  completedFavorite,

  /// Terminé, sans marque de favori.
  completedNeutral,

  /// Abandonné avant 20% — négatif, jamais traité comme une absence de
  /// signal : un visionnage commencé puis vite arrêté est aussi
  /// informatif qu'un visionnage terminé.
  abandonedEarly,

  /// Abandonné après 80% sans avoir terminé — neutre, ignoré : trop
  /// d'explications possibles (interrompu, fin remise à plus tard...)
  /// pour en tirer un signal de goût fiable dans un sens ou l'autre.
  abandonedLate;

  /// Poids brut, avant amortissement temporel et pondération IDF —
  /// cf. [TasteProfileBuilder]. `abandonedEarly` est calé sur
  /// [completedFavorite] en valeur absolue : la consigne est que ce
  /// signal "compte autant que les positifs", pas qu'il soit anecdotique.
  double get baseWeight => switch (this) {
        WatchSignal.rewatched => 2.0,
        WatchSignal.completedFavorite => 1.5,
        WatchSignal.completedNeutral => 1.0,
        WatchSignal.abandonedEarly => -1.5,
        WatchSignal.abandonedLate => 0.0,
      };
}
