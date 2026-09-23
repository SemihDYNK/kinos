import 'package:kinos/models/item_base_model.dart';
import 'package:kinos/recommendations/adapters/franchise_key.dart';
import 'package:kinos/recommendations/adapters/jellyfin_trait_extraction.dart';
import 'package:kinos/recommendations/models/candidate_item.dart';

/// Construit les candidats à partir d'une liste d'œuvres Jellyfin — à
/// l'appelant de fournir une liste déjà réduite à ce qui n'est ni vu, ni
/// en cours (cf. spec « Exclus tout ce qui est vu, en cours... ») ;
/// cette fonction ne fait qu'extraire les traits, elle ne filtre pas par
/// statut de visionnage.
List<CandidateItem> buildJellyfinCandidates(List<ItemBaseModel> items) {
  final candidates = <CandidateItem>[];
  for (final item in items) {
    final traits = traitsFromOverview(item.overview);
    if (traits.isEmpty) continue;
    candidates.add(CandidateItem(
      id: item.id,
      title: item.name,
      traits: traits,
      source: CandidateSource.jellyfinLibrary,
      franchiseKeys: franchiseKeysFor(item.name, traits),
      // `yearAired`, pas `productionYear` — jamais peuplé pour un item
      // chargé depuis le serveur (cf. `OverviewModel.fromBaseItemDto`,
      // même calibrage que `jellyfin_trait_extraction.dart`). `year` sert
      // ici au filet de sécurité du dédoublonnage Arr/Jellyfin
      // (`arr_jellyfin_dedup.dart`), qui tournait donc sans jamais
      // bénéficier de la tolérance d'année.
      year: item.overview.yearAired,
    ));
  }
  return candidates;
}
