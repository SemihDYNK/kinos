import 'package:kinos/recommendations/models/watch_classification.dart';

/// Valeurs brutes ayant servi à classer une œuvre de l'historique —
/// pour l'entrée de mise au point (cf. spec du calibrage : "les valeurs
/// brutes qui ont servi au classement, que je puisse vérifier
/// moi-même"). Ne porte que ce qui alimente `classifyWatch`, rien de
/// plus. [classification] porte la classification complète (pas
/// seulement le signal exploitable) — utile pour distinguer à l'œil
/// "jamais lancé", "zone grise" et "trop récent pour juger", qui
/// n'apparaîtraient sinon pas dans le rapport (les trois se traduisent
/// par l'absence de signal).
class WatchSignalSample {
  final String title;
  final bool played;
  final int playCount;
  final int playbackPositionTicks;
  final double progress;
  final DateTime? lastPlayed;
  final WatchClassification classification;

  const WatchSignalSample({
    required this.title,
    required this.played,
    required this.playCount,
    required this.playbackPositionTicks,
    required this.progress,
    required this.lastPlayed,
    required this.classification,
  });
}
