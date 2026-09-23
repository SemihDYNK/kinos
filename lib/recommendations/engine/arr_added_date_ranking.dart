import 'dart:math';

import 'package:kinos/recommendations/engine/recommendation_scorer.dart';
import 'package:kinos/recommendations/models/candidate_item.dart';
import 'package:kinos/recommendations/models/scored_candidate.dart';
import 'package:kinos/recommendations/models/taste_profile.dart';

/// Âge minimal d'un candidat Arr pour apparaître dans "Vous l'aviez mis
/// de côté" — en dessous, "Ajouts récents" couvre déjà la même œuvre
/// (les deux rangées sont triées par date d'ajout sur des catalogues qui
/// se recouvrent), doublon visible sinon. "Mis de côté" veut dire voulu
/// puis oublié, pas arrivé hier. Paramétrable (cf. le paramètre [minAge]
/// de [rankArrCandidatesByAddedDate]) : la valeur éditoriale ("un mois")
/// n'est pas gravée dans le calcul lui-même.
const defaultArrSetAsideMinAge = Duration(days: 30);

/// Au-delà de cet âge, la date d'ajout ne discrimine plus rien — huit
/// mois ou treize mois, c'est pareil, et un tri par date fige la rangée
/// sur les mêmes titres à chaque ouverture. Au-delà, l'ordre passe en
/// aléatoire stabilisé par la graine de session (cf. le paramètre
/// [seed] de [rankArrCandidatesByAddedDate]) plutôt que par date.
/// Paramétrable, même principe que [defaultArrSetAsideMinAge].
const defaultArrSetAsideStableOrderAge = Duration(days: 60);

/// Classe les candidats Arr "jamais lancés" pour la rangée "Vous l'aviez
/// mis de côté" — remplace le classement par affinité pour cette rangée
/// (cf. calibrage : genres/studios trop pauvres pour justifier un vrai
/// classement de goût sur cette source). "Ce que j'ai ajouté récemment
/// et jamais regardé" est déjà une raison suffisante d'apparaître ; une
/// recommandation qui ne peut pas se justifier ne vaut pas mieux qu'un
/// tri honnête.
///
/// Trois étapes, dans cet ordre :
///
/// 1. **Filtre d'âge** (cf. [minAge]) : un candidat ajouté il y a moins
///    de [minAge], ou dont la date d'ajout est inconnue (impossible de
///    vérifier le seuil), est écarté — sinon cette rangée doublonne
///    "Ajouts récents" sur les mêmes entrées récentes.
/// 2. **Bloc récent** (entre [minAge] et [stableOrderAge]) : trié par
///    date d'ajout décroissante, l'ancienneté a encore du sens à cette
///    échelle. Deux candidats ajoutés le même jour se départagent par
///    score, décroissant (cf. [_sameDay]) — l'affinité de goût (cf.
///    [RecommendationScorer.scoreCandidate]) ne sert jamais qu'à ça,
///    jamais à réordonner par date.
/// 3. **Bloc stable** (au-delà de [stableOrderAge]) : la date n'y
///    discrimine plus rien, donc ordre aléatoire au lieu de figer la
///    rangée sur les mêmes titres à chaque ouverture — mais stabilisé
///    par [seed] (même graine que les autres rangées "aléatoires" de
///    l'accueil, cf. `homeRowRandomSeedProvider`) : l'ordre reste
///    identique tant que l'application n'est pas relancée.
///
/// Le bloc récent passe toujours avant le bloc stable.
///
/// Aucune diversité par trait dominant ni par franchise ici,
/// volontairement : une rangée "mis de côté" doit rester un inventaire
/// honnête de ce qui a été ajouté, pas une recommandation qui cacherait
/// une suite pourtant bien présente dans la bibliothèque.
List<ScoredCandidate> rankArrCandidatesByAddedDate(
  TasteProfile profile,
  List<CandidateItem> candidates, {
  required DateTime now,
  RecommendationScorer scorer = const RecommendationScorer(),
  int seed = 0,
  Duration minAge = defaultArrSetAsideMinAge,
  Duration stableOrderAge = defaultArrSetAsideStableOrderAge,
}) {
  final scored = [
    for (final candidate in candidates)
      if (candidate.traits.isNotEmpty &&
          candidate.added != null &&
          now.difference(candidate.added!) >= minAge)
        scorer.scoreCandidate(profile, candidate),
  ];

  final recentBlock = <ScoredCandidate>[];
  final stableBlock = <ScoredCandidate>[];
  for (final item in scored) {
    // `added` non-null et assez ancien, garanti par le filtre ci-dessus.
    if (now.difference(item.item.added!) < stableOrderAge) {
      recentBlock.add(item);
    } else {
      stableBlock.add(item);
    }
  }

  recentBlock.sort((a, b) {
    final aDate = a.item.added!;
    final bDate = b.item.added!;
    if (_sameDay(aDate, bDate)) return b.score.compareTo(a.score);
    return bDate.compareTo(aDate); // plus récent d'abord
  });

  return [...recentBlock, ..._seededShuffle(stableBlock, seed)];
}

bool _sameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

/// Mélange de Fisher-Yates déterministe : même [seed] et mêmes [items]
/// d'entrée donnent toujours le même ordre en sortie. Même algorithme
/// que `_seededShuffle` dans `home_row_items_provider.dart` et dans
/// `recommendation_scorer.dart` — copie volontaire plutôt qu'un import
/// entre modules qui n'ont pas besoin de se connaître (le moteur de
/// recommandation ne dépend pas des providers Riverpod, l'inverse est
/// déjà le cas).
List<T> _seededShuffle<T>(List<T> items, int seed) {
  final random = Random(seed);
  final shuffled = [...items];
  for (var i = shuffled.length - 1; i > 0; i--) {
    final j = random.nextInt(i + 1);
    final swap = shuffled[i];
    shuffled[i] = shuffled[j];
    shuffled[j] = swap;
  }
  return shuffled;
}
