import 'package:kinos/screens/shared/outlined_text_field.dart';
import 'package:kinos/util/localization_helper.dart';
import 'package:kinos/widgets/shared/frosted_surface.dart';
import 'package:flutter/material.dart';

import 'package:auto_route/auto_route.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:kinos/arr/models/arr_library_entry.dart';
import 'package:kinos/arr/models/arr_service.dart';
import 'package:kinos/arr/providers/arr_library_providers.dart';
import 'package:kinos/arr/providers/arr_providers.dart';
import 'package:kinos/arr/screens/widgets/arr_library_grid.dart';
import 'package:kinos/arr/services/arr_api_client.dart';
import 'package:kinos/routes/auto_router.gr.dart';
import 'package:kinos/screens/shared/chips/filter_button.dart';
import 'package:kinos/screens/shared/kinos_notification_overlay.dart';
import 'package:kinos/theme/app_theme.dart';
import 'package:kinos/widgets/shared/anchored_popover.dart';

/// Onglet "Bibliothèque" — grille virtualisée des jaquettes, un seul
/// appel par session (cf. [arrLibraryProvider]). Tri/filtre dans
/// [arrLibraryViewProvider], en famille par instance comme le reste du
/// module : jamais partagé entre Radarr et Sonarr, ni avec l'onglet File
/// d'attente, ni avec Recherche/Films/Séries (cf. CLAUDE.md, le bug déjà
/// rencontré avec un filtre partagé entre onglets).
class ArrLibraryScreen extends ConsumerStatefulWidget {
  final ArrService service;
  final Widget? header;
  final EdgeInsets contentPadding;

  const ArrLibraryScreen(
      {required this.service,
      this.header,
      this.contentPadding = EdgeInsets.zero,
      super.key});

  @override
  ConsumerState<ArrLibraryScreen> createState() => _ArrLibraryScreenState();
}

const _sortLabels = {
  ArrLibrarySort.added: 'Date d\'ajout',
  ArrLibrarySort.title: 'Titre',
  ArrLibrarySort.year: 'Année',
  ArrLibrarySort.status: 'Statut',
};

final arrLibraryQueryProvider =
    StateProvider.autoDispose.family<String, ArrService>((ref, service) => '');

class _ArrLibraryScreenState extends ConsumerState<ArrLibraryScreen> {
  final _sortPopover = AnchoredPopoverController();

  int _compareBase(ArrLibrarySort sort, ArrLibraryEntry a, ArrLibraryEntry b) {
    return switch (sort) {
      // Absente : traitée comme la plus ancienne possible, pour finir en
      // dernier une fois le tri inversé (le plus récent d'abord).
      ArrLibrarySort.added =>
        (a.added ?? DateTime(1970)).compareTo(b.added ?? DateTime(1970)),
      ArrLibrarySort.title =>
        a.title.toLowerCase().compareTo(b.title.toLowerCase()),
      ArrLibrarySort.year => (a.year ?? 0).compareTo(b.year ?? 0),
      ArrLibrarySort.status => a.statusLabel.compareTo(b.statusLabel),
    };
  }

  List<ArrLibraryEntry> _apply(
      List<ArrLibraryEntry> entries, ArrLibraryViewState view) {
    final filtered = entries
        .where((e) => switch (view.filter) {
              ArrLibraryFilter.all => true,
              ArrLibraryFilter.monitored => e.monitored,
              ArrLibraryFilter.unmonitored => !e.monitored,
              ArrLibraryFilter.missing => !e.hasContent,
            })
        .toList();
    filtered.sort((a, b) {
      final cmp = _compareBase(view.sort, a, b);
      return view.ascending ? cmp : -cmp;
    });
    return filtered;
  }

  Future<void> _runAction(
    Future<ArrResult<void>> Function() action, {
    String? failureContext,
  }) async {
    final result = await action();
    if (!mounted) return;
    if (result case ArrFailure(:final detail)) {
      final parts = [failureContext, detail].nonNulls.toList();
      KinosSnack.show(
        parts.isEmpty ? 'Échec de l\'action.' : parts.join(' — '),
        context: context,
      );
    }
  }

  /// Pousse la fiche détail Arr — `await` puis rien d'autre : Flutter
  /// restaure de lui-même le focus sur le nœud de la grille (déjà
  /// re-demandé par `ArrLibraryGrid` juste avant cet appel, cf.
  /// `onOpenDetail`) une fois la route dépilée, comme tout retour de
  /// route standard — pas besoin de le redemander ici.
  Future<void> _openDetail(BuildContext context, ArrLibraryEntry entry) {
    return context.router.push(ArrDetailRoute(
      service: widget.service,
      id: entry.id,
    ));
  }

  Future<void> _confirmRemove(
      BuildContext context, ArrLibraryEntry entry) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => GlassAlertDialog(
        backgroundColor: AppColors.surfaceHigh,
        shape: const RoundedRectangleBorder(borderRadius: AppRadii.sheetBorder),
        title: const Text('Supprimer de la bibliothèque'),
        content: Text(
            '"${entry.title}" sera retiré de ${widget.service.label}, fichier compris.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      _runAction(
        () =>
            ref.read(arrLibraryProvider(widget.service).notifier).remove(entry),
        failureContext: 'Suppression',
      );
    }
  }

  Future<void> _showEdit(BuildContext context, ArrLibraryEntry entry) async {
    var monitored = entry.monitored;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => GlassAlertDialog(
          backgroundColor: AppColors.surfaceHigh,
          shape:
              const RoundedRectangleBorder(borderRadius: AppRadii.sheetBorder),
          title: Text('Modifier "${entry.title}"'),
          content: SizedBox(
            width: 380,
            child: Row(
              children: [
                Checkbox(
                  value: monitored,
                  onChanged: (value) =>
                      setDialogState(() => monitored = value ?? monitored),
                ),
                const Text('Surveillé'),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Annuler'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Enregistrer'),
            ),
          ],
        ),
      ),
    );
    if (confirmed == true && monitored != entry.monitored) {
      _runAction(
        () => ref
            .read(arrLibraryProvider(widget.service).notifier)
            .toggleMonitored(entry),
        failureContext: 'Modification',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(arrLibraryProvider(widget.service));
    final credentials =
        ref.watch(arrCredentialsProvider(widget.service)).valueOrNull;

    if (state.loading && state.entries.isEmpty) {
      return _placeholder(const Padding(
        padding: EdgeInsets.symmetric(vertical: AppSpacing.xl),
        child: Row(
          children: [
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            SizedBox(width: AppSpacing.sm),
            Text('Chargement de la bibliothèque…',
                style: TextStyle(color: AppColors.textSecondary)),
          ],
        ),
      ));
    }

    if (state.error != null && state.entries.isEmpty) {
      return _placeholder(Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl),
        child: Row(
          children: [
            const Icon(Icons.error_outline_rounded,
                size: 18, color: AppColors.error),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                _errorMessage(state.error!, state.errorDetail),
                style: const TextStyle(color: AppColors.error),
              ),
            ),
          ],
        ),
      ));
    }

    if (credentials == null || !credentials.isConfigured) {
      // Ne devrait pas arriver (le service est déjà configuré à ce
      // stade, sans quoi ArrHomeScreen n'aurait pas affiché cet onglet)
      // — repli défensif plutôt qu'une jaquette qui échoue en boucle.
      return _placeholder(const SizedBox.shrink());
    }

    final view = ref.watch(arrLibraryViewProvider(widget.service));
    final viewNotifier =
        ref.read(arrLibraryViewProvider(widget.service).notifier);
    final query =
        ref.watch(arrLibraryQueryProvider(widget.service)).trim().toLowerCase();
    final entries = _apply(state.entries, view)
        .where((entry) => entry.title.toLowerCase().contains(query))
        .toList();

    final toolbar = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.header != null) widget.header!,
        LayoutBuilder(
            builder: (context, constraints) => Wrap(
                  spacing: AppSpacing.md,
                  runSpacing: AppSpacing.sm,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    SizedBox(
                        width: constraints.maxWidth
                            .clamp(0, AppLibraryLayout.searchWidth),
                        child: OutlinedTextField(
                            onChanged: (value) => ref
                                .read(arrLibraryQueryProvider(widget.service)
                                    .notifier)
                                .state = value,
                            decoration: InputDecoration(
                                hintText:
                                    context.localized.managementSearchLibrary,
                                prefixIcon: const Icon(Icons.search),
                                border: InputBorder.none))),
                    Wrap(
                      spacing: AppSpacing.xxs,
                      runSpacing: AppSpacing.xxs,
                      children: [
                        FilterButton(
                          isSelected: view.filter == ArrLibraryFilter.all,
                          label: const Text('Tout'),
                          onPressed: () =>
                              viewNotifier.setFilter(ArrLibraryFilter.all),
                        ),
                        FilterButton(
                          isSelected: view.filter == ArrLibraryFilter.monitored,
                          label: const Text('Surveillé'),
                          onPressed: () => viewNotifier
                              .setFilter(ArrLibraryFilter.monitored),
                        ),
                        FilterButton(
                          isSelected:
                              view.filter == ArrLibraryFilter.unmonitored,
                          label: const Text('Non surveillé'),
                          onPressed: () => viewNotifier
                              .setFilter(ArrLibraryFilter.unmonitored),
                        ),
                        FilterButton(
                          isSelected: view.filter == ArrLibraryFilter.missing,
                          label: const Text('Manquant'),
                          onPressed: () =>
                              viewNotifier.setFilter(ArrLibraryFilter.missing),
                        ),
                      ],
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    AnchoredPopover(
                      controller: _sortPopover,
                      popoverBuilder: (context, close) => PopoverOptionList(
                        onSelected: close,
                        options: ArrLibrarySort.values
                            .map((sort) => PopoverOption(
                                  content: Text(_sortLabels[sort]!),
                                  selected: view.sort == sort,
                                  onSelect: () => viewNotifier.setSort(sort),
                                ))
                            .toList(),
                      ),
                      child: FocusRing(
                        borderRadius: AppRadii.controlBorder,
                        onActivate: _sortPopover.toggle,
                        child: ExcludeFocus(
                          child: Tooltip(
                            message: 'Trier',
                            child: TextButton.icon(
                              onPressed: _sortPopover.toggle,
                              label: Text('Trier : ${_sortLabels[view.sort]}'),
                              icon: const Icon(Icons.expand_more),
                            ),
                          ),
                        ),
                      ),
                    ),
                    // Sens du tri : contrôle indépendant du critère, mémorisé par
                    // critère (cf. ArrLibraryViewState.ascendingByCriterion) — pas
                    // question qu'inverser "Date d'ajout" retourne aussi "Titre".
                    FocusRing(
                      borderRadius: AppRadii.controlBorder,
                      onActivate: viewNotifier.toggleDirection,
                      child: ExcludeFocus(
                        child: Tooltip(
                          message: view.ascending ? 'Croissant' : 'Décroissant',
                          child: IconButton(
                            onPressed: viewNotifier.toggleDirection,
                            icon: Icon(
                              view.ascending
                                  ? Icons.arrow_upward_rounded
                                  : Icons.arrow_downward_rounded,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                )),
        const SizedBox(height: AppSpacing.sm),
        Text(
            '${context.localized.itemCount(entries.length)} · ↑↓←→ · Entrée · Maj+F10',
            style: AppTypography.meta),
        const SizedBox(height: AppSpacing.sm),
      ],
    );
    return ArrLibraryGrid(
      header: toolbar,
      contentPadding: widget.contentPadding,
      entries: entries,
      baseUrl: credentials.baseUrl,
      apiKey: credentials.apiKey,
      onOpenDetail: (entry) => _openDetail(context, entry),
      onSearch: (entry) => _runAction(
        () =>
            ref.read(arrLibraryProvider(widget.service).notifier).search(entry),
        failureContext: 'Recherche',
      ),
      onToggleMonitored: (entry) => _runAction(
        () => ref
            .read(arrLibraryProvider(widget.service).notifier)
            .toggleMonitored(entry),
        failureContext: 'Surveillance',
      ),
      onEdit: (entry) => _showEdit(context, entry),
      onRemove: (entry) => _confirmRemove(context, entry),
    );
  }

  Widget _placeholder(Widget child) => SingleChildScrollView(
        padding: widget.contentPadding,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (widget.header != null) widget.header!,
          child,
        ]),
      );

  String _errorMessage(ArrApiError error, String? detail) {
    final base = switch (error) {
      ArrApiError.unreachable => 'Serveur injoignable.',
      ArrApiError.unauthorized => 'Clé API invalide.',
      ArrApiError.notFound => 'Route introuvable.',
      ArrApiError.serverError => 'Erreur serveur.',
      ArrApiError.invalidResponse => 'Réponse inattendue.',
    };
    return detail == null ? base : '$base $detail';
  }
}
