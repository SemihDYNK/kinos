import 'package:flutter/material.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:kinos/recommendations/providers/home_catalog_providers.dart';
import 'package:kinos/screens/dashboard/single_row_section.dart';
import 'package:kinos/theme/app_theme.dart';

/// Inventaire du catalogue — filtres/tris purs, sans scoring (cf. spec
/// du lot graines/inventaire). Une rangée `SingleRowSection` par
/// catégorie non vide, dans un ordre fixe : bien notés -> genres étroits
/// -> décennies -> longs métrages. Même titre pour toutes (rupture de
/// registre typographique, cf. `AppTypography.catalogSectionTitle`) —
/// pas de scoring, jamais de justification au survol (contrairement aux
/// rangées "Pour vous"/par graine).
///
/// `homeCatalogInventoryResultProvider` porte déjà tout le calcul
/// (filtres, dédoublonnage contre le reste de la page) — ce widget ne
/// fait que peindre le résultat, silencieusement vide pendant le
/// chargement ou en l'absence de catégorie non vide. Ce provider ne
/// dépend que de la bibliothèque Jellyfin (cf. sa note) : ces rangées se
/// construisent dès que la bibliothèque est disponible, jamais après le
/// calcul complet des recommandations.
class CatalogInventorySection extends ConsumerWidget {
  final EdgeInsets contentPadding;

  /// Catégorie par catégorie : reflète l'activation de
  /// [HomeRowType.catalogWellRated]/[.catalogNarrowGenres]/
  /// [.catalogDecades]/[.catalogLongFilms] dans `homeRowsProvider` (cf.
  /// `dashboard_screen.dart`) — une catégorie désactivée n'est jamais
  /// rendue, indépendamment de ce que `homeCatalogInventoryResultProvider`
  /// a calculé pour elle.
  final bool showWellRated;
  final bool showNarrowGenres;
  final bool showDecades;
  final bool showLongFilms;

  const CatalogInventorySection({
    required this.contentPadding,
    this.showWellRated = true,
    this.showNarrowGenres = true,
    this.showDecades = true,
    this.showLongFilms = true,
    super.key,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final result = ref.watch(homeCatalogInventoryResultProvider).valueOrNull;
    if (result == null) {
      return const SliverToBoxAdapter(child: SizedBox.shrink());
    }

    return SliverMainAxisGroup(
      slivers: [
        if (showWellRated) ...[
          SliverPadding(
            padding: const EdgeInsets.only(top: AppSpacing.xl),
            sliver: SingleRowSection(
              title: 'Films bien notés',
              items: result.wellRatedMovies,
              contentPadding: contentPadding,
              titleStyle: AppTypography.catalogSectionTitle,
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.only(top: AppSpacing.xl),
            sliver: SingleRowSection(
              title: 'Séries bien notées',
              items: result.wellRatedSeries,
              contentPadding: contentPadding,
              titleStyle: AppTypography.catalogSectionTitle,
            ),
          ),
        ],
        if (showNarrowGenres)
          for (final entry in result.narrowGenres.entries)
            SliverPadding(
              padding: const EdgeInsets.only(top: AppSpacing.xl),
              sliver: SingleRowSection(
                title: entry.key,
                items: entry.value,
                contentPadding: contentPadding,
                titleStyle: AppTypography.catalogSectionTitle,
              ),
            ),
        if (showDecades)
          for (final entry in result.decades.entries)
            SliverPadding(
              padding: const EdgeInsets.only(top: AppSpacing.xl),
              sliver: SingleRowSection(
                title: 'Les ${entry.key}s',
                items: entry.value,
                contentPadding: contentPadding,
                titleStyle: AppTypography.catalogSectionTitle,
              ),
            ),
        if (showLongFilms)
          SliverPadding(
            padding: const EdgeInsets.only(top: AppSpacing.xl),
            sliver: SingleRowSection(
              title: 'Plus de 2h30',
              items: result.longFilms,
              contentPadding: contentPadding,
              titleStyle: AppTypography.catalogSectionTitle,
            ),
          ),
      ],
    );
  }
}
