import 'package:kinos/theme/app_theme.dart';
import 'package:flutter/material.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

class SettingsLabelDivider extends ConsumerWidget {
  final String label;
  const SettingsLabelDivider({required this.label, super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.xxs, vertical: AppSpacing.xs),
      child: Text(
        label,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
      ),
    );
  }
}
