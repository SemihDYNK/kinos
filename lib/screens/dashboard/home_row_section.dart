import 'package:flutter/material.dart';

import 'package:auto_route/auto_route.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:fladder/models/items/item_shared_models.dart';
import 'package:fladder/models/settings/home_row_model.dart';
import 'package:fladder/providers/dashboard/home_row_items_provider.dart';
import 'package:fladder/routes/auto_router.gr.dart';
import 'package:fladder/screens/dashboard/single_row_section.dart';

/// Une rangée configurable de l'accueil (cf. [HomeRowType]).
///
/// Charge son contenu paresseusement : [homeRowItemsProvider] est
/// `autoDispose`, la requête ne part que lorsque ce widget est construit —
/// donc seulement quand la rangée approche du champ de vision, jamais au
/// démarrage. Vide ou en échec (le provider absorbe déjà les erreurs) :
/// rien ne s'affiche, jamais de squelette permanent.
class HomeRowSection extends ConsumerWidget {
  final HomeRowModel row;
  final EdgeInsets contentPadding;

  const HomeRowSection({
    required this.row,
    required this.contentPadding,
    super.key,
  });

  /// `null` quand ce type de rangée n'a pas d'équivalent direct dans les
  /// filtres de [LibrarySearchRoute] (réalisateur, mieux notés, jamais vus,
  /// à redécouvrir, similaire) — le lien "tout voir" est alors omis plutôt
  /// que de mener vers une vue mal filtrée.
  VoidCallback? _seeAll(BuildContext context) {
    switch (row.type) {
      case HomeRowType.genre:
        final name = row.params['genreName'];
        if (name == null) return null;
        return () => context.router.push(
              LibrarySearchRoute(recursive: true, genres: {name: true}),
            );
      case HomeRowType.studio:
        final id = row.params['studioId'];
        final name = row.params['studioName'];
        if (id == null || name == null) return null;
        return () => context.router.push(
              LibrarySearchRoute(
                  recursive: true, studios: {Studio(id: id, name: name): true}),
            );
      case HomeRowType.decade:
        final decade = int.tryParse(row.params['decade'] ?? '');
        if (decade == null) return null;
        return () => context.router.push(
              LibrarySearchRoute(
                recursive: true,
                years: {for (var y = decade; y < decade + 10; y++) y: true},
              ),
            );
      case HomeRowType.collection:
        final id = row.params['boxSetId'];
        if (id == null) return null;
        return () =>
            context.router.push(LibrarySearchRoute(parentId: [id, 'folder']));
      case HomeRowType.director:
      case HomeRowType.topRated:
      case HomeRowType.unwatched:
      case HomeRowType.rediscover:
      case HomeRowType.similar:
        return null;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(homeRowItemsProvider(row));

    return items.when(
      data: (data) => SingleRowSection(
        title: row.title,
        items: data,
        contentPadding: contentPadding,
        onSeeAll: _seeAll(context),
      ),
      loading: () => const SliverToBoxAdapter(child: SizedBox.shrink()),
      error: (_, __) => const SliverToBoxAdapter(child: SizedBox.shrink()),
    );
  }
}
