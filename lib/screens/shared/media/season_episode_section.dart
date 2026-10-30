import 'package:kinos/screens/shared/media_navigation.dart';
import 'package:kinos/widgets/shared/status_card.dart';
import 'package:kinos/theme/app_icons.dart';
import 'package:flutter/services.dart';
import 'package:kinos/widgets/shared/frosted_surface.dart';
import 'package:flutter/material.dart';

import 'package:collection/collection.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:kinos/models/items/episode_model.dart';
import 'package:kinos/models/items/season_model.dart';
import 'package:kinos/theme/app_theme.dart';
import 'package:kinos/util/humanize_duration.dart';
import 'package:kinos/util/localization_helper.dart';
import 'package:kinos/util/text_metrics.dart';
import 'package:kinos/util/item_base_model/item_base_model_extensions.dart';
import 'package:kinos/widgets/shared/item_actions.dart';
import 'package:kinos/widgets/shared/labeled_selector.dart';
import 'package:kinos/widgets/shared/media_progress_bar.dart';
import 'package:kinos/widgets/shared/media_thumbnail.dart';

/// Sélecteur de saison ([LabeledSelector], même composant que les
/// sélecteurs de piste juste au-dessus) puis grille des épisodes de la
/// saison choisie — une seule saison affichée à la fois, jamais une
/// rangée par saison empilée (l'ancienne présentation, en carrousels
/// horizontaux).
class SeasonEpisodeSection extends ConsumerStatefulWidget {
  final List<SeasonModel> seasons;
  final bool seriesPresentation;
  final EdgeInsets contentPadding;

  /// Saison présélectionnée (ex. celle de l'épisode "à suivre") — repli
  /// sur la première saison si absente ou introuvable.
  final String? initialSeasonId;

  const SeasonEpisodeSection({
    required this.seasons,
    this.seriesPresentation = false,
    required this.contentPadding,
    this.initialSeasonId,
    super.key,
  });

  @override
  ConsumerState<SeasonEpisodeSection> createState() =>
      _SeasonEpisodeSectionState();
}

class _SeasonEpisodeSectionState extends ConsumerState<SeasonEpisodeSection> {
  String? _selectedSeasonId;

  @override
  void initState() {
    super.initState();
    _selectedSeasonId = widget.initialSeasonId;
  }

  String _seasonLabel(BuildContext context, SeasonModel season) =>
      season.seasonName.trim().isNotEmpty &&
              season.seasonName != context.localized.season(1)
          ? season.seasonName
          : '${context.localized.season(1)} ${season.season}';

  @override
  Widget build(BuildContext context) {
    final withEpisodes =
        widget.seasons.where((season) => season.episodes.isNotEmpty).toList();
    if (withEpisodes.isEmpty) return const SizedBox.shrink();

    final selected = withEpisodes
            .firstWhereOrNull((season) => season.id == _selectedSeasonId) ??
        withEpisodes.first;

    return Padding(
      padding: widget.contentPadding.copyWith(top: 0, bottom: 0),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final targetTileWidth = widget.seriesPresentation
              ? AppDetailLayout.seriesEpisodeWidth
              : AppGlass.episodeTargetWidth;
          final columns =
              (constraints.maxWidth / (targetTileWidth + AppSpacing.sm))
                  .floor()
                  .clamp(
                      2,
                      widget.seriesPresentation
                          ? AppDetailLayout.seriesEpisodeColumns
                          : 5);
          final tileWidth =
              (constraints.maxWidth - (columns - 1) * AppSpacing.sm) / columns;
          // Vignette 16:9 + libellé (numéro/titre, une ligne) + durée (une
          // ligne) — même principe de calcul que _CastGrid : la hauteur de
          // rangée découle de la largeur de vignette réelle, jamais d'un
          // ratio fixe approximatif. `mainAxisExtent` (pixels exacts), pas
          // `childAspectRatio` (converti en pixels par le delegate via une
          // division flottante — l'arrondi qui en ressort peut être
          // inférieur de quelques dixièmes de pixel à `tileHeight`, que le
          // libellé sous l'image réclame quand même en entier : débordement
          // visible en debug, bande rayée).
          //
          // Hauteur des lignes de texte mesurée réellement
          // (`measuredLineHeight`, pas `fontSize * height` : cette
          // approximation sous-évalue légèrement la hauteur de ligne
          // effective) et budget explicite du padding que `FocusRing`
          // retire à son enfant (`FocusRing.contentInset`) — sans ce
          // second terme, `_EpisodeTile` (enrobé dans un `FocusRing`
          // juste en dessous) débordait de 0,5 px sur chaque cellule,
          // quelle que soit la largeur de fenêtre : un budget qui ne
          // compte que l'image et le libellé oublie l'anneau de focus qui
          // entoure la cellule entière.
          final titleHeight = measuredLineHeight(
              context, Theme.of(context).textTheme.bodyMedium);
          final runtimeHeight = measuredLineHeight(
              context, Theme.of(context).textTheme.bodySmall);
          final tileHeight = tileWidth * 9 / 16 +
              AppSpacing.xs +
              titleHeight +
              runtimeHeight +
              FocusRing.contentInset(context);

          return FocusTraversalGroup(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (widget.seriesPresentation) ...[
                  Wrap(
                      spacing: AppSpacing.md,
                      runSpacing: AppSpacing.sm,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(context.localized.episode(2),
                            style: AppTypography.sectionTitleSmall),
                        FrostedSurface(
                            borderRadius: AppRadii.controlBorder,
                            child: Padding(
                                padding: const EdgeInsets.all(AppSpacing.xs),
                                child: withEpisodes.length > 1
                                    ? LabeledSelector(
                                        label: '',
                                        value: _seasonLabel(context, selected),
                                        options: withEpisodes
                                            .map((season) => (
                                                  label: _seasonLabel(
                                                      context, season),
                                                  selected:
                                                      season.id == selected.id,
                                                  subtitle: null,
                                                  onSelect: () => setState(() =>
                                                      _selectedSeasonId =
                                                          season.id)
                                                ))
                                            .toList())
                                    : Padding(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: AppSpacing.xs),
                                        child: Text(
                                            _seasonLabel(context, selected))))),
                        Text(
                            '${selected.episodes.length} ${context.localized.episode(selected.episodes.length)}',
                            style: Theme.of(context).textTheme.bodySmall),
                      ]),
                  const SizedBox(height: AppSpacing.md),
                ] else if (withEpisodes.length > 1) ...[
                  LabeledSelector(
                    label: context.localized.season(1),
                    value: _seasonLabel(context, selected),
                    options: withEpisodes
                        .map((season) => (
                              label: _seasonLabel(context, season),
                              selected: season.id == selected.id,
                              subtitle: null,
                              onSelect: () =>
                                  setState(() => _selectedSeasonId = season.id),
                            ))
                        .toList(),
                  ),
                  const SizedBox(height: AppSpacing.md),
                ],
                GridView.builder(
                  padding: EdgeInsets.zero,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: selected.episodes.length,
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: columns,
                    crossAxisSpacing: AppSpacing.sm,
                    mainAxisSpacing: AppSpacing.md,
                    mainAxisExtent: tileHeight,
                  ),
                  itemBuilder: (context, index) =>
                      _EpisodeTile(episode: selected.episodes[index]),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _EpisodeTile extends ConsumerWidget {
  final EpisodeModel episode;

  const _EpisodeTile({required this.episode});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    void openMenu([Offset? position]) {
      final box = context.findRenderObject() as RenderBox?;
      final point = position ?? box?.localToGlobal(Offset.zero) ?? Offset.zero;
      showGlassMenu(
          context: context,
          position:
              RelativeRect.fromLTRB(point.dx, point.dy, point.dx, point.dy),
          items: episode
              .generateActions(context, ref)
              .popupMenuItems(useIcons: true));
    }

    return MediaNavigation(
        previewImage: episode.images?.thumb ?? episode.images?.primary,
        key: ValueKey(episode.id),
        builder: (context) => Focus(
            canRequestFocus: false,
            onKeyEvent: (_, event) {
              if (event is KeyDownEvent &&
                  (event.logicalKey == LogicalKeyboardKey.contextMenu ||
                      (event.logicalKey == LogicalKeyboardKey.f10 &&
                          HardwareKeyboard.instance.isShiftPressed))) {
                openMenu();
                return KeyEventResult.handled;
              }
              return KeyEventResult.ignored;
            },
            child: Tooltip(
                message: '${context.localized.moreOptions} · Shift+F10',
                child: FocusRing(
                  focusNode: MediaNavigationScope.focusOf(context),
                  borderRadius: AppRadii.controlBorder,
                  onActivate: () => openMediaDetails(context, episode),
                  child: ExcludeFocus(
                    child: InkWell(
                      onTap: () => openMediaDetails(context, episode),
                      onSecondaryTapDown: (details) =>
                          openMenu(details.globalPosition),
                      borderRadius: AppRadii.controlBorder,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          AspectRatio(
                            aspectRatio: AppMedia.resumeAspectRatio,
                            child: ClipRRect(
                              borderRadius: AppRadii.controlBorder,
                              child: Stack(
                                fit: StackFit.expand,
                                children: [
                                  MediaArtwork(
                                      child: MediaThumbnail(
                                    thumbnail: episode.images?.thumb ??
                                        episode.images?.backDrop?.firstOrNull ??
                                        ((episode.primaryRatio ??
                                                    AppMedia
                                                        .resumeAspectRatio) >=
                                                1
                                            ? episode.images?.primary
                                            : null),
                                    fallback: episode.images?.primary,
                                  )),
                                  if (episode.userData.played)
                                    const Positioned(
                                      top: AppSpacing.xxs,
                                      right: AppSpacing.xxs,
                                      child: StatusCard(
                                          child: Icon(AppIcons.watched)),
                                    ),
                                  MediaProgressBar(
                                      progress: episode.userData.progress),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: AppSpacing.xs),
                          Text(
                            '${episode.episodeRange}. ${episode.name}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(color: AppColors.textPrimary),
                          ),
                          if (episode.overview.runTime != null)
                            Text(
                              episode.overview.runTime.humanize ?? '',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                        ],
                      ),
                    ),
                  ),
                ))));
  }
}
