import 'package:fladder/util/humanize_duration.dart';

/// Ligne de métadonnées du bandeau — texte simple séparé par des points,
/// jamais de badges ni de pastilles : "2024 · 1h 30m · 4K · 7.6 · Comédie".
String buildMediaMetaLine({
  int? year,
  Duration? runTime,
  String? resolution,
  double? communityRating,
  List<String> genres = const [],
}) {
  final parts = <String>[
    if (year != null) year.toString(),
    if (runTime != null && runTime.humanize != null) runTime.humanize!,
    if (resolution != null && resolution.isNotEmpty) resolution,
    if (communityRating != null && communityRating > 0) communityRating.toStringAsFixed(1),
    if (genres.isNotEmpty) genres.join(', '),
  ];
  return parts.join(' · ');
}
