import 'package:kinos/widgets/shared/frosted_surface.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:kinos/arr/models/arr_calendar_entry.dart';
import 'package:kinos/arr/models/arr_library_item.dart';
import 'package:kinos/arr/models/arr_media_detail.dart';
import 'package:kinos/theme/app_theme.dart';

const _months = [
  'janv.', 'févr.', 'mars', 'avr.', 'mai', 'juin', //
  'juil.', 'août', 'sept.', 'oct.', 'nov.', 'déc.',
];

String _formatDate(DateTime date) =>
    '${date.day} ${_months[date.month - 1]} ${date.year}';

Color _episodeStatusColor(ArrCalendarStatus status) => switch (status) {
      ArrCalendarStatus.announced => AppColors.calendarAnnounced,
      ArrCalendarStatus.downloaded => AppColors.calendarDownloaded,
      ArrCalendarStatus.missing => AppColors.calendarMissing,
    };

String _episodeStatusLabel(ArrCalendarStatus status) => switch (status) {
      ArrCalendarStatus.announced => 'Non diffusé',
      ArrCalendarStatus.downloaded => 'Présent',
      ArrCalendarStatus.missing => 'Manquant',
    };

/// Ligne du parcours de focus logique — soit un en-tête de saison, soit
/// un épisode d'une saison dépliée. Un seul parcours, même principe que
/// `ArrLibraryGrid`/`ArrCalendarWeekGrid` (un `Focus` ambiant + un index
/// logique, pas un `FocusNode` par ligne).
sealed class _Row {
  const _Row();
}

class _SeasonHeaderRow extends _Row {
  final ArrSeasonSummary season;
  const _SeasonHeaderRow(this.season);
}

class _EpisodeRow extends _Row {
  final ArrEpisode episode;
  const _EpisodeRow(this.episode);
}

/// Liste des saisons d'une série sur la fiche détail — dépliable : un
/// en-tête par saison (replié par défaut), le comptage présents/total
/// déjà affiché suffit à distinguer une saison complète d'une
/// incomplète sans déplier. Dépliée, une ligne par épisode (numéro,
/// titre, date de diffusion locale, statut). Recherche interactive et
/// automatique portées par ligne (saison ou épisode) via le menu
/// contextuel — aucun appel réseau ici, les callbacks portent l'action
/// (cf. CLAUDE.md).
class ArrSeasonSummaryList extends StatefulWidget {
  final List<ArrSeasonSummary> seasons;
  final List<ArrEpisode> episodes;
  final void Function(int seasonNumber) onInteractiveSearchSeason;
  final void Function(int seasonNumber) onAutoSearchSeason;
  final void Function(ArrEpisode episode) onInteractiveSearchEpisode;
  final void Function(ArrEpisode episode) onAutoSearchEpisode;

  const ArrSeasonSummaryList({
    required this.seasons,
    required this.episodes,
    required this.onInteractiveSearchSeason,
    required this.onAutoSearchSeason,
    required this.onInteractiveSearchEpisode,
    required this.onAutoSearchEpisode,
    super.key,
  });

  @override
  State<ArrSeasonSummaryList> createState() => _ArrSeasonSummaryListState();
}

class _ArrSeasonSummaryListState extends State<ArrSeasonSummaryList> {
  final _focusNode = FocusNode(debugLabel: 'ArrSeasonSummaryList');
  final Set<int> _expandedSeasons = {};
  int _focusedIndex = 0;

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  List<ArrSeasonSummary> get _sortedSeasons {
    final sorted = [...widget.seasons]
      ..sort((a, b) => a.seasonNumber.compareTo(b.seasonNumber));
    return sorted;
  }

  List<ArrEpisode> _episodesFor(int seasonNumber) {
    final episodes = widget.episodes
        .where((e) => e.seasonNumber == seasonNumber)
        .toList()
      ..sort((a, b) => a.episodeNumber.compareTo(b.episodeNumber));
    return episodes;
  }

  List<_Row> get _rows {
    final rows = <_Row>[];
    for (final season in _sortedSeasons) {
      rows.add(_SeasonHeaderRow(season));
      if (_expandedSeasons.contains(season.seasonNumber)) {
        for (final episode in _episodesFor(season.seasonNumber)) {
          rows.add(_EpisodeRow(episode));
        }
      }
    }
    return rows;
  }

  void _move(int delta) {
    final rows = _rows;
    if (rows.isEmpty) return;
    setState(
        () => _focusedIndex = (_focusedIndex + delta).clamp(0, rows.length - 1));
  }

  void _expand(int seasonNumber) =>
      setState(() => _expandedSeasons.add(seasonNumber));

  void _collapse(int seasonNumber) =>
      setState(() => _expandedSeasons.remove(seasonNumber));

  void _showContextMenu(BuildContext context, Offset globalPosition, _Row row) {
    final position = RelativeRect.fromLTRB(globalPosition.dx, globalPosition.dy,
        globalPosition.dx, globalPosition.dy);
    showGlassMenu<void>(
      context: context,
      position: position,
      items: switch (row) {
        _SeasonHeaderRow(:final season) => [
            PopupMenuItem(
              onTap: () =>
                  widget.onInteractiveSearchSeason(season.seasonNumber),
              child: const _MenuLabel(
                  icon: Icons.manage_search_rounded,
                  label: 'Recherche interactive'),
            ),
            PopupMenuItem(
              onTap: () => widget.onAutoSearchSeason(season.seasonNumber),
              child: const _MenuLabel(
                  icon: Icons.search_rounded, label: 'Recherche automatique'),
            ),
          ],
        _EpisodeRow(:final episode) => [
            PopupMenuItem(
              onTap: () => widget.onInteractiveSearchEpisode(episode),
              child: const _MenuLabel(
                  icon: Icons.manage_search_rounded,
                  label: 'Recherche interactive'),
            ),
            PopupMenuItem(
              onTap: () => widget.onAutoSearchEpisode(episode),
              child: const _MenuLabel(
                  icon: Icons.search_rounded, label: 'Recherche automatique'),
            ),
          ],
      },
    );
  }

  void _showContextMenuForFocused(BuildContext context) {
    final rows = _rows;
    if (_focusedIndex >= rows.length) return;
    final box = context.findRenderObject() as RenderBox?;
    final position =
        box == null ? Offset.zero : box.localToGlobal(box.size.center(Offset.zero));
    _showContextMenu(context, position, rows[_focusedIndex]);
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final rows = _rows;
    if (rows.isEmpty) return KeyEventResult.ignored;
    final focused = rows[_focusedIndex.clamp(0, rows.length - 1)];
    switch (event.logicalKey) {
      case LogicalKeyboardKey.arrowUp:
        _move(-1);
        return KeyEventResult.handled;
      case LogicalKeyboardKey.arrowDown:
        _move(1);
        return KeyEventResult.handled;
      case LogicalKeyboardKey.arrowRight:
        if (focused case _SeasonHeaderRow(:final season)) {
          _expand(season.seasonNumber);
        }
        return KeyEventResult.handled;
      case LogicalKeyboardKey.arrowLeft:
        if (focused case _SeasonHeaderRow(:final season)) {
          _collapse(season.seasonNumber);
        }
        return KeyEventResult.handled;
      case LogicalKeyboardKey.enter:
      case LogicalKeyboardKey.numpadEnter:
        if (focused case _SeasonHeaderRow(:final season)) {
          if (_expandedSeasons.contains(season.seasonNumber)) {
            _collapse(season.seasonNumber);
          } else {
            _expand(season.seasonNumber);
          }
        }
        return KeyEventResult.handled;
      case LogicalKeyboardKey.contextMenu:
        _showContextMenuForFocused(context);
        return KeyEventResult.handled;
      default:
        if (event.logicalKey == LogicalKeyboardKey.f10 &&
            HardwareKeyboard.instance.isShiftPressed) {
          _showContextMenuForFocused(context);
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.seasons.isEmpty) return const SizedBox.shrink();
    final rows = _rows;
    if (_focusedIndex >= rows.length) {
      _focusedIndex = rows.isEmpty ? 0 : rows.length - 1;
    }
    return Focus(
      focusNode: _focusNode,
      onKeyEvent: _onKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final (index, row) in rows.indexed)
            switch (row) {
              _SeasonHeaderRow(:final season) => _SeasonHeaderTile(
                  season: season,
                  expanded: _expandedSeasons.contains(season.seasonNumber),
                  focused: index == _focusedIndex,
                  onTap: () {
                    setState(() => _focusedIndex = index);
                    _focusNode.requestFocus();
                    if (_expandedSeasons.contains(season.seasonNumber)) {
                      _collapse(season.seasonNumber);
                    } else {
                      _expand(season.seasonNumber);
                    }
                  },
                  onSecondaryTapUp: (position) {
                    setState(() => _focusedIndex = index);
                    _focusNode.requestFocus();
                    _showContextMenu(context, position, row);
                  },
                ),
              _EpisodeRow(:final episode) => _EpisodeTile(
                  episode: episode,
                  focused: index == _focusedIndex,
                  onTap: () {
                    setState(() => _focusedIndex = index);
                    _focusNode.requestFocus();
                  },
                  onSecondaryTapUp: (position) {
                    setState(() => _focusedIndex = index);
                    _focusNode.requestFocus();
                    _showContextMenu(context, position, row);
                  },
                ),
            },
        ],
      ),
    );
  }
}

class _SeasonHeaderTile extends StatelessWidget {
  final ArrSeasonSummary season;
  final bool expanded;
  final bool focused;
  final VoidCallback onTap;
  final void Function(Offset globalPosition) onSecondaryTapUp;

  const _SeasonHeaderTile({
    required this.season,
    required this.expanded,
    required this.focused,
    required this.onTap,
    required this.onSecondaryTapUp,
  });

  @override
  Widget build(BuildContext context) {
    final complete = season.episodeCount > 0 &&
        season.episodeFileCount >= season.episodeCount;
    final label = season.seasonNumber == 0
        ? 'Épisodes spéciaux'
        : 'Saison ${season.seasonNumber}';
    return GestureDetector(
      onTap: onTap,
      onSecondaryTapUp: (details) => onSecondaryTapUp(details.globalPosition),
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
        child: Row(
          children: [
            Icon(
              expanded ? Icons.expand_more_rounded : Icons.chevron_right_rounded,
              size: 18,
              color: AppColors.textSecondary,
            ),
            const SizedBox(width: AppSpacing.xxs),
            Icon(
              season.monitored
                  ? Icons.bookmark_rounded
                  : Icons.bookmark_border_rounded,
              size: 16,
              color: season.monitored
                  ? AppColors.textSecondary
                  : AppColors.textDisabled,
            ),
            const SizedBox(width: AppSpacing.xs),
            Expanded(
              child: Text(label, style: Theme.of(context).textTheme.bodyMedium),
            ),
            Text(
              '${season.episodeFileCount}/${season.episodeCount} épisodes',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: complete ? AppColors.success : AppColors.textSecondary),
            ),
            const SizedBox(width: AppSpacing.sm),
            Text(
              season.monitored ? 'Surveillé' : 'Non surveillé',
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}

class _EpisodeTile extends StatelessWidget {
  final ArrEpisode episode;
  final bool focused;
  final VoidCallback onTap;
  final void Function(Offset globalPosition) onSecondaryTapUp;

  const _EpisodeTile({
    required this.episode,
    required this.focused,
    required this.onTap,
    required this.onSecondaryTapUp,
  });

  @override
  Widget build(BuildContext context) {
    final air = episode.airDateUtc?.toLocal();
    final status = computeArrCalendarStatus(
        hasFile: episode.hasFile, referenceDate: air);
    final style = Theme.of(context).textTheme.bodySmall;
    return GestureDetector(
      onTap: onTap,
      onSecondaryTapUp: (details) => onSecondaryTapUp(details.globalPosition),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: AppRadii.controlBorder,
          border: Border.all(
            color: focused ? AppColors.focus : Colors.transparent,
            width: 2,
          ),
        ),
        padding: const EdgeInsets.only(
            left: AppSpacing.xl,
            right: AppSpacing.xxs,
            top: AppSpacing.xxs,
            bottom: AppSpacing.xxs),
        child: Row(
          children: [
            SizedBox(
              width: 40,
              child: Text('E${episode.episodeNumber}',
                  style: style?.copyWith(color: AppColors.textSecondary)),
            ),
            Expanded(
              child: Text(episode.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: style?.copyWith(color: AppColors.textPrimary)),
            ),
            const SizedBox(width: AppSpacing.sm),
            Text(air == null ? '—' : _formatDate(air),
                style: style?.copyWith(color: AppColors.textSecondary)),
            const SizedBox(width: AppSpacing.sm),
            SizedBox(
              width: 76,
              child: Text(
                _episodeStatusLabel(status),
                textAlign: TextAlign.end,
                style: style?.copyWith(color: _episodeStatusColor(status)),
              ),
            ),
          ],
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
        // Flexible : "Recherche interactive"/"Recherche automatique"
        // dépassent la largeur par défaut d'un PopupMenuItem — même
        // correctif que ArrReleaseTable._MenuLabel.
        Flexible(
          child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
        ),
      ],
    );
  }
}
