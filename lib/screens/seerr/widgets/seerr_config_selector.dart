import 'package:flutter/material.dart';

import 'package:fladder/theme/app_theme.dart';
import 'package:fladder/util/adaptive_layout/adaptive_layout.dart';
import 'package:fladder/widgets/shared/item_actions.dart';
import 'package:fladder/widgets/shared/modal_bottom_sheet.dart';
import 'package:fladder/widgets/shared/modal_side_sheet.dart';

/// Sélecteur sobre "libellé + valeur actuelle" (profil de qualité, dossier
/// racine, serveur, tags, demandeur...) — remplace `EnumSelection` dans la
/// modale de demande Seerr : cadre fin, jamais une pastille arrondie
/// pleinement colorée ([EnumBox]). `EnumSelection`/[EnumBox] restent
/// utilisés tels quels ailleurs (panneau de contrôle, réglages, lecteur...),
/// hors périmètre de cette réécriture.
class SeerrConfigSelector extends StatelessWidget {
  final Widget label;
  final String current;
  final Widget? currentWidget;
  final List<ItemAction> Function(BuildContext context) itemBuilder;

  const SeerrConfigSelector({
    required this.label,
    required this.current,
    this.currentWidget,
    required this.itemBuilder,
    super.key,
  });

  Future<void> _openPicker(BuildContext context, List<ItemAction> items) async {
    if (AdaptiveLayout.viewSizeOf(context) != ViewSize.phone) {
      await showModalSideSheet(
        context,
        header: label,
        content: ListView(
          shrinkWrap: true,
          children: items.map((e) => e.toListItem(context, useIcons: true)).toList(),
        ),
      );
    } else {
      await showBottomSheetPill(
        context: context,
        content: (context, scrollController) => ListView(
          shrinkWrap: true,
          controller: scrollController,
          children: items.map((e) => e.toListItem(context, useIcons: true)).toList(),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Builder(
      builder: (context) {
        final items = itemBuilder(context);
        final hasMultipleItems = items.length > 1;
        final onActivate = hasMultipleItems ? () => _openPicker(context, items) : null;

        return Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            DefaultTextStyle.merge(
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
              child: label,
            ),
            const Spacer(),
            FocusRing(
              borderRadius: AppRadii.controlBorder,
              onActivate: onActivate,
              child: ExcludeFocus(
                child: InkWell(
                  borderRadius: AppRadii.controlBorder,
                  onTap: onActivate,
                  child: Container(
                    constraints: const BoxConstraints(maxWidth: 220),
                    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
                    decoration: BoxDecoration(
                      borderRadius: AppRadii.controlBorder,
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Flexible(
                          child: currentWidget ??
                              Text(
                                current,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.textPrimary),
                              ),
                        ),
                        if (hasMultipleItems) ...[
                          const SizedBox(width: AppSpacing.xxs),
                          const Icon(Icons.keyboard_arrow_down_rounded, size: 18, color: AppColors.textSecondary),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
