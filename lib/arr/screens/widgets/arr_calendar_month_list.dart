import 'package:kinos/widgets/shared/frosted_surface.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:kinos/arr/models/arr_calendar_entry.dart';
import 'package:kinos/arr/screens/widgets/arr_calendar_entry_card.dart';
import 'package:kinos/theme/app_theme.dart';

const _weekdayLabels = [
  'Lundi',
  'Mardi',
  'Mercredi',
  'Jeudi',
  'Vendredi',
  'Samedi',
  'Dimanche',
];

/// Vue mois du calendrier — repli plus dense que la grille semaine : un
/// jour par ligne, une entrée par ligne sous chaque jour (jamais une
/// grille de cases mensuelle). Navigation à un seul axe (haut/bas entre
/// entrées, pas de colonnes ici) ; gauche/droite change de mois — aucun
/// conflit avec la règle absolue puisqu'il n'y a qu'un seul axe
/// d'entrées à parcourir.
class ArrCalendarMonthList extends StatefulWidget {
  final List<ArrCalendarEntry> entries;

  /// Premier jour du mois affiché, minuit local.
  final DateTime monthStart;

  final void Function(ArrCalendarEntry entry) onOpenDetail;
  final void Function(ArrCalendarEntry entry) onSearch;
  final void Function(ArrCalendarEntry entry) onInteractiveSearch;
  final void Function(ArrCalendarEntry entry) onToggleMonitored;

  /// -1 = mois précédent, 1 = mois suivant.
  final void Function(int direction) onNavigatePeriod;

  const ArrCalendarMonthList({
    required this.entries,
    required this.monthStart,
    required this.onOpenDetail,
    required this.onSearch,
    required this.onInteractiveSearch,
    required this.onToggleMonitored,
    required this.onNavigatePeriod,
    super.key,
  });

  @override
  State<ArrCalendarMonthList> createState() => _ArrCalendarMonthListState();
}

class _ArrCalendarMonthListState extends State<ArrCalendarMonthList> {
  final _focusNode = FocusNode(debugLabel: 'ArrCalendarMonthList');
  int _focusedIndex = 0;

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant ArrCalendarMonthList oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.monthStart != oldWidget.monthStart) _focusedIndex = 0;
  }

  List<ArrCalendarEntry> get _sorted {
    final sorted = [...widget.entries];
    sorted.sort((a, b) => a.displayDate.compareTo(b.displayDate));
    return sorted;
  }

  void _move(int delta) {
    final entries = _sorted;
    if (entries.isEmpty) return;
    setState(() =>
        _focusedIndex = (_focusedIndex + delta).clamp(0, entries.length - 1));
  }

  void _showContextMenu(
      BuildContext context, Offset globalPosition, ArrCalendarEntry entry) {
    final position = RelativeRect.fromLTRB(globalPosition.dx, globalPosition.dy,
        globalPosition.dx, globalPosition.dy);
    showGlassMenu<void>(
      context: context,
      position: position,
      items: [
        PopupMenuItem(
          onTap: () => widget.onSearch(entry),
          child: const _MenuLabel(
              icon: Icons.search_rounded, label: 'Recherche automatique'),
        ),
        PopupMenuItem(
          onTap: () => widget.onInteractiveSearch(entry),
          child: const _MenuLabel(
              icon: Icons.manage_search_rounded,
              label: 'Recherche interactive'),
        ),
        PopupMenuItem(
          onTap: () => widget.onToggleMonitored(entry),
          child: _MenuLabel(
            icon: entry.monitored
                ? Icons.bookmark_remove_outlined
                : Icons.bookmark_add_outlined,
            label: entry.monitored ? 'Ne plus surveiller' : 'Surveiller',
          ),
        ),
      ],
    );
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final entries = _sorted;
    switch (event.logicalKey) {
      case LogicalKeyboardKey.arrowUp:
        _move(-1);
        return KeyEventResult.handled;
      case LogicalKeyboardKey.arrowDown:
        _move(1);
        return KeyEventResult.handled;
      case LogicalKeyboardKey.arrowLeft:
        widget.onNavigatePeriod(-1);
        return KeyEventResult.handled;
      case LogicalKeyboardKey.arrowRight:
        widget.onNavigatePeriod(1);
        return KeyEventResult.handled;
      case LogicalKeyboardKey.enter:
      case LogicalKeyboardKey.numpadEnter:
        if (entries.isNotEmpty) widget.onOpenDetail(entries[_focusedIndex]);
        return KeyEventResult.handled;
      case LogicalKeyboardKey.contextMenu:
        if (entries.isNotEmpty) {
          final box = context.findRenderObject() as RenderBox?;
          final position =
              box == null ? Offset.zero : box.localToGlobal(Offset.zero);
          _showContextMenu(context, position, entries[_focusedIndex]);
        }
        return KeyEventResult.handled;
      default:
        if (event.logicalKey == LogicalKeyboardKey.f10 &&
            HardwareKeyboard.instance.isShiftPressed &&
            entries.isNotEmpty) {
          final box = context.findRenderObject() as RenderBox?;
          final position =
              box == null ? Offset.zero : box.localToGlobal(Offset.zero);
          _showContextMenu(context, position, entries[_focusedIndex]);
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
    }
  }

  @override
  Widget build(BuildContext context) {
    final entries = _sorted;
    if (entries.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: AppSpacing.xl),
        child: Row(
          children: [
            Icon(Icons.calendar_month_outlined,
                size: 18, color: AppColors.textDisabled),
            SizedBox(width: AppSpacing.sm),
            Text('Aucune sortie prévue ce mois-ci.',
                style: TextStyle(color: AppColors.textSecondary)),
          ],
        ),
      );
    }
    final today = DateTime.now();
    final rows = <Widget>[];
    DateTime? lastDay;
    for (final (index, entry) in entries.indexed) {
      final day = DateTime(
          entry.displayDate.year, entry.displayDate.month, entry.displayDate.day);
      if (lastDay == null || !_isSameDate(day, lastDay)) {
        if (lastDay != null) rows.add(const SizedBox(height: AppSpacing.sm));
        rows.add(_DayHeader(date: day, isToday: _isSameDate(day, today)));
        lastDay = day;
      }
      rows.add(Padding(
        padding: const EdgeInsets.only(top: AppSpacing.xxs),
        child: ArrCalendarEntryCard(
          entry: entry,
          focused: index == _focusedIndex,
          onTap: () {
            setState(() => _focusedIndex = index);
            _focusNode.requestFocus();
            widget.onOpenDetail(entry);
          },
          onSecondaryTapUp: (position) {
            setState(() => _focusedIndex = index);
            _focusNode.requestFocus();
            _showContextMenu(context, position, entry);
          },
        ),
      ));
    }
    return Focus(
      focusNode: _focusNode,
      autofocus: true,
      onKeyEvent: _onKey,
      child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: rows),
    );
  }
}

bool _isSameDate(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

class _DayHeader extends StatelessWidget {
  final DateTime date;
  final bool isToday;
  const _DayHeader({required this.date, required this.isToday});

  @override
  Widget build(BuildContext context) {
    return Text(
      '${_weekdayLabels[date.weekday - 1]} ${date.day}',
      style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: isToday ? AppColors.textPrimary : AppColors.textSecondary,
            fontWeight: isToday ? FontWeight.w700 : FontWeight.w600,
          ),
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
        // Flexible : "Recherche interactive"/"automatique" dépassent la
        // largeur par défaut d'un PopupMenuItem sans lui.
        Flexible(
          child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
        ),
      ],
    );
  }
}
