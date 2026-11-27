import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:kinos/models/items/chapters_model.dart';
import 'package:kinos/models/items/media_segments_model.dart';
import 'package:kinos/providers/video_player_provider.dart';
import 'package:kinos/theme/app_theme.dart';
import 'package:kinos/util/duration_extensions.dart';
import 'package:kinos/widgets/shared/kinos_slider.dart';
import 'package:kinos/widgets/shared/segmented_track.dart';
import 'package:kinos/widgets/shared/trick_play_image.dart';

import 'seek_preview.dart';

class VideoProgressBar extends ConsumerStatefulWidget {
  final Function(bool value) wasPlayingChanged;
  final bool wasPlaying;
  final VoidCallback timerReset;
  final Duration duration;
  final Duration position;
  final bool buffering;
  final Duration buffer;
  final Function(Duration duration) onPositionChanged;

  /// Signal externe (survol/focus du conteneur, ex. un clavier Tab) qui
  /// s'ajoute au survol/glissement suivis en interne — `false` par
  /// défaut, sans effet : seul le lecteur desktop en a besoin (poignée
  /// visible au focus, pas seulement à la souris).
  final bool handleVisible;

  /// `false` par défaut (comportement historique, poignée toujours
  /// peinte, juste plus petite au repos) — `true` : la poignée
  /// disparaît complètement au repos, n'apparaît qu'au survol/glissement/
  /// focus ([handleVisible]).
  final bool hideHandleAtRest;

  const VideoProgressBar({
    required this.wasPlayingChanged,
    required this.wasPlaying,
    required this.timerReset,
    required this.onPositionChanged,
    required this.duration,
    required this.position,
    required this.buffering,
    required this.buffer,
    this.handleVisible = false,
    this.hideHandleAtRest = false,
    super.key,
  });

  @override
  ConsumerState<ConsumerStatefulWidget> createState() =>
      _ChapterProgressSliderState();
}

class _ChapterProgressSliderState extends ConsumerState<VideoProgressBar> {
  bool onHoverStart = false;
  bool onDragStart = false;
  double _chapterPosition = 0.0;
  double imageBottomOffset = 0.0;
  double chapterCardWidth = AppSeekPreview.width;
  Duration currentDuration = Duration.zero;

  /// L'aperçu tiré du fichier lui-même, quand le serveur n'a pas de
  /// trickplay (cf. [SeekPreviewEngine]) : ouvert au premier survol.
  SeekPreviewEngine? _preview;
  String? _previewSource;

  void _ensurePreview() {
    final model = ref.read(playBackModel);
    if (model?.trickPlay?.images.isNotEmpty == true) return;
    final source = SeekPreviewEngine.sourceOf(model);
    if (source == null || source == _previewSource) return;
    _previewSource = source;
    final old = _preview;
    _preview = null;
    unawaited(old?.dispose());
    SeekPreviewEngine.open(source).then((engine) {
      if (!mounted || _previewSource != source) {
        unawaited(engine?.dispose());
        return;
      }
      setState(() => _preview = engine);
      engine?.request(currentDuration);
    });
  }

  @override
  void dispose() {
    _previewSource = null;
    unawaited(_preview?.dispose());
    super.dispose();
  }

  /// Hauteurs communes à la barre de progression et à la barre de
  /// volume — cf. [SegmentedTrack.heightRest]/[SegmentedTrack.heightHover].
  /// `KinosSlider` reste utilisé ci-dessous, mais seulement pour son
  /// geste (glissement/tap) : son propre rendu de piste
  /// (`GappedContainerShape`, pensé pour un curseur isolé façon volume,
  /// pas pour une barre de progression) est rendu totalement
  /// transparent.
  static const _trackHeightRest = SegmentedTrack.heightRest;
  static const _trackHeightHover = SegmentedTrack.heightHover;


  @override
  Widget build(BuildContext context) {
    final List<Chapter> chapters =
        ref.read(playBackModel.select((value) => value?.chapters ?? []));
    final isVisible = onDragStart || onHoverStart || widget.handleVisible;
    final player = ref.watch(videoPlayerProvider);
    final position = onDragStart ? currentDuration : widget.position;
    final MediaSegmentsModel? mediaSegments =
        ref.read(playBackModel.select((value) => value?.mediaSegments));
    final durationMs = widget.duration.inMilliseconds;
    final playedFraction = durationMs > 0
        ? (position.inMilliseconds / durationMs).clamp(0.0, 1.0)
        : 0.0;
    final bufferFraction = durationMs > 0
        ? (widget.buffer.inMilliseconds / durationMs).clamp(0.0, 1.0)
        : 0.0;
    return LayoutBuilder(
      builder: (context, constraints) {
        final trackHeight = isVisible ? _trackHeightHover : _trackHeightRest;
        return Stack(
          clipBehavior: Clip.none,
          children: [
            Align(
              alignment: Alignment.center,
              child: MouseRegion(
                opaque: !widget.buffering,
                onHover: (event) {
                  setState(() {
                    onHoverStart = true;
                    _updateSliderPosition(
                        event.localPosition.dx, constraints.maxWidth);
                  });
                },
                onExit: (event) {
                  setState(() {
                    onHoverStart = false;
                  });
                },
                child: Listener(
                  onPointerDown: (event) {
                    setState(() {
                      onDragStart = true;
                      _updateSliderPosition(
                          event.localPosition.dx, constraints.maxWidth);
                    });
                  },
                  onPointerMove: (event) {
                    _updateSliderPosition(
                        event.localPosition.dx, constraints.maxWidth);
                  },
                  onPointerUp: (_) {
                    setState(() {
                      onDragStart = false;
                    });
                  },
                  child: Opacity(
                    opacity: widget.buffering ? 0 : 1.0,
                    // `KinosSlider` ne sert plus qu'à reconnaître le
                    // geste (tap/glissement) et à déclencher onChangeStart/
                    // onChanged/onChangeEnd — son propre rendu de piste
                    // (`GappedContainerShape`, le trou visible dans
                    // l'ancienne version) est rendu invisible ici ;
                    // `SegmentedTrack` ci-dessous porte tout l'affichage.
                    child: KinosSlider(
                      min: 0.0,
                      max: widget.duration.inMilliseconds.toDouble(),
                      animation: Duration.zero,
                      thumbWidth: 10.0,
                      showThumb: false,
                      activeTrackColor: Colors.transparent,
                      inactiveTrackColor: Colors.transparent,
                      value: (position.inMilliseconds).toDouble().clamp(
                            0,
                            widget.duration.inMilliseconds.toDouble(),
                          ),
                      onChangeEnd: (e) async {
                        currentDuration = Duration(milliseconds: e.toInt());
                        widget.onPositionChanged
                            .call(Duration(milliseconds: e.toInt()));
                        await Future.delayed(const Duration(milliseconds: 250));
                        if (widget.wasPlaying) {
                          player.play();
                        }
                        widget.timerReset.call();
                        setState(() {
                          onHoverStart = false;
                        });
                      },
                      onChangeStart: (value) {
                        setState(() {
                          onHoverStart = true;
                        });
                        widget.wasPlayingChanged
                            .call(player.lastState?.playing ?? false);
                        player.pause();
                      },
                      onChanged: (e) {
                        currentDuration = Duration(milliseconds: e.toInt());
                        widget.timerReset.call();
                      },
                    ),
                  ),
                ),
              ),
            ),
            // `Positioned.fill` + `Center` explicite : la piste ne doit
            // JAMAIS dépendre de l'alignement ambiant du `Stack`
            // englobant. Preuve mesurée de la régression (RenderBox) :
            // sans ceci, ce sous-arbre n'était pas positionné (pas de
            // `Positioned`), donc régi par l'alignement PAR DÉFAUT du
            // `Stack` racine (`AlignmentDirectional.topStart`, jamais
            // explicité) — la piste (haute de seulement `trackHeight`,
            // 4-6 px) se retrouvait plaquée en haut de la zone de 20 px
            // (centre Y ≈ trackHeight/2, ~2-3 px), alors que le pouce
            // (ci-dessous, `SizedBox` occupant toute la hauteur) se
            // centrait lui correctement à Y=10 — écart mesuré : 7 px,
            // exactement le décalage rapporté (858 vs 865).
            Positioned.fill(
              child: IgnorePointer(
                child: Center(
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      AnimatedContainer(
                        duration: AppDurations.hover,
                        height: trackHeight,
                        width: double.infinity,
                        child: widget.buffering
                            ? const ClipRRect(
                                borderRadius: AppRadii.controlBorder,
                                child: LinearProgressIndicator(
                                  backgroundColor: AppColors.progressTrack,
                                  valueColor: AlwaysStoppedAnimation(
                                      AppColors.textPrimary),
                                ),
                              )
                            : SegmentedTrack(
                                height: trackHeight,
                                primaryFraction: playedFraction,
                                secondaryFraction: bufferFraction,
                              ),
                      ),
                      ...?mediaSegments?.segments.map(
                        (segment) => Positioned(
                          left:
                              calculateStartOffset(constraints, segment.start),
                          right: calculateRightOffset(constraints, segment.end),
                          child: Container(
                            height: _trackHeightHover,
                            decoration: BoxDecoration(
                              color: segment.type.color,
                              borderRadius: AppRadii.controlBorder,
                            ),
                          ),
                        ),
                      ),
                      if (chapters.isNotEmpty && !widget.buffering) ...{
                        ...chapters.map(
                          (chapter) {
                            final offset = constraints.maxWidth /
                                (widget.duration.inMilliseconds /
                                        chapter.startPosition.inMilliseconds)
                                    .clamp(1, constraints.maxWidth);
                            final activePosition =
                                chapter.startPosition < widget.position;
                            if (chapter.startPosition.inSeconds == 0) {
                              return null;
                            }
                            return Positioned(
                              left: offset,
                              child: IgnorePointer(
                                child: Container(
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: activePosition
                                        ? AppColors.background
                                        : AppColors.textPrimary
                                            .withValues(alpha: 0.5),
                                  ),
                                  height: constraints.maxHeight,
                                  width: _trackHeightHover -
                                      (activePosition ? 2 : 4),
                                ),
                              ),
                            );
                          },
                        ).nonNulls,
                      },
                    ],
                  ),
                ),
              ),
            ),
            if (!widget.buffering) ...[
              chapterCard(
                  context, position, isVisible, constraints.maxHeight / 2),
              // Curseur (pouce) — `top: 0, bottom: 0` explicites (au lieu
              // d'un `SizedBox(height: constraints.maxHeight)` qui ne
              // fonctionnait que parce que sa hauteur coïncidait avec
              // celle de la zone) : centré par construction, sans lien
              // avec la hauteur animée de la piste (`trackHeight`,
              // 4-6 px) — visible seulement au survol/glissement/focus
              // (`isVisible`), jamais au repos.
              Positioned(
                left: (constraints.maxWidth /
                        (widget.duration.inMilliseconds /
                            position.inMilliseconds))
                    .clamp(1, constraints.maxWidth),
                top: 0,
                bottom: 0,
                child: Transform.translate(
                  offset: const Offset(-AppSpacing.sm / 2, 0),
                  child: IgnorePointer(
                    child: Center(
                      child: AnimatedOpacity(
                        duration: AppDurations.hover,
                        opacity: isVisible ? 1 : 0,
                        child: Container(
                          height: AppSpacing.sm,
                          width: AppSpacing.sm,
                          decoration: const BoxDecoration(
                            color: AppColors.textPrimary,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ],
        );
      },
    );
  }

  double calculateFractionWidth(BoxConstraints constraints, Duration incoming) {
    return (constraints.maxWidth *
            (incoming.inSeconds / widget.duration.inSeconds))
        .clamp(0, constraints.maxWidth);
  }

  double calculateStartOffset(BoxConstraints constraints, Duration start) {
    return (constraints.maxWidth *
            (start.inSeconds / widget.duration.inSeconds))
        .clamp(0, constraints.maxWidth);
  }

  double calculateEndOffset(BoxConstraints constraints, Duration end) {
    return (constraints.maxWidth * (end.inSeconds / widget.duration.inSeconds))
        .clamp(0, constraints.maxWidth);
  }

  double calculateRightOffset(BoxConstraints constraints, Duration end) {
    double endOffset = calculateEndOffset(constraints, end);
    return constraints.maxWidth - endOffset;
  }

  /// L'aperçu au survol : l'image de l'instant visé, le chapitre et le
  /// temps posés dessus sur un voile sombre (cf. « Texte sur image »).
  /// Sans image, le texte seul sur le voile.
  Widget chapterCard(BuildContext context, Duration duration, bool visible,
      double zoneCenterY) {
    final currentStream = ref.watch(playBackModel.select((value) => value));
    final chapter =
        (currentStream?.chapters ?? []).getChapterFromDuration(currentDuration);
    final trickPlay = currentStream?.trickPlay;
    final screenWidth = MediaQuery.of(context).size.width;
    final Widget? image = trickPlay != null && trickPlay.images.isNotEmpty
        ? AspectRatio(
            aspectRatio:
                trickPlay.width.toDouble() / trickPlay.height.toDouble(),
            child: TrickPlayImage(trickPlay, position: currentDuration))
        : _preview != null
            ? _PreviewFrame(_preview!)
            : chapter != null
                ? Image(
                    image: chapter.imageProvider,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                  )
                : null;
    final name = chapter?.name.trim() ?? '';
    final caption = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (name.isNotEmpty)
          Text(name.toUpperCase(),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.overline.copyWith(
                  color: AppColors.textPrimary
                      .withValues(alpha: AppSeekPreview.secondaryOpacity))),
        Text(
          currentDuration.readAbleDuration,
          style: AppTypography.sectionTitle.copyWith(
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ],
    );
    return Positioned(
      left: _chapterPosition.clamp(
          0, math.max(0, screenWidth - chapterCardWidth - AppSpacing.lg)),
      bottom: zoneCenterY + AppSeekPreview.gap,
      child: IgnorePointer(
        child: AnimatedOpacity(
          opacity: visible ? 1 : 0,
          duration: AppDurations.hover,
          child: SizedBox(
            key: const Key('seek-preview-card'),
            width: chapterCardWidth,
            child: ClipRRect(
              borderRadius: AppRadii.cardBorder,
              child: Stack(
                children: [
                  if (image != null)
                    Positioned.fill(
                        child: ColoredBox(
                            color: AppColors.scrim, child: image)),
                  if (image != null)
                    // Le voile, dense en bas, transparent aux deux tiers.
                    Positioned.fill(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.bottomCenter,
                            end: Alignment.topCenter,
                            stops: const [0, AppSeekPreview.scrimReach],
                            colors: [
                              AppColors.scrim
                                  .withValues(alpha: AppSeekPreview.scrim),
                              AppColors.scrim.withValues(alpha: 0),
                            ],
                          ),
                        ),
                      ),
                    ),
                  // L'image donne sa hauteur (16:9 par défaut) ; sans
                  // elle, le texte seul sur un fond voilé.
                  if (image != null)
                    AspectRatio(
                      aspectRatio: AppSeekPreview.aspectRatio,
                      child: Align(
                        alignment: Alignment.bottomLeft,
                        child: Padding(
                          padding: const EdgeInsets.all(AppSpacing.sm),
                          child: caption,
                        ),
                      ),
                    )
                  else
                    DecoratedBox(
                      decoration: BoxDecoration(
                          color: AppColors.scrim
                              .withValues(alpha: AppSeekPreview.scrim)),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.sm,
                            vertical: AppSpacing.xs),
                        child: caption,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _updateSliderPosition(double xPosition, double maxWidth) {
    if (widget.buffering) return;
    setState(() {
      _chapterPosition = xPosition - chapterCardWidth / 2;
      final value = ((maxWidth - xPosition) / maxWidth - 1).abs();
      currentDuration = Duration(
          milliseconds: (widget.duration.inMilliseconds * value).toInt());
    });
    _ensurePreview();
    _preview?.request(currentDuration);
  }
}

/// La dernière vignette de l'aperçu ; rien tant que la première n'est pas
/// arrivée.
class _PreviewFrame extends StatelessWidget {
  const _PreviewFrame(this.engine);
  final SeekPreviewEngine engine;

  @override
  Widget build(BuildContext context) => ValueListenableBuilder(
        valueListenable: engine.frame,
        builder: (context, frame, _) => frame == null
            ? const SizedBox.shrink()
            : AspectRatio(
                aspectRatio: frame.image.width / frame.image.height,
                child: RawImage(image: frame.image, fit: BoxFit.cover),
              ),
      );
}
