import 'package:flutter/material.dart';

import 'package:kinos/theme/app_theme.dart';
import 'package:kinos/widgets/shared/anchored_popover.dart';

/// Sélecteur sobre "Libellé · valeur" qui ouvre une liste de choix — jamais
/// une pastille remplie (cf. CLAUDE.md, pas de couleur d'accent
/// décorative). Ouvre un [AnchoredPopover] ancré sur lui-même plutôt qu'une
/// feuille modale pleine largeur : un choix parmi une liste courte ne
/// justifie pas ce poids. Partagé par [MediaStreamSelectors] (version,
/// piste audio, sous-titres), le sélecteur de saison de la fiche série et
/// son équivalent Arr : même composant, même interaction, où qu'un choix
/// parmi une liste courte soit nécessaire.
class LabeledSelector extends StatefulWidget {
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

  @override
  State<LabeledSelector> createState() => _LabeledSelectorState();
}

class _LabeledSelectorState extends State<LabeledSelector> {
  final _controller = AnchoredPopoverController();

  @override
  Widget build(BuildContext context) {
    return AnchoredPopover(
      controller: _controller,
      popoverBuilder: (context, close) => PopoverOptionList(
        onSelected: close,
        options: widget.options
            .map((option) => PopoverOption(
                  content: option.subtitle == null
                      ? Text(option.label)
                      : Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(option.label),
                            option.subtitle!,
                          ],
                        ),
                  selected: option.selected,
                  onSelect: option.onSelect,
                ))
            .toList(),
      ),
      child: FocusRing(
        borderRadius: AppRadii.controlBorder,
        onActivate: _controller.toggle,
        child: ExcludeFocus(
          child: InkWell(
            borderRadius: AppRadii.controlBorder,
            onTap: _controller.toggle,
            child: Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.xs, vertical: AppSpacing.xxs),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${widget.label} · ',
                    style: Theme.of(context)
                        .textTheme
                        .bodyMedium
                        ?.copyWith(color: AppColors.textSecondary),
                  ),
                  // Flexible + ellipsis : sans borne, une valeur longue (un
                  // chemin de dossier racine...) déborde du Row plutôt que
                  // de respecter la largeur réellement disponible — ce
                  // déclencheur vit parfois dans un conteneur étroit (une
                  // boîte de dialogue d'édition, par exemple).
                  Flexible(
                    child: Text(
                      widget.value,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context)
                          .textTheme
                          .bodyMedium
                          ?.copyWith(color: AppColors.textPrimary),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.xxs),
                  const Icon(Icons.keyboard_arrow_down_rounded,
                      size: 18, color: AppColors.textSecondary),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
