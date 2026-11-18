import 'package:flutter/material.dart';

import 'package:kinos/theme/app_theme.dart';

/// Une touche de raccourci, affichée à côté de la commande qu'elle
/// déclenche (règle : raccourcis visibles dans l'interface).
class KeyHint extends StatelessWidget {
  const KeyHint(this.label, {super.key});
  final String label;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
        child: Container(
          padding: AppUpcomingLayout.keyHintPadding,
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.borderStrong),
            borderRadius:
                const BorderRadius.all(Radius.circular(AppSpacing.xxs)),
          ),
          child: Text(label,
              style:
                  AppTypography.meta.copyWith(color: AppColors.textSecondary)),
        ),
      );
}
