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

/// Les raccourcis d'une tuile, rappelés à côté des filtres : `D` demander,
/// `S` suivre.
class TileKeyHints extends StatelessWidget {
  const TileKeyHints({super.key});

  @override
  Widget build(BuildContext context) {
    final style = AppTypography.meta.copyWith(color: AppColors.textSecondary);
    return Row(
        mainAxisSize: MainAxisSize.min,
        spacing: AppSpacing.xxs,
        children: [
          Text('Sur une tuile :', style: style),
          const KeyHint('D'),
          Text('demander', style: style),
          const SizedBox(width: AppSpacing.xxs),
          const KeyHint('S'),
          Text('suivre', style: style),
        ]);
  }
}
