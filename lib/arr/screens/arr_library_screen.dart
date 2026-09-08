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

enum _LibrarySort { title, year, status }

enum _LibraryFilter { all, monitored, unmonitored, missing }

/// Onglet "Bibliothèque" — grille virtualisée des jaquettes, un seul
/// appel par session (cf. [arrLibraryProvider]). Tri/filtre en état
/// local à cet écran : aucun provider partagé, ni avec l'onglet File
/// d'attente, ni avec Recherche/Films/Séries (cf. CLAUDE.md, le bug déjà
/// rencontré avec un filtre partagé entre onglets).
class ArrLibraryScreen extends ConsumerStatefulWidget {
  final ArrService service;

  const ArrLibraryScreen({required this.service, super.key});

  @override
  ConsumerState<ArrLibraryScreen> createState() => _ArrLibraryScreenState();
}

class _ArrLibraryScreenState extends ConsumerState<ArrLibraryScreen> {
  _LibrarySort _sort = _LibrarySort.title;
  _LibraryFilter _filter = _LibraryFilter.all;

  List<ArrLibraryEntry> _apply(List<ArrLibraryEntry> entries) {
    final filtered = entries
        .where((e) => switch (_filter) {
              _LibraryFilter.all => true,
              _LibraryFilter.monitored => e.monitored,
              _LibraryFilter.unmonitored => !e.monitored,
              _LibraryFilter.missing => !e.hasContent,
            })
        .toList();
    filtered.sort((a, b) => switch (_sort) {
          _LibrarySort.title =>
            a.title.toLowerCase().compareTo(b.title.toLowerCase()),
          _LibrarySort.year => (b.year ?? 0).compareTo(a.year ?? 0),
          _LibrarySort.status => a.statusLabel.compareTo(b.statusLabel),
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

    final entries = _apply(state.entries);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              '↑↓←→ naviguer · Entrée détail · clic droit ou touche Menu : actions',
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: AppColors.textDisabled),
            ),
            const Spacer(),
            Row(
              spacing: AppSpacing.xxs,
              children: [
                FilterButton(
                  isSelected: _filter == _LibraryFilter.all,
                  label: const Text('Tout'),
                  onPressed: () => setState(() => _filter = _LibraryFilter.all),
                ),
                FilterButton(
                  isSelected: _filter == _LibraryFilter.monitored,
                  label: const Text('Surveillé'),
                  onPressed: () =>
                      setState(() => _filter = _LibraryFilter.monitored),
                ),
                FilterButton(
                  isSelected: _filter == _LibraryFilter.unmonitored,
                  label: const Text('Non surveillé'),
                  onPressed: () =>
                      setState(() => _filter = _LibraryFilter.unmonitored),
                ),
                FilterButton(
                  isSelected: _filter == _LibraryFilter.missing,
                  label: const Text('Manquant'),
                  onPressed: () =>
                      setState(() => _filter = _LibraryFilter.missing),
                ),
              ],
            ),
            const SizedBox(width: AppSpacing.sm),
            FocusRing(
              borderRadius: AppRadii.controlBorder,
              child: ExcludeFocus(
                child: PopupMenuButton<_LibrarySort>(
                  tooltip: 'Trier',
                  color: AppColors.surfaceHigh,
                  shape: const RoundedRectangleBorder(
                      borderRadius: AppRadii.sheetBorder),
                  icon: const Icon(Icons.sort_rounded,
                      color: AppColors.textSecondary),
                  onSelected: (value) => setState(() => _sort = value),
                  itemBuilder: (context) => const [
                    PopupMenuItem(
                        value: _LibrarySort.title, child: Text('Titre')),
                    PopupMenuItem(
                        value: _LibrarySort.year, child: Text('Année')),
                    PopupMenuItem(
                        value: _LibrarySort.status, child: Text('Statut')),
                  ],
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
