import 'package:flutter/material.dart';

import 'package:fladder/theme/app_theme.dart';
import 'package:fladder/widgets/shared/anchored_popover.dart';
import 'package:fladder/widgets/shared/item_actions.dart';

/// Sélecteur sobre "libellé + valeur actuelle" (profil de qualité, dossier
/// racine, serveur, tags, demandeur...) — remplace `EnumSelection` dans la
/// modale de demande Seerr : cadre fin, jamais une pastille arrondie
/// pleinement colorée ([EnumBox]). Ouvre un [AnchoredPopover] ancré sur son
/// propre bouton plutôt qu'un panneau ou une feuille modale — un choix
/// parmi une poignée d'options ne justifie pas ce poids, y compris quand ce
/// sélecteur vit lui-même dans une modale (la demande Seerr) : le popover
/// s'empile correctement au-dessus d'elle, se replace s'il déborderait de
/// la fenêtre, et Échap ne ferme que lui — un second Échap ferme la modale.
/// `EnumSelection`/[EnumBox] restent utilisés tels quels ailleurs (panneau
/// de contrôle, réglages, lecteur...), hors périmètre de cette réécriture.
class SeerrConfigSelector extends StatefulWidget {
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

  @override
  State<SeerrConfigSelector> createState() => _SeerrConfigSelectorState();
}

class _SeerrConfigSelectorState extends State<SeerrConfigSelector> {
  // Champ d'état, pas une variable locale au build : le popover doit
  // continuer de répondre au même contrôleur si le parent se reconstruit
  // (ex. sélection de tag) pendant qu'il est ouvert.
  final _controller = AnchoredPopoverController();

  List<PopoverOption> _options(VoidCallback close, List<ItemAction> items) {
    return items.whereType<ItemActionButton>().map((item) {
      return PopoverOption(
        content: item.label ?? const SizedBox.shrink(),
        selected: item.selected,
        onSelect: () {
          item.action?.call();
          close();
        },
      );
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final items = widget.itemBuilder(context);
    final hasMultipleItems = items.length > 1;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        DefaultTextStyle.merge(
          style: Theme.of(context)
              .textTheme
              .bodyMedium
              ?.copyWith(color: AppColors.textSecondary),
          child: widget.label,
        ),
        const Spacer(),
        AnchoredPopover(
          controller: _controller,
          popoverBuilder: (context, close) => PopoverOptionList(
            options: _options(close, items),
          ),
          child: FocusRing(
            borderRadius: AppRadii.controlBorder,
            onActivate: hasMultipleItems ? _controller.toggle : null,
            child: ExcludeFocus(
              child: InkWell(
                borderRadius: AppRadii.controlBorder,
                onTap: hasMultipleItems ? _controller.toggle : null,
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 220),
                  padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
                  decoration: BoxDecoration(
                    borderRadius: AppRadii.controlBorder,
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(
                        child: widget.currentWidget ??
                            Text(
                              widget.current,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyMedium
                                  ?.copyWith(color: AppColors.textPrimary),
                            ),
                      ),
                      if (hasMultipleItems) ...[
                        const SizedBox(width: AppSpacing.xxs),
                        const Icon(Icons.keyboard_arrow_down_rounded,
                            size: 18, color: AppColors.textSecondary),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
