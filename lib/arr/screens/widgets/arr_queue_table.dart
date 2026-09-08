import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:fladder/arr/models/arr_queue_item.dart';
import 'package:fladder/screens/details_screens/components/media_info_formatters.dart';
import 'package:fladder/theme/app_theme.dart';
import 'package:fladder/widgets/shared/focus_row.dart';

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
/// Sélection multiple (Maj/Ctrl+clic) et menu contextuel appliqués au
/// widget parent via les callbacks — cette table ne connaît que
/// l'affichage, le tri et la sélection ; jamais d'appel réseau direct
/// (cf. CLAUDE.md : aucun appel API depuis un widget).
class ArrQueueTable extends StatefulWidget {
  final List<ArrQueueItem> items;
  final String instanceLabel;
  final void Function(ArrQueueItem item) onPause;
  final void Function(ArrQueueItem item) onResume;
  final void Function(ArrQueueItem item) onForceImport;
  final void Function(List<ArrQueueItem> items,
      {required bool removeFromClient, required bool blocklist}) onRemove;

  const ArrQueueTable({
    required this.items,
    required this.instanceLabel,
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

  final Set<int> _selected = {};
  int? _lastClickedIndex;

  static const _checkboxWidth = 32.0;
  static const _minTitleWidth = 240.0;
  static const _instanceWidth = 72.0;
  static const _indexerWidth = 120.0;
  static const _qualityWidth = 110.0;
  static const _sizeWidth = 84.0;
  static const _progressWidth = 140.0;
  static const _timeLeftWidth = 84.0;
  static const _statusWidth = 130.0;
  static const _actionsWidth = 72.0;
  static const _columnGap = AppSpacing.xs;

  static const _minTableWidth = _checkboxWidth +
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

  List<ArrQueueItem> get _sorted {
    final sorted = [...widget.items];
    sorted.sort((a, b) {
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
    return sorted;
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

  void _onRowTap(int index, List<ArrQueueItem> rows,
      {required bool shift, required bool ctrl}) {
    final id = rows[index].id;
    setState(() {
      if (shift && _lastClickedIndex != null) {
        final start = _lastClickedIndex!.clamp(0, rows.length - 1);
        final range = [start, index]..sort();
        _selected.addAll(rows.sublist(range[0], range[1] + 1).map((e) => e.id));
      } else if (ctrl) {
        if (!_selected.add(id)) _selected.remove(id);
        _lastClickedIndex = index;
      } else {
        _selected
          ..clear()
          ..add(id);
        _lastClickedIndex = index;
      }
    });
  }

  void _clearSelection() => setState(_selected.clear);

  Future<void> _confirmRemove(
    BuildContext context,
    List<ArrQueueItem> items, {
    required bool blocklist,
  }) async {
    final multiple = items.length > 1;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surfaceHigh,
        shape: const RoundedRectangleBorder(borderRadius: AppRadii.sheetBorder),
        title: Text(
            blocklist ? 'Blocklist et remplacement' : 'Retirer de la file'),
        content: Text(
          blocklist
              ? '${multiple ? '${items.length} éléments seront' : "\"${items.first.title}\" sera"} '
                  'bloqués et retirés du client de téléchargement ; le serveur cherchera un remplacement.'
              : '${multiple ? '${items.length} éléments seront' : "\"${items.first.title}\" sera"} '
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
      widget.onRemove(items, removeFromClient: true, blocklist: blocklist);
      _clearSelection();
    }
  }

  Future<void> _showDetail(BuildContext context, ArrQueueItem item) {
    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
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

  void _showContextMenu(
      BuildContext context, Offset globalPosition, ArrQueueItem row) {
    final targets = _selected.contains(row.id) && _selected.length > 1
        ? widget.items.where((e) => _selected.contains(e.id)).toList()
        : [row];
    if (targets.length == 1 && !_selected.contains(row.id)) {
      setState(() {
        _selected
          ..clear()
          ..add(row.id);
      });
    }

    final position = RelativeRect.fromLTRB(globalPosition.dx, globalPosition.dy,
        globalPosition.dx, globalPosition.dy);
    final singleRowActionable = targets.length == 1 ? targets.first : null;

    showMenu<void>(
      context: context,
      position: position,
      items: [
        if (singleRowActionable != null &&
            singleRowActionable.status != ArrQueueStatus.paused)
          PopupMenuItem(
            onTap: () => widget.onPause(singleRowActionable),
            child: const _MenuLabel(
                icon: Icons.pause_rounded, label: 'Mettre en pause'),
          ),
        if (singleRowActionable != null &&
            singleRowActionable.status == ArrQueueStatus.paused)
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
                      _selected.addAll(rows.map((e) => e.id));
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
                  for (final (index, item) in rows.indexed)
                    _ArrQueueRow(
                      key: ValueKey(item.id),
                      item: item,
                      striped: index.isOdd,
                      selected: _selected.contains(item.id),
                      instanceLabel: widget.instanceLabel,
                      onTap: ({required shift, required ctrl}) =>
                          _onRowTap(index, rows, shift: shift, ctrl: ctrl),
                      onSecondaryTap: (position) =>
                          _showContextMenu(context, position, item),
                      onOpenDetail: () => _showDetail(context, item),
                      onDelete: () =>
                          _confirmRemove(context, [item], blocklist: false),
                      onPause: () => widget.onPause(item),
                      onResume: () => widget.onResume(item),
                      onMoreActions: (position) =>
                          _showContextMenu(context, position, item),
                    ),
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
          Expanded(
              child: _header(
                  context, 'Titre', double.infinity, _ArrQueueColumn.title)),
          gap,
          SizedBox(
              width: _ArrQueueTableState._instanceWidth,
              child: Text('Instance',
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
  final ArrQueueItem item;
  final bool striped;
  final bool selected;
  final String instanceLabel;
  final void Function({required bool shift, required bool ctrl}) onTap;
  final void Function(Offset globalPosition) onSecondaryTap;
  final VoidCallback onOpenDetail;
  final VoidCallback onDelete;
  final VoidCallback onPause;
  final VoidCallback onResume;
  final void Function(Offset globalPosition) onMoreActions;

  const _ArrQueueRow({
    required this.item,
    required this.striped,
    required this.selected,
    required this.instanceLabel,
    required this.onTap,
    required this.onSecondaryTap,
    required this.onOpenDetail,
    required this.onDelete,
    required this.onPause,
    required this.onResume,
    required this.onMoreActions,
    super.key,
  });

  bool get _isPaused => item.status == ArrQueueStatus.paused;

  @override
  Widget build(BuildContext context) {
    final baseStyle = Theme.of(context)
        .textTheme
        .bodySmall
        ?.copyWith(color: AppColors.textPrimary.withValues(alpha: 0.9));
    const gap = SizedBox(width: AppSpacing.xs);
    final progress = item.progress;

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
            // ligne contient aussi les FocusRing pause/reprendre et
            // "plus d'actions", qui doivent rester atteignables — flèche
            // droite pour y entrer, cf. FocusRow ci-dessus.
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
                        Expanded(
                          child: Tooltip(
                            message: item.title,
                            child: Text(item.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: baseStyle),
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
                          child: Text(item.indexer ?? '—',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: baseStyle),
                        ),
                        gap,
                        SizedBox(
                          width: _ArrQueueTableState._qualityWidth,
                          child: Text(item.qualityName ?? '—',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: baseStyle),
                        ),
                        gap,
                        SizedBox(
                          width: _ArrQueueTableState._sizeWidth,
                          child: Text(formatFileSize(item.size) ?? '—',
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
                                        _statusColor(item.status)),
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
                          child: Text(item.timeLeft ?? '—',
                              textAlign: TextAlign.end,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: baseStyle),
                        ),
                        gap,
                        SizedBox(
                          width: _ArrQueueTableState._statusWidth,
                          child: Text(item.status.label,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: baseStyle?.copyWith(
                                  color: _statusColor(item.status))),
                        ),
                        gap,
                        SizedBox(
                          width: _ArrQueueTableState._actionsWidth,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              FocusRing(
                                borderRadius: AppRadii.controlBorder,
                                onActivate: _isPaused ? onResume : onPause,
                                child: ExcludeFocus(
                                  child: Tooltip(
                                    message: _isPaused
                                        ? 'Reprendre'
                                        : 'Mettre en pause',
                                    child: IconButton(
                                      iconSize: 16,
                                      visualDensity: VisualDensity.compact,
                                      onPressed: _isPaused ? onResume : onPause,
                                      icon: Icon(
                                        _isPaused
                                            ? Icons.play_arrow_rounded
                                            : Icons.pause_rounded,
                                        color: AppColors.textSecondary,
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
