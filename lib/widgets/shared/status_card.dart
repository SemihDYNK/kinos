import 'package:flutter/material.dart';

import 'package:kinos/theme/app_theme.dart';
import 'package:kinos/widgets/shared/frosted_surface.dart';

class StatusCard extends StatelessWidget {
  final Color? color;
  final Widget child;

  const StatusCard({this.color, required this.child, super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.xxs),
      child: FrostedSurface(
        borderRadius: AppMediaIcons.circle,
        color: AppMediaIcons.surface,
        child: ConstrainedBox(
          constraints: const BoxConstraints(
              minWidth: AppMediaIcons.badgeSize,
              minHeight: AppMediaIcons.badgeSize),
          child: Center(
            widthFactor: 1,
            heightFactor: 1,
            child: IconTheme(
              data: IconThemeData(
                  size: AppMediaIcons.badgeIconSize,
                  color: color ?? AppColors.textPrimary),
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}
