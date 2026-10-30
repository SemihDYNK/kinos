import 'package:kinos/widgets/shared/frosted_surface.dart';
import 'package:flutter/material.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iconsax_plus/iconsax_plus.dart';

import 'package:kinos/jellyfin/jellyfin_open_api.enums.swagger.dart';
import 'package:kinos/models/item_base_model.dart';
import 'package:kinos/models/items/item_shared_models.dart';
import 'package:kinos/models/library_search/library_search_model.dart';
import 'package:kinos/models/library_search/library_search_options.dart';
import 'package:kinos/providers/library_search_provider.dart';
import 'package:kinos/screens/seerr/widgets/seerr_filter_dialogs.dart';
import 'package:kinos/screens/shared/chips/category_chip.dart';
import 'package:kinos/screens/shared/chips/filter_button.dart';
import 'package:kinos/theme/app_theme.dart';
import 'package:kinos/util/localization_helper.dart';
import 'package:kinos/util/map_bool_helper.dart';
import 'package:kinos/util/refresh_state.dart';

class LibraryFilterChips extends ConsumerStatefulWidget {
  const LibraryFilterChips(
      {this.quickOnly = false, this.wrap = false, super.key});
  final bool quickOnly;
  final bool wrap;

  @override
  ConsumerState<ConsumerStatefulWidget> createState() =>
      _LibraryFilterChipsState();
}

class _LibraryFilterChipsState extends ConsumerState<LibraryFilterChips> {
  @override
  Widget build(BuildContext context) {
    final uniqueKey = widget.key ?? UniqueKey();
    final libraryProvider =
        ref.watch(librarySearchProvider(uniqueKey).notifier);
    final groupBy = ref.watch(
        librarySearchProvider(uniqueKey).select((v) => v.filters.groupBy));
    final favourites = ref.watch(
        librarySearchProvider(uniqueKey).select((v) => v.filters.favourites));
    final recursive = ref.watch(
        librarySearchProvider(uniqueKey).select((v) => v.filters.recursive));
    final hideEmpty = ref.watch(librarySearchProvider(uniqueKey)
        .select((v) => v.filters.hideEmptyShows));
    final librarySearchResults = ref.watch(librarySearchProvider(uniqueKey));

    final chips = [
      if (!widget.quickOnly && librarySearchResults.folderOverwrite.isEmpty)
        CategoryChip(
          label: Text(context.localized.library(2)),
          items: librarySearchResults.views.sortByKey((value) => value.name),
          labelBuilder: (item) => Text(item.name),
          onSave: (value) => libraryProvider.setViews(value),
          onCancel: () => libraryProvider.setViews(librarySearchResults.views),
          onClear: () => libraryProvider
              .setViews(librarySearchResults.views.setAll(false)),
        )
      else if (!widget.quickOnly &&
          librarySearchResults.folderOverwrite.length > 1)
        CategoryChip(
          label: Text(context.localized.mediaTypeFolder(2)),
          items: librarySearchResults.folderOverwrite
              .sortByKey((value) => value.name),
          labelBuilder: (item) => Text(item.name),
          onSave: (value) => libraryProvider.setFolderOverwrite(value),
          onCancel: () => libraryProvider
              .setFolderOverwrite(librarySearchResults.folderOverwrite),
          onClear: () => libraryProvider.setFolderOverwrite(
              librarySearchResults.folderOverwrite.setAll(false)),
        ),
      if (!widget.quickOnly)
        CategoryChip<KinosItemType>(
          label: Text(context.localized
              .type(librarySearchResults.filters.types.length)),
          items: librarySearchResults.filters.types
              .sortByKey((value) => value.label(context.localized)),
          activeIcon: IconsaxPlusBold.filter_tick,
          labelBuilder: (item) => Row(
            children: [
              Icon(item.icon),
              const SizedBox(width: 12),
              Text(item.label(context.localized)),
            ],
          ),
          onSave: (value) => libraryProvider.setTypes(value),
          onClear: () => libraryProvider
              .setTypes(librarySearchResults.filters.types.setAll(false)),
        ),
      if (!widget.quickOnly)
        FilterButton(
          isSelected: favourites != null,
          icon: switch (favourites) {
            true => IconsaxPlusBold.heart,
            false => IconsaxPlusBold.heart_slash,
            null => null,
          },
          label: Text(context.localized.favorites),
          onLongPress: () {
            libraryProvider.setFavourites(null);
            context.refreshData();
          },
          onPressed: () {
            final newValue = switch (favourites) {
              true => false,
              false => null,
              null => true,
            };
            libraryProvider.setFavourites(newValue);
            context.refreshData();
          },
        ),
      if (!widget.quickOnly)
        FilterButton(
          isSelected: recursive == true,
          icon: recursive == true ? IconsaxPlusBold.tick_circle : null,
          label: Text(context.localized.recursive),
          onPressed: () {
            libraryProvider.toggleRecursive();
            context.refreshData();
          },
        ),
      if (librarySearchResults.filters.genres.isNotEmpty)
        CategoryChip<String>(
          label: Text(context.localized
              .genre(librarySearchResults.filters.genres.length)),
          activeIcon: IconsaxPlusBold.hierarchy_2,
          items: librarySearchResults.filters.genres,
          labelBuilder: (item) => Text(item),
          onSave: (value) => libraryProvider.setGenres(value),
          onCancel: () =>
              libraryProvider.setGenres(librarySearchResults.filters.genres),
          onClear: () => libraryProvider
              .setGenres(librarySearchResults.filters.genres.setAll(false)),
        ),
      if (librarySearchResults.filters.years.isNotEmpty)
        FilterButton(
          isSelected: librarySearchResults.yearRange.$1 != null ||
              librarySearchResults.yearRange.$2 != null,
          icon: IconsaxPlusBold.calendar_1,
          label: Text(yearLabel(context, librarySearchResults.yearRange)),
          onPressed: () => openYearDialog(
            context,
            (first, last) {
              libraryProvider.setYearsRange(first, last);
              context.refreshData();
            },
            librarySearchResults.yearRange,
            fullYearRange: librarySearchResults.availableYearRange,
          ),
        ),
      if (!widget.quickOnly && librarySearchResults.filters.studios.isNotEmpty)
        CategoryChip<Studio>(
          label: Text(context.localized
              .studio(librarySearchResults.filters.studios.length)),
          activeIcon: IconsaxPlusBold.airdrop,
          items: librarySearchResults.filters.studios,
          labelBuilder: (item) => Text(item.name),
          onSave: (value) => libraryProvider.setStudios(value),
          onCancel: () =>
              libraryProvider.setStudios(librarySearchResults.filters.studios),
          onClear: () => libraryProvider
              .setStudios(librarySearchResults.filters.studios.setAll(false)),
        ),
      if (!widget.quickOnly && librarySearchResults.filters.tags.isNotEmpty)
        CategoryChip<String>(
          label: Text(context.localized
              .label(librarySearchResults.filters.tags.length)),
          activeIcon: Icons.label_rounded,
          items: librarySearchResults.filters.tags,
          labelBuilder: (item) => Text(item),
          onSave: (value) => libraryProvider.setTags(value),
          onCancel: () =>
              libraryProvider.setTags(librarySearchResults.filters.tags),
          onClear: () => libraryProvider
              .setTags(librarySearchResults.filters.tags.setAll(false)),
        ),
      if (!widget.quickOnly)
        FilterButton(
          isSelected: groupBy != GroupBy.none,
          icon: groupBy != GroupBy.none ? IconsaxPlusBold.bag_tick : null,
          label: Text(context.localized.group),
          onPressed: () {
            _openGroupDialogue(context, ref, libraryProvider, uniqueKey);
          },
        ),
      CategoryChip<ItemFilter>(
        label: Text(widget.quickOnly
            ? 'Vu / Non vu'
            : context.localized
                .filter(librarySearchResults.filters.itemFilters.length)),
        items: widget.quickOnly
            ? {
                for (final filter in [
                  ItemFilter.isplayed,
                  ItemFilter.isunplayed
                ])
                  filter:
                      librarySearchResults.filters.itemFilters[filter] ?? false
              }
            : librarySearchResults.filters.itemFilters,
        labelBuilder: (item) => Text(item.label(context)),
        onSave: (value) => libraryProvider.setFilters(
            {...librarySearchResults.filters.itemFilters, ...value}),
        onClear: () => libraryProvider.setFilters(widget.quickOnly
            ? {
                ...librarySearchResults.filters.itemFilters,
                ItemFilter.isplayed: false,
                ItemFilter.isunplayed: false
              }
            : librarySearchResults.filters.itemFilters.setAll(false)),
      ),
      if (!widget.quickOnly &&
          librarySearchResults.filters.types[KinosItemType.series] == true)
        FilterButton(
          isSelected: !hideEmpty,
          icon: !hideEmpty ? IconsaxPlusBold.ghost : null,
          label: Text(!hideEmpty
              ? context.localized.hideEmpty
              : context.localized.showEmpty),
          onPressed: libraryProvider.toggleEmptyShows,
        ),
      if (!widget.quickOnly &&
          librarySearchResults.filters.officialRatings.isNotEmpty)
        CategoryChip<String>(
          label: Text(context.localized
              .rating(librarySearchResults.filters.officialRatings.length)),
          activeIcon: Icons.star_rate_rounded,
          items: librarySearchResults.filters.officialRatings,
          labelBuilder: (item) => Text(item),
          onSave: (value) => libraryProvider.setRatings(value),
          onCancel: () => libraryProvider
              .setRatings(librarySearchResults.filters.officialRatings),
          onClear: () => libraryProvider.setRatings(
              librarySearchResults.filters.officialRatings.setAll(false)),
        ),
    ];

    return FocusTraversalGroup(
      policy: ReadingOrderTraversalPolicy(),
      child: widget.wrap
          ? Wrap(
              spacing: AppSpacing.xs,
              runSpacing: AppSpacing.xs,
              children: chips)
          : Row(
              mainAxisSize: MainAxisSize.min,
              spacing: AppSpacing.xxs,
              children: chips,
            ),
    );
  }

  void _openGroupDialogue(
    BuildContext context,
    WidgetRef ref,
    LibrarySearchNotifier provider,
    Key uniqueKey,
  ) {
    showDialog(
      context: context,
      builder: (context) {
        final groupBy = ref.watch(
            librarySearchProvider(uniqueKey).select((v) => v.filters.groupBy));
        return GlassAlertDialog(
          content: SizedBox(
            width: MediaQuery.of(context).size.width * 0.65,
            child: ListView(
              shrinkWrap: true,
              children: [
                Text(context.localized.groupBy),
                ...GroupBy.values.map(
                  (group) => CheckboxListTile(
                    value: groupBy == group,
                    onChanged: (_) {
                      if (group != groupBy) {
                        provider.setGroupBy(group);
                      }
                      Navigator.pop(context);
                    },
                    title: Text(group.value(context)),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class LibraryActiveFilters extends ConsumerWidget {
  const LibraryActiveFilters({required this.providerKey, super.key});
  final Key providerKey;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(librarySearchProvider(providerKey));
    final notifier = ref.read(librarySearchProvider(providerKey).notifier);
    final filters = state.filters;
    final chips = <(String, VoidCallback)>[
      for (final genre in filters.genres.included)
        (genre, () => notifier.setGenres({...filters.genres, genre: false})),
      for (final studio in filters.studios.included)
        (
          studio.name,
          () => notifier.setStudios({...filters.studios, studio: false})
        ),
      for (final tag in filters.tags.included)
        (tag, () => notifier.setTags({...filters.tags, tag: false})),
      for (final rating in filters.officialRatings.included)
        (
          rating,
          () => notifier.setRatings({...filters.officialRatings, rating: false})
        ),
      for (final filter in filters.itemFilters.included)
        (
          filter.label(context),
          () => notifier.setFilters({...filters.itemFilters, filter: false})
        ),
      if (filters.years.included.isNotEmpty)
        (
          yearLabel(context, state.yearRange),
          () => notifier.setYears(filters.years.setAll(false))
        ),
      if (filters.favourites != null)
        (context.localized.favorites, () => notifier.setFavourites(null)),
      if (filters.groupBy != GroupBy.none)
        (
          filters.groupBy.value(context),
          () => notifier.setGroupBy(GroupBy.none)
        ),
    ];
    if (chips.isEmpty) return const SizedBox.shrink();
    return Padding(
        padding: const EdgeInsets.only(top: AppSpacing.xs),
        child: Wrap(
          spacing: AppSpacing.xs,
          runSpacing: AppSpacing.xxs,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            for (final chip in chips)
              InputChip(
                  label: Text(chip.$1),
                  onDeleted: chip.$2,
                  deleteButtonTooltipMessage: 'Supprimer'),
            TextButton(
                onPressed: notifier.clearRefinements,
                child: const Text('Effacer')),
          ],
        ));
  }
}
