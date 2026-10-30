import 'package:kinos/screens/shared/media_navigation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:kinos/l10n/generated/app_localizations.dart';
import 'package:kinos/models/item_base_model.dart';
import 'package:kinos/models/items/episode_model.dart';
import 'package:kinos/models/items/images_models.dart';
import 'package:kinos/theme/app_theme.dart';
import 'package:kinos/util/localization_helper.dart';
import 'package:kinos/widgets/shared/focus_row.dart';
import 'package:kinos/widgets/shared/media_progress_bar.dart';
import 'package:kinos/widgets/shared/media_thumbnail.dart';

/// Une seule rangée de reprise, navigable au clavier et par les flèches du titre.
class ContinueWatchingSection extends StatefulWidget {
  const ContinueWatchingSection(
      {required this.items, required this.contentPadding, super.key});
  final List<ItemBaseModel> items;
  final EdgeInsets contentPadding;

  @override
  State<ContinueWatchingSection> createState() =>
      _ContinueWatchingSectionState();
}

class _ContinueWatchingSectionState extends State<ContinueWatchingSection> {
  final _scroll = ScrollController();
  final _nodes = <FocusNode>[];

  KeyEventResult _onKeyEvent(FocusNode _, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    final current = _nodes.indexWhere((node) => node.hasFocus);
    if (current < 0) return KeyEventResult.ignored;
    final rtl = Directionality.of(context) == TextDirection.rtl;
    final delta = event.logicalKey == LogicalKeyboardKey.arrowRight
        ? (rtl ? -1 : 1)
        : event.logicalKey == LogicalKeyboardKey.arrowLeft
            ? (rtl ? 1 : -1)
            : 0;
    final next = current + delta;
    if (delta == 0 || next < 0 || next >= widget.items.length) {
      return KeyEventResult.ignored;
    }
    _nodes[next].requestFocus();
    return KeyEventResult.handled;
  }

  FocusNode _nodeFor(int index) {
    while (_nodes.length <= index) {
      final node = FocusNode();
      node.addListener(() {
        final target = node.context;
        if (node.hasFocus && target != null) {
          final render = target.findRenderObject();
          if (render == null) return;
          Scrollable.maybeOf(target, axis: Axis.horizontal)
              ?.position
              .ensureVisible(
                  render,
                  alignment: .5,
                  duration: MediaQuery.disableAnimationsOf(target)
                      ? Duration.zero
                      : AppDurations.pageTransition,
                  curve: AppMotion.easeOut);
        }
      });
      _nodes.add(node);
    }
    return _nodes[index];
  }

  void _move(int direction) {
    if (!_scroll.hasClients) return;
    final target =
        (_scroll.offset + direction * _scroll.position.viewportDimension)
            .clamp(0.0, _scroll.position.maxScrollExtent);
    if (MediaQuery.disableAnimationsOf(context)) {
      _scroll.jumpTo(target);
    } else {
      _scroll.animateTo(target,
          duration: AppDurations.navigationExpand, curve: AppMotion.easeOut);
    }
  }

  @override
  void dispose() {
    _scroll.dispose();
    for (final node in _nodes) {
      node.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.items.isEmpty) {
      return const SliverToBoxAdapter(child: SizedBox.shrink());
    }
    return SliverLayoutBuilder(builder: (context, constraints) {
      final width =
          constraints.crossAxisExtent - widget.contentPadding.horizontal;
      final columns = (width / AppMedia.resumeTargetWidth).floor().clamp(4, 5);
      final tileWidth = (width - (columns - 1) * AppSpacing.gridGap) / columns;
      final theme = Theme.of(context).textTheme;
      double lineHeight(TextStyle? style) => TextPainter(
            text: TextSpan(text: 'Ag', style: style),
            textDirection: Directionality.of(context),
            textScaler: MediaQuery.textScalerOf(context),
          ).preferredLineHeight;
      final tileHeight = tileWidth / AppMedia.resumeAspectRatio +
          AppSpacing.xs +
          lineHeight(theme.titleMedium) +
          lineHeight(theme.bodySmall) +
          FocusRing.contentInset(context);
      return SliverMainAxisGroup(slivers: [
        SliverPadding(
            padding: widget.contentPadding,
            sliver: SliverToBoxAdapter(
                child: Row(children: [
              Expanded(
                  child: Text('Continuer à regarder',
                      style: theme.headlineMedium)),
              if (widget.items.length > columns)
                for (final direction in [-1, 1])
                  FocusRing(
                      onActivate: () => _move(direction),
                      child: ExcludeFocus(
                          child: IconButton(
                        tooltip: direction < 0
                            ? context.localized.discoveryScrollPrevious
                            : context.localized.discoveryScrollNext,
                        onPressed: () => _move(direction),
                        icon: Icon(direction < 0
                            ? Icons.chevron_left
                            : Icons.chevron_right),
                      ))),
            ]))),
        SliverPadding(
            padding: widget.contentPadding.copyWith(top: AppSpacing.sm),
            sliver: SliverToBoxAdapter(
                child: FocusRow(
              child: ScrollConfiguration(
                behavior:
                    ScrollConfiguration.of(context).copyWith(scrollbars: false),
                child: Focus(
                    canRequestFocus: false,
                    onKeyEvent: _onKeyEvent,
                    child: SingleChildScrollView(
                      controller: _scroll,
                      scrollDirection: Axis.horizontal,
                      physics: const NeverScrollableScrollPhysics(),
                      child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            for (var index = 0;
                                index < widget.items.length;
                                index++) ...[
                              SizedBox(
                                  width: tileWidth,
                                  height: tileHeight,
                                  child: _ContinueWatchingCard(
                                      item: widget.items[index],
                                      focusNode: _nodeFor(index))),
                              if (index < widget.items.length - 1)
                                const SizedBox(width: AppSpacing.gridGap),
                            ],
                          ]),
                    )),
              ),
            ))),
      ]);
    });
  }
}

class _ContinueWatchingCard extends StatelessWidget {
  final ItemBaseModel item;

  const _ContinueWatchingCard({required this.item, required this.focusNode});
  final FocusNode focusNode;

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
    return MediaNavigation(
        focusNode: focusNode,
        previewImage: _thumbnail ?? item.getPosters?.primary,
        key: ValueKey(item.id),
        builder: (context) => FocusRing(
              posterMotion: true,
              focusNode: MediaNavigationScope.focusOf(context),
              onActivate: () => openMediaDetails(context, item),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AspectRatio(
                    aspectRatio: AppMedia.resumeAspectRatio,
                    child: ClipRRect(
                      borderRadius: AppRadii.cardBorder,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          MediaArtwork(
                              child: MediaThumbnail(
                                  thumbnail: _thumbnail,
                                  fallback: item.getPosters?.primary)),
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
            ));
  }
}
