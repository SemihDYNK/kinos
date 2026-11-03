import 'package:kinos/theme/app_theme.dart';
import 'package:kinos/util/text_metrics.dart';
import 'package:kinos/util/localization_helper.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart' show ScrollCacheExtent;

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
  final _nodes = <String, FocusNode>{};
  final _railFocus = FocusNode(skipTraversal: true);
  int _focusGeneration = 0;
  int? _pendingIndex;

  @override
  void didUpdateWidget(covariant _DiscoverPosterRail oldWidget) {
    super.didUpdateWidget(oldWidget);
    final ids = widget.row.posters.map((poster) => poster.id).toList();
    if (listEquals(
        oldWidget.row.posters.map((poster) => poster.id).toList(), ids)) {
      return;
    }
    _focusGeneration++;
    _pendingIndex = null;
    for (final id in _nodes.keys.where((id) => !ids.contains(id)).toList()) {
      final node = _nodes.remove(id)!;
      WidgetsBinding.instance.addPostFrameCallback((_) => node.dispose());
    }
  }

  FocusNode _nodeFor(int index) =>
      _nodes.putIfAbsent(widget.row.posters[index].id, () => FocusNode());

  KeyEventResult _onKey(KeyEvent event, double extent) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    final current = _railFocus.hasPrimaryFocus && _pendingIndex != null
        ? _pendingIndex!
        : widget.row.posters
            .indexWhere((poster) => _nodes[poster.id]?.hasPrimaryFocus == true);
    if (current < 0) return KeyEventResult.ignored;
    final rtl = Directionality.of(context) == TextDirection.rtl;
    final delta = event.logicalKey == LogicalKeyboardKey.arrowRight
        ? (rtl ? -1 : 1)
        : event.logicalKey == LogicalKeyboardKey.arrowLeft
            ? (rtl ? 1 : -1)
            : 0;
    final next = current + delta;
    if (delta == 0 || next < 0 || next >= widget.row.posters.length) {
      return delta != 0 && _railFocus.hasPrimaryFocus
          ? KeyEventResult.handled
          : KeyEventResult.ignored;
    }
    _pendingIndex = next;
    // Hold focus in the rail while its source card leaves the lazy viewport.
    _railFocus.requestFocus();
    _focusPoster(next, extent, ++_focusGeneration);
    return KeyEventResult.handled;
  }

  Future<void> _focusPoster(int index, double extent, int generation) async {
    final start = index * extent;
    final end = start + extent;
    final target = (start < _scroll.offset
            ? start
            : end > _scroll.offset + _scroll.position.viewportDimension
                ? end - _scroll.position.viewportDimension
                : _scroll.offset)
        .clamp(0.0, _scroll.position.maxScrollExtent);
    if (AppMotion.enabled(context)) {
      await _scroll.animateTo(target,
          duration: AppDurations.selection, curve: AppMotion.easeOut);
    } else {
      _scroll.jumpTo(target);
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || generation != _focusGeneration) return;
      _pendingIndex = null;
      if (_railFocus.hasPrimaryFocus && index < widget.row.posters.length) {
        _nodeFor(index).requestFocus();
      }
    });
    WidgetsBinding.instance.scheduleFrame();
  }

  @override
  void dispose() {
    _focusGeneration++;
    _scroll.dispose();
    _railFocus.dispose();
    for (final node in _nodes.values) {
      node.dispose();
    }
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
                  child: Focus(
                    focusNode: _railFocus,
                    onKeyEvent: (_, event) =>
                        _onKey(event, width + AppSpacing.gridGap),
                    child: SizedBox(
                      height: height,
                      child: ListView.builder(
                        controller: _scroll,
                        scrollDirection: Axis.horizontal,
                        physics: const NeverScrollableScrollPhysics(),
                        scrollCacheExtent: ScrollCacheExtent.pixels(width),
                        itemExtent: width + AppSpacing.gridGap,
                        itemCount: widget.row.posters.length,
                        itemBuilder: (context, index) {
                          final poster = widget.row.posters[index];
                          return Padding(
                              padding: const EdgeInsetsDirectional.only(
                                  end: AppSpacing.gridGap),
                              child: SizedBox(
                                width: width,
                                height: height,
                                child: Builder(
                                    builder: (context) => SeerrPosterCard(
                                          key: ValueKey(poster.id),
                                          poster: poster,
                                          focusNode: _nodeFor(index),
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
                              ));
                        },
                      ),
                    ),
                  ),
                ),
              ]);
        }),
      );
}
