import 'package:flutter/material.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:kinos/models/seerr/seerr_dashboard_model.dart';
import 'package:kinos/screens/seerr/widgets/seerr_request_banner_card.dart';
import 'package:kinos/theme/app_theme.dart';

class SeerrRequestBannerRow extends ConsumerWidget {
  final List<SeerrDashboardPosterModel> posters;
  final String label;
  final EdgeInsets contentPadding;
  final void Function(SeerrDashboardPosterModel poster)? onTap;
  final void Function(SeerrDashboardPosterModel focused)? onFocused;
  final void Function(SeerrDashboardPosterModel focused)? onRequestAddTap;
  final void Function()? onLabelClick;

  const SeerrRequestBannerRow({
    required this.posters,
    required this.label,
    this.contentPadding = const EdgeInsets.symmetric(horizontal: 16),
    this.onTap,
    this.onFocused,
    this.onRequestAddTap,
    this.onLabelClick,
    super.key,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
        padding:
            contentPadding.copyWith(top: AppSpacing.lg, bottom: AppSpacing.md),
        child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (onLabelClick != null)
                FocusRing(
                    onActivate: onLabelClick,
                    child: ExcludeFocus(
                        child: TextButton(
                            onPressed: onLabelClick,
                            child: Text(label,
                                style: AppTypography.sectionTitleSmall))))
              else
                Text(label, style: AppTypography.sectionTitleSmall),
              const SizedBox(height: AppSpacing.md),
              ListView.separated(
                  shrinkWrap: true,
                  padding: EdgeInsets.zero,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: posters.length,
                  separatorBuilder: (_, __) =>
                      const SizedBox(height: AppSpacing.xs),
                  itemBuilder: (context, index) => Focus(
                      canRequestFocus: false,
                      onFocusChange: (focused) {
                        if (focused) onFocused?.call(posters[index]);
                      },
                      child: SeerrRequestBannerCard(
                          key: Key(posters[index].id),
                          poster: posters[index],
                          onTap: onTap))),
            ]));
  }
}
