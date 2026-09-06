import 'package:flutter/material.dart';

import 'package:fladder/models/item_base_model.dart';
import 'package:fladder/theme/app_theme.dart';
import 'package:fladder/util/fladder_image.dart';
import 'package:fladder/widgets/shared/grid_focus_traveler.dart';

/// Grille "Ajouts récents" à une ligne, réutilisée par toutes les sections
/// de l'accueil (fixes et rangées configurables) : une vraie grille qui
/// remplit la largeur, jamais un carrousel horizontal.
///
/// Une seule ligne — le surplus n'est ni affiché ni défilable, il est
/// tronqué. Les flèches gauche/droite déplacent le focus entre les
/// jaquettes (cf. [GridFocusTraveler]), elles ne font jamais défiler quoi
/// que ce soit à l'intérieur de la rangée. `onSeeAll` (facultatif) donne
/// accès au surplus via la vue complète.
///
/// Sliver direct, à insérer dans les `slivers:` d'un [CustomScrollView].
class SingleRowSection extends StatelessWidget {
  final String title;
  final List<ItemBaseModel> items;
  final EdgeInsets contentPadding;
  final VoidCallback? onSeeAll;

  const SingleRowSection({
    required this.title,
    required this.items,
    required this.contentPadding,
    this.onSeeAll,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const SliverToBoxAdapter(child: SizedBox.shrink());
    }

    final width = MediaQuery.sizeOf(context).width - contentPadding.horizontal;
    final columns = context.tokens.density.columnsFor(width);
    // Une seule ligne : le reste est tronqué, jamais affiché ni défilable.
    final visible = items.take(columns).toList();

    return SliverMainAxisGroup(
      slivers: [
        SliverPadding(
          padding: contentPadding,
          sliver: SliverToBoxAdapter(
            child: Row(
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const Spacer(),
                if (onSeeAll != null)
                  FocusRing(
                    borderRadius: AppRadii.controlBorder,
                    onActivate: onSeeAll,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.xs, vertical: AppSpacing.xxs),
                      child: Text(
                        'tout voir',
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(color: AppColors.textPrimary),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        SliverPadding(
          padding: contentPadding.copyWith(top: AppSpacing.sm),
          sliver: GridFocusTraveler(
            itemCount: visible.length,
            crossAxisCount: columns,
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: columns,
              crossAxisSpacing: AppSpacing.gridGap,
              mainAxisSpacing: AppSpacing.gridGap,
              childAspectRatio: 2 / 3,
            ),
            itemBuilder: (context, selectedIndex, index) =>
                _Tile(item: visible[index]),
          ),
        ),
      ],
    );
  }
}

class _Tile extends StatelessWidget {
  final ItemBaseModel item;

  const _Tile({required this.item});

  @override
  Widget build(BuildContext context) {
    // Primary est déjà en 2:3, comme la cellule : cover ne recadre rien.
    // Les replis (thumb/backdrop, en 16:9) recadreraient lourdement en
    // cover dans une cellule 2:3 — contain sur fond surface, comme la
    // vignette "Continuer à regarder" pour le même cas de figure.
    final image = item.getPosters?.primary;
    final fallback = image == null ? (item.getPosters?.thumb ?? item.getPosters?.randomBackDrop) : null;

    return FocusRing(
      onActivate: () => item.navigateTo(context),
      child: ClipRRect(
        borderRadius: AppRadii.cardBorder,
        child: ColoredBox(
          color: AppColors.surface,
          child: FladderImage(
            image: image ?? fallback,
            fit: image != null ? BoxFit.cover : BoxFit.contain,
          ),
        ),
      ),
    );
  }
}
