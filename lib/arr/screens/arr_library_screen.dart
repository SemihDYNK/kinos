import 'package:flutter/material.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:fladder/arr/models/arr_library_entry.dart';
import 'package:fladder/arr/models/arr_service.dart';
import 'package:fladder/arr/providers/arr_library_providers.dart';
import 'package:fladder/arr/providers/arr_providers.dart';
import 'package:fladder/arr/screens/widgets/arr_library_grid.dart';
import 'package:fladder/arr/services/arr_api_client.dart';
import 'package:fladder/screens/shared/chips/filter_button.dart';
import 'package:fladder/screens/shared/fladder_notification_overlay.dart';
import 'package:fladder/theme/app_theme.dart';
import 'package:fladder/widgets/shared/anchored_popover.dart';

/// Onglet "Bibliothèque" — grille virtualisée des jaquettes, un seul
/// appel par session (cf. [arrLibraryProvider]). Tri/filtre dans
/// [arrLibraryViewProvider], en famille par instance comme le reste du
/// module : jamais partagé entre Radarr et Sonarr, ni avec l'onglet File
/// d'attente, ni avec Recherche/Films/Séries (cf. CLAUDE.md, le bug déjà
/// rencontré avec un filtre partagé entre onglets).
class ArrLibraryScreen extends ConsumerStatefulWidget {
  final ArrService service;

  const ArrLibraryScreen({required this.service, super.key});

  @override
  ConsumerState<ArrLibraryScreen> createState() => _ArrLibraryScreenState();
}

const _sortLabels = {
  ArrLibrarySort.added: 'Date d\'ajout',
  ArrLibrarySort.title: 'Titre',
  ArrLibrarySort.year: 'Année',
  ArrLibrarySort.status: 'Statut',
};

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
      FladderSnack.show(
        parts.isEmpty ? 'Échec de l\'action.' : parts.join(' — '),
        context: context,
      );
    }
  }

  Future<void> _showDetail(BuildContext context, ArrLibraryEntry entry) {
    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surfaceHigh,
        shape: const RoundedRectangleBorder(borderRadius: AppRadii.sheetBorder),
        title: Text(entry.title,
            style: Theme.of(context).textTheme.headlineMedium),
        content: SizedBox(
          width: 380,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _DetailRow(label: 'Année', value: entry.year?.toString() ?? '—'),
              _DetailRow(label: 'Statut', value: entry.statusLabel),
              _DetailRow(
                  label: 'Surveillé', value: entry.monitored ? 'Oui' : 'Non'),
              if (entry.isMovie)
                _DetailRow(label: 'Qualité', value: entry.qualityName ?? '—'),
              if (!entry.isMovie)
                _DetailRow(
                    label: 'Saisons',
                    value: (entry.seasonCount ?? 0).toString()),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Fermer'),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmRemove(
      BuildContext context, ArrLibraryEntry entry) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
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
        builder: (context, setDialogState) => AlertDialog(
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
      return const Padding(
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
      );
    }

    if (state.error != null && state.entries.isEmpty) {
      return Padding(
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
      );
    }

    if (credentials == null || !credentials.isConfigured) {
      // Ne devrait pas arriver (le service est déjà configuré à ce
      // stade, sans quoi ArrHomeScreen n'aurait pas affiché cet onglet)
      // — repli défensif plutôt qu'une jaquette qui échoue en boucle.
      return const SizedBox.shrink();
    }

    final view = ref.watch(arrLibraryViewProvider(widget.service));
    final viewNotifier =
        ref.read(arrLibraryViewProvider(widget.service).notifier);
    final entries = _apply(state.entries, view);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            // Expanded + ellipsis, pas Spacer : ce texte est le seul élément
            // de cette ligne sans largeur naturelle bornée — sans ça, la
            // rangée de contrôles à droite (4 filtres + tri + sens) peut se
            // faire pousser hors champ par une fenêtre étroite, avec un
            // débordement de Row qui rend le dernier bouton (le sens du
            // tri) instable au clic : la cible visuelle et la cible de
            // geste réelle ne coïncident plus forcément.
            Expanded(
              child: Text(
                '↑↓←→ naviguer · Entrée détail · clic droit ou touche Menu : actions',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: AppColors.textDisabled),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Row(
              spacing: AppSpacing.xxs,
              children: [
                FilterButton(
                  isSelected: view.filter == ArrLibraryFilter.all,
                  label: const Text('Tout'),
                  onPressed: () => viewNotifier.setFilter(ArrLibraryFilter.all),
                ),
                FilterButton(
                  isSelected: view.filter == ArrLibraryFilter.monitored,
                  label: const Text('Surveillé'),
                  onPressed: () =>
                      viewNotifier.setFilter(ArrLibraryFilter.monitored),
                ),
                FilterButton(
                  isSelected: view.filter == ArrLibraryFilter.unmonitored,
                  label: const Text('Non surveillé'),
                  onPressed: () =>
                      viewNotifier.setFilter(ArrLibraryFilter.unmonitored),
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
                    child: IconButton(
                      onPressed: _sortPopover.toggle,
                      icon: const Icon(Icons.sort_rounded,
                          color: AppColors.textSecondary),
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
        ),
        const SizedBox(height: AppSpacing.sm),
        Expanded(
          child: ArrLibraryGrid(
            entries: entries,
            baseUrl: credentials.baseUrl,
            apiKey: credentials.apiKey,
            onOpenDetail: (entry) => _showDetail(context, entry),
            onSearch: (entry) => _runAction(
              () => ref
                  .read(arrLibraryProvider(widget.service).notifier)
                  .search(entry),
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
          ),
        ),
      ],
    );
  }

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

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;
  const _DetailRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xxs),
      child: Row(
        children: [
          SizedBox(
            width: 90,
            child: Text(label,
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: AppColors.textSecondary)),
          ),
          Expanded(
            child: Text(value,
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: AppColors.textPrimary)),
          ),
        ],
      ),
    );
  }
}
