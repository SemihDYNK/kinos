import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'package:auto_route/auto_route.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iconsax_plus/iconsax_plus.dart';

import 'package:fladder/models/account_model.dart';
import 'package:fladder/models/item_base_model.dart';
import 'package:fladder/models/library_filter_model.dart';
import 'package:fladder/models/media_playback_model.dart';
import 'package:fladder/providers/settings/client_settings_provider.dart';
import 'package:fladder/providers/user_provider.dart';
import 'package:fladder/providers/video_player_provider.dart';
import 'package:fladder/routes/auto_router.dart';
import 'package:fladder/routes/auto_router.gr.dart';
import 'package:fladder/screens/shared/user_icon.dart';
import 'package:fladder/theme/app_theme.dart';
import 'package:fladder/util/adaptive_layout/adaptive_layout.dart';
import 'package:fladder/util/localization_helper.dart';
import 'package:fladder/widgets/navigation_scaffold/components/navigation_body.dart';
import 'package:fladder/widgets/shared/custom_tooltip.dart';

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

const _collapsedWidth = 64.0;
const _expandedWidth = 240.0;

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
/// `sideBarWidth`, ce qui permet à des fonds teintés comme celui du tableau
/// de bord de s'arrêter avant elle), et la barre elle-même est peinte
/// par-dessus dans un [Positioned.fill] séparé. Fond `AppColors.background`
/// pur — jamais teinté (cf. CLAUDE.md § Bandeau teinté).
class SideNavigationRail extends ConsumerWidget {
  final Widget child;
  const SideNavigationRail({required this.child, super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textDirection = Directionality.of(context);
    final isRtl = textDirection == TextDirection.rtl;
    final tooltipPosition =
        isRtl ? TooltipPosition.left : TooltipPosition.right;

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

    // -0.1 : évite un liseré d'un pixel entre le contenu et la barre à
    // certaines échelles d'écran (arrondi de layout).
    final width =
        (expanded ? _expandedWidth : _collapsedWidth) + startInset - 0.1;

    final fullScreenChildRoute =
        fullScreenRoutes.contains(context.router.current.name);

    final seerrAvailable = ref.watch(userProvider
        .select((value) => value?.seerrCredentials?.isConfigured ?? false));
    final user = ref.watch(userProvider);

    final destinations = _railDestinations(
      context: context,
      seerrAvailable: seerrAvailable,
    );
    // navBarNode doit toujours pouvoir reprendre le focus : rattaché à
    // l'item actif, ou au premier par défaut si aucun ne correspond à la
    // route courante (ex. réglages, panneau de contrôle hors "Gestion").
    final navBarNodeIndex = destinations
        .indexWhere((d) => d.selected)
        .clamp(0, destinations.length - 1);

    return Stack(
      children: [
        AdaptiveLayout(
          data: AdaptiveLayout.of(context).copyWith(sideBarWidth: width),
          child: child,
        ),
        Positioned.fill(
          child: Align(
            alignment: AlignmentDirectional.topStart,
            child: AnimatedOpacity(
              duration: AppDurations.pageTransition,
              opacity: fullScreenChildRoute ? 0 : 1,
              child: IgnorePointer(
                ignoring: fullScreenChildRoute,
                child: FocusTraversalGroup(
                  policy: _RailTraversalPolicy(),
                  child: AnimatedContainer(
                    duration: AppDurations.pageTransition,
                    curve: Curves.easeOutCubic,
                    width: width,
                    color: AppColors.background,
                    padding: EdgeInsetsDirectional.only(
                      start: startInset,
                      top: directionalPadding.top > 0
                          ? directionalPadding.top
                          : AppSpacing.xs,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.xs,
                              vertical: AppSpacing.xs),
                          child: FocusRing(
                            borderRadius: AppRadii.controlBorder,
                            onActivate: () => ref
                                .read(clientSettingsProvider.notifier)
                                .toggleSideBar(),
                            child: _RailRow(
                              icon: expanded
                                  ? IconsaxPlusLinear.sidebar_left
                                  : IconsaxPlusLinear.menu,
                              expanded: false,
                              label: '',
                              selected: false,
                            ),
                          ),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        for (var i = 0; i < destinations.length; i++)
                          Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: AppSpacing.xs, vertical: 2),
                            child: CustomTooltip(
                              position: tooltipPosition,
                              tooltipContent: expanded
                                  ? null
                                  : _TooltipBubble(
                                      label: destinations[i].label),
                              child: FocusRing(
                                borderRadius: AppRadii.controlBorder,
                                focusNode:
                                    i == navBarNodeIndex ? navBarNode : null,
                                onActivate: destinations[i].onTap,
                                child: _RailRow(
                                  icon: destinations[i].selected
                                      ? destinations[i].selectedIcon
                                      : destinations[i].icon,
                                  label: destinations[i].label,
                                  selected: destinations[i].selected,
                                  expanded: expanded,
                                ),
                              ),
                            ),
                          ),
                        const Spacer(),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(AppSpacing.xs,
                              AppSpacing.sm, AppSpacing.xs, AppSpacing.sm),
                          child: CustomTooltip(
                            position: tooltipPosition,
                            tooltipContent: expanded
                                ? null
                                : _TooltipBubble(
                                    label: context.localized.switchUser),
                            child: FocusRing(
                              borderRadius: AppRadii.controlBorder,
                              onActivate: () => _switchProfile(context, ref),
                              child:
                                  _ProfileRow(user: user, expanded: expanded),
                            ),
                          ),
                        ),
                        // Séparateur : les réglages ne sont pas une
                        // destination de navigation comme les autres, d'où
                        // le trait plutôt qu'un simple espacement.
                        const Padding(
                          padding: EdgeInsetsDirectional.symmetric(
                              horizontal: AppSpacing.sm),
                          child: Divider(
                              height: AppSpacing.sm,
                              thickness: 1,
                              color: AppColors.border),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.xs, vertical: 2),
                          child: CustomTooltip(
                            position: tooltipPosition,
                            tooltipContent: expanded
                                ? null
                                : _TooltipBubble(
                                    label: context.localized.settings),
                            child: FocusRing(
                              borderRadius: AppRadii.controlBorder,
                              onActivate: () => _openSettings(context),
                              child: _RailRow(
                                icon: IconsaxPlusLinear.setting_2,
                                label: context.localized.settings,
                                selected: context.router.current.name
                                    .contains('Settings'),
                                expanded: expanded,
                              ),
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
      ],
    );
  }

  void _openSettings(BuildContext context) {
    if (AdaptiveLayout.layoutModeOf(context) == LayoutMode.single) {
      context.router.push(const SettingsRoute());
    } else {
      context.router.push(const ClientSettingsRoute());
    }
  }

  /// Accueil, Films, Séries, Recherche, Demandes, Gestion — dans cet ordre.
  /// Demandes n'apparaît que si utilisable (Jellyseerr configuré) : la
  /// montrer sans condition mène vers un écran cassé. Gestion, elle, reste
  /// toujours visible même sans aucun service *Arr configuré — c'est par
  /// elle qu'on les configure, la masquer la rendrait inatteignable.
  List<_RailDestination> _railDestinations({
    required BuildContext context,
    required bool seerrAvailable,
  }) {
    final args = context.router.current.args;
    final activeTypes = args is LibrarySearchRouteArgs
        ? (args.types?.entries
                .where((e) => e.value)
                .map((e) => e.key)
                .toSet() ??
            const <FladderItemType>{})
        : const <FladderItemType>{};
    final isLibrarySearch = args is LibrarySearchRouteArgs;
    final currentRouteName = context.router.current.name;

    return [
      _RailDestination(
        label: context.localized.home,
        icon: IconsaxPlusLinear.home_1,
        selectedIcon: IconsaxPlusBold.home_1,
        selected: currentRouteName == DashboardRoute.name,
        onTap: () => context.router.navigate(const DashboardRoute()),
      ),
      _RailDestination(
        label: context.localized.mediaTypeMovie(2),
        // Pas de clap de cinéma dans iconsax_plus (seule bibliothèque
        // d'icônes du projet) : le plus proche disponible, distinct d'un
        // écran de télévision.
        icon: IconsaxPlusLinear.video_play,
        selectedIcon: IconsaxPlusBold.video_play,
        selected: setEquals(activeTypes, const {FladderItemType.movie}),
        onTap: () => context.router.navigate(
          LibrarySearchRoute().withFilter(
            const LibraryFilterModel(
                types: {FladderItemType.movie: true}, recursive: true),
          ),
        ),
      ),
      _RailDestination(
        label: context.localized.mediaTypeSeries(2),
        icon: IconsaxPlusLinear.monitor,
        selectedIcon: IconsaxPlusBold.monitor,
        selected: setEquals(activeTypes, const {FladderItemType.series}),
        onTap: () => context.router.navigate(
          LibrarySearchRoute().withFilter(
            const LibraryFilterModel(
                types: {FladderItemType.series: true}, recursive: true),
          ),
        ),
      ),
      _RailDestination(
        label: context.localized.search,
        icon: IconsaxPlusLinear.search_normal_1,
        selectedIcon: IconsaxPlusBold.search_normal_1,
        selected: isLibrarySearch && activeTypes.isEmpty,
        onTap: () => context.router.navigate(LibrarySearchRoute()),
      ),
      if (seerrAvailable)
        _RailDestination(
          label: 'Demandes',
          icon: IconsaxPlusLinear.send_2,
          selectedIcon: IconsaxPlusBold.send_2,
          selected: currentRouteName == SeerrRoute.name,
          onTap: () => context.router.navigate(const SeerrRoute()),
        ),
      _RailDestination(
        label: 'Gestion',
        icon: IconsaxPlusLinear.chart_3,
        selectedIcon: IconsaxPlusBold.chart_3,
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

class _TooltipBubble extends StatelessWidget {
  final String label;
  const _TooltipBubble({required this.label});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.surfaceHigh,
        borderRadius: AppRadii.controlBorder,
        border: Border.all(color: AppColors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
        child: Text(
          label,
          style: Theme.of(context)
              .textTheme
              .bodySmall
              ?.copyWith(color: AppColors.textPrimary),
        ),
      ),
    );
  }
}

/// Icône (+ libellé en mode déplié) d'un item de la barre. L'indicateur
/// d'item actif — fond `surfaceHigh` et icône `textPrimary` — reste le même
/// dans les deux états ; le liseré vertical, lui, n'a de sens qu'avec un
/// libellé à côté, donc seulement en mode déplié.
class _RailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final bool expanded;
  const _RailRow({
    required this.icon,
    required this.label,
    required this.selected,
    required this.expanded,
  });

  @override
  Widget build(BuildContext context) {
    final foreground =
        selected ? AppColors.textPrimary : AppColors.textSecondary;
    return Container(
      height: 44,
      decoration: BoxDecoration(
        color: selected ? AppColors.surfaceHigh : Colors.transparent,
        borderRadius: AppRadii.controlBorder,
      ),
      child: expanded
          ? Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
              child: Row(
                children: [
                  Container(
                    width: 3,
                    height: selected ? 20 : 0,
                    decoration: BoxDecoration(
                      color: AppColors.textPrimary,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Icon(icon, color: foreground, size: 22),
                  if (label.isNotEmpty) ...[
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context)
                            .textTheme
                            .bodyMedium
                            ?.copyWith(color: foreground),
                      ),
                    ),
                  ],
                ],
              ),
            )
          : Center(child: Icon(icon, color: foreground, size: 22)),
    );
  }
}

class _ProfileRow extends StatelessWidget {
  final AccountModel? user;
  final bool expanded;
  const _ProfileRow({required this.user, required this.expanded});

  @override
  Widget build(BuildContext context) {
    final avatar = SizedBox.square(
      dimension: 32,
      child: UserIcon(user: user, cornerRadius: AppRadii.control),
    );
    if (!expanded) return Center(child: avatar);
    return Row(
      children: [
        avatar,
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Text(
            user?.name ?? '',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(color: AppColors.textPrimary),
          ),
        ),
      ],
    );
  }
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
