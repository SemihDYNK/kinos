import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:auto_route/auto_route.dart';
import 'package:collection/collection.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sliver_tools/sliver_tools.dart';

import 'package:kinos/arr/models/arr_library_item.dart';
import 'package:kinos/arr/models/arr_media_detail.dart';
import 'package:kinos/arr/models/arr_service.dart';
import 'package:kinos/arr/providers/arr_detail_providers.dart';
import 'package:kinos/arr/providers/arr_jellyfin_link_provider.dart';
import 'package:kinos/arr/providers/arr_search_providers.dart';
import 'package:kinos/arr/screens/widgets/arr_detail_edit_dialog.dart';
import 'package:kinos/arr/screens/widgets/arr_detail_search_section.dart';
import 'package:kinos/arr/screens/widgets/arr_season_summary_list.dart';
import 'package:kinos/arr/services/arr_api_client.dart';
import 'package:kinos/arr/widgets/arr_desktop_scope.dart';
import 'package:kinos/models/items/images_models.dart';
import 'package:kinos/routes/auto_router.gr.dart';
import 'package:kinos/screens/details_screens/components/media_info_formatters.dart';
import 'package:kinos/screens/shared/kinos_notification_overlay.dart';
import 'package:kinos/theme/app_theme.dart';
import 'package:kinos/util/adaptive_layout/adaptive_layout.dart';
import 'package:kinos/util/router_extension.dart';
import 'package:kinos/util/sliver_list_padding.dart';
import 'package:kinos/widgets/shared/fading_hero_backdrop.dart';

/// Fiche détail Arr — ouverte depuis une jaquette de la bibliothèque
/// (cf. `ArrLibraryGrid`). Alimentée par Radarr/Sonarr, pas par Jellyfin :
/// un film peut être suivi par Radarr sans exister dans la bibliothèque
/// Jellyfin (précisément le cas où lancer une recherche a du sens).
///
/// Pas de [heroTint] issu du service de palette — le fanart Radarr/Sonarr
/// n'y passe pas (il n'a pas d'identité d'item Jellyfin à mettre en
/// cache) : [AppColors.heroFallback], le même repli que la palette
/// utilise déjà en cas d'échec, sert de teinte fixe.
@RoutePage()
class ArrDetailScreen extends ConsumerStatefulWidget {
  final ArrService service;
  final int id;

  /// Déplie la recherche interactive à l'ouverture — film entier, ou
  /// série entière si [initialSearchEpisodeId] est absent. Utilisé par
  /// le menu contextuel du calendrier ("Recherche interactive" pousse
  /// cette route plutôt que de dupliquer `ArrReleaseTable` ailleurs).
  final bool autoExpandSearch;

  /// Scope la recherche interactive à cet épisode dès l'ouverture — id
  /// épisode Sonarr d'une entrée de calendrier précise. Implique
  /// [autoExpandSearch].
  final int? initialSearchEpisodeId;

  const ArrDetailScreen({
    required this.service,
    required this.id,
    this.autoExpandSearch = false,
    this.initialSearchEpisodeId,
    super.key,
  });

  @override
  ConsumerState<ArrDetailScreen> createState() => _ArrDetailScreenState();
}

class _ArrDetailScreenState extends ConsumerState<ArrDetailScreen> {
  final _menuAnchorKey = GlobalKey();
  final _searchController = ArrDetailSearchSectionController();
  bool _autoExpandConsumed = false;

  ArrDetailKey get _key => (service: widget.service, id: widget.id);

  Future<void> _runAction(
    Future<ArrResult<void>> Function() action, {
    String? failureContext,
    String? successMessage,
  }) async {
    final result = await action();
    if (!mounted) return;
    switch (result) {
      case ArrSuccess():
        if (successMessage != null) {
          KinosSnack.show(successMessage, context: context);
        }
      case ArrFailure(:final detail):
        final parts = [failureContext, detail].nonNulls.toList();
        KinosSnack.show(
          parts.isEmpty ? 'Échec de l\'action.' : parts.join(' — '),
          context: context,
        );
    }
  }

  Future<void> _confirmRemove(
      BuildContext context, ArrDetailEntry entry) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surfaceHigh,
        shape: const RoundedRectangleBorder(borderRadius: AppRadii.sheetBorder),
        title: const Text('Supprimer de la bibliothèque'),
        content: Text(
            '"${entry.title}" sera retiré de ${widget.service.label}, fichier compris.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      final notifier = ref.read(arrDetailProvider(_key).notifier);
      await _runAction(notifier.remove, failureContext: 'Suppression');
      if (mounted) context.router.popBack();
    }
  }

  Future<void> _showEdit(BuildContext context, ArrDetailEntry entry) async {
    final qualityProfiles =
        ref.read(arrQualityProfilesProvider(widget.service)).valueOrNull ??
            const [];
    final rootFolders =
        ref.read(arrRootFoldersProvider(widget.service)).valueOrNull ??
            const [];
    final result = await showArrDetailEditDialog(
      context,
      entry: entry,
      qualityProfiles: qualityProfiles,
      rootFolders: rootFolders,
    );
    if (result == null || !mounted) return;
    final notifier = ref.read(arrDetailProvider(_key).notifier);
    await _runAction(
      () => notifier.edit(
        monitored: result.monitored,
        qualityProfileId: result.qualityProfileId,
        rootFolderPath: result.rootFolderPath,
      ),
      failureContext: 'Modification',
    );
  }

  void _showActionMenu(BuildContext context, Offset globalPosition,
      ArrDetailEntry entry, ArrJellyfinLinkMatch? jellyfinMatch) {
    final position = RelativeRect.fromLTRB(globalPosition.dx, globalPosition.dy,
        globalPosition.dx, globalPosition.dy);
    final notifier = ref.read(arrDetailProvider(_key).notifier);
    showMenu<void>(
      context: context,
      position: position,
      items: [
        PopupMenuItem(
          onTap: () => _runAction(notifier.toggleMonitored,
              failureContext: 'Surveillance'),
          child: _MenuLabel(
            icon: entry.monitored
                ? Icons.bookmark_remove_outlined
                : Icons.bookmark_add_outlined,
            label: entry.monitored ? 'Ne plus surveiller' : 'Surveiller',
          ),
        ),
        PopupMenuItem(
          onTap: () => _runAction(notifier.triggerSearch,
              failureContext: 'Recherche',
              successMessage: 'Recherche automatique lancée.'),
          child: const _MenuLabel(
              icon: Icons.search_rounded, label: 'Recherche automatique'),
        ),
        PopupMenuItem(
          onTap: () => entry.isMovie
              ? _searchController.expandMovie()
              : _searchController.expandSeries(),
          child: const _MenuLabel(
              icon: Icons.manage_search_rounded,
              label: 'Recherche interactive'),
        ),
        PopupMenuItem(
          onTap: () => _showEdit(context, entry),
          child: const _MenuLabel(icon: Icons.edit_outlined, label: 'Modifier'),
        ),
        const PopupMenuDivider(),
        PopupMenuItem(
          onTap: () => _confirmRemove(context, entry),
          child: const _MenuLabel(
              icon: Icons.delete_outline_rounded, label: 'Supprimer'),
        ),
        if (jellyfinMatch != null) ...[
          const PopupMenuDivider(),
          PopupMenuItem(
            onTap: () =>
                context.router.push(DetailsRoute(id: jellyfinMatch.id)),
            child: const _MenuLabel(
                icon: Icons.open_in_new_rounded, label: 'Voir dans Jellyfin'),
          ),
        ],
      ],
    );
  }

  /// Une seule fois par ouverture d'écran (`_autoExpandConsumed`) : une
  /// fois l'entrée chargée, déplie la recherche interactive selon les
  /// paramètres de route (cf. `ArrCalendarScreen._openInteractiveSearch`)
  /// — un post-frame callback laisse `ArrDetailSearchSection` s'attacher
  /// au contrôleur avant qu'on l'appelle.
  void _maybeAutoExpandSearch(ArrDetailEntry entry) {
    if (!widget.autoExpandSearch || _autoExpandConsumed) return;
    _autoExpandConsumed = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      if (entry.isMovie) {
        _searchController.expandMovie();
        return;
      }
      final episodeId = widget.initialSearchEpisodeId;
      if (episodeId == null) {
        _searchController.expandSeries();
        return;
      }
      final episodes =
          await ref.read(arrSeriesEpisodesProvider(entry.id).future);
      if (!mounted) return;
      final episode =
          episodes.where((e) => e.id == episodeId).firstOrNull;
      if (episode != null) {
        _searchController.expandEpisode(episode);
      } else {
        _searchController.expandSeries();
      }
    });
  }

  Offset _menuAnchor() {
    final box = _menuAnchorKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || !box.attached) return Offset.zero;
    return box.localToGlobal(box.size.center(Offset.zero));
  }

  String _errorMessage(ArrApiError error, String? detail) {
    final base = switch (error) {
      ArrApiError.unreachable => 'Serveur injoignable.',
      ArrApiError.unauthorized => 'Clé API invalide.',
      ArrApiError.notFound =>
        'Route introuvable — œuvre supprimée entre-temps ?',
      ArrApiError.serverError => 'Erreur serveur.',
      ArrApiError.invalidResponse => 'Réponse inattendue.',
    };
    return detail == null ? base : '$base $detail';
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(arrDetailProvider(_key));
    final sideBarInset = AdaptiveLayout.of(context).sideBarWidth;

    return ArrDesktopScope(
      child: CallbackShortcuts(
        bindings: {
          const SingleActivator(LogicalKeyboardKey.escape): () =>
              context.router.popBack(),
        },
        child: Focus(
          autofocus: true,
          onKeyEvent: (node, event) {
            if (event is! KeyDownEvent) return KeyEventResult.ignored;
            final entry = state.entry;
            if (entry == null) return KeyEventResult.ignored;
            final isContextMenuKey =
                event.logicalKey == LogicalKeyboardKey.contextMenu ||
                    (event.logicalKey == LogicalKeyboardKey.f10 &&
                        HardwareKeyboard.instance.isShiftPressed);
            if (!isContextMenuKey) return KeyEventResult.ignored;
            final jellyfinMatch = ref
                .read(arrJellyfinLinkProvider((
                  title: entry.title,
                  year: entry.year,
                  isMovie: entry.isMovie,
                )))
                .valueOrNull;
            _showActionMenu(context, _menuAnchor(), entry, jellyfinMatch);
            return KeyEventResult.handled;
          },
          child: ColoredBox(
            color: AppColors.background,
            child: Padding(
              padding: EdgeInsetsDirectional.only(start: sideBarInset),
              child: _buildBody(context, state),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context, ArrDetailState state) {
    if (state.entry == null) {
      if (state.loading) {
        return const Center(
          child: CircularProgressIndicator(strokeCap: StrokeCap.round),
        );
      }
      return Stack(
        children: [
          Center(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.xl),
              child: Text(
                state.error != null
                    ? _errorMessage(state.error!, state.errorDetail)
                    : 'Introuvable.',
                style: const TextStyle(color: AppColors.error),
              ),
            ),
          ),
          const _BackButton(),
        ],
      );
    }
    _maybeAutoExpandSearch(state.entry!);
    return _ArrDetailContent(
      entry: state.entry!,
      service: widget.service,
      menuAnchorKey: _menuAnchorKey,
      searchController: _searchController,
      onToggleMonitored: () => _runAction(
          ref.read(arrDetailProvider(_key).notifier).toggleMonitored,
          failureContext: 'Surveillance'),
      onSearch: () => _runAction(
          ref.read(arrDetailProvider(_key).notifier).triggerSearch,
          failureContext: 'Recherche',
          successMessage: 'Recherche automatique lancée.'),
      onInteractiveSearch: () => _searchController.expandSeries(),
      onEdit: (entry) => _showEdit(context, entry),
      onRemove: (entry) => _confirmRemove(context, entry),
      onShowMenu: (position, entry, jellyfinMatch) =>
          _showActionMenu(context, position, entry, jellyfinMatch),
      onSearchSeason: (seasonNumber, interactive) => interactive
          ? _searchController.expandSeason(seasonNumber)
          : _runAction(
              () => ref
                  .read(sonarrClientProvider)!
                  .triggerSeasonSearch(state.entry!.id, seasonNumber),
              failureContext: 'Recherche',
              successMessage: 'Recherche automatique lancée.'),
      onSearchEpisode: (episode, interactive) => interactive
          ? _searchController.expandEpisode(episode)
          : _runAction(
              () => ref.read(sonarrClientProvider)!.triggerEpisodeSearch(episode.id),
              failureContext: 'Recherche',
              successMessage: 'Recherche automatique lancée.'),
    );
  }
}

class _ArrDetailContent extends ConsumerWidget {
  final ArrDetailEntry entry;
  final ArrService service;
  final GlobalKey menuAnchorKey;
  final ArrDetailSearchSectionController searchController;
  final VoidCallback onToggleMonitored;
  final VoidCallback onSearch;
  final VoidCallback onInteractiveSearch;
  final void Function(ArrDetailEntry entry) onEdit;
  final void Function(ArrDetailEntry entry) onRemove;
  final void Function(
          Offset position, ArrDetailEntry entry, ArrJellyfinLinkMatch? match)
      onShowMenu;
  final void Function(int seasonNumber, bool interactive) onSearchSeason;
  final void Function(ArrEpisode episode, bool interactive) onSearchEpisode;

  const _ArrDetailContent({
    required this.entry,
    required this.service,
    required this.menuAnchorKey,
    required this.searchController,
    required this.onToggleMonitored,
    required this.onSearch,
    required this.onInteractiveSearch,
    required this.onEdit,
    required this.onRemove,
    required this.onShowMenu,
    required this.onSearchSeason,
    required this.onSearchEpisode,
  });

  static const _minTitleHeight = 560.0;
  static const _maxTitleHeight = 640.0;
  static const _backdropHeight = 1000.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final image = entry.fanartUrl ?? entry.posterUrl;
    final qualityProfiles =
        ref.watch(arrQualityProfilesProvider(service)).valueOrNull ?? const [];
    final qualityProfileName = qualityProfiles
        .where((p) => p.id == entry.qualityProfileId)
        .map((p) => p.name)
        .firstOrNull;
    final jellyfinMatch = ref
        .watch(arrJellyfinLinkProvider(
            (title: entry.title, year: entry.year, isMovie: entry.isMovie)))
        .valueOrNull;

    return Stack(
      children: [
        CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            const DefaultSliverTopBadding(),
            SliverStack(
              children: [
                SliverPositioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  height: _backdropHeight,
                  child: FadingHeroBackdrop(
                    image: image == null
                        ? null
                        : ImageData(
                            path: image,
                            key: 'arr_${service.name}_${entry.id}'),
                    heroTint: AppColors.heroFallback,
                    holdUntil: _minTitleHeight,
                  ),
                ),
                SliverMainAxisGroup(
                  slivers: [
                    SliverToBoxAdapter(
                      child: _TitleBlock(
                        entry: entry,
                        service: service,
                        menuAnchorKey: menuAnchorKey,
                        minHeight: _minTitleHeight,
                        maxHeight: _maxTitleHeight,
                        qualityProfileName: qualityProfileName,
                        jellyfinMatch: jellyfinMatch,
                        onToggleMonitored: onToggleMonitored,
                        onSearch: onSearch,
                        onInteractiveSearch: onInteractiveSearch,
                        onEdit: () => onEdit(entry),
                        onRemove: () => onRemove(entry),
                        onShowMenu: (position) =>
                            onShowMenu(position, entry, jellyfinMatch),
                      ),
                    ),
                    SliverPadding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.screenPadding),
                      sliver: SliverToBoxAdapter(
                        child: _DetailBody(
                          entry: entry,
                          qualityProfileName: qualityProfileName,
                          searchController: searchController,
                          onSearchSeason: onSearchSeason,
                          onSearchEpisode: onSearchEpisode,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const DefaultSliverBottomPadding(),
          ],
        ),
        const _BackButton(),
      ],
    );
  }
}

/// Positionné à `start: AppSpacing.sm`, pas `sideBarInset + AppSpacing.sm`
/// comme `MediaDetailScaffold` : cet écran indente tout son contenu (pas
/// seulement le bandeau) d'un seul `Padding(start: sideBarInset)` au
/// niveau de `_ArrDetailScreenState.build` — même convention que
/// `ArrSearchScreen`/`ArrLibraryScreen`, plus simple que le double
/// padding de l'écran détail Jellyfin.
class _BackButton extends StatelessWidget {
  const _BackButton();

  @override
  Widget build(BuildContext context) {
    return PositionedDirectional(
      top: MediaQuery.paddingOf(context).top + AppSpacing.sm,
      start: AppSpacing.sm,
      child: FocusRing(
        borderRadius: AppRadii.controlBorder,
        onActivate: () => context.router.popBack(),
        child: ExcludeFocus(
          child: IconButton.filledTonal(
            style: IconButton.styleFrom(
              backgroundColor: AppColors.scrim.withValues(alpha: 0.4),
              foregroundColor: AppColors.textPrimary,
            ),
            onPressed: () => context.router.popBack(),
            icon: const BackButtonIcon(),
          ),
        ),
      ),
    );
  }
}

/// Bloc titre posé sur le bandeau — titre, année/durée/genres, note,
/// actions (surveillance, recherche, modifier, supprimer, lien Jellyfin
/// si trouvé). Chaque action est un bouton (déjà atteignable au clavier
/// via Tab/Entrée) ET présente dans le menu contextuel (clic droit sur ce
/// bloc, ou touche Menu/Maj+F10 — cf. `_ArrDetailScreenState`), jamais
/// l'un sans l'autre.
class _TitleBlock extends StatelessWidget {
  final ArrDetailEntry entry;
  final ArrService service;
  final GlobalKey menuAnchorKey;
  final double minHeight;
  final double maxHeight;
  final String? qualityProfileName;
  final ArrJellyfinLinkMatch? jellyfinMatch;
  final VoidCallback onToggleMonitored;
  final VoidCallback onSearch;
  final VoidCallback onInteractiveSearch;
  final VoidCallback onEdit;
  final VoidCallback onRemove;
  final void Function(Offset position) onShowMenu;

  const _TitleBlock({
    required this.entry,
    required this.service,
    required this.menuAnchorKey,
    required this.minHeight,
    required this.maxHeight,
    required this.qualityProfileName,
    required this.jellyfinMatch,
    required this.onToggleMonitored,
    required this.onSearch,
    required this.onInteractiveSearch,
    required this.onEdit,
    required this.onRemove,
    required this.onShowMenu,
  });

  @override
  Widget build(BuildContext context) {
    // Texte sur image (cf. CLAUDE.md) : textPrimary, jamais textSecondary
    // (pas de garantie de contraste sur une image) — 75% d'opacité pour
    // le secondaire, cf. les styles inline ci-dessous.
    final year = entry.year;
    final runtime = entry.runtimeMinutes;
    final metaParts = <String>[
      if (year != null) year.toString(),
      if (runtime != null) '$runtime min',
      if (entry.genres.isNotEmpty) entry.genres.join(', '),
    ];
    final secondaryButtonStyle = IconButton.styleFrom(
      side: const BorderSide(color: AppColors.textPrimary),
      foregroundColor: AppColors.textPrimary,
      overlayColor: AppColors.textPrimary,
    );

    return ConstrainedBox(
      constraints: BoxConstraints(minHeight: minHeight, maxHeight: maxHeight),
      child: GestureDetector(
        onSecondaryTapDown: (details) => onShowMenu(details.globalPosition),
        child: Stack(
          alignment: Alignment.bottomLeft,
          children: [
            Padding(
              key: menuAnchorKey,
              padding: const EdgeInsets.all(AppSpacing.screenPadding),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    entry.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context)
                        .textTheme
                        .displayLarge
                        ?.copyWith(color: AppColors.textPrimary),
                  ),
                  if (metaParts.isNotEmpty || entry.rating != null) ...[
                    const SizedBox(height: AppSpacing.xs),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (metaParts.isNotEmpty)
                          Flexible(
                            child: Text(
                              metaParts.join(' · '),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(
                                      color: AppColors.textPrimary
                                          .withValues(alpha: 0.75)),
                            ),
                          ),
                        if (entry.rating != null) ...[
                          const SizedBox(width: AppSpacing.xs),
                          const Icon(Icons.star_rounded,
                              size: 14, color: AppColors.textPrimary),
                          const SizedBox(width: 2),
                          Text(
                            entry.rating!.toStringAsFixed(1),
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(
                                    color: AppColors.textPrimary
                                        .withValues(alpha: 0.75)),
                          ),
                        ],
                      ],
                    ),
                  ],
                  const SizedBox(height: AppSpacing.md),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      FocusRing(
                        borderRadius: AppRadii.controlBorder,
                        onActivate: onToggleMonitored,
                        child: ExcludeFocus(
                          child: Tooltip(
                            message: entry.monitored
                                ? 'Ne plus surveiller'
                                : 'Surveiller',
                            child: IconButton.outlined(
                              style: secondaryButtonStyle,
                              onPressed: onToggleMonitored,
                              icon: Icon(
                                entry.monitored
                                    ? Icons.bookmark_rounded
                                    : Icons.bookmark_border_rounded,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.xxs),
                      FocusRing(
                        borderRadius: AppRadii.controlBorder,
                        onActivate: onSearch,
                        child: ExcludeFocus(
                          child: Tooltip(
                            message: 'Recherche automatique',
                            child: IconButton.outlined(
                              style: secondaryButtonStyle,
                              onPressed: onSearch,
                              icon: const Icon(Icons.search_rounded),
                            ),
                          ),
                        ),
                      ),
                      if (!entry.isMovie) ...[
                        const SizedBox(width: AppSpacing.xxs),
                        FocusRing(
                          borderRadius: AppRadii.controlBorder,
                          onActivate: onInteractiveSearch,
                          child: ExcludeFocus(
                            child: Tooltip(
                              message: 'Recherche interactive (série entière)',
                              child: IconButton.outlined(
                                style: secondaryButtonStyle,
                                onPressed: onInteractiveSearch,
                                icon: const Icon(Icons.manage_search_rounded),
                              ),
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(width: AppSpacing.xxs),
                      FocusRing(
                        borderRadius: AppRadii.controlBorder,
                        onActivate: onEdit,
                        child: ExcludeFocus(
                          child: Tooltip(
                            message: 'Modifier',
                            child: IconButton.outlined(
                              style: secondaryButtonStyle,
                              onPressed: onEdit,
                              icon: const Icon(Icons.edit_outlined),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.xxs),
                      FocusRing(
                        borderRadius: AppRadii.controlBorder,
                        onActivate: onRemove,
                        child: ExcludeFocus(
                          child: Tooltip(
                            message: 'Supprimer',
                            child: IconButton.outlined(
                              style: secondaryButtonStyle,
                              onPressed: onRemove,
                              icon: const Icon(Icons.delete_outline_rounded),
                            ),
                          ),
                        ),
                      ),
                      if (jellyfinMatch != null) ...[
                        const SizedBox(width: AppSpacing.sm),
                        FocusRing(
                          borderRadius: AppRadii.controlBorder,
                          onActivate: () => context.router
                              .push(DetailsRoute(id: jellyfinMatch!.id)),
                          child: ExcludeFocus(
                            child: OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(
                                    color: AppColors.textPrimary),
                                foregroundColor: AppColors.textPrimary,
                              ),
                              onPressed: () => context.router
                                  .push(DetailsRoute(id: jellyfinMatch!.id)),
                              icon: const Icon(Icons.open_in_new_rounded,
                                  size: 16),
                              label: const Text('Voir dans Jellyfin'),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Corps de la fiche, sous le bandeau : résumé, informations Arr
/// (profil, dossier, surveillance, taille, fichier présent) et — série —
/// la liste des saisons, puis la recherche interactive.
class _DetailBody extends ConsumerWidget {
  final ArrDetailEntry entry;
  final String? qualityProfileName;
  final ArrDetailSearchSectionController searchController;
  final void Function(int seasonNumber, bool interactive) onSearchSeason;
  final void Function(ArrEpisode episode, bool interactive) onSearchEpisode;

  const _DetailBody({
    required this.entry,
    required this.qualityProfileName,
    required this.searchController,
    required this.onSearchSeason,
    required this.onSearchEpisode,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final episodes = entry.isMovie
        ? const <ArrEpisode>[]
        : ref.watch(arrSeriesEpisodesProvider(entry.id)).valueOrNull ??
            const <ArrEpisode>[];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if ((entry.overview ?? '').isNotEmpty) ...[
          Text(entry.overview!,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: AppColors.textPrimary)),
          const SizedBox(height: AppSpacing.lg),
        ],
        _InfoSection(entry: entry, qualityProfileName: qualityProfileName),
        if (!entry.isMovie && entry.series!.seasons.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.lg),
          Text('Saisons', style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: AppSpacing.sm),
          ArrSeasonSummaryList(
            seasons: entry.series!.seasons,
            episodes: episodes,
            onInteractiveSearchSeason: (n) => onSearchSeason(n, true),
            onAutoSearchSeason: (n) => onSearchSeason(n, false),
            onInteractiveSearchEpisode: (e) => onSearchEpisode(e, true),
            onAutoSearchEpisode: (e) => onSearchEpisode(e, false),
          ),
        ],
        const SizedBox(height: AppSpacing.lg),
        ArrDetailSearchSection(entry: entry, controller: searchController),
      ],
    );
  }
}

class _InfoSection extends StatelessWidget {
  final ArrDetailEntry entry;
  final String? qualityProfileName;

  const _InfoSection({required this.entry, required this.qualityProfileName});

  @override
  Widget build(BuildContext context) {
    final movie = entry.movie;
    return Wrap(
      spacing: AppSpacing.xl,
      runSpacing: AppSpacing.xs,
      children: [
        _InfoItem(label: 'Profil de qualité', value: qualityProfileName ?? '—'),
        _InfoItem(label: 'Dossier racine', value: entry.rootFolderPath ?? '—'),
        _InfoItem(
            label: 'Surveillance', value: entry.monitored ? 'Oui' : 'Non'),
        _InfoItem(
            label: 'Taille sur disque',
            value: formatFileSize(entry.sizeOnDisk) ?? '—'),
        if (movie != null && movie.hasFile) ...[
          _InfoItem(
              label: 'Qualité du fichier', value: movie.fileQualityName ?? '—'),
          _InfoItem(label: 'Codec', value: movie.fileCodec ?? '—'),
          _InfoItem(label: 'Source', value: movie.fileSource ?? '—'),
        ],
      ],
    );
  }
}

class _InfoItem extends StatelessWidget {
  final String label;
  final String value;
  const _InfoItem({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label,
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: AppColors.textSecondary)),
        Text(value,
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(color: AppColors.textPrimary)),
      ],
    );
  }
}

class _MenuLabel extends StatelessWidget {
  final IconData icon;
  final String label;
  const _MenuLabel({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 18, color: AppColors.textSecondary),
        const SizedBox(width: AppSpacing.xs),
        Text(label),
      ],
    );
  }
}
