import 'package:kinos/widgets/shared/frosted_surface.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:kinos/arr/models/arr_queue_item.dart';
import 'package:kinos/screens/details_screens/components/media_info_formatters.dart';
import 'package:kinos/theme/app_theme.dart';
import 'package:kinos/widgets/shared/focus_row.dart';

enum _ArrQueueColumn {
  title,
  indexer,
  quality,
  size,
  progress,
  timeLeft,
  status,
}

Color _statusColor(ArrQueueStatus status) => switch (status) {
      ArrQueueStatus.downloading ||
      ArrQueueStatus.queued ||
      ArrQueueStatus.importing =>
        AppColors.textSecondary,
      ArrQueueStatus.paused => AppColors.textDisabled,
      ArrQueueStatus.completed => AppColors.success,
      ArrQueueStatus.warning => AppColors.warning,
      ArrQueueStatus.failed => AppColors.error,
    };

/// Table dense de la file d'attente — une seule instance à la fois (le
/// sélecteur vit dans [ArrHomeScreen]), donc la colonne "instance" est
/// constante sur toutes les lignes ; gardée quand même pour rester lisible
/// si une vue combinée est ajoutée plus tard.
///
/// Une ligne par [ArrQueueGroup] plutôt que par [ArrQueueItem] : un paquet
/// de saison Sonarr partage un seul `downloadId` sur plusieurs
/// enregistrements (un par épisode), qu'il faut regrouper — sans quoi
/// taille/progression, identiques sur chaque épisode, semblent se répéter
/// et se lisent comme démultipliées par le nombre d'épisodes.
///
/// Sélection multiple (Maj/Ctrl+clic) et menu contextuel appliqués au
/// widget parent via les callbacks — cette table ne connaît que
/// l'affichage, le tri et la sélection ; jamais d'appel réseau direct
/// (cf. CLAUDE.md : aucun appel API depuis un widget).
class ArrQueueTable extends StatefulWidget {
  final List<ArrQueueItem> items;
  final String instanceLabel;

  /// `true` si un client qBittorrent est configuré — condition nécessaire
  /// (mais pas suffisante : la route peut encore échouer au moment de
  /// l'appel) pour activer pause/reprise sur une ligne.
  final bool downloadClientReady;

  final void Function(ArrQueueGroup group) onPause;
  final void Function(ArrQueueGroup group) onResume;
  final void Function(ArrQueueGroup group) onForceImport;
  final void Function(List<ArrQueueGroup> groups,
      {required bool removeFromClient, required bool blocklist}) onRemove;

  const ArrQueueTable({
    required this.items,
    required this.instanceLabel,
    required this.downloadClientReady,
    required this.onPause,
    required this.onResume,
    required this.onForceImport,
    required this.onRemove,
    super.key,
  });

  @override
  State<ArrQueueTable> createState() => _ArrQueueTableState();
}

class _ArrQueueTableState extends State<ArrQueueTable> {
  _ArrQueueColumn _sortColumn = _ArrQueueColumn.status;
  bool _ascending = true;

  final Set<String> _selected = {};
  final Set<String> _expanded = {};
  int? _lastClickedIndex;

  static const _checkboxWidth = 32.0;
  static const _expandWidth = 20.0;
  static const _minTitleWidth = 240.0;
  static const _instanceWidth = 72.0;
  static const _indexerWidth = 120.0;
  static const _qualityWidth = 110.0;
  static const _sizeWidth = 84.0;
  static const _progressWidth = 140.0;
  static const _timeLeftWidth = 84.0;
  static const _statusWidth = 130.0;
  // Two compact buttons plus their external focus-ring padding.
  static const _actionsWidth = AppPageLayout.toolbarHeight * 2;
  static const _columnGap = AppSpacing.xs;

  static const _minTableWidth = _checkboxWidth +
      _columnGap +
      _expandWidth +
      _columnGap +
      _minTitleWidth +
      _columnGap +
      _instanceWidth +
      _columnGap +
      _indexerWidth +
      _columnGap +
      _qualityWidth +
      _columnGap +
      _sizeWidth +
      _columnGap +
      _progressWidth +
      _columnGap +
      _timeLeftWidth +
      _columnGap +
      _statusWidth +
      _columnGap +
      _actionsWidth;

  int _compareNum(num? a, num? b) {
    if (a == null && b == null) return 0;
    if (a == null) return 1;
    if (b == null) return -1;
    return a.compareTo(b);
  }

  int _compareStr(String? a, String? b) =>
      (a?.toLowerCase() ?? '').compareTo(b?.toLowerCase() ?? '');

  List<ArrQueueGroup> get _sorted {
    final groups = ArrQueueGroup.groupItems(widget.items);
    groups.sort((a, b) {
      final result = switch (_sortColumn) {
        _ArrQueueColumn.title => _compareStr(a.title, b.title),
        _ArrQueueColumn.indexer => _compareStr(a.indexer, b.indexer),
        _ArrQueueColumn.quality => _compareStr(a.qualityName, b.qualityName),
        _ArrQueueColumn.size => _compareNum(a.size, b.size),
        _ArrQueueColumn.progress => _compareNum(a.progress, b.progress),
        _ArrQueueColumn.timeLeft => _compareStr(a.timeLeft, b.timeLeft),
        _ArrQueueColumn.status => _compareNum(a.status.index, b.status.index),
      };
      return _ascending ? result : -result;
    });
    return groups;
  }

  void _onHeaderTap(_ArrQueueColumn column) {
    setState(() {
      if (_sortColumn == column) {
        _ascending = !_ascending;
      } else {
        _sortColumn = column;
        _ascending = true;
      }
    });
  }

  void _onRowTap(int index, List<ArrQueueGroup> rows,
      {required bool shift, required bool ctrl}) {
    final key = rows[index].key;
    setState(() {
      if (shift && _lastClickedIndex != null) {
        final start = _lastClickedIndex!.clamp(0, rows.length - 1);
        final range = [start, index]..sort();
        _selected
            .addAll(rows.sublist(range[0], range[1] + 1).map((e) => e.key));
      } else if (ctrl) {
        if (!_selected.add(key)) _selected.remove(key);
        _lastClickedIndex = index;
      } else {
        _selected
          ..clear()
          ..add(key);
        _lastClickedIndex = index;
      }
    });
  }

  void _toggleExpanded(String key) => setState(() {
        if (!_expanded.remove(key)) _expanded.add(key);
      });

  void _clearSelection() => setState(_selected.clear);

  Future<void> _confirmRemove(
    BuildContext context,
    List<ArrQueueGroup> groups, {
    required bool blocklist,
  }) async {
    final totalItems = groups.fold<int>(0, (sum, g) => sum + g.episodeCount);
    final multiple = totalItems > 1;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => GlassAlertDialog(
        backgroundColor: AppColors.surfaceHigh,
        shape: const RoundedRectangleBorder(borderRadius: AppRadii.sheetBorder),
        title: Text(
            blocklist ? 'Blocklist et remplacement' : 'Retirer de la file'),
        content: Text(
          blocklist
              ? '${multiple ? '$totalItems éléments seront' : "\"${groups.first.title}\" sera"} '
                  'bloqués et retirés du client de téléchargement ; le serveur cherchera un remplacement.'
              : '${multiple ? '$totalItems éléments seront' : "\"${groups.first.title}\" sera"} '
                  'retirés de la file et annulés côté client de téléchargement.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Confirmer'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      widget.onRemove(groups, removeFromClient: true, blocklist: blocklist);
      _clearSelection();
    }
  }

  Future<void> _showDetail(BuildContext context, ArrQueueItem item) {
    return showDialog(
      context: context,
      builder: (context) => GlassAlertDialog(
        backgroundColor: AppColors.surfaceHigh,
        shape: const RoundedRectangleBorder(borderRadius: AppRadii.sheetBorder),
        title:
            Text(item.title, style: Theme.of(context).textTheme.headlineMedium),
        content: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(item.status.label,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: _statusColor(item.status),
                      fontWeight: FontWeight.w600)),
              const SizedBox(height: AppSpacing.sm),
              _DetailRow(label: 'Indexeur', value: item.indexer ?? '—'),
              _DetailRow(label: 'Qualité', value: item.qualityName ?? '—'),
              _DetailRow(
                  label: 'Taille', value: formatFileSize(item.size) ?? '—'),
              _DetailRow(
                  label: 'Protocole',
                  value: item.protocol.isEmpty ? '—' : item.protocol),
              if (item.errorMessage != null) ...[
                const SizedBox(height: AppSpacing.sm),
                Text(item.errorMessage!,
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: AppColors.error)),
              ],
              if (item.statusMessages.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.sm),
                for (final message in item.statusMessages)
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.xxs),
                    child: Text('• $message',
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(color: AppColors.textSecondary)),
                  ),
              ],
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

  bool _canControl(ArrQueueGroup group) =>
      widget.downloadClientReady && (group.downloadId?.isNotEmpty ?? false);

  String _controlDisabledReason(ArrQueueGroup group) {
    if (group.downloadId == null || group.downloadId!.isEmpty) {
      return 'Identifiant de téléchargement absent — action indisponible.';
    }
    return 'Client de téléchargement non configuré (Réglages → qBittorrent).';
  }

  void _showContextMenu(
      BuildContext context, Offset globalPosition, ArrQueueGroup row) {
    final targets = _selected.contains(row.key) && _selected.length > 1
        ? _sorted.where((e) => _selected.contains(e.key)).toList()
        : [row];
    if (targets.length == 1 && !_selected.contains(row.key)) {
      setState(() {
        _selected
          ..clear()
          ..add(row.key);
      });
    }

    final position = RelativeRect.fromLTRB(globalPosition.dx, globalPosition.dy,
        globalPosition.dx, globalPosition.dy);
    final singleRowActionable = targets.length == 1 ? targets.first : null;
    final controllable =
        singleRowActionable != null && _canControl(singleRowActionable);

    showGlassMenu<void>(
      context: context,
      position: position,
      items: [
        if (controllable && singleRowActionable.status != ArrQueueStatus.paused)
          PopupMenuItem(
            onTap: () => widget.onPause(singleRowActionable),
            child: const _MenuLabel(
                icon: Icons.pause_rounded, label: 'Mettre en pause'),
          ),
        if (controllable && singleRowActionable.status == ArrQueueStatus.paused)
          PopupMenuItem(
            onTap: () => widget.onResume(singleRowActionable),
            child: const _MenuLabel(
                icon: Icons.play_arrow_rounded, label: 'Reprendre'),
          ),
        if (singleRowActionable != null)
          PopupMenuItem(
            onTap: () => widget.onForceImport(singleRowActionable),
            child: const _MenuLabel(
                icon: Icons.file_download_done_rounded,
                label: 'Forcer l\'import'),
          ),
        const PopupMenuDivider(),
        PopupMenuItem(
          onTap: () => _confirmRemove(context, targets, blocklist: false),
          child: const _MenuLabel(
              icon: Icons.remove_circle_outline_rounded,
              label: 'Supprimer du client'),
        ),
        PopupMenuItem(
          onTap: () => _confirmRemove(context, targets, blocklist: true),
          child: const _MenuLabel(
              icon: Icons.block_rounded,
              label: 'Blocklist + chercher un remplaçant'),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final rows = _sorted;
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth < _minTableWidth
            ? _minTableWidth
            : constraints.maxWidth;
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SizedBox(
            width: width,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _ArrQueueHeaderRow(
                  sortColumn: _sortColumn,
                  ascending: _ascending,
                  onTap: _onHeaderTap,
                  allSelected:
                      rows.isNotEmpty && _selected.length == rows.length,
                  someSelected: _selected.isNotEmpty,
                  onToggleAll: (value) => setState(() {
                    if (value) {
                      _selected.addAll(rows.map((e) => e.key));
                    } else {
                      _selected.clear();
                    }
                  }),
                ),
                const Divider(height: 1, thickness: 1, color: AppColors.border),
                if (rows.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: AppSpacing.lg),
                    child: Text('File d\'attente vide.',
                        style: TextStyle(color: AppColors.textSecondary)),
                  )
                else
                  for (final (index, group) in rows.indexed) ...[
                    _ArrQueueRow(
                      key: ValueKey(group.key),
                      group: group,
                      striped: index.isOdd,
                      selected: _selected.contains(group.key),
                      expanded: _expanded.contains(group.key),
                      instanceLabel: widget.instanceLabel,
                      canControl: _canControl(group),
                      controlDisabledReason: _controlDisabledReason(group),
                      onTap: ({required shift, required ctrl}) =>
                          _onRowTap(index, rows, shift: shift, ctrl: ctrl),
                      onSecondaryTap: (position) =>
                          _showContextMenu(context, position, group),
                      onOpenDetail: () => _showDetail(context, group.primary),
                      onDelete: () =>
                          _confirmRemove(context, [group], blocklist: false),
                      onPause: () => widget.onPause(group),
                      onResume: () => widget.onResume(group),
                      onToggleExpanded: group.isGrouped
                          ? () => _toggleExpanded(group.key)
                          : null,
                      onMoreActions: (position) =>
                          _showContextMenu(context, position, group),
                    ),
                    if (group.isGrouped && _expanded.contains(group.key))
                      for (final item in group.items)
                        _ArrQueueSubRow(
                          key: ValueKey('${group.key}-${item.id}'),
                          item: item,
                          striped: index.isOdd,
                          onOpenDetail: () => _showDetail(context, item),
                        ),
                  ],
              ],
            ),
          ),
        );
      },
    );
  }
}

class _MenuLabel extends StatelessWidget {
  final IconData icon;
  final String label;
  const _MenuLabel({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 18, color: AppColors.textSecondary),
        const SizedBox(width: AppSpacing.xs),
        Text(label),
      ],
    );
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

class _ArrQueueHeaderRow extends StatelessWidget {
  final _ArrQueueColumn sortColumn;
  final bool ascending;
  final ValueChanged<_ArrQueueColumn> onTap;
  final bool allSelected;
  final bool someSelected;
  final ValueChanged<bool> onToggleAll;

  const _ArrQueueHeaderRow({
    required this.sortColumn,
    required this.ascending,
    required this.onTap,
    required this.allSelected,
    required this.someSelected,
    required this.onToggleAll,
  });

  Widget _header(
      BuildContext context, String label, double width, _ArrQueueColumn column,
      {TextAlign align = TextAlign.start}) {
    final selected = sortColumn == column;
    return SizedBox(
      width: width,
      child: FocusRing(
        borderRadius: AppRadii.controlBorder,
        onActivate: () => onTap(column),
        child: ExcludeFocus(
          child: InkWell(
            borderRadius: AppRadii.controlBorder,
            onTap: () => onTap(column),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
              child: Row(
                mainAxisAlignment: align == TextAlign.end
                    ? MainAxisAlignment.end
                    : MainAxisAlignment.start,
                children: [
                  if (align == TextAlign.end && selected) ...[
                    Icon(
                        ascending
                            ? Icons.arrow_upward_rounded
                            : Icons.arrow_downward_rounded,
                        size: 12,
                        color: AppColors.textPrimary),
                    const SizedBox(width: AppSpacing.xxs),
                  ],
                  Flexible(
                    child: Text(
                      label,
                      textAlign: align,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: selected
                              ? AppColors.textPrimary
                              : AppColors.textSecondary),
                    ),
                  ),
                  if (align != TextAlign.end && selected) ...[
                    const SizedBox(width: AppSpacing.xxs),
                    Icon(
                        ascending
                            ? Icons.arrow_upward_rounded
                            : Icons.arrow_downward_rounded,
                        size: 12,
                        color: AppColors.textPrimary),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const gap = SizedBox(width: AppSpacing.xs);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
      child: Row(
        children: [
          SizedBox(
            width: _ArrQueueTableState._checkboxWidth,
            child: FocusRing(
              borderRadius: AppRadii.controlBorder,
              onActivate: () => onToggleAll(!allSelected),
              child: ExcludeFocus(
                child: Checkbox(
                  value: allSelected ? true : (someSelected ? null : false),
                  tristate: true,
                  onChanged: (value) => onToggleAll(value ?? false),
                ),
              ),
            ),
          ),
          gap,
          const SizedBox(width: _ArrQueueTableState._expandWidth),
          gap,
          Expanded(
              child: _header(
                  context, 'Titre', double.infinity, _ArrQueueColumn.title)),
          gap,
          SizedBox(
              width: _ArrQueueTableState._instanceWidth,
              child: Text('Instance',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: AppColors.textSecondary))),
          gap,
          _header(context, 'Indexeur', _ArrQueueTableState._indexerWidth,
              _ArrQueueColumn.indexer),
          gap,
          _header(context, 'Qualité', _ArrQueueTableState._qualityWidth,
              _ArrQueueColumn.quality),
          gap,
          _header(context, 'Taille', _ArrQueueTableState._sizeWidth,
              _ArrQueueColumn.size,
              align: TextAlign.end),
          gap,
          _header(context, 'Progression', _ArrQueueTableState._progressWidth,
              _ArrQueueColumn.progress,
              align: TextAlign.end),
          gap,
          _header(context, 'Restant', _ArrQueueTableState._timeLeftWidth,
              _ArrQueueColumn.timeLeft,
              align: TextAlign.end),
          gap,
          _header(context, 'Statut', _ArrQueueTableState._statusWidth,
              _ArrQueueColumn.status),
          gap,
          const SizedBox(width: _ArrQueueTableState._actionsWidth),
        ],
      ),
    );
  }
}

class _ArrQueueRow extends StatelessWidget {
  final ArrQueueGroup group;
  final bool striped;
  final bool selected;
  final bool expanded;
  final String instanceLabel;
  final bool canControl;
  final String controlDisabledReason;
  final void Function({required bool shift, required bool ctrl}) onTap;
  final void Function(Offset globalPosition) onSecondaryTap;
  final VoidCallback onOpenDetail;
  final VoidCallback onDelete;
  final VoidCallback onPause;
  final VoidCallback onResume;
  final VoidCallback? onToggleExpanded;
  final void Function(Offset globalPosition) onMoreActions;

  const _ArrQueueRow({
    required this.group,
    required this.striped,
    required this.selected,
    required this.expanded,
    required this.instanceLabel,
    required this.canControl,
    required this.controlDisabledReason,
    required this.onTap,
    required this.onSecondaryTap,
    required this.onOpenDetail,
    required this.onDelete,
    required this.onPause,
    required this.onResume,
    required this.onToggleExpanded,
    required this.onMoreActions,
    super.key,
  });

  bool get _isPaused => group.status == ArrQueueStatus.paused;

  @override
  Widget build(BuildContext context) {
    final baseStyle = Theme.of(context)
        .textTheme
        .bodySmall
        ?.copyWith(color: AppColors.textPrimary.withValues(alpha: 0.9));
    const gap = SizedBox(width: AppSpacing.xs);
    final progress = group.progress;

    return ColoredBox(
      color: selected
          ? AppColors.surfaceHover
          : (striped ? AppColors.surface : Colors.transparent),
      child: FocusRow(
        child: Focus(
          onKeyEvent: (node, event) {
            if (event is! KeyDownEvent) return KeyEventResult.ignored;
            if (event.logicalKey == LogicalKeyboardKey.delete ||
                event.logicalKey == LogicalKeyboardKey.backspace) {
              onDelete();
              return KeyEventResult.handled;
            }
            if (event.logicalKey == LogicalKeyboardKey.enter) {
              onOpenDetail();
              return KeyEventResult.handled;
            }
            return KeyEventResult.ignored;
          },
          child: FocusRing(
            onActivate: onOpenDetail,
            // Pas d'ExcludeFocus ici : contrairement au motif habituel
            // (un seul enfant nativement focusable à exclure), cette
            // ligne contient aussi les FocusRing déplier/pause/reprendre
            // et "plus d'actions", qui doivent rester atteignables —
            // flèche droite pour y entrer, cf. FocusRow ci-dessus.
            child: Builder(
              builder: (context) {
                // État capturé à `onTapDown`, consommé par `onTap` juste
                // après — un seul geste, jamais deux dispatchs
                // concurrents (un `Listener.onPointerDown` séparé
                // déclencherait la sélection deux fois : une fois avec
                // les modificateurs, une fois sans, le second appel
                // écrasant le premier).
                var shiftHeld = false;
                var ctrlHeld = false;
                return GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTapDown: (_) {
                    final keysPressed =
                        HardwareKeyboard.instance.logicalKeysPressed;
                    shiftHeld =
                        keysPressed.contains(LogicalKeyboardKey.shiftLeft) ||
                            keysPressed.contains(LogicalKeyboardKey.shiftRight);
                    ctrlHeld = keysPressed
                            .contains(LogicalKeyboardKey.controlLeft) ||
                        keysPressed.contains(LogicalKeyboardKey.controlRight) ||
                        keysPressed.contains(LogicalKeyboardKey.metaLeft) ||
                        keysPressed.contains(LogicalKeyboardKey.metaRight);
                  },
                  onTap: () => onTap(shift: shiftHeld, ctrl: ctrlHeld),
                  onSecondaryTapUp: (details) =>
                      onSecondaryTap(details.globalPosition),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.xs, vertical: AppSpacing.sm),
                    child: Row(
                      children: [
                        SizedBox(
                          width: _ArrQueueTableState._checkboxWidth,
                          child: ExcludeFocus(
                            child: Checkbox(
                              value: selected,
                              onChanged: (_) => onTap(shift: false, ctrl: true),
                            ),
                          ),
                        ),
                        gap,
                        SizedBox(
                          width: _ArrQueueTableState._expandWidth,
                          child: onToggleExpanded == null
                              ? null
                              : FocusRing(
                                  borderRadius: AppRadii.controlBorder,
                                  onActivate: onToggleExpanded,
                                  child: ExcludeFocus(
                                    child: InkWell(
                                      borderRadius: AppRadii.controlBorder,
                                      onTap: onToggleExpanded,
                                      child: Icon(
                                        expanded
                                            ? Icons.expand_more_rounded
                                            : Icons.chevron_right_rounded,
                                        size: 16,
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                  ),
                                ),
                        ),
                        gap,
                        Expanded(
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Flexible(
                                child: Tooltip(
                                  message: group.title,
                                  child: Text(group.title,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: baseStyle),
                                ),
                              ),
                              if (group.isGrouped) ...[
                                const SizedBox(width: AppSpacing.xs),
                                Text(
                                  group.groupLabel,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodySmall
                                      ?.copyWith(
                                          color: AppColors.textSecondary),
                                ),
                              ],
                            ],
                          ),
                        ),
                        gap,
                        SizedBox(
                          width: _ArrQueueTableState._instanceWidth,
                          child: Text(instanceLabel,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: baseStyle),
                        ),
                        gap,
                        SizedBox(
                          width: _ArrQueueTableState._indexerWidth,
                          child: Text(group.indexer ?? '—',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: baseStyle),
                        ),
                        gap,
                        SizedBox(
                          width: _ArrQueueTableState._qualityWidth,
                          child: Text(group.qualityName ?? '—',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: baseStyle),
                        ),
                        gap,
                        SizedBox(
                          width: _ArrQueueTableState._sizeWidth,
                          child: Text(formatFileSize(group.size) ?? '—',
                              textAlign: TextAlign.end,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: baseStyle),
                        ),
                        gap,
                        SizedBox(
                          width: _ArrQueueTableState._progressWidth,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              Expanded(
                                child: ClipRRect(
                                  borderRadius: AppRadii.controlBorder,
                                  child: LinearProgressIndicator(
                                    value: progress,
                                    minHeight: 6,
                                    backgroundColor: AppColors.border,
                                    valueColor: AlwaysStoppedAnimation(
                                        _statusColor(group.status)),
                                  ),
                                ),
                              ),
                              const SizedBox(width: AppSpacing.xxs),
                              Text(
                                progress == null
                                    ? '—'
                                    : '${(progress * 100).round()}%',
                                style: baseStyle,
                              ),
                            ],
                          ),
                        ),
                        gap,
                        SizedBox(
                          width: _ArrQueueTableState._timeLeftWidth,
                          child: Text(group.timeLeft ?? '—',
                              textAlign: TextAlign.end,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: baseStyle),
                        ),
                        gap,
                        SizedBox(
                          width: _ArrQueueTableState._statusWidth,
                          child: Tooltip(
                            message: group.statusMessages.isEmpty
                                ? group.status.label
                                : group.statusMessages.join('\n'),
                            child: Text(group.status.label,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: baseStyle?.copyWith(
                                    color: _statusColor(group.status))),
                          ),
                        ),
                        gap,
                        SizedBox(
                          width: _ArrQueueTableState._actionsWidth,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              FocusRing(
                                borderRadius: AppRadii.controlBorder,
                                onActivate: canControl
                                    ? (_isPaused ? onResume : onPause)
                                    : null,
                                child: ExcludeFocus(
                                  child: Tooltip(
                                    message: canControl
                                        ? (_isPaused
                                            ? 'Reprendre'
                                            : 'Mettre en pause')
                                        : controlDisabledReason,
                                    child: IconButton(
                                      iconSize: 16,
                                      visualDensity: VisualDensity.compact,
                                      onPressed: canControl
                                          ? (_isPaused ? onResume : onPause)
                                          : null,
                                      icon: Icon(
                                        _isPaused
                                            ? Icons.play_arrow_rounded
                                            : Icons.pause_rounded,
                                        color: canControl
                                            ? AppColors.textSecondary
                                            : AppColors.textDisabled,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              Builder(
                                builder: (context) => FocusRing(
                                  borderRadius: AppRadii.controlBorder,
                                  onActivate: () {
                                    final box = context.findRenderObject()
                                        as RenderBox?;
                                    final position = box?.localToGlobal(
                                        box.size.center(Offset.zero));
                                    onMoreActions(position ?? Offset.zero);
                                  },
                                  child: ExcludeFocus(
                                    child: Tooltip(
                                      message: 'Plus d\'actions',
                                      child: IconButton(
                                        iconSize: 16,
                                        visualDensity: VisualDensity.compact,
                                        onPressed: () {
                                          final box = context.findRenderObject()
                                              as RenderBox?;
                                          final position = box?.localToGlobal(
                                              box.size.center(Offset.zero));
                                          onMoreActions(
                                              position ?? Offset.zero);
                                        },
                                        icon: const Icon(
                                            Icons.more_vert_rounded,
                                            color: AppColors.textSecondary),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

/// Ligne d'épisode repliée sous un paquet de saison déplié — lecture
/// seule (le groupe entier porte les actions), mais reste atteignable au
/// clavier (Entrée ouvre son détail) : chaque sous-ligne est un enfant à
/// part entière du même parcours de focus que les lignes de groupe,
/// naviguable aux flèches haut/bas comme n'importe quel autre "voisin".
class _ArrQueueSubRow extends StatelessWidget {
  final ArrQueueItem item;
  final bool striped;
  final VoidCallback onOpenDetail;

  const _ArrQueueSubRow({
    required this.item,
    required this.striped,
    required this.onOpenDetail,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context)
        .textTheme
        .bodySmall
        ?.copyWith(color: AppColors.textSecondary);
    return ColoredBox(
      color: striped ? AppColors.surface : Colors.transparent,
      child: Focus(
        onKeyEvent: (node, event) {
          if (event is! KeyDownEvent) return KeyEventResult.ignored;
          if (event.logicalKey == LogicalKeyboardKey.enter) {
            onOpenDetail();
            return KeyEventResult.handled;
          }
          return KeyEventResult.ignored;
        },
        child: FocusRing(
          borderRadius: AppRadii.controlBorder,
          onActivate: onOpenDetail,
          child: ExcludeFocus(
            child: InkWell(
              onTap: onOpenDetail,
              child: Padding(
                padding: const EdgeInsets.only(
                  left: _ArrQueueTableState._checkboxWidth +
                      AppSpacing.xs +
                      _ArrQueueTableState._expandWidth +
                      AppSpacing.xs +
                      AppSpacing.lg,
                  right: AppSpacing.xs,
                  top: AppSpacing.xxs,
                  bottom: AppSpacing.xxs,
                ),
                child: Text(
                  item.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: style,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
