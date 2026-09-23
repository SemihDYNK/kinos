import 'package:kinos/models/item_base_model.dart';
import 'package:kinos/models/items/item_shared_models.dart';
import 'package:kinos/recommendations/adapters/jellyfin_trait_extraction.dart';
import 'package:kinos/recommendations/models/watch_classification.dart';
import 'package:kinos/recommendations/models/watch_event.dart';

/// Seuil de `PlayCount` retenu pour "revu" — cf. [classifyWatch].
/// `> 1` (donc `>= 2`) était trop large d'après le calibrage (18 œuvres
/// sur 33 classées "revu" dans un historique réel) : une lecture
/// interrompue puis reprise peut faire incrémenter `PlayCount` deux fois
/// pour un seul visionnage, pas deux. `>= 3` réduit ce faux positif sans
/// l'éliminer — cf. la mise en garde ci-dessous, `UserItemDataDto`
/// n'expose aucune donnée qui permettrait de trancher exactement.
const minRewatchPlayCount = 3;

/// Ancienneté minimale de `LastPlayedDate` pour qu'une œuvre "en cours"
/// à faible ou forte progression compte comme un abandon plutôt qu'une
/// lecture en pause — cf. [classifyWatch].
///
/// Raisonnement (cf. spec du calibrage) : Jellyfin remet
/// `PlaybackPositionTicks` à zéro dès qu'une lecture est marquée
/// terminée — l'historique des œuvres *terminées* ne peut donc
/// structurellement jamais porter de position partielle. Le signal
/// d'abandon ne peut se trouver que dans les œuvres *reprenables*
/// (`Played == false`, position > 0) — mais une position faible ou
/// élevée ne suffit pas à elle seule : un film à 8% ouvert il y a trois
/// jours est probablement encore en cours de visionnage, pas abandonné.
/// Il faut croiser la progression avec l'ancienneté de la dernière
/// lecture.
///
/// 30 jours : assez long pour ne pas confondre une pause de quelques
/// jours (voyage, semaine chargée) avec un abandon, assez court pour
/// qu'une œuvre délaissée depuis plus d'un mois soit raisonnablement
/// considérée comme telle. Choix arbitraire documenté, pas une valeur
/// que Jellyfin expose ou recommande — à ajuster via le paramètre
/// [classifyWatch] si l'expérience montre qu'il faut resserrer ou
/// élargir.
const defaultAbandonmentStaleness = Duration(days: 30);

/// Classifie une œuvre de l'historique — retourne la classification
/// complète (cf. [WatchClassification], qui inclut les cas sans signal
/// exploitable, utiles au diagnostic).
///
/// - `playCount >= [minRewatchPlayCount]` : revu, le plus fiable.
///
///   Limite connue, à signaler : la spec demande "deux lectures
///   complètes séparées dans le temps", mais `UserItemDataDto` (le seul
///   objet que Jellyfin expose ici) ne porte qu'un compteur agrégé
///   (`PlayCount`) et une unique date (`LastPlayedDate`) — aucune trace
///   par session, donc aucun moyen de vérifier que deux lectures sont
///   bien séparées dans le temps plutôt qu'une reprise après
///   interruption comptée deux fois. Ce seuil est un compromis sur la
///   seule donnée disponible, pas la règle exacte demandée — une
///   détection fiable demanderait une autre source (ex. le plugin
///   Playback Reporting de Jellyfin, qui journalise chaque session ;
///   hors périmètre de ce lot, aucun appel à son API n'est fait ici).
/// - terminé (`played`) : favori -> fort positif, sinon positif modéré.
/// - jamais lancé (`playbackPositionTicks == 0`, non terminé) :
///   [WatchClassification.neverStarted], aucun signal.
/// - commencé mais pas terminé : la staleness de `lastPlayed` tranche
///   d'abord (cf. [defaultAbandonmentStaleness]) — trop récent :
///   [WatchClassification.tooRecentToJudge], aucun signal (encore en
///   cours, pas un abandon). `lastPlayed` absent : traité comme "trop
///   récent" par prudence, on ne peut pas confirmer l'ancienneté.
///   Assez ancien : avant 20% -> abandon précoce (négatif), après 80%
///   -> abandon tardif (neutre, ignoré), entre les deux -> zone grise
///   (la spec ne tranche pas ce cas, `null` plutôt qu'une règle
///   inventée).
WatchClassification classifyWatch(
  UserData userData, {
  DateTime? now,
  Duration abandonmentStaleness = defaultAbandonmentStaleness,
}) {
  if (userData.played) {
    if (userData.playCount >= minRewatchPlayCount) {
      return WatchClassification.rewatched;
    }
    return userData.isFavourite
        ? WatchClassification.completedFavorite
        : WatchClassification.completedNeutral;
  }

  if (userData.playbackPositionTicks <= 0) {
    return WatchClassification.neverStarted;
  }

  final lastPlayed = userData.lastPlayed;
  final reference = now ?? DateTime.now();
  final isStale = lastPlayed != null &&
      reference.difference(lastPlayed) >= abandonmentStaleness;
  if (!isStale) return WatchClassification.tooRecentToJudge;

  if (userData.progress < 20) return WatchClassification.abandonedEarly;
  if (userData.progress > 80) return WatchClassification.abandonedLate;
  return WatchClassification.greyZone;
}

/// Construit les événements de visionnage à partir de l'historique
/// Jellyfin — items marqués vus (`isPlayed: true`) et items reprenables
/// (résumé en cours ou abandonné, cf. `usersUserIdItemsResumeGet`).
/// Filtre les items sans trait exploitable (rien à apprendre) et ceux
/// sans signal net (cf. [classifyWatch]).
///
/// Limite connue pour un item de type Épisode (les abandons repris
/// concernent souvent un épisode précis, pas une série entière) :
/// Jellyfin ne porte généralement pas ses propres genres/tags sur
/// l'épisode, seulement sur la série parente — `traitsFromOverview`
/// renvoie alors une liste vide et l'événement est filtré ici, pas
/// silencieusement mal noté. Remonter jusqu'à la série parente pour
/// hériter ses traits demanderait un appel réseau par épisode concerné,
/// non fait dans ce lot.
List<WatchEvent> buildJellyfinWatchEvents(
  List<ItemBaseModel> items, {
  DateTime? now,
  Duration abandonmentStaleness = defaultAbandonmentStaleness,
}) {
  final events = <WatchEvent>[];
  for (final item in items) {
    final signal = classifyWatch(item.userData,
            now: now, abandonmentStaleness: abandonmentStaleness)
        .signal;
    if (signal == null) continue;
    final traits = traitsFromOverview(item.overview);
    if (traits.isEmpty) continue;
    events.add(WatchEvent(
      itemId: item.id,
      traits: traits,
      signal: signal,
      occurredAt: item.userData.lastPlayed,
    ));
  }
  return events;
}
