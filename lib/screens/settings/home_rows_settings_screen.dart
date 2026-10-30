import 'package:kinos/widgets/shared/frosted_surface.dart';
import 'package:flutter/material.dart';

import 'package:auto_route/auto_route.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:kinos/jellyfin/jellyfin_open_api.enums.swagger.dart';
import 'package:kinos/models/settings/home_row_model.dart';
import 'package:kinos/providers/api_provider.dart';
import 'package:kinos/providers/settings/home_rows_provider.dart';
import 'package:kinos/theme/app_theme.dart';
import 'package:kinos/util/localization_helper.dart';

/// Écran de configuration des rangées de l'accueil : activation,
/// réordonnancement (glisser-déposer + équivalent clavier), ajout.
@RoutePage()
class HomeRowsSettingsScreen extends ConsumerWidget {
  const HomeRowsSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rows = ref.watch(homeRowsProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        title: Text('Rangées de l\'accueil',
            style: Theme.of(context).textTheme.headlineMedium),
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.screenPadding),
        children: [
          if (rows.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl),
              child: Text(
                'Aucune rangée configurée pour l\'instant.',
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(color: AppColors.textSecondary),
              ),
            ),
          ReorderableListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            buildDefaultDragHandles: false,
            itemCount: rows.length,
            onReorder: (oldIndex, newIndex) =>
                ref.read(homeRowsProvider.notifier).reorder(oldIndex, newIndex),
            itemBuilder: (context, index) => _HomeRowTile(
              key: ValueKey(rows[index].id),
              row: rows[index],
              index: index,
              lastIndex: rows.length - 1,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          FocusRing(
            onActivate: () => _openAddRowSheet(context, ref),
            child: ExcludeFocus(
              child: OutlinedButton.icon(
                onPressed: () => _openAddRowSheet(context, ref),
                icon: const Icon(Icons.add_rounded),
                label: const Text('Ajouter une rangée'),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _openAddRowSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const FrostedSurface(child: _AddHomeRowSheet()),
    );
  }
}

class _HomeRowTile extends ConsumerWidget {
  final HomeRowModel row;
  final int index;
  final int lastIndex;

  const _HomeRowTile(
      {required super.key,
      required this.row,
      required this.index,
      required this.lastIndex});

  void _cycleCacheDays(WidgetRef ref) {
    const choices = [1, 3, 7, 14, 30];
    final current = int.tryParse(row.params['cacheDays'] ?? '') ?? 7;
    final next = choices[(choices.indexOf(current) + 1) % choices.length];
    ref.read(homeRowsProvider.notifier).setDiscoveryCacheDays(row.id, next);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(homeRowsProvider.notifier);

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Container(
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: AppRadii.cardBorder,
        ),
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
        child: Row(
          children: [
            ReorderableDragStartListener(
              index: index,
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: AppSpacing.xxs),
                child: Icon(Icons.drag_indicator_rounded,
                    color: AppColors.textSecondary),
              ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    row.title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: row.enabled
                              ? AppColors.textPrimary
                              : AppColors.textDisabled,
                        ),
                  ),
                  Text(row.type.label,
                      style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
            ),
            if (row.type == HomeRowType.seerrDiscovery)
              FocusRing(
                borderRadius: AppRadii.controlBorder,
                onActivate: () => _cycleCacheDays(ref),
                child: ExcludeFocus(
                    child: TextButton(
                  onPressed: () => _cycleCacheDays(ref),
                  child: Text(context.localized.discoveryCacheDays(
                      int.tryParse(row.params['cacheDays'] ?? '') ?? 7)),
                )),
              ),
            FocusRing(
              borderRadius: AppRadii.controlBorder,
              onActivate: index == 0 ? null : () => notifier.moveUp(row.id),
              child: ExcludeFocus(
                child: IconButton(
                  onPressed: index == 0 ? null : () => notifier.moveUp(row.id),
                  icon: const Icon(Icons.keyboard_arrow_up_rounded),
                  tooltip: 'Monter',
                ),
              ),
            ),
            FocusRing(
              borderRadius: AppRadii.controlBorder,
              onActivate:
                  index == lastIndex ? null : () => notifier.moveDown(row.id),
              child: ExcludeFocus(
                child: IconButton(
                  onPressed: index == lastIndex
                      ? null
                      : () => notifier.moveDown(row.id),
                  icon: const Icon(Icons.keyboard_arrow_down_rounded),
                  tooltip: 'Descendre',
                ),
              ),
            ),
            FocusRing(
              borderRadius: AppRadii.controlBorder,
              onActivate: () => notifier.toggle(row.id),
              child: ExcludeFocus(
                child: Switch(
                  value: row.enabled,
                  onChanged: (_) => notifier.toggle(row.id),
                ),
              ),
            ),
            FocusRing(
              borderRadius: AppRadii.controlBorder,
              onActivate: () => notifier.remove(row.id),
              child: ExcludeFocus(
                child: IconButton(
                  onPressed: () => notifier.remove(row.id),
                  icon: const Icon(Icons.delete_outline_rounded),
                  tooltip: 'Supprimer',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Choix du type puis, si besoin, de son paramètre (genre, réalisateur,
/// studio, décennie ou collection) — récupérés depuis le serveur.
class _AddHomeRowSheet extends ConsumerStatefulWidget {
  const _AddHomeRowSheet();

  @override
  ConsumerState<_AddHomeRowSheet> createState() => _AddHomeRowSheetState();
}

class _AddHomeRowSheetState extends ConsumerState<_AddHomeRowSheet> {
  HomeRowType? _selectedType;

  @override
  Widget build(BuildContext context) {
    final type = _selectedType;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.screenPadding),
        child: type == null
            ? _TypePicker(onSelected: (t) {
                if (t.needsParam) {
                  setState(() => _selectedType = t);
                } else {
                  ref
                      .read(homeRowsProvider.notifier)
                      .add(type: t, title: t.defaultTitle(null));
                  Navigator.of(context).pop();
                }
              })
            : _ParamPicker(
                type: type,
                onBack: () => setState(() => _selectedType = null),
                onPicked: (params, label) {
                  ref.read(homeRowsProvider.notifier).add(
                        type: type,
                        title: type.defaultTitle(label),
                        params: params,
                      );
                  Navigator.of(context).pop();
                },
              ),
      ),
    );
  }
}

class _TypePicker extends StatelessWidget {
  final ValueChanged<HomeRowType> onSelected;

  const _TypePicker({required this.onSelected});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Type de rangée',
            style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: AppSpacing.sm),
        for (final t in HomeRowType.values)
          FocusRing(
            onActivate: () => onSelected(t),
            child: ExcludeFocus(
              child: ListTile(
                onTap: () => onSelected(t),
                title: Text(t.label,
                    style: Theme.of(context).textTheme.bodyMedium),
                trailing: const Icon(Icons.chevron_right_rounded,
                    color: AppColors.textSecondary),
              ),
            ),
          ),
      ],
    );
  }
}

/// Sélecteur du paramètre requis par [type] — recherche côté serveur pour
/// genres, réalisateurs, studios et collections ; liste statique pour les
/// décennies.
class _ParamPicker extends ConsumerStatefulWidget {
  final HomeRowType type;
  final VoidCallback onBack;
  final void Function(Map<String, String> params, String label) onPicked;

  const _ParamPicker(
      {required this.type, required this.onBack, required this.onPicked});

  @override
  ConsumerState<_ParamPicker> createState() => _ParamPickerState();
}

class _ParamPickerState extends ConsumerState<_ParamPicker> {
  late final Future<List<(String id, String name)>> _options = _load();

  Future<List<(String id, String name)>> _load() async {
    final api = ref.read(jellyApiProvider);
    switch (widget.type) {
      case HomeRowType.genre:
        final response = await api.genresGet(sortBy: [ItemSortBy.sortname]);
        return (response.body?.items ?? [])
            .map((e) => (e.id ?? '', e.name ?? ''))
            .where((e) => e.$1.isNotEmpty)
            .toList();
      case HomeRowType.director:
        final response =
            await api.personsGet(personTypes: const ['Director'], limit: 200);
        return (response.body ?? []).map((e) => (e.id, e.name)).toList();
      case HomeRowType.studio:
        final response = await api.studiosGet(limit: 200);
        return (response.body?.items ?? [])
            .map((e) => (e.id ?? '', e.name ?? ''))
            .where((e) => e.$1.isNotEmpty)
            .toList();
      case HomeRowType.collection:
        final response = await api.usersUserIdItemsGet(
          includeItemTypes: const [BaseItemKind.boxset],
          recursive: true,
          limit: 200,
        );
        return (response.body?.items ?? [])
            .map((e) => (e.id ?? '', e.name ?? ''))
            .where((e) => e.$1.isNotEmpty)
            .toList();
      case HomeRowType.decade:
        final currentDecade = (DateTime.now().year ~/ 10) * 10;
        return [
          for (var d = currentDecade; d >= 1920; d -= 10)
            (d.toString(), '${d}s')
        ];
      case HomeRowType.topRated:
      case HomeRowType.unwatched:
      case HomeRowType.rediscover:
      case HomeRowType.similar:
      case HomeRowType.forYou:
      case HomeRowType.setAside:
      case HomeRowType.tasteSeeds:
      case HomeRowType.catalogWellRated:
      case HomeRowType.catalogNarrowGenres:
      case HomeRowType.catalogDecades:
      case HomeRowType.seerrDiscovery:
      case HomeRowType.catalogLongFilms:
        return const [];
    }
  }

  Map<String, String> _paramsFor(String id, String name) =>
      switch (widget.type) {
        HomeRowType.genre => {'genreId': id, 'genreName': name},
        HomeRowType.director => {'personId': id, 'personName': name},
        HomeRowType.studio => {'studioId': id, 'studioName': name},
        HomeRowType.collection => {'boxSetId': id, 'boxSetName': name},
        HomeRowType.decade => {'decade': id},
        _ => const {},
      };

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            FocusRing(
              borderRadius: AppRadii.controlBorder,
              onActivate: widget.onBack,
              child: ExcludeFocus(
                child: IconButton(
                    onPressed: widget.onBack,
                    icon: const Icon(Icons.arrow_back_rounded)),
              ),
            ),
            const SizedBox(width: AppSpacing.xs),
            Text(widget.type.label,
                style: Theme.of(context).textTheme.headlineMedium),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 400),
          child: FutureBuilder<List<(String id, String name)>>(
            future: _options,
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: AppSpacing.xl),
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              final options = snapshot.data!;
              if (options.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl),
                  child: Text(
                    'Rien à proposer pour le moment.',
                    style: Theme.of(context)
                        .textTheme
                        .bodyMedium
                        ?.copyWith(color: AppColors.textSecondary),
                  ),
                );
              }
              return ListView.builder(
                shrinkWrap: true,
                itemCount: options.length,
                itemBuilder: (context, index) {
                  final (id, name) = options[index];
                  return FocusRing(
                    onActivate: () =>
                        widget.onPicked(_paramsFor(id, name), name),
                    child: ExcludeFocus(
                      child: ListTile(
                        onTap: () =>
                            widget.onPicked(_paramsFor(id, name), name),
                        title: Text(name,
                            style: Theme.of(context).textTheme.bodyMedium),
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}
