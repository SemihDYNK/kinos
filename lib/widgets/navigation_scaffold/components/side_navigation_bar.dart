import 'package:kinos/theme/app_icons.dart';
import 'package:kinos/screens/shared/kinos_icon.dart';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show OverflowBoxFit;

import 'package:auto_route/auto_route.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:kinos/models/account_model.dart';
import 'package:kinos/models/view_model.dart';
import 'package:kinos/jellyfin/jellyfin_open_api.enums.swagger.dart';
import 'package:kinos/providers/views_provider.dart';
import 'package:kinos/models/media_playback_model.dart';
import 'package:kinos/providers/settings/client_settings_provider.dart';
import 'package:kinos/providers/dashboard/catalog_navigation_provider.dart';
import 'package:kinos/providers/user_provider.dart';
import 'package:kinos/providers/video_player_provider.dart';
import 'package:kinos/routes/auto_router.dart';
import 'package:kinos/routes/auto_router.gr.dart';
import 'package:kinos/screens/shared/user_icon.dart';
import 'package:kinos/theme/app_theme.dart';
import 'package:kinos/util/adaptive_layout/adaptive_layout.dart';
import 'package:kinos/util/localization_helper.dart';
import 'package:kinos/widgets/navigation_scaffold/components/navigation_body.dart';

/// Cible d'échappement clavier depuis le contenu : GridFocusTraveler et
/// FocusRow y renvoient le focus quand on sort par la gauche (flèche
/// gauche depuis le bord d'une grille ou d'une rangée). Rattachée ici à
/// l'item actif de la barre — cf. [SideNavigationRail._railItems].
final navBarNode = FocusNode();

/// Repli forcé de la barre pendant la lecture, indépendant du réglage
/// persisté ([ClientSettingsModel.expandSideBar]).
///
/// Entièrement dérivé de [mediaPlaybackProvider] plutôt que basculé à la
/// main : redevient faux exactement quand l'état repasse à
/// [VideoPlayerState.disposed] (lecture réellement quittée), jamais avant —
/// donc jamais en `minimized` (lecture réduite, barre flottante) ni en
/// `fullScreen`. C'est ce qui garantit qu'elle ne réapparaît pas tant qu'on
/// n'a pas quitté la lecture. Couvre aussi le lecteur audio plein écran, qui
/// partage le même état : effet de bord accepté plutôt que dupliquer le
/// mécanisme pour un cas hors périmètre (cf. CLAUDE.md § Périmètre).
final sideBarForceCollapsedProvider = Provider<bool>((ref) {
  final state = ref.watch(mediaPlaybackProvider.select((value) => value.state));
  return state != VideoPlayerState.disposed;
});

class _RailDestination {
  final String label;
  final IconData icon;
  final IconData selectedIcon;
  final bool selected;
  final VoidCallback onTap;
  const _RailDestination({
    required this.label,
    required this.icon,
    required this.selectedIcon,
    required this.selected,
    required this.onTap,
  });
}

/// Barre latérale de navigation.
///
/// Ce n'est pas une colonne séparée : le contenu est peint plein cadre en
/// dessous ([AdaptiveLayout] y reporte la largeur courante via
/// `sideBarWidth` réserve l'espace des commandes du contenu). La capsule
/// graphite flotte sur le fond plein cadre, sans colonne opaque derrière.
class SideNavigationRail extends ConsumerWidget {
  final Widget child;
  const SideNavigationRail({required this.child, super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textDirection = Directionality.of(context);

    final persistedExpanded = ref
        .watch(clientSettingsProvider.select((value) => value.expandSideBar));
    final forceCollapsed = ref.watch(sideBarForceCollapsedProvider);
    final expanded = persistedExpanded && !forceCollapsed;

    final safePadding = MediaQuery.paddingOf(context);
    final directionalPadding = EdgeInsetsDirectional.fromSTEB(
      safePadding.left,
      safePadding.top,
      safePadding.right,
      safePadding.bottom,
    ).resolve(textDirection);
    final startInset = directionalPadding.left;

    final layout = AdaptiveLayout.of(context);

    final fullScreenChildRoute =
        fullScreenRoutes.contains(context.router.current.name);

    final seerrAvailable = ref.watch(userProvider
        .select((value) => value?.seerrCredentials?.isConfigured ?? false));
    final user = ref.watch(userProvider);

    final destinations = _railDestinations(
      context: context,
      seerrAvailable: seerrAvailable,
      views: ref
          .watch(viewsProvider)
          .views
          .where((view) => {CollectionType.movies, CollectionType.tvshows}
              .contains(view.collectionType))
          .toList(),
    );
    // navBarNode doit toujours pouvoir reprendre le focus : rattaché à
    // l'item actif, ou au premier par défaut si aucun ne correspond à la
    // route courante (ex. réglages, panneau de contrôle hors "Gestion").
    final navBarNodeIndex = destinations
        .indexWhere((d) => d.selected)
        .clamp(0, destinations.length - 1);

    return TweenAnimationBuilder<double>(
      tween: Tween(end: expanded ? 1 : 0),
      duration: !AppMotion.enabled(context)
          ? Duration.zero
          : expanded
              ? AppDurations.navigationExpand
              : AppDurations.navigationCollapse,
      curve: AppMotion.navigationReveal,
      child: child,
      builder: (context, progress, content) {
        final animatedWidth = AppNavigation.collapsedWidth +
            (AppNavigation.expandedWidth - AppNavigation.collapsedWidth) *
                progress +
            startInset +
            AppNavigation.inset * 2;
        return Stack(
          children: [
            AdaptiveLayout(
              data: layout.copyWith(sideBarWidth: animatedWidth),
              child: content!,
            ),
            Positioned.fill(
              child: Align(
                alignment: AlignmentDirectional.centerStart,
                child: AnimatedOpacity(
                  duration: !AppMotion.enabled(context)
                      ? Duration.zero
                      : AppDurations.pageTransition,
                  opacity: fullScreenChildRoute ? 0 : 1,
                  child: IgnorePointer(
                    ignoring: fullScreenChildRoute,
                    child: FocusTraversalGroup(
                      policy: _RailTraversalPolicy(),
                      child: SizedBox(
                        width: animatedWidth,
                        child: Padding(
                          padding: EdgeInsetsDirectional.only(
                            start: startInset + AppNavigation.inset,
                            end: AppNavigation.inset,
                            top: directionalPadding.top + AppNavigation.inset,
                            bottom:
                                directionalPadding.bottom + AppNavigation.inset,
                          ),
                          child: ClipRRect(
                            borderRadius: AppNavigation.border,
                            child: BackdropFilter(
                              enabled: !MediaQuery.highContrastOf(context),
                              filter: ui.ImageFilter.blur(
                                  sigmaX: AppNavigation.blurSigma,
                                  sigmaY: AppNavigation.blurSigma),
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  color: MediaQuery.highContrastOf(context)
                                      ? AppColors.surface
                                      : AppNavigation.surface,
                                  borderRadius: AppNavigation.border,
                                  border: Border.all(
                                      color: AppNavigation.glassBorder,
                                      width: AppNavigation.borderWidth),
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                      vertical: AppSpacing.xs),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      Padding(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: AppSpacing.xs,
                                            vertical: AppSpacing.xs),
                                        child: FocusRing(
                                          borderRadius: AppNavigation.selection,
                                          onActivate: () {
                                            ref
                                                .read(catalogScopeProvider
                                                    .notifier)
                                                .state = allCatalog;
                                            context.router.navigate(
                                                const DashboardRoute());
                                          },
                                          child: SizedBox(
                                            height: AppNavigation.rowHeight,
                                            child: Center(
                                                child: AnimatedSwitcher(
                                                    duration: AppMotion.enabled(
                                                            context)
                                                        ? AppDurations
                                                            .navigationSelection
                                                        : Duration.zero,
                                                    child: expanded
                                                        ? const KinosWordmark()
                                                        : const KinosIcon(
                                                            size: AppBrand
                                                                .markSize))),
                                          ),
                                        ),
                                      ),
                                      Padding(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: AppSpacing.xs,
                                            vertical: AppSpacing.xxs),
                                        child: _RailHint(
                                          message: expanded
                                              ? 'Réduire la barre'
                                              : 'Déployer la barre',
                                          child: FocusRing(
                                            borderRadius:
                                                AppNavigation.selection,
                                            onActivate: () => ref
                                                .read(clientSettingsProvider
                                                    .notifier)
                                                .toggleSideBar(),
                                            child: _RailRow(
                                              icon: expanded
                                                  ? Icons.chevron_left
                                                  : Icons.chevron_right,
                                              label: expanded
                                                  ? 'Réduire'
                                                  : 'Déployer',
                                              selected: false,
                                              expansion: progress,
                                            ),
                                          ),
                                        ),
                                      ),
                                      const _RailDivider(),
                                      Flexible(
                                          child: SingleChildScrollView(
                                              child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        crossAxisAlignment:
                                            CrossAxisAlignment.stretch,
                                        children: [
                                          for (var i = 0;
                                              i < destinations.length;
                                              i++)
                                            Padding(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: AppSpacing.xs,
                                                      vertical: 2),
                                              child: _RailHint(
                                                message: destinations[i].label,
                                                child: Semantics(
                                                  label: destinations[i].label,
                                                  selected:
                                                      destinations[i].selected,
                                                  button: true,
                                                  child: FocusRing(
                                                    borderRadius:
                                                        AppNavigation.selection,
                                                    focusNode:
                                                        i == navBarNodeIndex
                                                            ? navBarNode
                                                            : null,
                                                    onActivate:
                                                        destinations[i].onTap,
                                                    child: _RailRow(
                                                      icon: destinations[i]
                                                              .selected
                                                          ? destinations[i]
                                                              .selectedIcon
                                                          : destinations[i]
                                                              .icon,
                                                      label:
                                                          destinations[i].label,
                                                      selected: destinations[i]
                                                          .selected,
                                                      expansion: progress,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ),
                                        ],
                                      ))),
                                      const _RailDivider(),
                                      Padding(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: AppSpacing.xs,
                                            vertical: 2),
                                        child: _RailHint(
                                          message: context.localized.settings,
                                          child: FocusRing(
                                            borderRadius:
                                                AppNavigation.selection,
                                            onActivate: () =>
                                                _openSettings(context),
                                            child: _RailRow(
                                              icon: AppIcons.settings,
                                              label: context.localized.settings,
                                              selected: context
                                                  .router.current.name
                                                  .contains('Settings'),
                                              expansion: progress,
                                            ),
                                          ),
                                        ),
                                      ),
                                      Padding(
                                        padding: const EdgeInsets.fromLTRB(
                                            AppSpacing.xs,
                                            AppSpacing.sm,
                                            AppSpacing.xs,
                                            AppSpacing.sm),
                                        child: _RailHint(
                                          message: context.localized.switchUser,
                                          child: FocusRing(
                                            borderRadius:
                                                AppNavigation.selection,
                                            onActivate: () =>
                                                _switchProfile(context, ref),
                                            child: _ProfileRow(
                                                user: user,
                                                expansion: progress),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  void _openSettings(BuildContext context) {
    if (AdaptiveLayout.layoutModeOf(context) == LayoutMode.single) {
      context.router.push(const SettingsRoute());
    } else {
      context.router.push(const ClientSettingsRoute());
    }
  }

  /// Bibliothèques du serveur, puis Demandes et Arr. Les accueils sont en haut.
  List<_RailDestination> _railDestinations({
    required BuildContext context,
    required bool seerrAvailable,
    required List<ViewModel> views,
  }) {
    final currentRouteName = context.router.current.name;
    final args = context.router.current.args;
    return [
      for (final view in views)
        _RailDestination(
          label: view.name,
          icon: view.collectionType == CollectionType.movies
              ? AppIcons.films
              : AppIcons.series,
          selectedIcon: view.collectionType == CollectionType.movies
              ? AppIcons.filmsSelected
              : AppIcons.seriesSelected,
          selected: currentRouteName == LibrarySearchRoute.name &&
              args is LibrarySearchRouteArgs &&
              (args.parentId?.contains(view.id) ?? false),
          onTap: () => view.navigateToView(context),
        ),
      if (seerrAvailable)
        _RailDestination(
          label: 'Demandes',
          icon: AppIcons.requests,
          selectedIcon: AppIcons.requestsSelected,
          selected: currentRouteName == SeerrRoute.name,
          onTap: () => context.router.navigate(const SeerrRoute()),
        ),
      _RailDestination(
        label: 'Arr',
        icon: AppIcons.activity,
        selectedIcon: AppIcons.activitySelected,
        selected: currentRouteName.startsWith('Arr'),
        onTap: () => context.router.push(const ArrHomeRoute()),
      ),
    ];
  }

  Future<void> _switchProfile(BuildContext context, WidgetRef ref) async {
    await ref.read(userProvider.notifier).logoutUser();
    if (context.mounted) context.router.replaceAll([LoginRoute()]);
  }
}

class _RailDivider extends StatelessWidget {
  const _RailDivider();

  @override
  Widget build(BuildContext context) => const Divider(
        height: AppSpacing.lg,
        thickness: AppNavigation.borderWidth,
        indent: AppSpacing.md,
        endIndent: AppSpacing.md,
        color: AppNavigation.glassBorder,
      );
}

/// Le même libellé est disponible à la souris, au clavier et au lecteur d'écran.
class _RailHint extends StatefulWidget {
  const _RailHint({required this.message, required this.child});
  final String message;
  final Widget child;

  @override
  State<_RailHint> createState() => _RailHintState();
}

class _RailHintState extends State<_RailHint> {
  final _tooltip = GlobalKey<TooltipState>();
  final _focus = FocusNode(canRequestFocus: false);

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Focus(
        focusNode: _focus,
        onFocusChange: (focused) {
          if (focused) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted && _focus.hasFocus) {
                _tooltip.currentState?.ensureTooltipVisible();
              }
            });
          } else {
            Tooltip.dismissAllToolTips();
          }
        },
        child: Tooltip(
            key: _tooltip, message: widget.message, child: widget.child),
      );
}

/// Icône (+ libellé en mode déplié) d'un item de la barre. L'indicateur
/// d'item actif — fond `surfaceHigh` et icône `textPrimary` — reste le même
/// dans les deux états ; le liseré vertical, lui, n'a de sens qu'avec un
/// libellé à côté, donc seulement en mode déplié.
class _RailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final double expansion;
  const _RailRow(
      {required this.icon,
      required this.label,
      required this.selected,
      required this.expansion});

  @override
  Widget build(BuildContext context) {
    final foreground =
        selected ? AppColors.textPrimary : AppColors.textSecondary;
    return ConstrainedBox(
      constraints: BoxConstraints(
          minHeight: AppNavigation.rowHeight * context.tokens.density.scale),
      child: AnimatedContainer(
        duration: AppMotion.enabled(context)
            ? AppDurations.navigationSelection
            : Duration.zero,
        curve: AppMotion.navigationReveal,
        decoration: BoxDecoration(
          color: selected ? AppColors.surfaceHover : Colors.transparent,
          borderRadius: AppNavigation.selection,
        ),
        padding: const EdgeInsets.all(AppSpacing.xs),
        child: Row(children: [
          SizedBox(
              width: AppNavigation.collapsedWidth -
                  AppSpacing.xs * 4 -
                  FocusRing.boxInset(context),
              child: Center(
                  child: Icon(icon,
                      color: foreground, size: AppNavigation.iconSize))),
          _RailLabel(label: label, expansion: expansion, color: foreground),
        ]),
      ),
    );
  }
}

class _RailLabel extends StatelessWidget {
  const _RailLabel(
      {required this.label,
      required this.expansion,
      required this.color,
      this.maxLines = 2});
  final String label;
  final double expansion;
  final Color color;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    final reveal =
        AppMotion.navigationLabels.transform(expansion.clamp(0.0, 1.0));
    return Expanded(
        child: expansion == 0
            ? const SizedBox.shrink()
            : ClipRect(
                child: Align(
                  alignment: AlignmentDirectional.centerStart,
                  heightFactor: expansion,
                  child: OverflowBox(
                    alignment: AlignmentDirectional.centerStart,
                    fit: OverflowBoxFit.deferToChild,
                    minWidth: AppNavigation.expandedWidth -
                        AppNavigation.collapsedWidth,
                    maxWidth: AppNavigation.expandedWidth -
                        AppNavigation.collapsedWidth,
                    child: Opacity(
                        opacity: reveal,
                        child: Transform.translate(
                          offset: Offset(
                              (Directionality.of(context) == TextDirection.rtl
                                      ? -1
                                      : 1) *
                                  AppSpacing.xs *
                                  (1 - reveal),
                              0),
                          child: Padding(
                              padding: const EdgeInsetsDirectional.only(
                                  start: AppSpacing.sm),
                              child: Text(label,
                                  maxLines: maxLines,
                                  overflow: TextOverflow.ellipsis,
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodyMedium
                                      ?.copyWith(color: color))),
                        )),
                  ),
                ),
              ));
  }
}

class _ProfileRow extends StatelessWidget {
  final AccountModel? user;
  final double expansion;
  const _ProfileRow({required this.user, required this.expansion});

  @override
  Widget build(BuildContext context) => Row(children: [
        SizedBox(
            width: AppNavigation.collapsedWidth -
                AppSpacing.xs * 2 -
                FocusRing.boxInset(context),
            child: Center(
                child: SizedBox.square(
              dimension: AppNavigation.avatarSize,
              child: UserIcon(
                  user: user, cornerRadius: AppNavigation.avatarSize / 2),
            ))),
        _RailLabel(
            label: user?.name ?? '',
            expansion: expansion,
            color: AppColors.textPrimary,
            maxLines: 1),
      ]);
}

/// Parcours haut/bas au clavier au sein de la barre, et sortie vers le
/// contenu (flèche vers le sens de lecture) — cf. [GridFocusTravelerPolicy]
/// côté contenu pour le trajet inverse (flèche gauche depuis le bord d'une
/// grille, qui renvoie sur [navBarNode]).
class _RailTraversalPolicy extends ReadingOrderTraversalPolicy {
  _RailTraversalPolicy();

  @override
  bool inDirection(FocusNode currentNode, TraversalDirection direction) {
    final isRtl = Directionality.of(currentNode.context!) == TextDirection.rtl;
    final toMainDirection =
        isRtl ? TraversalDirection.left : TraversalDirection.right;
    final awayFromMainDirection =
        isRtl ? TraversalDirection.right : TraversalDirection.left;

    if (direction == awayFromMainDirection) {
      return false;
    }
    if (direction == toMainDirection) {
      if (lastMainFocus != null && _isLaidOut(lastMainFocus!)) {
        lastMainFocus!.requestFocus();
        return true;
      } else {
        return super.inDirection(currentNode, direction);
      }
    }
    if (direction == TraversalDirection.up ||
        direction == TraversalDirection.down) {
      final scope = currentNode.enclosingScope;
      if (scope == null) {
        return false;
      }

      final candidates = scope.traversalDescendants
          .where((n) =>
              n.canRequestFocus &&
              FocusTraversalGroup.maybeOfNode(n) == this &&
              _isLaidOut(n))
          .toList();

      if (candidates.isEmpty) return false;

      final sorted = sortDescendants(candidates, currentNode).toList();

      var index = sorted.indexOf(currentNode);
      if (index == -1) {
        index = direction == TraversalDirection.down ? -1 : sorted.length;
      }

      final nextIndex =
          direction == TraversalDirection.down ? index + 1 : index - 1;

      if (nextIndex < 0 || nextIndex >= sorted.length) {
        return true;
      }

      requestFocusCallback(sorted[nextIndex]);
      return true;
    }
    return super.inDirection(currentNode, direction);
  }
}

bool _isLaidOut(FocusNode node) {
  final ro = node.context?.findRenderObject();
  return ro is RenderBox && ro.hasSize;
}
