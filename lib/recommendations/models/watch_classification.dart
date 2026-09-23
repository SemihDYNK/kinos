import 'package:kinos/recommendations/models/watch_signal.dart';

/// Résultat complet de la classification d'une œuvre de l'historique —
/// un sur-ensemble de [WatchSignal] : porte aussi les raisons pour
/// lesquelles aucun signal n'a été retenu (jamais lancé, zone grise,
/// trop récent pour juger), utiles au diagnostic même si elles ne
/// produisent aucun [WatchEvent].
enum WatchClassification {
  rewatched,
  completedFavorite,
  completedNeutral,
  abandonedEarly,
  abandonedLate,

  /// Jamais lancé (`PlaybackPositionTicks == 0`, non terminé).
  neverStarted,

  /// Position de lecture partielle, mais trop proche dans le temps
  /// (`LastPlayedDate`) pour juger qu'il s'agit d'un abandon plutôt
  /// que d'une lecture en pause — cf. `classifyWatch`.
  tooRecentToJudge,

  /// Position de lecture partielle, ancienne, mais entre 20% et 80% —
  /// ni assez tôt ni assez tard pour trancher (cf. spec d'origine).
  greyZone;

  /// `null` pour toute catégorie qui ne produit pas de signal
  /// exploitable — seuls les cinq premiers cas alimentent
  /// [TasteProfileBuilder].
  WatchSignal? get signal => switch (this) {
        WatchClassification.rewatched => WatchSignal.rewatched,
        WatchClassification.completedFavorite => WatchSignal.completedFavorite,
        WatchClassification.completedNeutral => WatchSignal.completedNeutral,
        WatchClassification.abandonedEarly => WatchSignal.abandonedEarly,
        WatchClassification.abandonedLate => WatchSignal.abandonedLate,
        WatchClassification.neverStarted ||
        WatchClassification.tooRecentToJudge ||
        WatchClassification.greyZone =>
          null,
      };
}
