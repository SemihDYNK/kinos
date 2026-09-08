import 'package:flutter/material.dart';

import 'package:fladder/theme/app_theme.dart';
import 'package:fladder/widgets/shared/modal_bottom_sheet.dart';

/// Sélecteur sobre "Libellé · valeur" qui ouvre une liste de choix — jamais
/// une pastille remplie (cf. CLAUDE.md, pas de couleur d'accent
/// décorative). Partagé par [MediaStreamSelectors] (version, piste audio,
/// sous-titres) et le sélecteur de saison de la fiche série : même
/// composant, même interaction, où qu'un choix parmi une liste courte soit
/// nécessaire.
class LabeledSelector extends StatelessWidget {
  final String label;
  final String value;
  final List<
      ({
        String label,
        bool selected,
        VoidCallback onSelect,
        Widget? subtitle
      })> options;

  const LabeledSelector({
    required this.label,
    required this.value,
    required this.options,
    super.key,
  });

  void _open(BuildContext context) {
    showBottomSheetPill(
      context: context,
      content: (context, scrollController) => ListView(
        controller: scrollController,
        shrinkWrap: true,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md, vertical: AppSpacing.sm),
            child:
                Text(label, style: Theme.of(context).textTheme.headlineSmall),
          ),
          for (final option in options)
            FocusRing(
              borderRadius: AppRadii.controlBorder,
              onActivate: () {
                option.onSelect();
                Navigator.of(context).pop();
              },
              child: ExcludeFocus(
                child: ListTile(
                  onTap: () {
                    option.onSelect();
                    Navigator.of(context).pop();
                  },
                  title: Text(
                    option.label,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: option.selected
                            ? AppColors.textPrimary
                            : AppColors.textSecondary),
                  ),
                  subtitle: option.subtitle,
                  trailing: option.selected
                      ? const Icon(Icons.check_rounded,
                          color: AppColors.textPrimary)
                      : null,
                ),
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FocusRing(
      borderRadius: AppRadii.controlBorder,
      onActivate: () => _open(context),
      child: ExcludeFocus(
        child: InkWell(
          borderRadius: AppRadii.controlBorder,
          onTap: () => _open(context),
          child: Padding(
            padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.xs, vertical: AppSpacing.xxs),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '$label · ',
                  style: Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.copyWith(color: AppColors.textSecondary),
                ),
                Text(
                  value,
                  style: Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.copyWith(color: AppColors.textPrimary),
                ),
                const SizedBox(width: AppSpacing.xxs),
                const Icon(Icons.keyboard_arrow_down_rounded,
                    size: 18, color: AppColors.textSecondary),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
