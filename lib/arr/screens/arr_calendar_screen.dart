import 'package:flutter/material.dart';

import 'package:auto_route/auto_route.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:kinos/arr/models/arr_calendar_entry.dart';
import 'package:kinos/arr/models/arr_service.dart';
import 'package:kinos/arr/providers/arr_calendar_providers.dart';
import 'package:kinos/arr/screens/widgets/arr_calendar_month_list.dart';
import 'package:kinos/arr/screens/widgets/arr_calendar_week_grid.dart';
import 'package:kinos/arr/services/arr_api_client.dart';
import 'package:kinos/routes/auto_router.gr.dart';
import 'package:kinos/screens/shared/chips/filter_button.dart';
import 'package:kinos/screens/shared/kinos_notification_overlay.dart';
import 'package:kinos/theme/app_theme.dart';

enum _ArrCalendarViewMode { week, month }

/// Onglet "Calendrier" — sorties à venir/manquantes, semaine par défaut,
/// mois en repli plus dense. Même conventions d'état que les onglets
/// Bibliothèque/File d'attente : le provider en famille par instance ET
/// par plage (`arrCalendarProvider`) porte tout l'appel réseau, cet
/// écran ne fait qu'orchestrer navigation de période + actions.
class ArrCalendarScreen extends ConsumerStatefulWidget {
  final ArrService service;

  const ArrCalendarScreen({required this.service, super.key});

  @override
  ConsumerState<ArrCalendarScreen> createState() => _ArrCalendarScreenState();
}

class _ArrCalendarScreenState extends ConsumerState<ArrCalendarScreen> {
  _ArrCalendarViewMode _viewMode = _ArrCalendarViewMode.week;
  DateTime _anchor = _todayLocalMidnight();

  static DateTime _todayLocalMidnight() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  DateTime get _weekStart =>
      _anchor.subtract(Duration(days: _anchor.weekday - 1));

  DateTime get _monthStart => DateTime(_anchor.year, _anchor.month);

  ({DateTime start, DateTime end}) get _period => switch (_viewMode) {
        _ArrCalendarViewMode.week => (
            start: _weekStart,
            end: _weekStart.add(const Duration(days: 7)),
          ),
        _ArrCalendarViewMode.month => (
            start: _monthStart,
            end: DateTime(_monthStart.year, _monthStart.month + 1),
          ),
      };

  ArrCalendarKey get _key {
    final period = _period;
    return (service: widget.service, start: period.start, end: period.end);
  }

  void _navigatePeriod(int direction) {
    setState(() {
      _anchor = switch (_viewMode) {
        _ArrCalendarViewMode.week =>
          _anchor.add(Duration(days: 7 * direction)),
        _ArrCalendarViewMode.month =>
          DateTime(_anchor.year, _anchor.month + direction, _anchor.day),
      };
    });
  }

  void _goToday() => setState(() => _anchor = _todayLocalMidnight());

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

  Future<void> _openDetail(ArrCalendarEntry entry) {
    return context.router.push(
        ArrDetailRoute(service: widget.service, id: entry.detailId));
  }

  Future<void> _openInteractiveSearch(ArrCalendarEntry entry) {
    return context.router.push(ArrDetailRoute(
      service: widget.service,
      id: entry.detailId,
      autoExpandSearch: true,
      initialSearchEpisodeId: entry.episodeId,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final notifier = ref.read(arrCalendarProvider(_key).notifier);
    final state = ref.watch(arrCalendarProvider(_key));

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Header(
          viewMode: _viewMode,
          periodLabel: _periodLabel(),
          onPrevious: () => _navigatePeriod(-1),
          onNext: () => _navigatePeriod(1),
          onToday: _goToday,
          onSelectViewMode: (mode) => setState(() => _viewMode = mode),
        ),
        const SizedBox(height: AppSpacing.sm),
        if (state.loading && state.entries.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: AppSpacing.xl),
            child: Row(
              children: [
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                SizedBox(width: AppSpacing.sm),
                Text('Chargement du calendrier…',
                    style: TextStyle(color: AppColors.textSecondary)),
              ],
            ),
          )
        else if (state.error != null && state.entries.isEmpty)
          Padding(
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
          )
        else
          switch (_viewMode) {
            _ArrCalendarViewMode.week => ArrCalendarWeekGrid(
                entries: state.entries,
                weekStart: _weekStart,
                onOpenDetail: _openDetail,
                onSearch: (entry) => _runAction(() => notifier.search(entry),
                    failureContext: 'Recherche'),
                onInteractiveSearch: _openInteractiveSearch,
                onToggleMonitored: (entry) => _runAction(
                    () => notifier.toggleMonitored(entry),
                    failureContext: 'Surveillance'),
                onNavigatePeriod: _navigatePeriod,
              ),
            _ArrCalendarViewMode.month => ArrCalendarMonthList(
                entries: state.entries,
                monthStart: _monthStart,
                onOpenDetail: _openDetail,
                onSearch: (entry) => _runAction(() => notifier.search(entry),
                    failureContext: 'Recherche'),
                onInteractiveSearch: _openInteractiveSearch,
                onToggleMonitored: (entry) => _runAction(
                    () => notifier.toggleMonitored(entry),
                    failureContext: 'Surveillance'),
                onNavigatePeriod: _navigatePeriod,
              ),
          },
      ],
    );
  }

  String _periodLabel() {
    const months = [
      'janvier',
      'février',
      'mars',
      'avril',
      'mai',
      'juin',
      'juillet',
      'août',
      'septembre',
      'octobre',
      'novembre',
      'décembre',
    ];
    return switch (_viewMode) {
      _ArrCalendarViewMode.week => () {
          final end = _weekStart.add(const Duration(days: 6));
          return '${_weekStart.day} — ${end.day} ${months[end.month - 1]} ${end.year}';
        }(),
      _ArrCalendarViewMode.month =>
        '${months[_monthStart.month - 1]} ${_monthStart.year}',
    };
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

class _Header extends StatelessWidget {
  final _ArrCalendarViewMode viewMode;
  final String periodLabel;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final VoidCallback onToday;
  final ValueChanged<_ArrCalendarViewMode> onSelectViewMode;

  const _Header({
    required this.viewMode,
    required this.periodLabel,
    required this.onPrevious,
    required this.onNext,
    required this.onToday,
    required this.onSelectViewMode,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        FocusRing(
          borderRadius: AppRadii.controlBorder,
          onActivate: onPrevious,
          child: ExcludeFocus(
            child: IconButton(
              onPressed: onPrevious,
              icon: const Icon(Icons.chevron_left_rounded),
              color: AppColors.textSecondary,
            ),
          ),
        ),
        FocusRing(
          borderRadius: AppRadii.controlBorder,
          onActivate: onNext,
          child: ExcludeFocus(
            child: IconButton(
              onPressed: onNext,
              icon: const Icon(Icons.chevron_right_rounded),
              color: AppColors.textSecondary,
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.xs),
        FocusRing(
          borderRadius: AppRadii.controlBorder,
          onActivate: onToday,
          child: ExcludeFocus(
            child: OutlinedButton(
              onPressed: onToday,
              child: const Text('Aujourd\'hui'),
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Text(
            periodLabel,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
        Row(
          spacing: AppSpacing.xxs,
          children: [
            FilterButton(
              isSelected: viewMode == _ArrCalendarViewMode.week,
              label: const Text('Semaine'),
              onPressed: () => onSelectViewMode(_ArrCalendarViewMode.week),
            ),
            FilterButton(
              isSelected: viewMode == _ArrCalendarViewMode.month,
              label: const Text('Mois'),
              onPressed: () => onSelectViewMode(_ArrCalendarViewMode.month),
            ),
          ],
        ),
      ],
    );
  }
}
