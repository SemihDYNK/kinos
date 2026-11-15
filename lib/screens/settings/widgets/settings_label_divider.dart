import 'package:flutter/material.dart';

import 'package:kinos/theme/app_theme.dart';

/// Titre d'une section de réglages, posé au-dessus de son groupe.
///
/// Le caractère vient de l'échelle typographique : un titre de section, pas
/// un libellé gras de liste.
class SettingsLabelDivider extends StatelessWidget {
  final String label;
  const SettingsLabelDivider({required this.label, super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(
          left: AppSpacing.xxs,
          right: AppSpacing.xxs,
          top: AppSpacing.md,
          bottom: AppSpacing.xs),
      child: Text(label, style: AppTypography.sectionTitleSmall),
    );
  }
}
