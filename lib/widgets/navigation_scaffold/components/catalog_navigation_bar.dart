import 'dart:async';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kinos/jellyfin/jellyfin_open_api.enums.swagger.dart';
import 'package:kinos/providers/dashboard/catalog_navigation_provider.dart';
import 'package:kinos/models/items/images_models.dart';
import 'package:kinos/providers/user_provider.dart';
import 'package:kinos/routes/auto_router.gr.dart';
import 'package:kinos/screens/shared/media_navigation.dart';
import 'package:kinos/seerr/seerr_models.dart';
import 'package:kinos/theme/app_theme.dart';
import 'package:kinos/util/adaptive_layout/adaptive_layout.dart';
import 'package:kinos/util/kinos_image.dart';
import 'package:kinos/widgets/shared/anchored_popover.dart';
import 'package:kinos/widgets/shared/frosted_surface.dart';

final _capsuleKey = GlobalKey(debugLabel: 'CatalogCapsule');

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
      if (route == DashboardRoute.name ||
          route == SeerrSearchRoute.name ||
          route == GenrePageRoute.name)
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
                key: _capsuleKey,
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
                      _CatalogSearchButton(
                          pageContext: context, anchorKey: _capsuleKey),
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

/// Pilote la recherche de la barre du haut depuis l'extérieur, pour que le
/// raccourci global (Ctrl K) ouvre le même champ que le bouton.
class CatalogSearchController {
  _CatalogSearchButtonState? _state;

  /// Vrai tant que la barre du haut, et donc son champ, est affichée.
  bool get isAttached => _state != null;
  // Différé à la fin de la frame : le raccourci peut arriver pendant une
  // mise en page en cours, où changer la taille du bouton est interdit.
  void open() {
    WidgetsBinding.instance.addPostFrameCallback((_) => _state?._activate());
    WidgetsBinding.instance.ensureVisualUpdate();
  }
}

final catalogSearchController = CatalogSearchController();

/// Ouvre la recherche rapide dans la barre du haut. Hors des écrans qui
/// l'affichent (fiches détail…), bascule sur la page de recherche de la
/// bibliothèque.
void showCatalogSearch(BuildContext context) {
  if (catalogSearchController.isAttached) {
    catalogSearchController.open();
  } else {
    context.router.push(LibrarySearchRoute());
  }
}

/// Bouton « Rechercher » de la barre du haut : activé, il devient lui-même
/// le champ de saisie, et les résultats pendent dessous dans un voile ancré.
class _CatalogSearchButton extends StatefulWidget {
  const _CatalogSearchButton(
      {required this.pageContext, required this.anchorKey});
  final BuildContext pageContext;

  /// La capsule entière : les résultats pendent sous son bord, alignés à
  /// droite, plutôt que sous le seul champ.
  final GlobalKey anchorKey;

  @override
  State<_CatalogSearchButton> createState() => _CatalogSearchButtonState();
}

class _CatalogSearchButtonState extends State<_CatalogSearchButton> {
  final _popover = AnchoredPopoverController();
  final _text = TextEditingController();
  final _buttonFocus = FocusNode(debugLabel: 'CatalogSearchButton');
  final _fieldFocus = FocusNode(debugLabel: 'CatalogSearchField');
  final _firstResultFocus = FocusNode(debugLabel: 'CatalogSearchFirstResult');
  Timer? _debounce;
  bool _active = false;
  bool _typing = false;
  String _query = '';

  @override
  void initState() {
    super.initState();
    catalogSearchController._state = this;
    _fieldFocus.addListener(_onFieldFocus);
  }

  @override
  void dispose() {
    if (catalogSearchController._state == this) {
      catalogSearchController._state = null;
    }
    _debounce?.cancel();
    _text.dispose();
    _buttonFocus.dispose();
    _fieldFocus.dispose();
    _firstResultFocus.dispose();
    super.dispose();
  }

  void _activate() {
    if (_active) {
      _fieldFocus.requestFocus();
      return;
    }
    setState(() => _active = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _active) _fieldFocus.requestFocus();
    });
  }

  /// Referme le champ. [restoreFocus] rend le focus au bouton — sauf
  /// quand on part vers une autre page, qui gère le sien.
  void _deactivate({bool restoreFocus = true}) {
    if (!_active) return;
    _debounce?.cancel();
    _text.clear();
    _popover.hide();
    setState(() {
      _active = false;
      _typing = false;
      _query = '';
    });
    if (restoreFocus) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _buttonFocus.canRequestFocus) {
          _buttonFocus.requestFocus();
        }
      });
    }
  }

  // Un champ vide qu'on quitte se referme ; un champ avec une saisie reste
  // ouvert tant que ses résultats ont le focus.
  void _onFieldFocus() {
    if (!_fieldFocus.hasFocus && _text.text.trim().isEmpty && _active) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && !_fieldFocus.hasFocus && _text.text.trim().isEmpty) {
          _deactivate(restoreFocus: false);
        }
      });
    }
  }

  void _changeQuery(String value) {
    _debounce?.cancel();
    final hasText = value.trim().isNotEmpty;
    setState(() => _typing = hasText);
    if (hasText) {
      _popover.show();
    } else {
      _popover.hide();
      setState(() => _query = '');
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 300), () {
      if (mounted) {
        setState(() {
          _query = value.trim();
          _typing = false;
        });
      }
    });
  }

  void _open(void Function(BuildContext page) navigate) {
    _deactivate(restoreFocus: false);
    if (widget.pageContext.mounted) navigate(widget.pageContext);
  }

  KeyEventResult _onFieldKey(FocusNode _, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    if (event.logicalKey == LogicalKeyboardKey.escape) {
      _deactivate();
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.arrowDown &&
        _firstResultFocus.context != null) {
      _firstResultFocus.requestFocus();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  // Pas d'AnimatedSize à durée nulle : Flutter le redessinerait pendant sa
  // propre mise en page. Sans mouvement (clavier, mouvement réduit), le
  // bouton change de taille d'un coup.
  Widget _animatedSize(bool motion, Widget child) => motion
      ? AnimatedSize(
          duration: AppDurations.popover,
          curve: AppMotion.easeOut,
          alignment: AlignmentDirectional.centerEnd,
          child: child)
      : child;

  @override
  Widget build(BuildContext context) {
    final motion = AppMotion.enabled(context);
    return AnchoredPopover(
      controller: _popover,
      manageFocus: false,
      gap: AppTopNavigation.searchPopoverGap,
      anchorKey: widget.anchorKey,
      unroll: true,
      preferredDirection: AxisDirection.down,
      alignEnd: true,
      constraints: BoxConstraints(
          minWidth: AppTopNavigation.searchPopoverWidth,
          maxWidth: AppTopNavigation.searchPopoverWidth,
          maxHeight: MediaQuery.sizeOf(context).height *
              AppTopNavigation.searchPopoverHeightFraction),
      // Échap ou un clic à côté des résultats referme tout le champ.
      onOpenChanged: (open) {
        if (!open && _text.text.trim().isNotEmpty) _deactivate();
      },
      popoverBuilder: (_, __) => _CatalogSearchResults(
        query: _query,
        typing: _typing,
        firstResultFocus: _firstResultFocus,
        onBackToField: _fieldFocus.requestFocus,
        onOpen: _open,
      ),
      child: _animatedSize(
        motion,
        _active
            ? Container(
                // Même hauteur que la loupe : la capsule ne bouge pas
                // verticalement et le voile s'ancre sous son bord.
                height: AppTopNavigation.searchControlHeight,
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.search, size: AppNavigation.iconSize),
                  const SizedBox(width: AppSpacing.xs),
                  SizedBox(
                    width: AppTopNavigation.searchFieldWidth,
                    child: Focus(
                      onKeyEvent: _onFieldKey,
                      skipTraversal: true,
                      child: TextField(
                        controller: _text,
                        focusNode: _fieldFocus,
                        onChanged: _changeQuery,
                        cursorColor: AppColors.textPrimary,
                        style: Theme.of(context).textTheme.bodyMedium,
                        textInputAction: TextInputAction.search,
                        // Un clic ailleurs referme un champ resté vide.
                        onTapOutside: (_) {
                          if (_text.text.trim().isEmpty) {
                            _deactivate(restoreFocus: false);
                          }
                        },
                        // Champ nu, posé dans la capsule : ni fond ni cadre
                        // du thème des champs, qui collaient au texte.
                        decoration: InputDecoration(
                            isDense: true,
                            filled: false,
                            contentPadding: EdgeInsets.zero,
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                            hintText: 'Rechercher un film ou une série…',
                            hintStyle: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(color: AppColors.textSecondary)),
                      ),
                    ),
                  ),
                  IconButton(
                      tooltip: 'Fermer · Échap',
                      visualDensity: VisualDensity.compact,
                      iconSize: AppNavigation.iconSize,
                      onPressed: _deactivate,
                      icon: const Icon(Icons.close)),
                ]),
              )
            : Tooltip(
                message: 'Rechercher · Ctrl K',
                child: FocusRing(
                    focusNode: _buttonFocus,
                    onActivate: _activate,
                    borderRadius: AppNavigation.border,
                    child: const Padding(
                        padding: EdgeInsets.all(AppSpacing.sm),
                        child: Icon(Icons.search,
                            size: AppNavigation.iconSize,
                            semanticLabel: 'Rechercher'))),
              ),
      ),
    );
  }
}

class _CatalogSearchResults extends ConsumerWidget {
  const _CatalogSearchResults({
    required this.query,
    required this.typing,
    required this.firstResultFocus,
    required this.onBackToField,
    required this.onOpen,
  });
  final String query;
  final bool typing;
  final FocusNode firstResultFocus;
  final VoidCallback onBackToField;
  final void Function(void Function(BuildContext page) navigate) onOpen;

  Widget _message(Widget child) => SizedBox(
      height: AppTopNavigation.searchPopoverEmptyHeight,
      child: Center(child: child));

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final search = (
      query: query,
      language: Localizations.localeOf(context).toLanguageTag()
    );
    if (typing || query.isEmpty) {
      return _message(const CircularProgressIndicator());
    }
    return ref.watch(quickSearchProvider(search)).when(
          loading: () => _message(const CircularProgressIndicator()),
          error: (_, __) => _message(TextButton(
              onPressed: () => ref.invalidate(quickSearchProvider(search)),
              child: const Text('Recherche indisponible · Réessayer'))),
          data: (found) => _list(context, found),
        );
  }

  Widget _list(BuildContext context, QuickSearchResults found) {
    final library = found.library;
    final outside = found.outside;
    if (library.isEmpty && outside.isEmpty) {
      return _message(const Text('Aucun résultat'));
    }
    var first = true;
    FocusNode? firstFocus() {
      if (!first) return null;
      first = false;
      return firstResultFocus;
    }

    // Flèche haut depuis le premier résultat : retour au champ.
    return Focus(
      skipTraversal: true,
      onKeyEvent: (_, event) {
        if (event is KeyDownEvent &&
            event.logicalKey == LogicalKeyboardKey.arrowUp &&
            firstResultFocus.hasFocus) {
          onBackToField();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.all(AppSpacing.xs),
        children: [
          if (library.isNotEmpty) ...[
            _header(context, 'Dans la bibliothèque', first: true),
            for (final item in library)
              _row(
                context,
                focusNode: firstFocus(),
                image: item.getPosters?.primary,
                title: item.title,
                subtitle: item.subText ?? '',
                onActivate: () => onOpen(item.navigateTo),
              ),
            if (library.length >= 24)
              TextButton(
                  onPressed: () => onOpen((page) => page.router
                      .push(LibrarySearchRoute(query: query, recursive: true))),
                  child: const Text('Voir tous les résultats')),
          ],
          if (outside.isNotEmpty) ...[
            _header(context, 'À demander', first: library.isEmpty),
            for (final poster in outside)
              _row(
                context,
                focusNode: firstFocus(),
                image: poster.images.primary,
                title: poster.title,
                subtitle: [
                  poster.type == SeerrMediaType.tvshow ? 'Série' : 'Film',
                  if (poster.releaseYear case final year?) year,
                  if (poster.hasDisplayStatus)
                    poster.displayStatusLabel(context),
                ].join(' · '),
                onActivate: () => onOpen((page) => pushMediaRoute(
                    page,
                    SeerrDetailsRoute(
                      tag: MediaNavigationScope.tagOf(page),
                      mediaType: poster.type == SeerrMediaType.tvshow
                          ? 'tvshow'
                          : 'movie',
                      tmdbId: poster.tmdbId,
                      poster: poster,
                    ))),
              ),
          ],
        ],
      ),
    );
  }

  Widget _header(BuildContext context, String label, {required bool first}) =>
      Padding(
        padding: EdgeInsets.fromLTRB(
            AppSpacing.xs,
            first ? AppSpacing.xxs : AppSpacing.sm,
            AppSpacing.xs,
            AppSpacing.xxs),
        child: Text(label,
            style: Theme.of(context)
                .textTheme
                .labelMedium
                ?.copyWith(color: AppColors.textSecondary)),
      );

  Widget _row(
    BuildContext context, {
    required FocusNode? focusNode,
    required ImageData? image,
    required String title,
    required String subtitle,
    required VoidCallback onActivate,
  }) =>
      Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.xxs),
        child: FocusRing(
          focusNode: focusNode,
          onActivate: onActivate,
          child: Padding(
              padding: const EdgeInsets.all(AppSpacing.xs),
              child: Row(children: [
                SizedBox(
                    width: AppTopNavigation.resultPosterWidth,
                    height: AppTopNavigation.resultPosterWidth *
                        AppMedia.posterHeightRatio,
                    child: ClipRRect(
                        borderRadius: AppRadii.cardBorder,
                        child: KinosImage(image: image, fit: BoxFit.cover))),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
                      Text(subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodySmall),
                    ])),
              ])),
        ),
      );
}
