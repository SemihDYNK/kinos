/// Ligne de métadonnées du bandeau — texte simple séparé par des points,
/// jamais de badges ni de pastilles : "2024 · 1h 30m · 4K · 7.6 · Comédie".
///
/// [extras] porte les jetons intermédiaires propres à chaque type
/// d'écran (durée puis résolution pour un film ; nombre de saisons puis
/// durée moyenne d'un épisode pour une série...) — dans l'ordre voulu par
/// l'appelant, entre l'année et la note.
String buildMediaMetaLine({
  int? year,
  List<String> extras = const [],
  double? communityRating,
  List<String> genres = const [],
}) {
  final parts = <String>[
    if (year != null) year.toString(),
    ...extras.where((extra) => extra.isNotEmpty),
    if (communityRating != null && communityRating > 0)
      communityRating.toStringAsFixed(1),
    if (genres.isNotEmpty) genres.join(', '),
  ];
  return parts.join(' · ');
}
