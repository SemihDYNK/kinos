import 'package:flutter/material.dart';

import 'package:kinos/theme/app_theme.dart';

/// Bouton de filtre sobre — texte (+ icône optionnelle) dans un cadre fin,
/// jamais une pastille pleinement arrondie ni un fond coloré plein.
/// L'état actif se lit par la couleur du texte et une bordure/fond léger,
/// pas par un badge. Remplace `ExpressiveButton` dans les barres de
/// filtres bibliothèque/Seerr — `ExpressiveButton` reste utilisé tel quel
/// par des écrans hors périmètre de cette réécriture (bibliothèques,
/// musique).
class FilterButton extends StatelessWidget {
  final bool isSelected;
  final Widget label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final VoidCallback? onLongPress;

  const FilterButton({
    required this.isSelected,
    required this.label,
    this.icon,
    required this.onPressed,
    this.onLongPress,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final color = isSelected ? AppColors.textPrimary : AppColors.textSecondary;
    return FocusRing(
      borderRadius: AppRadii.controlBorder,
      onActivate: onPressed,
      child: ExcludeFocus(
        child: InkWell(
          borderRadius: AppRadii.controlBorder,
          onTap: onPressed,
          onLongPress: onLongPress,
          child: Container(
            padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
            decoration: BoxDecoration(
              borderRadius: AppRadii.controlBorder,
              border: Border.all(
                  color:
                      isSelected ? AppColors.borderStrong : AppColors.border),
              color: isSelected ? AppColors.surfaceHigh : AppColors.surface,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (icon != null) ...[
                  Icon(icon, size: 16, color: color),
                  const SizedBox(width: AppSpacing.xxs),
                ],
                DefaultTextStyle(
                  style: Theme.of(context)
                      .textTheme
                      .bodyMedium!
                      .copyWith(color: color),
                  child: IconTheme.merge(
                    // Une icône dans `label` (ex. la flèche de CategoryChip)
                    // suit la même couleur d'état sans que chaque appelant
                    // n'ait à la teinter lui-même.
                    data: IconThemeData(color: color, size: 16),
                    child: label,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
