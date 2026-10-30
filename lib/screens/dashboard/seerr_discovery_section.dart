import 'package:kinos/models/items/images_models.dart';
import 'package:kinos/models/seerr/seerr_dashboard_model.dart';
import 'package:kinos/screens/shared/media_navigation.dart';
import 'package:kinos/seerr/seerr_models.dart';
import 'package:kinos/widgets/shared/frosted_surface.dart';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kinos/models/settings/home_row_model.dart';
import 'package:kinos/providers/user_provider.dart';
import 'package:kinos/providers/connectivity_provider.dart'
    show offlineStateProvider;
import 'package:kinos/providers/dashboard_provider.dart';
import 'package:kinos/providers/views_provider.dart';
import 'package:kinos/recommendations/engine/home_registry.dart';
import 'package:kinos/recommendations/seerr/discovery_models.dart';
import 'package:kinos/recommendations/seerr/discovery_providers.dart';
import 'package:kinos/recommendations/seerr/discovery_registry.dart';
import 'package:kinos/routes/auto_router.gr.dart';
import 'package:kinos/theme/app_theme.dart';
import 'package:kinos/util/localization_helper.dart';

class SeerrDiscoverySection extends ConsumerWidget {
  final HomeRowModel row;
  final EdgeInsets contentPadding;
  final String? mediaType;
  const SeerrDiscoverySection(
      {super.key,
      required this.row,
      required this.contentPadding,
      this.mediaType});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final account = ref.watch(userProvider);
    if (!row.enabled || account?.seerrCredentials?.isConfigured != true) {
      return const SliverToBoxAdapter(child: SizedBox.shrink());
    }
    final days =
        (int.tryParse(row.params['cacheDays'] ?? '') ?? 7).clamp(1, 30);
    final scope = (
      serverId: account!.credentials.serverId,
      userId: account.id,
      seerrUrl: discoveryServerUrl(account.seerrCredentials!.serverUrl),
      language: Localizations.localeOf(context).toLanguageTag(),
      cacheDays: days
    );
    return _DiscoveryResult(
        key: ValueKey((scope, mediaType)),
        scope: scope,
        padding: contentPadding,
        mediaType: mediaType);
  }
}

class _DiscoveryResult extends ConsumerStatefulWidget {
  final DiscoveryScope scope;
  final EdgeInsets padding;
  final String? mediaType;
  const _DiscoveryResult(
      {super.key, required this.scope, required this.padding, this.mediaType});
  @override
  ConsumerState<_DiscoveryResult> createState() => _DiscoveryResultState();
}

class _DiscoveryResultState extends ConsumerState<_DiscoveryResult> {
  static int _nextView = 0;
  final int _view = ++_nextView;
  bool _started = false;
  late final String _accountScope;
  StateController<({Object? owner, Set<String> ids})>? _registry;
  @override
  void initState() {
    super.initState();
    if (kDebugMode) debugPrint('[Seerr découverte] vue=$_view montée');
    _accountScope = discoveryAccountScope(
        widget.scope.serverId, widget.scope.userId, widget.scope.seerrUrl);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() => _started = true);
    });
  }

  @override
  void dispose() {
    if (kDebugMode) debugPrint('[Seerr découverte] vue=$_view démontée');
    final registry = _registry;
    // Provider mutations are forbidden during widget tree disposal.
    scheduleMicrotask(() {
      if (registry != null &&
          registry.mounted &&
          identical(registry.state.owner, this)) {
        registry.state = (owner: null, ids: const {});
      }
    });
    super.dispose();
  }

  void _publish(List<DiscoveryItem> items) {
    final registry = _registry;
    final ids = reserveIds(items, (item) => item.key.identity, reserve: 30);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || registry == null || !registry.mounted) return;
      if (registry.state.ids.length == ids.length &&
          registry.state.ids.containsAll(ids) &&
          identical(registry.state.owner, this)) {
        return;
      }
      registry.state = (owner: this, ids: ids);
    });
  }

  Future<void> _open(BuildContext origin, DiscoveryItem item) async {
    final image =
        (MediaNavigationScope.tagOf(origin) as MediaNavigationOrigin).image;
    final poster = SeerrDashboardPosterModel(
        id: item.key.identity,
        type: item.key.type == 'tv'
            ? SeerrMediaType.tvshow
            : SeerrMediaType.movie,
        tmdbId: item.key.id,
        title: item.title,
        overview: '',
        images: ImagesData(primary: image),
        mediaStatus: SeerrMediaStatus.unknown,
        jellyfinItemId: null,
        releaseYear: item.year?.toString());
    await pushMediaRoute(
        origin,
        SeerrDetailsRoute(
            poster: poster,
            tag: MediaNavigationScope.tagOf(origin),
            mediaType: item.key.type == 'tv' ? 'tvshow' : 'movie',
            tmdbId: item.key.id));
  }

  @override
  Widget build(BuildContext context) {
    if (!_started) return const SliverToBoxAdapter(child: SizedBox.shrink());
    ref.listen(offlineStateProvider, (previous, next) {
      if (kDebugMode) {
        debugPrint(
            '[Seerr découverte] vue=$_view connexion=${next ? 'hors ligne' : 'en ligne'}');
      }
    });
    ref.watch(discoveryRegistryProvider(_accountScope));
    _registry = ref.read(discoveryRegistryProvider(_accountScope).notifier);
    if (ref.watch(offlineStateProvider)) {
      _publish(const []);
      return const SliverToBoxAdapter(child: SizedBox.shrink());
    }
    final requested = ref.watch(discoveryRequestedProvider(_accountScope));
    final dashboard = ref.watch(dashboardProvider);
    final views = ref.watch(viewsProvider);
    final higher = <String>{
      ...requested,
      ...[
        ...dashboard.resumeVideo,
        ...dashboard.nextUp,
        ...views.dashboardViews.expand((view) => view.recentlyAdded)
      ].map(discoveryIdentityOf).whereType<String>(),
    };
    final value = ref.watch(seerrDiscoveryProvider(widget.scope));
    // Refreshing AsyncValue can carry old data: never display it while checking.
    final data = !value.isLoading && !value.hasError
        ? value.valueOrNull ?? <DiscoveryItem>[]
        : <DiscoveryItem>[];
    final items = excludeKnown(data, (item) => item.key.identity, higher)
        .where((item) =>
            widget.mediaType == null || item.key.type == widget.mediaType)
        .toList();
    _publish(items);
    if (items.isEmpty) {
      return const SliverToBoxAdapter(child: SizedBox.shrink());
    }
    return DiscoveryRowGrid(
        items: items, padding: widget.padding, onOpen: _open);
  }
}

/// Public rendering seam for keyboard, navigation and layout tests.
class DiscoveryRowGrid extends StatelessWidget {
  final List<DiscoveryItem> items;
  final EdgeInsets padding;
  final void Function(BuildContext, DiscoveryItem) onOpen;
  const DiscoveryRowGrid(
      {super.key,
      required this.items,
      required this.padding,
      required this.onOpen});
  @override
  Widget build(BuildContext context) {
    return SliverMainAxisGroup(slivers: [
      for (final type in ['movie', 'tv'])
        if (items.any((item) => item.key.type == type))
          SliverPadding(
            padding: padding.copyWith(top: AppSpacing.xl),
            sliver: SliverToBoxAdapter(
                child: _HorizontalDiscoveryRow(
              key: ValueKey(type),
              title: type == 'movie'
                  ? context.localized.discoveryMoviesTitle
                  : context.localized.discoverySeriesTitle,
              items: items
                  .where((item) => item.key.type == type)
                  .take(15)
                  .toList(),
              onOpen: onOpen,
            )),
          ),
    ]);
  }
}

class _HorizontalDiscoveryRow extends StatefulWidget {
  final List<DiscoveryItem> items;
  final String title;
  final void Function(BuildContext, DiscoveryItem) onOpen;
  const _HorizontalDiscoveryRow(
      {super.key,
      required this.title,
      required this.items,
      required this.onOpen});
  @override
  State<_HorizontalDiscoveryRow> createState() =>
      _HorizontalDiscoveryRowState();
}

class _HorizontalDiscoveryRowState extends State<_HorizontalDiscoveryRow> {
  final _scroll = ScrollController();
  final _nodes = List.generate(15, (_) => FocusNode());
  @override
  void dispose() {
    _scroll.dispose();
    for (final node in _nodes) {
      node.dispose();
    }
    super.dispose();
  }

  void _move(double delta) {
    if (_scroll.hasClients) {
      _scroll.jumpTo(
          (_scroll.offset + delta).clamp(0, _scroll.position.maxScrollExtent));
    }
  }

  @override
  Widget build(BuildContext context) =>
      LayoutBuilder(builder: (context, constraints) {
        final columns = context.tokens.density.columnsFor(constraints.maxWidth);
        final width =
            (constraints.maxWidth - AppSpacing.gridGap * (columns - 1)) /
                columns;
        final scaler = MediaQuery.textScalerOf(context);
        final captionHeight = scaler.scale(AppTypography.cardTitle.fontSize!) *
                AppTypography.cardTitle.height! +
            scaler.scale(AppTypography.meta.fontSize!) *
                AppTypography.meta.height! +
            AppSpacing.xs +
            AppSpacing.xxs;
        final height = (width - FocusRing.contentInset(context)) *
                AppMedia.posterHeightRatio +
            captionHeight +
            FocusRing.contentInset(context);
        return FocusTraversalGroup(
            policy: OrderedTraversalPolicy(),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(
                    child: Tooltip(
                        message: context.localized.discoveryShortcuts,
                        child: Text(widget.title,
                            style:
                                Theme.of(context).textTheme.headlineMedium))),
                for (final direction in [-1, 1])
                  FocusTraversalOrder(
                    order: NumericFocusOrder(direction < 0 ? 2 : 3),
                    child: FocusRing(
                      onActivate: () => _move(direction * constraints.maxWidth),
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
                      )),
                    ),
                  ),
              ]),
              const SizedBox(height: AppSpacing.sm),
              FocusTraversalOrder(
                  order: const NumericFocusOrder(1),
                  child: FocusTraversalGroup(
                    policy: WidgetOrderTraversalPolicy(),
                    child: Focus(
                        canRequestFocus: false,
                        onKeyEvent: (node, event) {
                          if (event is! KeyDownEvent &&
                              event is! KeyRepeatEvent) {
                            return KeyEventResult.ignored;
                          }
                          final current =
                              _nodes.indexWhere((node) => node.hasFocus);
                          if (current < 0) return KeyEventResult.ignored;
                          final rtl =
                              Directionality.of(context) == TextDirection.rtl;
                          final delta = event.logicalKey ==
                                  LogicalKeyboardKey.arrowRight
                              ? (rtl ? -1 : 1)
                              : event.logicalKey == LogicalKeyboardKey.arrowLeft
                                  ? (rtl ? 1 : -1)
                                  : 0;
                          final next = current + delta;
                          if (delta == 0 ||
                              next < 0 ||
                              next >= widget.items.length) {
                            return KeyEventResult.ignored;
                          }
                          _nodes[next].requestFocus();
                          final target = _nodes[next].context;
                          if (target != null) {
                            Scrollable.ensureVisible(target, alignment: 0.5);
                          }
                          return KeyEventResult.handled;
                        },
                        child: ScrollConfiguration(
                          behavior: ScrollConfiguration.of(context)
                              .copyWith(scrollbars: false),
                          child: SingleChildScrollView(
                            controller: _scroll,
                            physics: const NeverScrollableScrollPhysics(),
                            scrollDirection: Axis.horizontal,
                            child: Row(children: [
                              for (var index = 0;
                                  index < widget.items.length;
                                  index++)
                                Padding(
                                    padding: EdgeInsetsDirectional.only(
                                        end: index == widget.items.length - 1
                                            ? 0
                                            : AppSpacing.gridGap),
                                    child: SizedBox(
                                        width: width,
                                        height: height,
                                        child: _DiscoveryCard(
                                            item: widget.items[index],
                                            focusNode: _nodes[index],
                                            onOpen: (origin) => widget.onOpen(
                                                origin, widget.items[index])))),
                            ]),
                          ),
                        )),
                  )),
            ]));
      });
}

class _DiscoveryCard extends StatelessWidget {
  final DiscoveryItem item;
  final ValueChanged<BuildContext> onOpen;
  final FocusNode? focusNode;
  const _DiscoveryCard(
      {required this.item, required this.onOpen, this.focusNode});
  Future<void> _menu(BuildContext context, Offset? position) async {
    final box = context.findRenderObject() as RenderBox;
    final point = position ?? box.localToGlobal(Offset.zero);
    final chosen = await showGlassMenu<bool>(
        context: context,
        position: RelativeRect.fromLTRB(point.dx, point.dy, point.dx, point.dy),
        items: [
          PopupMenuItem(
              value: true, child: Text(context.localized.discoveryToRequest))
        ]);
    if (chosen == true && context.mounted) onOpen(context);
  }

  @override
  Widget build(BuildContext context) {
    final image = item.posterPath == null
        ? null
        : ImageData(
            path: 'https://image.tmdb.org/t/p/w500${item.posterPath}',
            key: item.key.identity);
    return MediaNavigation(
        key: ValueKey(item.key.identity),
        previewImage: image,
        focusNode: focusNode,
        builder: (context) => Semantics(
              button: true,
              label: '${item.title}, ${context.localized.discoveryToRequest}',
              child: CallbackShortcuts(
                  bindings: {
                    const SingleActivator(LogicalKeyboardKey.f10, shift: true):
                        () => _menu(context, null),
                    const SingleActivator(LogicalKeyboardKey.contextMenu): () =>
                        _menu(context, null),
                  },
                  child: GestureDetector(
                    onSecondaryTapDown: (details) =>
                        _menu(context, details.globalPosition),
                    child: FocusRing(
                        posterMotion: true,
                        focusNode: focusNode,
                        onActivate: () => onOpen(context),
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Expanded(
                                  child: ClipRRect(
                                      borderRadius: AppRadii.cardBorder,
                                      child: ColoredBox(
                                        color: AppColors.surface,
                                        child: MediaArtwork(
                                            child: image == null
                                                ? const Icon(
                                                    Icons.movie_outlined)
                                                : Image(
                                                    image: image.imageProvider,
                                                    fit: BoxFit.cover,
                                                    errorBuilder: (_, __,
                                                            ___) =>
                                                        const Icon(Icons
                                                            .movie_outlined),
                                                  )),
                                      ))),
                              const SizedBox(height: AppSpacing.xs),
                              Text(item.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: AppTypography.cardTitle),
                              const SizedBox(height: AppSpacing.xxs),
                              Row(children: [
                                Icon(Icons.add_rounded,
                                    size: AppTypography.meta.fontSize,
                                    color: AppColors.textSecondary),
                                const SizedBox(width: AppSpacing.xxs),
                                Expanded(
                                    child: Text(
                                        context.localized.discoveryToRequest,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: AppTypography.meta)),
                              ]),
                            ])),
                  )),
            ));
  }
}
