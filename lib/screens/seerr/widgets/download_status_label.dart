import 'package:kinos/theme/app_theme.dart';
import 'package:flutter/material.dart';

import 'package:kinos/models/seerr/seerr_dashboard_model.dart';
import 'package:kinos/seerr/seerr_models.dart';
import 'package:kinos/util/localization_helper.dart';

class DownloadStatusLabel extends StatelessWidget {
  final SeerrDashboardPosterModel poster;
  final List<int>? filterSeasons;

  const DownloadStatusLabel({
    required this.poster,
    this.filterSeasons,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final standardDownloads = poster.mediaInfo?.downloadStatus ?? [];
    final fourKDownloads = poster.mediaInfo?.downloadStatus4k ?? [];
    final allDownloads = [...standardDownloads, ...fourKDownloads];

    final relevantDownloads = filterSeasons != null && filterSeasons!.isNotEmpty
        ? allDownloads
            .where((d) => filterSeasons!.contains(d.episode?.seasonNumber))
            .toList()
        : allDownloads;

    num totalSize = 0;
    num totalRemaining = 0;

    for (final download in relevantDownloads) {
      if (download.size != null) {
        totalSize += download.size!;
        totalRemaining += download.sizeLeft ?? 0;
      }
    }

    final hasDownloads = totalSize > 0;
    final percentage =
        hasDownloads ? ((totalSize - totalRemaining) / totalSize) * 100 : 0.0;

    if (hasDownloads) {
      String downloadLabel = context.localized.processing;

      if (poster.type == SeerrMediaType.tvshow &&
          relevantDownloads.isNotEmpty) {
        final firstDownload = relevantDownloads.first;
        final seasonNum = firstDownload.episode?.seasonNumber;
        final episodeNum = firstDownload.episode?.episodeNumber;

        if (seasonNum != null && episodeNum != null) {
          downloadLabel =
              '${context.localized.processing} S${seasonNum}E$episodeNum';
        }
      }

      return _status(
          context,
          '$downloadLabel · ${percentage.clamp(0, 100).round()} %',
          AppColors.textSecondary);
    }
    final color = switch (poster.mediaStatus) {
      SeerrMediaStatus.available => AppColors.success,
      SeerrMediaStatus.partiallyAvailable => AppColors.warning,
      SeerrMediaStatus.pending => AppColors.warning,
      _ => switch (poster.requestStatus) {
          SeerrRequestStatus.declined ||
          SeerrRequestStatus.failed =>
            AppColors.error,
          SeerrRequestStatus.pending => AppColors.warning,
          SeerrRequestStatus.completed => AppColors.success,
          _ => AppColors.textSecondary,
        },
    };
    return _status(context, poster.displayStatusLabel(context), color);
  }

  Widget _status(BuildContext context, String label, Color color) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          DecoratedBox(
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              child: const SizedBox.square(
                  dimension: AppManagementLayout.statusDotSize)),
          const SizedBox(width: AppSpacing.xs),
          Flexible(
              child: Text(label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.cardTitle)),
        ],
      );
}
