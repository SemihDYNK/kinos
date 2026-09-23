import 'package:flutter/material.dart';

import 'package:kinos/arr/models/arr_calendar_entry.dart';
import 'package:kinos/theme/app_theme.dart';

Color _statusColor(ArrCalendarStatus status) => switch (status) {
      ArrCalendarStatus.announced => AppColors.calendarAnnounced,
      ArrCalendarStatus.downloaded => AppColors.calendarDownloaded,
      ArrCalendarStatus.missing => AppColors.calendarMissing,
    };

String _statusLabel(ArrCalendarStatus status) => switch (status) {
      ArrCalendarStatus.announced => 'Annoncé',
      ArrCalendarStatus.downloaded => 'Téléchargé',
      ArrCalendarStatus.missing => 'Manquant',
    };

/// Carte compacte d'une entrée de calendrier — partagée par la grille
/// semaine et la liste mois, aucune logique réseau (cf. CLAUDE.md,
/// jamais d'appel API depuis un widget) : les callbacks portent toute
/// l'action, ce widget n'affiche que ce qu'on lui donne.
class ArrCalendarEntryCard extends StatelessWidget {
  final ArrCalendarEntry entry;
  final bool focused;
  final VoidCallback onTap;
  final void Function(Offset globalPosition) onSecondaryTapUp;

  const ArrCalendarEntryCard({
    required this.entry,
    required this.focused,
    required this.onTap,
    required this.onSecondaryTapUp,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final titleStyle = Theme.of(context)
        .textTheme
        .bodySmall
        ?.copyWith(color: AppColors.textPrimary, fontWeight: FontWeight.w600);
    final subtitleStyle = Theme.of(context)
        .textTheme
        .bodySmall
        ?.copyWith(color: AppColors.textSecondary);

    return GestureDetector(
      onTap: onTap,
      onSecondaryTapUp: (details) => onSecondaryTapUp(details.globalPosition),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: AppRadii.controlBorder,
          color: AppColors.surface,
          border: Border.all(
            color: focused ? AppColors.focus : Colors.transparent,
            width: 2,
          ),
        ),
        padding: const EdgeInsets.all(AppSpacing.xxs),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _Thumb(url: entry.posterUrl),
            const SizedBox(width: AppSpacing.xxs),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(entry.title,
                      maxLines: 1, overflow: TextOverflow.ellipsis, style: titleStyle),
                  if (entry.subtitle != null)
                    Text(entry.subtitle!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: subtitleStyle),
                  if (entry.hasNonObviousDateBasis)
                    Text(entry.dateBasisLabel,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: subtitleStyle?.copyWith(
                            color: AppColors.textDisabled)),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.xxs),
            Tooltip(
              message: _statusLabel(entry.status),
              child: Container(
                width: 8,
                height: 8,
                margin: const EdgeInsets.only(top: 4),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _statusColor(entry.status),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Vignette d'affiche 28×28 — repli icône si [url] est absent, même
/// registre que `ArrLibraryGrid` (jamais de jaquette cassée à l'écran).
class _Thumb extends StatelessWidget {
  final String? url;
  const _Thumb({required this.url});

  @override
  Widget build(BuildContext context) {
    const size = 28.0;
    if (url == null || url!.isEmpty) {
      return const SizedBox(
        width: size,
        height: size,
        child: ColoredBox(
          color: AppColors.surfaceHigh,
          child: Icon(Icons.movie_creation_outlined,
              size: 14, color: AppColors.textDisabled),
        ),
      );
    }
    return ClipRRect(
      borderRadius: const BorderRadius.all(Radius.circular(2)),
      child: Image.network(
        url!,
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => const ColoredBox(
          color: AppColors.surfaceHigh,
          child: Icon(Icons.movie_creation_outlined,
              size: 14, color: AppColors.textDisabled),
        ),
      ),
    );
  }
}
