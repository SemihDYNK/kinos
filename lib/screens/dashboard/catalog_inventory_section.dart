import 'package:flutter/material.dart';
import 'package:kinos/models/item_base_model.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:kinos/recommendations/providers/home_catalog_providers.dart';
import 'package:kinos/screens/dashboard/single_row_section.dart';
import 'package:kinos/theme/app_theme.dart';

/// Inventaire du catalogue — filtres/tris purs, sans scoring (cf. spec
/// du lot graines/inventaire). Une rangée `SingleRowSection` par
/// catégorie non vide, dans un ordre fixe : bien notés -> genres étroits
/// -> décennies -> longs métrages. Même style de titre pour toutes —
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
  final KinosItemType? mediaType;

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
    this.mediaType,
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

    Widget row(String title, List<ItemBaseModel> items) {
      final visible = mediaType == null
          ? items
          : items.where((item) => item.type == mediaType).toList();
      if (visible.isEmpty) {
        return const SliverToBoxAdapter(child: SizedBox.shrink());
      }
      return SliverPadding(
        padding: const EdgeInsets.only(top: AppSpacing.xl),
        sliver: SingleRowSection(
            title: title, items: visible, contentPadding: contentPadding),
      );
    }

    return SliverMainAxisGroup(slivers: [
      if (showWellRated && mediaType != KinosItemType.series)
        row('Films bien notés', result.wellRatedMovies),
      if (showWellRated && mediaType != KinosItemType.movie)
        row('Séries bien notées', result.wellRatedSeries),
      if (showNarrowGenres)
        for (final entry in result.narrowGenres.entries)
          row(entry.key, entry.value),
      if (showDecades)
        for (final entry in result.decades.entries)
          row('Les ${entry.key}s', entry.value),
      if (showLongFilms && mediaType != KinosItemType.series)
        row('Plus de 2h30', result.longFilms),
    ]);
  }
}
