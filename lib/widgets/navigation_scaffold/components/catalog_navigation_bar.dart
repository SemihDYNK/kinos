import 'dart:async';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kinos/jellyfin/jellyfin_open_api.enums.swagger.dart';
import 'package:kinos/providers/dashboard/catalog_navigation_provider.dart';
import 'package:kinos/providers/user_provider.dart';
import 'package:kinos/routes/auto_router.gr.dart';
import 'package:kinos/screens/shared/outlined_text_field.dart';
import 'package:kinos/seerr/seerr_models.dart';
import 'package:kinos/theme/app_theme.dart';
import 'package:kinos/util/adaptive_layout/adaptive_layout.dart';
import 'package:kinos/util/kinos_image.dart';
import 'package:kinos/widgets/shared/frosted_surface.dart';

class CatalogNavigationBar extends ConsumerWidget {
  const CatalogNavigationBar({required this.child, super.key});
  final Widget child;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final route = context.router.current.name;
    final visible = !{
      DetailsRoute.name,
      SeerrDetailsRoute.name,
      ArrTitleDetailsRoute.name,
      PhotoViewerRoute.name,
      LiveTvRoute.name,
    }.contains(route);
    if (!visible) return child;
    final scope = ref.watch(catalogScopeProvider);
    final configured = ref.watch(userProvider
        .select((user) => user?.seerrCredentials?.isConfigured ?? false));
    void select(CatalogScope value) {
      ref.read(catalogScopeProvider.notifier).state = value;
      context.router.navigate(const DashboardRoute());
    }

    Widget tab(String label, bool active, VoidCallback action) => FocusRing(
          onActivate: action,
          borderRadius: AppNavigation.selection,
          child: SizedBox(
            height: AppNavigation.rowHeight,
            child: Stack(alignment: Alignment.center, children: [
              Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                  child: Text(label,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          color: active
                              ? AppColors.textPrimary
                              : AppColors.textPrimary.withValues(alpha: .75)))),
            ]),
          ),
        );
    return Stack(children: [
      if (route == DashboardRoute.name || route == SeerrSearchRoute.name)
        child
      else if ({
        LibrarySearchRoute.name,
        ArrHomeRoute.name,
        SeerrRoute.name,
        SettingsRoute.name
      }.contains(route))
        AdaptiveLayout(
          data: AdaptiveLayout.of(context).copyWith(
              topBarHeight: AdaptiveLayout.of(context).topBarHeight +
                  AppTopNavigation.contentInset),
          child: child,
        )
      else
        Padding(
            padding: const EdgeInsets.only(top: AppTopNavigation.contentInset),
            child: child),
      PositionedDirectional(
        start: AppSpacing.screenPadding,
        end: AppSpacing.screenPadding,
        top: MediaQuery.paddingOf(context).top + AppSpacing.sm,
        child: Align(
            alignment: Alignment.topCenter,
            child: FrostedSurface(
                color: AppNavigation.surface,
                borderRadius: AppNavigation.border,
                child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.xs, vertical: AppSpacing.xxs),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Flexible(
                          child: SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: _CatalogTabs(
                                  activeIndex: route == DashboardRoute.name
                                      ? scope == allCatalog
                                          ? 0
                                          : scope.libraryId == null &&
                                                  scope.kind ==
                                                      BaseItemKind.movie
                                              ? 1
                                              : scope.libraryId == null &&
                                                      scope.kind ==
                                                          BaseItemKind.series
                                                  ? 2
                                                  : null
                                      : configured &&
                                              route == SeerrSearchRoute.name
                                          ? 3
                                          : null,
                                  children: [
                                    tab(
                                        'À la une',
                                        route == DashboardRoute.name &&
                                            scope == allCatalog,
                                        () => select(allCatalog)),
                                    tab(
                                        'Films',
                                        route == DashboardRoute.name &&
                                            scope.kind == BaseItemKind.movie &&
                                            scope.libraryId == null,
                                        () => select((
                                              kind: BaseItemKind.movie,
                                              libraryId: null
                                            ))),
                                    tab(
                                        'Séries',
                                        route == DashboardRoute.name &&
                                            scope.kind == BaseItemKind.series &&
                                            scope.libraryId == null,
                                        () => select((
                                              kind: BaseItemKind.series,
                                              libraryId: null
                                            ))),
                                    if (configured)
                                      tab(
                                          'Découvrir',
                                          route == SeerrSearchRoute.name,
                                          () => context.router.navigate(
                                              SeerrSearchRoute(
                                                  mode:
                                                      SeerrSearchMode.search))),
                                  ]))),
                      const SizedBox(width: AppSpacing.xs),
                      FocusRing(
                          onActivate: () => showCatalogSearch(context),
                          borderRadius: AppNavigation.border,
                          child: Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: AppSpacing.md,
                                  vertical: AppSpacing.sm),
                              child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.search,
                                        size: AppNavigation.iconSize),
                                    if (MediaQuery.sizeOf(context).width >=
                                        AppTopNavigation.fullSearchWidth) ...[
                                      const SizedBox(width: AppSpacing.xs),
                                      const Text('Rechercher'),
                                      const SizedBox(width: AppSpacing.lg),
                                      Text('Ctrl K',
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodySmall),
                                    ],
                                  ]))),
                    ])))),
      ),
    ]);
  }
}

class _CatalogTabs extends StatefulWidget {
  const _CatalogTabs({required this.activeIndex, required this.children});
  final int? activeIndex;
  final List<Widget> children;
  @override
  State<_CatalogTabs> createState() => _CatalogTabsState();
}

class _CatalogTabsState extends State<_CatalogTabs> {
  final _rowKey = GlobalKey();
  final _tabKeys = <GlobalKey>[];
  double? _indicatorX;

  void _measure() {
    if (!mounted) return;
    final index = widget.activeIndex;
    if (index == null || index >= _tabKeys.length) return;
    final row = _rowKey.currentContext?.findRenderObject() as RenderBox?;
    final tab =
        _tabKeys[index].currentContext?.findRenderObject() as RenderBox?;
    if (row == null || tab == null || !row.hasSize || !tab.hasSize) return;
    final x =
        tab.localToGlobal(Offset(tab.size.width / 2, 0), ancestor: row).dx -
            AppSpacing.lg / 2;
    if (_indicatorX == null || (x - _indicatorX!).abs() > .01) {
      setState(() => _indicatorX = x);
    }
  }

  @override
  Widget build(BuildContext context) {
    while (_tabKeys.length < widget.children.length) {
      _tabKeys.add(GlobalKey());
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => _measure());
    return Stack(children: [
      Row(key: _rowKey, mainAxisSize: MainAxisSize.min, children: [
        for (var i = 0; i < widget.children.length; i++)
          KeyedSubtree(key: _tabKeys[i], child: widget.children[i]),
      ]),
      if (_indicatorX != null && widget.activeIndex != null)
        Positioned(
          left: 0,
          bottom: AppSpacing.xxs,
          child: IgnorePointer(
              child: TweenAnimationBuilder<double>(
            tween: Tween(end: _indicatorX!),
            duration: AppMotion.enabled(context)
                ? AppDurations.navigationSelection
                : Duration.zero,
            curve: AppMotion.navigationReveal,
            child: const SizedBox(
                key: ValueKey('catalog-active-indicator'),
                height: AppTopNavigation.indicatorHeight,
                width: AppSpacing.lg,
                child: ColoredBox(color: AppColors.textPrimary)),
            builder: (_, x, child) =>
                Transform.translate(offset: Offset(x, 0), child: child),
          )),
        ),
    ]);
  }
}

Future<void> showCatalogSearch(BuildContext context) => showDialog<void>(
      context: context,
      builder: (_) => AdaptiveLayout(
          data: AdaptiveLayout.of(context),
          child: _CatalogSearch(pageContext: context)),
    );

class _CatalogSearch extends ConsumerStatefulWidget {
  const _CatalogSearch({required this.pageContext});
  final BuildContext pageContext;
  @override
  ConsumerState<_CatalogSearch> createState() => _CatalogSearchState();
}

class _CatalogSearchState extends ConsumerState<_CatalogSearch> {
  Timer? _debounce;
  final _inputFocus = FocusNode();
  final _firstResultFocus = FocusNode();
  String _query = '';
  bool _typing = false;

  @override
  void dispose() {
    _debounce?.cancel();
    _inputFocus.dispose();
    _firstResultFocus.dispose();
    super.dispose();
  }

  void _changeQuery(String value) {
    _debounce?.cancel();
    setState(() => _typing = true);
    _debounce = Timer(const Duration(milliseconds: 300), () {
      if (mounted) {
        setState(() {
          _query = value.trim();
          _typing = false;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) => Focus(
        onKeyEvent: (_, event) {
          if (event is KeyDownEvent &&
              event.logicalKey == LogicalKeyboardKey.arrowDown &&
              _inputFocus.hasFocus &&
              _firstResultFocus.context != null) {
            _firstResultFocus.requestFocus();
            return KeyEventResult.handled;
          }
          return KeyEventResult.ignored;
        },
        child: Shortcuts(
          shortcuts: const {
            SingleActivator(LogicalKeyboardKey.escape): DismissIntent()
          },
          child: Actions(
            actions: {
              DismissIntent: CallbackAction<DismissIntent>(onInvoke: (_) {
                Navigator.of(context).pop();
                return null;
              })
            },
            child: GlassDialog(
              alignment: Alignment.topCenter,
              constraints: const BoxConstraints(
                  maxWidth: AppTopNavigation.searchPanelWidth),
              insetPadding: EdgeInsets.fromLTRB(
                  AppSpacing.lg,
                  MediaQuery.paddingOf(context).top + AppSpacing.xxl,
                  AppSpacing.lg,
                  AppSpacing.lg),
              child: SizedBox(
                height: MediaQuery.sizeOf(context).height *
                    AppTopNavigation.searchHeightFraction,
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(children: [
                          Expanded(
                              child: OutlinedTextField(
                                  autoFocus: true,
                                  focusNode: _inputFocus,
                                  placeHolder:
                                      'Rechercher un film ou une série…',
                                  onChanged: _changeQuery)),
                          IconButton(
                              tooltip: 'Fermer · Échap',
                              onPressed: () => Navigator.of(context).pop(),
                              icon: const Icon(Icons.close)),
                        ]),
                        const SizedBox(height: AppSpacing.md),
                        Expanded(child: _results()),
                      ]),
                ),
              ),
            ),
          ),
        ),
      );

  Widget _results() {
    final results = ref.watch(quickSearchProvider(_query));
    if (_typing) return const Center(child: CircularProgressIndicator());
    if (_query.isEmpty) {
      return const Center(child: Text('Recherchez dans vos films et séries'));
    }
    return results.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, __) => Center(
          child: TextButton(
              onPressed: () => ref.invalidate(quickSearchProvider(_query)),
              child: const Text('Recherche indisponible · Réessayer'))),
      data: (items) => items.isEmpty
          ? const Center(child: Text('Aucun résultat'))
          : ListView.separated(
              itemCount: items.length + (items.length >= 24 ? 1 : 0),
              separatorBuilder: (_, __) =>
                  const SizedBox(height: AppSpacing.xs),
              itemBuilder: (context, index) {
                if (index == items.length) {
                  return TextButton(
                      onPressed: () {
                        Navigator.of(context).pop();
                        if (widget.pageContext.mounted) {
                          widget.pageContext.router.push(LibrarySearchRoute(
                              query: _query, recursive: true));
                        }
                      },
                      child: const Text('Voir tous les résultats'));
                }
                final item = items[index];
                return FocusRing(
                  focusNode: index == 0 ? _firstResultFocus : null,
                  onActivate: () {
                    Navigator.of(context).pop();
                    if (widget.pageContext.mounted) {
                      item.navigateTo(widget.pageContext);
                    }
                  },
                  child: Padding(
                      padding: const EdgeInsets.all(AppSpacing.xs),
                      child: Row(children: [
                        SizedBox(
                            width: AppTopNavigation.resultPosterWidth,
                            height: AppTopNavigation.resultPosterWidth *
                                AppMedia.posterHeightRatio,
                            child: ClipRRect(
                                borderRadius: AppRadii.cardBorder,
                                child: KinosImage(
                                    image: item.getPosters?.primary,
                                    fit: BoxFit.cover))),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                              Text(item.title,
                                  maxLines: 1, overflow: TextOverflow.ellipsis),
                              Text(item.subText ?? '',
                                  style: Theme.of(context).textTheme.bodySmall),
                            ])),
                      ])),
                );
              },
            ),
    );
  }
}
