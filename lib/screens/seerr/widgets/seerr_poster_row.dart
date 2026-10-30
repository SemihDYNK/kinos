import 'package:kinos/theme/app_theme.dart';
import 'package:kinos/util/text_metrics.dart';
import 'package:kinos/util/localization_helper.dart';
import 'package:flutter/material.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:kinos/models/seerr/seerr_dashboard_model.dart';
import 'package:kinos/providers/arguments_provider.dart';
import 'package:kinos/screens/seerr/widgets/seerr_poster_card.dart';
import 'package:kinos/util/adaptive_layout/adaptive_layout.dart';
import 'package:kinos/util/focus_provider.dart';
import 'package:kinos/widgets/shared/ensure_visible.dart';
import 'package:kinos/widgets/shared/horizontal_list.dart';

class SeerrPosterRow extends ConsumerWidget {
  final List<SeerrDashboardPosterModel> posters;
  final String label;
  final bool showStatus;
  final EdgeInsets contentPadding;
  final void Function(SeerrDashboardPosterModel focused)? onFocused;

  final void Function()? onLabelClick;

  const SeerrPosterRow({
    required this.posters,
    required this.label,
    this.showStatus = false,
    this.contentPadding = const EdgeInsets.symmetric(horizontal: 16),
    this.onFocused,
    this.onLabelClick,
    super.key,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (showStatus) return _DiscoverPosterRail(row: this);
    final dominantRatio = AdaptiveLayout.poster(context).ratio;
    return HorizontalList<SeerrDashboardPosterModel>(
      contentPadding: contentPadding,
      label: label,
      autoFocus: ref.read(argumentsStateProvider).htpcMode
          ? FocusProvider.autoFocusOf(context)
          : false,
      onLabelClick: onLabelClick,
      dominantRatio: dominantRatio,
      items: posters,
      onFocused: (index) {
        if (onFocused != null) {
          onFocused?.call(posters[index]);
        } else {
          context.ensureVisible();
        }
      },
      itemBuilder: (context, index) => SeerrPosterCard(
        key: Key(posters[index].id),
        poster: posters[index],
        aspectRatio: dominantRatio,
      ),
    );
  }
}

class _DiscoverPosterRail extends StatefulWidget {
  const _DiscoverPosterRail({required this.row});
  final SeerrPosterRow row;
  @override
  State<_DiscoverPosterRail> createState() => _DiscoverPosterRailState();
}

class _DiscoverPosterRailState extends State<_DiscoverPosterRail> {
  final _scroll = ScrollController();
  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _move(double delta) {
    if (!_scroll.hasClients) return;
    final target =
        (_scroll.offset + delta).clamp(0.0, _scroll.position.maxScrollExtent);
    if (AppMotion.enabled(context)) {
      _scroll.animateTo(target,
          duration: AppDurations.selection, curve: AppMotion.easeOut);
    } else {
      _scroll.jumpTo(target);
    }
  }

  @override
  Widget build(BuildContext context) => Padding(
        padding: widget.row.contentPadding.copyWith(bottom: AppSpacing.xl),
        child: LayoutBuilder(builder: (context, constraints) {
          final columns =
              context.tokens.density.columnsFor(constraints.maxWidth);
          final width =
              (constraints.maxWidth - (columns - 1) * AppSpacing.gridGap) /
                  columns;
          final height = width / AppMedia.posterAspectRatio +
              measuredLineHeight(
                  context, Theme.of(context).textTheme.titleMedium) +
              measuredLineHeight(
                  context, Theme.of(context).textTheme.titleSmall) +
              AppSpacing.xs;
          return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Expanded(
                      child: Text(widget.row.label,
                          style: Theme.of(context).textTheme.headlineMedium)),
                  if (widget.row.onLabelClick != null)
                    FocusRing(
                        onActivate: widget.row.onLabelClick,
                        borderRadius: AppRadii.controlBorder,
                        child: ExcludeFocus(
                            child: TextButton(
                                onPressed: widget.row.onLabelClick,
                                child: Text(context.localized.showMore)))),
                  if (widget.row.posters.length > columns)
                    for (final direction in [-1, 1])
                      FocusRing(
                          onActivate: () =>
                              _move(direction * constraints.maxWidth),
                          child: ExcludeFocus(
                              child: IconButton(
                            onPressed: () =>
                                _move(direction * constraints.maxWidth),
                            tooltip: direction < 0
                                ? context.localized.discoveryScrollPrevious
                                : context.localized.discoveryScrollNext,
                            icon: Icon(direction < 0
                                ? Icons.chevron_left
                                : Icons.chevron_right),
                          ))),
                ]),
                const SizedBox(height: AppSpacing.sm),
                ScrollConfiguration(
                  behavior: ScrollConfiguration.of(context)
                      .copyWith(scrollbars: false),
                  child: SingleChildScrollView(
                    controller: _scroll,
                    scrollDirection: Axis.horizontal,
                    physics: const NeverScrollableScrollPhysics(),
                    child: Row(children: [
                      for (final poster in widget.row.posters)
                        Padding(
                            padding: const EdgeInsetsDirectional.only(
                                end: AppSpacing.gridGap),
                            child: SizedBox(
                              width: width,
                              height: height,
                              child: Builder(
                                  builder: (context) => SeerrPosterCard(
                                        key: ValueKey(poster.id),
                                        poster: poster,
                                        showStatus: true,
                                        imageAspectRatio:
                                            AppMedia.posterAspectRatio,
                                        onFocusChanged: (focused) {
                                          if (!focused) return;
                                          Scrollable.ensureVisible(context,
                                              alignmentPolicy:
                                                  ScrollPositionAlignmentPolicy
                                                      .keepVisibleAtEnd,
                                              duration:
                                                  AppMotion.enabled(context)
                                                      ? AppDurations.selection
                                                      : Duration.zero);
                                        },
                                      )),
                            )),
                    ]),
                  ),
                ),
              ]);
        }),
      );
}
