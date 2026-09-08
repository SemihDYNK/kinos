import 'package:flutter/material.dart';

import 'package:auto_route/auto_route.dart';

import 'package:kinos/models/item_base_model.dart';
import 'package:kinos/models/library_search/library_search_options.dart';
import 'package:kinos/routes/auto_router.gr.dart';
import 'package:kinos/screens/dashboard/single_row_section.dart';

/// Rangée "Ajouts récents" — une ligne (cf. [SingleRowSection]), "tout voir"
/// mène à la vue complète triée par date d'ajout.
class RecentlyAddedSection extends StatelessWidget {
  final List<ItemBaseModel> items;
  final EdgeInsets contentPadding;

  const RecentlyAddedSection({
    required this.items,
    required this.contentPadding,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return SingleRowSection(
      title: 'Ajouts récents',
      items: items,
      contentPadding: contentPadding,
      onSeeAll: () => context.router.push(
        LibrarySearchRoute(
          recursive: true,
          sortingOptions: SortingOptions.dateAdded,
          sortOrder: SortingOrder.descending,
        ),
      ),
    );
  }
}
