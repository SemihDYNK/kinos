import 'package:flutter/material.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:kinos/recommendations/providers/home_catalog_providers.dart';
import 'package:kinos/screens/dashboard/recommendation_tile.dart';
import 'package:kinos/theme/app_theme.dart';

/// Rangées par graine — jusqu'à quelques rangées personnelles
/// supplémentaires, restreintes chacune à un seul trait de goût (cf.
/// spec du lot graines/inventaire). Même rendu que "Pour vous" (jaquette,
/// survol — cf. `recommendation_tile.dart`), juste un jeu de candidats
/// plus étroit et un titre dérivé de l'œuvre source plutôt que du nom du
/// trait.
///
/// `homeSeedRowsResultProvider` porte déjà tout le calcul (sélection des
/// graines, dédoublonnage contre le reste de la page) — ce widget ne
/// fait que peindre le résultat. Ne dépend que de la bibliothèque
/// Jellyfin (cf. la note sur ce provider) — jamais du calcul complet des
/// recommandations, qui peut prendre plusieurs dizaines de secondes.
/// Silencieux en l'absence de graine retenue (bibliothèque trop petite,
/// aucun trait n'atteint le plancher de qualité) ou pendant que le
/// calcul charge : pas de rangée vide, pas de squelette, pas de message
/// d'erreur — cohérent avec le reste de l'accueil (cf.
/// `homeRowItemsProvider`).
class TasteSeedRowsSection extends ConsumerWidget {
  final EdgeInsets contentPadding;

  const TasteSeedRowsSection({required this.contentPadding, super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final result = ref.watch(homeSeedRowsResultProvider).valueOrNull;
    if (result == null || result.seedRows.isEmpty) {
      return const SliverToBoxAdapter(child: SizedBox.shrink());
    }

    return SliverMainAxisGroup(
      slivers: [
        for (final row in result.seedRows)
          SliverPadding(
            padding: const EdgeInsets.only(top: AppSpacing.xl),
            sliver: RecommendationRowGrid(
              title: row.title,
              tiles: [
                for (final scored in row.candidates)
                  if (result.jellyfinItemsById[scored.item.id] case final item?)
                    RecommendationTile.jellyfin(item: item),
              ],
              contentPadding: contentPadding,
            ),
          ),
      ],
    );
  }
}
