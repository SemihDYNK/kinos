import 'package:flutter/material.dart';

import 'package:kinos/l10n/generated/app_localizations.dart';
import 'package:kinos/models/item_base_model.dart';
import 'package:kinos/models/items/episode_model.dart';
import 'package:kinos/models/items/images_models.dart';
import 'package:kinos/theme/app_theme.dart';
import 'package:kinos/util/localization_helper.dart';
import 'package:kinos/widgets/shared/focus_row.dart';
import 'package:kinos/widgets/shared/grid_focus_traveler.dart';
import 'package:kinos/widgets/shared/media_progress_bar.dart';
import 'package:kinos/widgets/shared/media_thumbnail.dart';

/// En dessous de ce nombre d'items, la rangée n'est pas étalée sur toute la
/// largeur — cf. [_SparseRow].
const _fullGridThreshold = 3;

/// Rangée "Continuer à regarder" : grille de vignettes 16:9, pas un
/// carrousel — elle remplit la largeur disponible (sauf rangée peu remplie,
/// cf. [_SparseRow]). Sliver direct, à insérer dans les `slivers:` d'un
/// [CustomScrollView].
class ContinueWatchingSection extends StatelessWidget {
  final List<ItemBaseModel> items;
  final EdgeInsets contentPadding;

  const ContinueWatchingSection({
    required this.items,
    required this.contentPadding,
    super.key,
  });

  int _columnsFor(double width) {
    const target = 280.0;
    return (width / target).floor().clamp(4, 5);
  }

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const SliverToBoxAdapter(child: SizedBox.shrink());
    }

    final width = MediaQuery.sizeOf(context).width - contentPadding.horizontal;
    final columns = _columnsFor(width);
    // Largeur qu'une vignette aurait dans une grille pleine à ce nombre de
    // colonnes — réutilisée telle quelle par la rangée peu remplie.
    final tileWidth = (width - (columns - 1) * AppSpacing.gridGap) / columns;
    // Vignette 16:9 + libellé sous l'image (titre une ligne + sous-titre
    // une ligne, cf. _ContinueWatchingCard) — hauteur dérivée de la
    // largeur réelle, jamais d'un ratio fixe appliqué à la carte entière
    // (image + libellé) : la fraction de pixel que produit ce ratio
    // reconverti en pixels est inférieure à ce que les deux lignes de
    // texte réclament en entier — débordement visible en debug (bande
    // rayée) sur toutes les vignettes à la fois. Même formule que
    // `season_episode_section.dart` (16:9 + AppSpacing.xs + 44, même
    // gabarit de libellé). Réutilisée telle quelle par la rangée peu
    // remplie (`_SparseRow`), qui appliquait le même `AspectRatio(16/9)`
    // problématique à la carte entière.
    final tileHeight = tileWidth * 9 / 16 + AppSpacing.xs + 44;

    return SliverMainAxisGroup(
      slivers: [
        SliverPadding(
          padding: contentPadding,
          sliver: SliverToBoxAdapter(
            child: Text(
              'Continuer à regarder',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
          ),
        ),
        SliverPadding(
          padding: contentPadding.copyWith(top: AppSpacing.sm),
          sliver: items.length < _fullGridThreshold
              ? SliverToBoxAdapter(
                  child: _SparseRow(
                      items: items,
                      tileWidth: tileWidth,
                      tileHeight: tileHeight),
                )
              : GridFocusTraveler(
                  itemCount: items.length,
                  crossAxisCount: columns,
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: columns,
                    crossAxisSpacing: AppSpacing.gridGap,
                    mainAxisSpacing: AppSpacing.gridGap,
                    mainAxisExtent: tileHeight,
                  ),
                  itemBuilder: (context, selectedIndex, index) =>
                      _ContinueWatchingCard(item: items[index]),
                ),
        ),
      ],
    );
  }
}

/// Rangée peu remplie (< [_fullGridThreshold] items) : largeur de vignette
/// constante (celle d'une grille pleine), alignée à gauche — jamais étalée
/// sur toute la largeur disponible.
class _SparseRow extends StatelessWidget {
  final List<ItemBaseModel> items;
  final double tileWidth;
  final double tileHeight;

  const _SparseRow(
      {required this.items,
      required this.tileWidth,
      required this.tileHeight});

  @override
  Widget build(BuildContext context) {
    return FocusRow(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final item in items) ...[
            // `tileHeight` en dur (pas d'AspectRatio) — même raison que la
            // grille pleine ci-dessus : la carte a un libellé sous l'image
            // qui réclame sa hauteur entière, un ratio fixe appliqué à la
            // carte entière peut y manquer de quelques dixièmes de pixel.
            SizedBox(
              width: tileWidth,
              height: tileHeight,
              child: _ContinueWatchingCard(item: item),
            ),
            if (item != items.last) const SizedBox(width: AppSpacing.gridGap),
          ],
        ],
      ),
    );
  }
}

class _ContinueWatchingCard extends StatelessWidget {
  final ItemBaseModel item;

  const _ContinueWatchingCard({required this.item});

  String _subtitle(AppLocalizations l10n) {
    final runTime = item.overview.runTime;
    final remaining =
        runTime != null ? runTime * (1 - item.userData.progress / 100) : null;
    final remainingLabel = remaining == null
        ? null
        : remaining.inHours > 0
            ? '${remaining.inHours}h ${remaining.inMinutes % 60} restantes'
            : '${remaining.inMinutes} min restantes';

    if (item case EpisodeModel episode) {
      return [episode.seasonEpisodeLabel(l10n), remainingLabel]
          .nonNulls
          .join(' · ');
    }
    return remainingLabel ?? '';
  }

  /// Thumb en priorité (déjà en 16:9), repli sur un backdrop, Primary
  /// (portrait) en dernier recours seulement — et dans ce cas on ne la
  /// rogne pas : cf. [_ContinueWatchingThumbnail].
  ImageData? get _thumbnail =>
      item.getPosters?.thumb ?? item.getPosters?.randomBackDrop;

  @override
  Widget build(BuildContext context) {
    return FocusRing(
      onActivate: () => item.navigateTo(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: AppRadii.cardBorder,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  MediaThumbnail(
                      thumbnail: _thumbnail,
                      fallback: item.getPosters?.primary),
                  MediaProgressBar(progress: item.userData.progress),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            item.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          Text(
            _subtitle(context.localized),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}
