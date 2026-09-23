import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:kinos/models/items/chapters_model.dart';
import 'package:kinos/models/items/media_segments_model.dart';
import 'package:kinos/providers/video_player_provider.dart';
import 'package:kinos/theme/app_theme.dart';
import 'package:kinos/util/duration_extensions.dart';
import 'package:kinos/util/list_padding.dart';
import 'package:kinos/util/string_extensions.dart';
import 'package:kinos/widgets/shared/kinos_slider.dart';
import 'package:kinos/widgets/shared/segmented_track.dart';
import 'package:kinos/widgets/shared/trick_play_image.dart';

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
  double chapterCardWidth = 250;
  Duration currentDuration = Duration.zero;

  /// Hauteurs communes à la barre de progression et à la barre de
  /// volume — cf. [SegmentedTrack.heightRest]/[SegmentedTrack.heightHover].
  /// `KinosSlider` reste utilisé ci-dessous, mais seulement pour son
  /// geste (glissement/tap) : son propre rendu de piste
  /// (`GappedContainerShape`, pensé pour un curseur isolé façon volume,
  /// pas pour une barre de progression) est rendu totalement
  /// transparent.
  static const _trackHeightRest = SegmentedTrack.heightRest;
  static const _trackHeightHover = SegmentedTrack.heightHover;

  /// Géométrie du petit marqueur triangulaire (un carré pivoté à -45°)
  /// sous l'infobulle de chapitre — cf. [chapterCard]. Taille du carré
  /// avant rotation, et décalage vers le bas appliqué avant rotation
  /// pour détacher visuellement sa pointe du bord de l'infobulle.
  static const _caretSize = 30.0;
  static const _caretPushDown = 10.0;

  /// Distance verticale entre le bord bas (non transformé) de la carte
  /// infobulle+marqueur et la pointe du marqueur une fois pivoté.
  /// `Stack(alignment: bottomCenter)` place le CENTRE du carré (30 px de
  /// côté) à `côté / 2` au-dessus de ce bord bas, avant le décalage de
  /// `_caretPushDown` vers le bas ; la rotation à -45° l'éloigne encore
  /// de `côté × √2 / 2` (moitié de sa diagonale) en dessous de son
  /// propre centre. Net : `pushDown + côté × (√2 − 1) / 2` — dérivée de
  /// la géométrie du marqueur, jamais un nombre choisi à l'oeil (mesuré
  /// et corrigé une première fois via RenderBox : la formule initiale
  /// omettait le terme `−côté/2` de l'alignement `bottomCenter`, d'où un
  /// écart de 15 px avec le centre réel de la piste).
  static final double _caretTipDrop =
      _caretPushDown + _caretSize * (math.sqrt2 - 1) / 2;

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

  Widget chapterCard(BuildContext context, Duration duration, bool visible,
      double zoneCenterY) {
    final currentStream = ref.watch(playBackModel.select((value) => value));
    final chapter =
        (currentStream?.chapters ?? []).getChapterFromDuration(currentDuration);
    final trickPlay = currentStream?.trickPlay;
    final screenWidth = MediaQuery.of(context).size.width;
    final calculatedPosition = _chapterPosition;
    final offsetDifference = _chapterPosition - calculatedPosition;
    return Positioned(
      left:
          calculatedPosition.clamp(-10, screenWidth - (chapterCardWidth + 45)),
      // Ancre le bord bas de la carte à une distance FIXE et calculée
      // (`_caretTipDrop`) du centre de la piste (`zoneCenterY`) : la
      // pointe du marqueur triangulaire vise exactement ce centre,
      // quelle que soit la hauteur réelle du contenu (image + légende,
      // variable selon la longueur du nom de chapitre) — remplace
      // l'ancien `Transform.translate(0, -height - 10)` qui supposait
      // une hauteur de carte constante (350 px, jamais la hauteur
      // réelle), une approximation qui ne coïncidait qu'à quelques
      // pixels près avec le centre réel de la piste (mesuré : ~3 px
      // d'écart rapporté).
      bottom: zoneCenterY + _caretTipDrop,
      child: IgnorePointer(
        child: AnimatedOpacity(
          opacity: visible ? 1 : 0,
          duration: const Duration(milliseconds: 250),
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: chapterCardWidth),
            child: Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: AnimatedSize(
                  duration: const Duration(milliseconds: 250),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 250),
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxHeight: 250),
                          child: ClipRRect(
                            borderRadius:
                                const BorderRadius.all(Radius.circular(8)),
                            child: trickPlay == null || trickPlay.images.isEmpty
                                ? chapter != null
                                    ? Image(
                                        image: chapter.imageProvider,
                                        fit: BoxFit.contain,
                                      )
                                    : const SizedBox.shrink()
                                : AspectRatio(
                                    aspectRatio: trickPlay.width.toDouble() /
                                        trickPlay.height.toDouble(),
                                    child: TrickPlayImage(
                                      trickPlay,
                                      position: currentDuration,
                                    ),
                                  ),
                          ),
                        ),
                      ),
                      Stack(
                        alignment: Alignment.bottomCenter,
                        children: [
                          Transform.translate(
                            offset: Offset(offsetDifference, _caretPushDown),
                            child: Transform.rotate(
                              angle: -math.pi / 4,
                              child: Container(
                                key: const Key('chapter-card-caret'),
                                height: _caretSize,
                                width: _caretSize,
                                decoration: const BoxDecoration(
                                  color: AppColors.surfaceHigh,
                                  borderRadius: AppRadii.cardBorder,
                                ),
                              ),
                            ),
                          ),
                          Container(
                            decoration: const BoxDecoration(
                              color: AppColors.surfaceHigh,
                              borderRadius: AppRadii.cardBorder,
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(8.0),
                              // `MainAxisSize.min`, pas `.max` : cette
                              // Row vit dans une `ConstrainedBox
                              // (maxWidth: chapterCardWidth)` (250) —
                              // avec `.max`, elle réclamait ces 250 px
                              // même quand le texte tenait dans 80,
                              // d'où la boîte bien plus large que son
                              // contenu rapportée (mesuré : la largeur
                              // de la Row égalait la contrainte
                              // maximale, pas la somme de ses enfants).
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                spacing: AppSpacing.sm,
                                children: [
                                  if (chapter?.name.isNotEmpty ?? false)
                                    Flexible(
                                      child: Text(
                                        chapter?.name.capitalize() ?? "",
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleSmall
                                            ?.copyWith(
                                                fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                  Text(
                                    currentDuration.readAbleDuration,
                                    textAlign: TextAlign.center,
                                    // Typographie tabulaire : même
                                    // traitement que le compteur du
                                    // voile (cf.
                                    // `video_player_bar_content.dart`),
                                    // les chiffres ne sautent plus
                                    // latéralement à chaque seconde.
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleSmall
                                        ?.copyWith(
                                      fontWeight: FontWeight.bold,
                                      fontFeatures: const [
                                        FontFeature.tabularFigures()
                                      ],
                                    ),
                                  )
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ].addPadding(const EdgeInsets.symmetric(vertical: 4)),
                  ),
                ),
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
  }
}
