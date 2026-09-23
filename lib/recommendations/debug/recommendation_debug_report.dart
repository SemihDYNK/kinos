import 'package:kinos/recommendations/models/candidate_item.dart';
import 'package:kinos/recommendations/models/scored_candidate.dart';
import 'package:kinos/recommendations/models/taste_profile.dart';
import 'package:kinos/recommendations/models/trait.dart';
import 'package:kinos/recommendations/models/watch_classification.dart';
import 'package:kinos/recommendations/models/watch_signal_sample.dart';

/// Ordre d'affichage des catégories de classification — cf. spec du
/// calibrage : "le nombre d'œuvres classées dans chaque catégorie de
/// signal". Étendu aux catégories sans signal exploitable
/// ([WatchClassification.neverStarted]/[tooRecentToJudge]/[greyZone]) :
/// utiles pour vérifier que le filtre d'ancienneté (cf.
/// `classifyWatch`) fait bien la différence entre "en pause" et
/// "abandonné", pas seulement que le signal négatif se déclenche.
const _classificationOrder = [
  WatchClassification.rewatched,
  WatchClassification.completedFavorite,
  WatchClassification.completedNeutral,
  WatchClassification.abandonedEarly,
  WatchClassification.abandonedLate,
  WatchClassification.neverStarted,
  WatchClassification.tooRecentToJudge,
  WatchClassification.greyZone,
];

const _classificationLabels = {
  WatchClassification.rewatched: 'Revu',
  WatchClassification.completedFavorite: 'Terminé + favori',
  WatchClassification.completedNeutral: 'Terminé',
  WatchClassification.abandonedEarly: 'Abandon précoce (<20%, ancien)',
  WatchClassification.abandonedLate: 'Abandon tardif (>80%, ancien, ignoré)',
  WatchClassification.neverStarted: 'Jamais lancé',
  WatchClassification.tooRecentToJudge:
      'En pause récemment (position partielle, pas assez ancien pour juger)',
  WatchClassification.greyZone: 'Zone grise (20-80%, ancien, ignorée)',
};

/// Point d'entrée de mise au point du lot — imprime le profil et les
/// candidats notés, pour calibrer le scoring sur un vrai catalogue
/// avant de brancher une interface (cf. spec). Retourne une [String]
/// plutôt que d'imprimer directement : appelable depuis un test, un
/// `print()` ponctuel, ou n'importe quel harnais de débogage.
///
/// [topTraitCount] : nombre de traits de profil affichés (les plus
/// pesants, positifs et négatifs) — le profil complet peut compter des
/// centaines de traits, illisible tel quel.
///
/// [classificationCounts] : répartition par catégorie de classification
/// (cf. spec du calibrage — vérifier que le signal négatif se déclenche
/// vraiment, et que le filtre d'ancienneté distingue bien "en pause"
/// d'"abandonné"). `null` : section omise.
///
/// [candidateCountsBySource] : nombre de candidats considérés par
/// source avant score/diversité (cf. spec — vérifier si le filtre "avec
/// fichier" élimine tous les candidats Arr, ou s'ils sont simplement
/// absents en amont).
///
/// [arrOnlyCandidates] : rangée Arr "Vous l'aviez mis de côté", triée
/// par date d'ajout décroissante — pas un classement de goût (cf.
/// `RecommendationResult`/`rankArrCandidatesByAddedDate` : les candidats
/// Arr n'ont pas assez de traits crédibles pour ça). Exclut déjà tout ce
/// qui est connu de Jellyfin (cf. `excludeArrCandidatesKnownToJellyfin`)
/// — aucun chevauchement attendu avec [candidates]. `null` : section
/// omise ; fournie mais vide, elle reste imprimée pour que "0 retenu"
/// reste visible plutôt que silencieusement absent.
///
/// [sampleEvents] : valeurs brutes de quelques œuvres de l'historique
/// (cf. spec — "que je puisse vérifier moi-même" que la position de
/// lecture est bien lue).
String buildRecommendationDebugReport({
  required TasteProfile profile,
  required List<ScoredCandidate> candidates,
  int topTraitCount = 15,
  Map<WatchClassification, int>? classificationCounts,
  Map<CandidateSource, int>? candidateCountsBySource,
  List<ScoredCandidate>? arrOnlyCandidates,
  List<WatchSignalSample>? sampleEvents,
}) {
  final buffer = StringBuffer();

  buffer.writeln('=== Profil de goût ===');
  buffer.writeln(
      'Historique (œuvres ayant produit un signal) : ${profile.catalogSize}');
  buffer.writeln('Base IDF (bibliothèque si disponible, sinon historique) : '
      '${profile.idfBaseSize}');
  buffer.writeln('Traits distincts : ${profile.weights.length}');

  if (classificationCounts != null) {
    buffer.writeln('--- Répartition par catégorie de classification ---');
    for (final classification in _classificationOrder) {
      buffer.writeln(
          '${_classificationLabels[classification]} : ${classificationCounts[classification] ?? 0}');
    }
  }

  if (sampleEvents != null) {
    buffer.writeln('--- Échantillon de valeurs brutes (historique) ---');
    if (sampleEvents.isEmpty) {
      buffer.writeln('(aucune œuvre dans l\'historique)');
    }
    for (final sample in sampleEvents) {
      buffer.writeln(
          '${sample.title} — played=${sample.played} playCount=${sample.playCount} '
          'playbackPositionTicks=${sample.playbackPositionTicks} '
          'progress=${sample.progress.toStringAsFixed(1)}% '
          'lastPlayed=${sample.lastPlayed?.toIso8601String() ?? '—'} '
          '-> ${sample.classification.name}');
    }
  }

  final sorted = profile.sortedByWeight;
  buffer.writeln('--- Traits les plus positifs ---');
  for (final entry in sorted.take(topTraitCount)) {
    buffer.writeln(_traitLine(entry.key, entry.value));
  }
  final mostNegative =
      sorted.reversed.where((e) => e.value < 0).take(topTraitCount).toList();
  buffer.writeln('--- Traits les plus négatifs ---');
  if (mostNegative.isEmpty) {
    buffer.writeln('(aucun — vérifier la répartition par catégorie ci-dessus : '
        "aucun 'abandon précoce' classé ?)");
  } else {
    for (final entry in mostNegative) {
      buffer.writeln(_traitLine(entry.key, entry.value));
    }
  }

  if (candidateCountsBySource != null) {
    buffer.writeln();
    buffer.writeln('=== Candidats considérés avant score (par source) ===');
    for (final source in CandidateSource.values) {
      buffer.writeln('${source.name} : ${candidateCountsBySource[source] ?? 0}');
    }
  }

  buffer.writeln();
  buffer.writeln('=== Recommandations (Jellyfin, ${candidates.length}) ===');
  _writeCandidateList(buffer, profile, candidates);

  if (arrOnlyCandidates != null) {
    buffer.writeln();
    buffer.writeln(
        '=== "Vous l\'aviez mis de côté" (Arr, ${arrOnlyCandidates.length}) ===');
    buffer.writeln('Triée par date d\'ajout décroissante, pas par affinité — '
        'le score n\'y départage plus qu\'une égalité de date (cf. '
        '`rankArrCandidatesByAddedDate`). Déjà exclusive de la rangée '
        'Jellyfin ci-dessus (cf. `excludeArrCandidatesKnownToJellyfin`).');
    _writeArrCandidateList(buffer, profile, arrOnlyCandidates);
  }

  return buffer.toString();
}

void _writeCandidateList(
    StringBuffer buffer, TasteProfile profile, List<ScoredCandidate> candidates) {
  for (final (index, scored) in candidates.indexed) {
    buffer.writeln(
        '${index + 1}. ${scored.item.title} — score ${scored.score.toStringAsFixed(3)} '
        '(${scored.item.source.name}) — ${_justificationLine(profile, scored)}');
  }
}

/// Même contenu que [_writeCandidateList], avec la date d'ajout en plus
/// — c'est désormais le critère de tri principal de cette rangée, elle
/// doit être visible pour vérifier le tri sans deviner.
void _writeArrCandidateList(
    StringBuffer buffer, TasteProfile profile, List<ScoredCandidate> candidates) {
  for (final (index, scored) in candidates.indexed) {
    final added = scored.item.added;
    final addedLabel = added == null ? 'date inconnue' : 'ajouté le ${_dateOnly(added)}';
    buffer.writeln(
        '${index + 1}. ${scored.item.title} — $addedLabel — score '
        '${scored.score.toStringAsFixed(3)} — ${_justificationLine(profile, scored)}');
  }
}

String _justificationLine(TasteProfile profile, ScoredCandidate scored) {
  final justification = scored.justification;
  return justification == null
      ? '(aucune justification crédible)'
      : _traitLine(justification, profile.weightOf(justification));
}

String _dateOnly(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

String _traitLine(TraitKey trait, double weight) =>
    '[${trait.kind.name}] ${trait.value} : ${weight.toStringAsFixed(3)}';
