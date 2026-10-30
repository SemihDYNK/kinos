import 'package:flutter/material.dart';
import 'package:kinos/theme/app_theme.dart';

/// En-tête fonctionnel commun : identité Inter, actions adaptables au texte.
class AppPageHeader extends StatelessWidget {
  const AppPageHeader(
      {required this.title, this.subtitle, this.trailing, super.key});
  final String title;
  final String? subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) =>
      LayoutBuilder(builder: (context, constraints) {
        final heading = Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: AppTypography.sectionTitle.copyWith(
                      fontSize: AppPageLayout.titleSize,
                      fontWeight: FontWeight.w700,
                      fontVariations: const [FontVariation('wght', 700)],
                      height: AppPageLayout.titleHeight,
                      letterSpacing: AppPageLayout.titleTracking)),
              if (subtitle != null && subtitle!.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.xs),
                Text(subtitle!,
                    style: Theme.of(context)
                        .textTheme
                        .bodyMedium
                        ?.copyWith(color: AppColors.textSecondary)),
              ],
            ]);
        if (trailing == null) return heading;
        if (constraints.maxWidth < AppPageLayout.compactWidth) {
          return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                heading,
                const SizedBox(height: AppSpacing.md),
                trailing!
              ]);
        }
        return Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Expanded(child: heading),
          const SizedBox(width: AppSpacing.lg),
          trailing!,
        ]);
      });
}

/// Mesure de lecture réelle, même dans un SliverToBoxAdapter de largeur imposée.
class MediaSynopsis extends StatelessWidget {
  const MediaSynopsis(this.text, {super.key});
  final String text;
  @override
  Widget build(BuildContext context) => Align(
      alignment: AlignmentDirectional.centerStart,
      child: ConstrainedBox(
          constraints:
              const BoxConstraints(maxWidth: AppDetailLayout.readingWidth),
          child: Text(text,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.textPrimary,
                  height: AppTypography.body.height))));
}

/// Pinned search controls must occlude catalog artwork scrolling beneath them.
class SearchHeaderSurface extends StatelessWidget {
  const SearchHeaderSurface({required this.child, super.key});
  final Widget child;
  @override
  Widget build(BuildContext context) =>
      ColoredBox(color: AppColors.background, child: child);
}
