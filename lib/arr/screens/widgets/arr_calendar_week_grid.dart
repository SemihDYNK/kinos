import 'package:kinos/widgets/shared/frosted_surface.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:kinos/arr/models/arr_calendar_entry.dart';
import 'package:kinos/arr/screens/widgets/arr_calendar_entry_card.dart';
import 'package:kinos/theme/app_theme.dart';

const _weekdayLabels = ['Lun', 'Mar', 'Mer', 'Jeu', 'Ven', 'Sam', 'Dim'];

/// Vue semaine du calendrier — 7 colonnes lundi→dimanche. Focus à 2
/// coordonnées (jour, ligne) plutôt que l'index unique de `ArrLibraryGrid` :
/// les colonnes n'ont jamais la même longueur ici, un index à plat
/// perdrait la correspondance "même ligne visuelle" en changeant de
/// colonne. Haut/bas déplacent la ligne dans la colonne courante
/// (clampée) ; gauche/droite déplacent la colonne à ligne constante
/// (clampée à la colonne cible) — franchir le bord gauche du lundi ou
/// le bord droit du dimanche change de semaine (cf. [onNavigatePeriod]),
/// unique façon de satisfaire "les flèches gauche/droite quand le focus
/// est sur la grille" sans contredire la règle absolue (les 4 flèches
/// restent une navigation entre entrées).
class ArrCalendarWeekGrid extends StatefulWidget {
  final List<ArrCalendarEntry> entries;

  /// Lundi de la semaine affichée, minuit local.
  final DateTime weekStart;

  final void Function(ArrCalendarEntry entry) onOpenDetail;
  final void Function(ArrCalendarEntry entry) onSearch;
  final void Function(ArrCalendarEntry entry) onInteractiveSearch;
  final void Function(ArrCalendarEntry entry) onToggleMonitored;

  /// -1 = semaine précédente, 1 = semaine suivante.
  final void Function(int direction) onNavigatePeriod;

  const ArrCalendarWeekGrid({
    required this.entries,
    required this.weekStart,
    required this.onOpenDetail,
    required this.onSearch,
    required this.onInteractiveSearch,
    required this.onToggleMonitored,
    required this.onNavigatePeriod,
    super.key,
  });

  @override
  State<ArrCalendarWeekGrid> createState() => _ArrCalendarWeekGridState();
}

class _ArrCalendarWeekGridState extends State<ArrCalendarWeekGrid> {
  static const _cap = 3;

  final _focusNode = FocusNode(debugLabel: 'ArrCalendarWeekGrid');
  int _focusedDay = 0;
  int _focusedRow = 0;
  final Set<int> _expandedDays = {};

  /// Bord à retrouver le focus une fois la nouvelle semaine chargée —
  /// posé juste avant [onNavigatePeriod], consommé dans
  /// [didUpdateWidget].
  String? _carryFocusToEdge;

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant ArrCalendarWeekGrid oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.weekStart != oldWidget.weekStart) {
      _expandedDays.clear();
      _focusedDay = _carryFocusToEdge == 'start' ? 0 : 6;
      _focusedRow = 0;
      _carryFocusToEdge = null;
    } else {
      final days = _bucketByDay();
      final count = _visibleCount(days[_focusedDay].length, _focusedDay);
      if (_focusedRow >= count) _focusedRow = count == 0 ? 0 : count - 1;
    }
  }

  List<List<ArrCalendarEntry>> _bucketByDay() {
    final days = List.generate(7, (_) => <ArrCalendarEntry>[]);
    for (final entry in widget.entries) {
      final offset = entry.displayDate
          .difference(DateTime(widget.weekStart.year, widget.weekStart.month,
              widget.weekStart.day))
          .inDays;
      if (offset < 0 || offset > 6) continue;
      days[offset].add(entry);
    }
    for (final day in days) {
      day.sort((a, b) => a.displayDate.compareTo(b.displayDate));
    }
    return days;
  }

  bool _hasOverflow(int total, int day) =>
      !_expandedDays.contains(day) && total > _cap;

  int _visibleCount(int total, int day) =>
      _hasOverflow(total, day) ? _cap : total;

  void _move({int deltaDay = 0, int deltaRow = 0}) {
    final days = _bucketByDay();
    if (deltaRow != 0) {
      final count = _visibleCount(days[_focusedDay].length, _focusedDay);
      if (count == 0) return;
      setState(() =>
          _focusedRow = (_focusedRow + deltaRow).clamp(0, count - 1));
      return;
    }
    if (deltaDay != 0) {
      final nextDay = _focusedDay + deltaDay;
      if (nextDay < 0) {
        _carryFocusToEdge = 'end';
        widget.onNavigatePeriod(-1);
        return;
      }
      if (nextDay > 6) {
        _carryFocusToEdge = 'start';
        widget.onNavigatePeriod(1);
        return;
      }
      final count = _visibleCount(days[nextDay].length, nextDay);
      setState(() {
        _focusedDay = nextDay;
        _focusedRow = count == 0 ? 0 : _focusedRow.clamp(0, count - 1);
      });
    }
  }

  void _activateFocused(List<List<ArrCalendarEntry>> days) {
    final dayEntries = days[_focusedDay];
    if (_hasOverflow(dayEntries.length, _focusedDay) &&
        _focusedRow == _cap - 1) {
      setState(() => _expandedDays.add(_focusedDay));
      return;
    }
    if (_focusedRow < dayEntries.length) {
      widget.onOpenDetail(dayEntries[_focusedRow]);
    }
  }

  void _showContextMenuForFocused(
      BuildContext context, List<List<ArrCalendarEntry>> days) {
    final dayEntries = days[_focusedDay];
    if (_focusedRow >= dayEntries.length) return;
    final entry = dayEntries[_focusedRow];
    final box = context.findRenderObject() as RenderBox?;
    final position =
        box == null ? Offset.zero : box.localToGlobal(box.size.center(Offset.zero));
    _showContextMenu(context, position, entry);
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
    final days = _bucketByDay();
    switch (event.logicalKey) {
      case LogicalKeyboardKey.arrowLeft:
        _move(deltaDay: -1);
        return KeyEventResult.handled;
      case LogicalKeyboardKey.arrowRight:
        _move(deltaDay: 1);
        return KeyEventResult.handled;
      case LogicalKeyboardKey.arrowUp:
        _move(deltaRow: -1);
        return KeyEventResult.handled;
      case LogicalKeyboardKey.arrowDown:
        _move(deltaRow: 1);
        return KeyEventResult.handled;
      case LogicalKeyboardKey.enter:
      case LogicalKeyboardKey.numpadEnter:
        _activateFocused(days);
        return KeyEventResult.handled;
      case LogicalKeyboardKey.contextMenu:
        _showContextMenuForFocused(context, days);
        return KeyEventResult.handled;
      default:
        if (event.logicalKey == LogicalKeyboardKey.f10 &&
            HardwareKeyboard.instance.isShiftPressed) {
          _showContextMenuForFocused(context, days);
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
    }
  }

  @override
  Widget build(BuildContext context) {
    final days = _bucketByDay();
    if (widget.entries.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: AppSpacing.xl),
        child: Row(
          children: [
            Icon(Icons.calendar_month_outlined,
                size: 18, color: AppColors.textDisabled),
            SizedBox(width: AppSpacing.sm),
            Text('Aucune sortie prévue cette semaine.',
                style: TextStyle(color: AppColors.textSecondary)),
          ],
        ),
      );
    }
    final today = DateTime.now();
    return Focus(
      focusNode: _focusNode,
      autofocus: true,
      onKeyEvent: _onKey,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var day = 0; day < 7; day++) ...[
            if (day > 0) const SizedBox(width: AppSpacing.xs),
            Expanded(
              child: _DayColumn(
                date: widget.weekStart.add(Duration(days: day)),
                isToday: _isSameDate(
                    widget.weekStart.add(Duration(days: day)), today),
                entries: days[day],
                cap: _cap,
                expanded: _expandedDays.contains(day),
                focusedRow: day == _focusedDay ? _focusedRow : null,
                onExpand: () => setState(() => _expandedDays.add(day)),
                onEntryTap: (row) {
                  setState(() {
                    _focusedDay = day;
                    _focusedRow = row;
                  });
                  _focusNode.requestFocus();
                  widget.onOpenDetail(days[day][row]);
                },
                onEntrySecondaryTap: (row, position) {
                  setState(() {
                    _focusedDay = day;
                    _focusedRow = row;
                  });
                  _focusNode.requestFocus();
                  _showContextMenu(context, position, days[day][row]);
                },
              ),
            ),
          ],
        ],
      ),
    );
  }
}

bool _isSameDate(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

class _DayColumn extends StatelessWidget {
  final DateTime date;
  final bool isToday;
  final List<ArrCalendarEntry> entries;
  final int cap;
  final bool expanded;
  final int? focusedRow;
  final VoidCallback onExpand;
  final void Function(int row) onEntryTap;
  final void Function(int row, Offset globalPosition) onEntrySecondaryTap;

  const _DayColumn({
    required this.date,
    required this.isToday,
    required this.entries,
    required this.cap,
    required this.expanded,
    required this.focusedRow,
    required this.onExpand,
    required this.onEntryTap,
    required this.onEntrySecondaryTap,
  });

  @override
  Widget build(BuildContext context) {
    final hasOverflow = !expanded && entries.length > cap;
    final visibleReal = hasOverflow ? cap - 1 : entries.length;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.xs),
          child: Text(
            '${_weekdayLabels[date.weekday - 1]} ${date.day}',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: isToday
                      ? AppColors.textPrimary
                      : AppColors.textSecondary,
                  fontWeight: isToday ? FontWeight.w700 : FontWeight.w400,
                ),
          ),
        ),
        for (var row = 0; row < visibleReal; row++) ...[
          if (row > 0) const SizedBox(height: AppSpacing.xxs),
          ArrCalendarEntryCard(
            entry: entries[row],
            focused: focusedRow == row,
            onTap: () => onEntryTap(row),
            onSecondaryTapUp: (position) => onEntrySecondaryTap(row, position),
          ),
        ],
        if (hasOverflow) ...[
          const SizedBox(height: AppSpacing.xxs),
          _OverflowCell(
            count: entries.length - visibleReal,
            focused: focusedRow == cap - 1,
            onTap: onExpand,
          ),
        ],
      ],
    );
  }
}

class _OverflowCell extends StatelessWidget {
  final int count;
  final bool focused;
  final VoidCallback onTap;

  const _OverflowCell(
      {required this.count, required this.focused, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: AppRadii.controlBorder,
          border: Border.all(
            color: focused ? AppColors.focus : Colors.transparent,
            width: 2,
          ),
        ),
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.xxs, vertical: AppSpacing.xxs),
        child: Text(
          '+ $count autres',
          style: Theme.of(context)
              .textTheme
              .bodySmall
              ?.copyWith(color: AppColors.textSecondary),
        ),
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
