import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:async/async.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iconsax_plus/iconsax_plus.dart';
import 'package:screen_brightness/screen_brightness.dart';
import 'package:volume_controller/volume_controller.dart';

import 'package:kinos/models/item_base_model.dart';
import 'package:kinos/models/items/media_segments_model.dart';
import 'package:kinos/models/items/media_streams_model.dart';
import 'package:kinos/models/media_playback_model.dart';
import 'package:kinos/models/playback/playback_model.dart';
import 'package:kinos/models/settings/video_player_settings.dart';
import 'package:kinos/providers/pip_provider.dart';
import 'package:kinos/providers/settings/client_settings_provider.dart';
import 'package:kinos/providers/settings/video_player_settings_provider.dart';
import 'package:kinos/providers/user_provider.dart';
import 'package:kinos/providers/video_player_provider.dart';
import 'package:kinos/screens/shared/default_title_bar.dart';
import 'package:kinos/screens/shared/media/components/item_logo.dart';
import 'package:kinos/screens/video_player/components/video_playback_information.dart';
import 'package:kinos/screens/video_player/components/video_player_brightness_indicator.dart';
import 'package:kinos/screens/video_player/components/video_player_controls_extras.dart';
import 'package:kinos/screens/video_player/components/video_player_options_sheet.dart';
import 'package:kinos/screens/video_player/components/video_player_quality_controls.dart';
import 'package:kinos/screens/video_player/components/video_player_screenshot_indicator.dart';
import 'package:kinos/screens/video_player/components/video_player_seek_indicator.dart';
import 'package:kinos/screens/video_player/components/video_player_speed_indicator.dart';
import 'package:kinos/screens/video_player/components/video_player_volume_indicator.dart';
import 'package:kinos/screens/video_player/components/video_progress_bar.dart';
import 'package:kinos/screens/video_player/components/video_quality_badge.dart';
import 'package:kinos/screens/video_player/components/video_volume_slider.dart';
import 'package:kinos/theme/app_theme.dart';
import 'package:kinos/util/adaptive_layout/adaptive_layout.dart';
import 'package:kinos/util/bitrate_helper.dart';
import 'package:kinos/util/duration_extensions.dart';
import 'package:kinos/util/input_handler.dart';
import 'package:kinos/util/list_padding.dart';
import 'package:kinos/util/localization_helper.dart';
import 'package:kinos/util/string_extensions.dart';
import 'package:kinos/widgets/full_screen_helpers/full_screen_wrapper.dart';
import 'package:kinos/widgets/shared/anchored_popover.dart';
import 'package:kinos/widgets/shared/track_label.dart';
import 'package:kinos/wrappers/pip_manager.dart';

class DesktopControls extends ConsumerStatefulWidget {
  const DesktopControls({super.key});

  @override
  ConsumerState<ConsumerStatefulWidget> createState() =>
      _DesktopControlsState();
}

class _DesktopControlsState extends ConsumerState<DesktopControls> {
  final GlobalKey _bottomControlsKey = GlobalKey();

  late final initInputDevice = AdaptiveLayout.inputDeviceOf(context);

  // 3s d'inactivité, pas 5 — refonte du langage visuel du lecteur.
  late RestartableTimer timer = RestartableTimer(
    const Duration(seconds: 3),
    () => mounted ? toggleOverlay(value: false) : null,
  );

  // Un popover ancré par section (audio/sous-titres/image/vitesse/
  // qualité) — desktop uniquement. AnchoredPopover gère lui-même le
  // positionnement, la fermeture (clic extérieur/Échap) et le retour du
  // focus au déclencheur ; ces contrôleurs ne servent qu'à ouvrir le bon
  // popover depuis un raccourci clavier (S, A) plutôt que depuis le clic
  // sur le bouton lui-même.
  final _audioPopover = AnchoredPopoverController();
  final _subtitlesPopover = AnchoredPopoverController();
  final _imagePopover = AnchoredPopoverController();
  final _speedPopover = AnchoredPopoverController();
  final _qualityPopover = AnchoredPopoverController();
  bool _qualityExpanded = false;

  // Barre de progression desktop — ~3px au repos, ~5px au survol/focus ;
  // poignée invisible au repos, visible seulement au survol/glissement/
  // focus. La zone cliquable (SizedBox englobant, ci-dessous) reste
  // large : c'est l'apparence qui s'affine, pas la cible.
  bool _progressHovering = false;
  bool _progressFocused = false;
  final _progressFocusNode = FocusNode(debugLabel: 'VideoProgressBar');

  double? previousVolume;

  final fadeDuration = const Duration(milliseconds: 350);
  bool showOverlay = true;
  bool wasPlaying = false;
  SystemUiMode? _currentSystemUiMode;

  bool _speedBoostActive = false;
  double? _originalSpeed;

  Offset? _doubleTapPosition;

  final SeekIndicatorController _seekController = SeekIndicatorController();

  late final double topPadding = MediaQuery.of(context).viewPadding.top;
  late final double bottomPadding = MediaQuery.of(context).viewPadding.bottom;

  String? _vDragSide;
  double? _vDragStartValue;
  double? _vDragLastValue;

  int? _lastSelectedSubtitleIndex;

  @override
  void initState() {
    super.initState();
    timer.reset();
    _lastSelectedSubtitleIndex = null;
  }

  @override
  void dispose() {
    _deactivateSpeedBoost();
    _progressFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isInPip = ref.watch(pipStateProvider).asData?.value ?? false;
    final player = ref.watch(videoPlayerProvider);
    if (isInPip) {
      // Keep only the subtitle widget so it's captured in the PiP frame.
      final pipSubtitleWidget =
          player.subtitleWidget(false, controlsKey: _bottomControlsKey);
      return Stack(
        children: [
          if (pipSubtitleWidget != null)
            Positioned.fill(child: pipSubtitleWidget),
        ],
      );
    }
    final mediaSegments =
        ref.watch(playBackModel.select((value) => value?.mediaSegments));
    final subtitleWidget =
        player.subtitleWidget(showOverlay, controlsKey: _bottomControlsKey);
    final isDesktop = AdaptiveLayout.of(context).isDesktop || kIsWeb;
    final speedBoostEnabled = ref.watch(
        videoPlayerSettingsProvider.select((value) => value.enableSpeedBoost));

    return Listener(
      onPointerSignal: setVolume,
      child: InputHandler(
        autoFocus: true,
        keyMap: ref.watch(videoPlayerSettingsProvider
            .select((value) => value.currentShortcuts)),
        keyMapResult: _onKey,
        onKeyEvent: isDesktop && speedBoostEnabled
            ? (node, event) {
                if (event.logicalKey == LogicalKeyboardKey.space) {
                  return _handleSpacebarEvent(event);
                }
                return KeyEventResult.ignored;
              }
            : null,
        child: PopScope(
          canPop: false,
          onPopInvokedWithResult: (didPop, result) {
            if (!didPop) {
              closePlayer();
            }
          },
          child: MouseRegion(
            cursor: showOverlay
                ? SystemMouseCursors.basic
                : SystemMouseCursors.none,
            onExit: (event) => toggleOverlay(value: false),
            onEnter: (event) => toggleOverlay(value: true),
            onHover: AdaptiveLayout.of(context).isDesktop || kIsWeb
                ? (event) => toggleOverlay(value: true)
                : null,
            child: Stack(
              children: [
                Positioned.fill(
                  child: GestureDetector(
                    onTap: initInputDevice == InputDevice.pointer
                        ? null
                        : () => toggleOverlay(),
                    onDoubleTapDown: initInputDevice == InputDevice.touch
                        ? _handleDoubleTapDown
                        : null,
                    onDoubleTap: initInputDevice == InputDevice.pointer
                        ? () => fullScreenHelper.toggleFullScreen(ref)
                        : _handleDoubleTapSeek,
                    onLongPressStart: initInputDevice == InputDevice.touch
                        ? _handleLongPressStart
                        : null,
                    onLongPressEnd: initInputDevice == InputDevice.touch
                        ? _handleLongPressEnd
                        : null,
                    onVerticalDragStart: initInputDevice == InputDevice.touch
                        ? _handleVerticalDragStart
                        : null,
                    onVerticalDragUpdate: initInputDevice == InputDevice.touch
                        ? _handleVerticalDragUpdate
                        : null,
                    onVerticalDragEnd: initInputDevice == InputDevice.touch
                        ? _handleVerticalDragEnd
                        : null,
                    //better play/pause handling on Desktop (works with dragging on click)
                    onHorizontalDragDown: initInputDevice == InputDevice.pointer
                        ? (details) => player.playOrPause()
                        : null,
                  ),
                ),
                if (subtitleWidget != null) subtitleWidget,
                if (AdaptiveLayout.of(context).isDesktop)
                  Consumer(builder: (context, ref, child) {
                    final playing = ref.watch(
                        mediaPlaybackProvider.select((value) => value.playing));
                    final buffering = ref.watch(mediaPlaybackProvider
                        .select((value) => value.buffering));
                    return playButton(playing, buffering);
                  }),
                IgnorePointer(
                  ignoring: !showOverlay,
                  child: AnimatedOpacity(
                    duration: fadeDuration,
                    opacity: showOverlay ? 1 : 0,
                    child: Column(
                      children: [
                        isDesktop
                            ? desktopTopBar(context)
                            : topButtons(context),
                        const Spacer(),
                        isDesktop
                            ? desktopBottomBar(context)
                            : bottomButtons(context),
                      ],
                    ),
                  ),
                ),
                VideoPlayerSeekIndicator(controller: _seekController),
                const VideoPlayerVolumeIndicator(),
                const VideoPlayerBrightnessIndicator(),
                const VideoPlayerSpeedIndicator(),
                const VideoPlayerScreenshotIndicator(),
                Consumer(
                  builder: (context, ref, child) {
                    final position = ref.watch(mediaPlaybackProvider
                        .select((value) => value.position));
                    final skippedSegments = ref.watch(mediaPlaybackProvider
                        .select((value) => value.skippedSegments));
                    MediaSegment? segment = mediaSegments?.atPosition(position);
                    SegmentVisibility forceShow =
                        segment?.visibility(position, force: showOverlay) ??
                            SegmentVisibility.hidden;
                    final segmentSkipType = ref.watch(
                        videoPlayerSettingsProvider.select((value) =>
                            value.segmentSkipSettings[segment?.type]));

                    final segmentId = segment != null
                        ? '${segment.type.name}_${segment.start.inMilliseconds}'
                        : null;
                    final wasSkipped = segmentId != null &&
                        skippedSegments.contains(segmentId);

                    final autoSkip = forceShow != SegmentVisibility.hidden &&
                        (segmentSkipType == SegmentSkip.skip ||
                            (segmentSkipType == SegmentSkip.skipOnce &&
                                !wasSkipped)) &&
                        player.lastState?.buffering == false;

                    if (autoSkip) {
                      skipToSegmentEnd(segment, segmentId);
                    }
                    return Stack(
                      children: [
                        Align(
                          alignment: Alignment.centerRight,
                          child: Padding(
                            padding: const EdgeInsets.all(32),
                            child: SkipSegmentButton(
                              segment: segment,
                              skipType: segmentSkipType,
                              visibility: forceShow,
                              pressedSkip: () =>
                                  skipToSegmentEnd(segment, null),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget playButton(bool playing, bool buffering) {
    return Align(
      alignment: Alignment.center,
      child: AnimatedScale(
        curve: Curves.easeInOutCubicEmphasized,
        scale: playing
            ? 0
            : buffering
                ? 0
                : 1,
        duration: const Duration(milliseconds: 250),
        child: IconButton.outlined(
          onPressed: () => ref.read(videoPlayerProvider).play(),
          isSelected: true,
          iconSize: 65,
          tooltip: "Resume video",
          icon: const Icon(IconsaxPlusBold.play),
        ),
      ),
    );
  }

  Widget topButtons(BuildContext context) {
    final currentItem = ref.watch(playBackModel.select((value) => value?.item));
    final maxHeight = 150
        .clamp(
            50,
            (MediaQuery.sizeOf(context).height * 0.25)
                .clamp(51, double.maxFinite))
        .toDouble();
    return Container(
      decoration: BoxDecoration(
          gradient: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Colors.black.withValues(alpha: 0.8),
          Colors.black.withValues(alpha: 0),
        ],
      )),
      child: Padding(
        padding: MediaQuery.paddingOf(context).copyWith(bottom: 0, top: 0),
        child: Container(
          alignment: Alignment.topCenter,
          child: Column(
            children: [
              const Align(
                alignment: Alignment.topCenter,
                child: DefaultTitleBar(),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Row(
                  spacing: 16,
                  mainAxisSize: MainAxisSize.max,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    IconButton(
                      onPressed: () => minimizePlayer(context),
                      icon: const Icon(
                        IconsaxPlusLinear.arrow_down_1,
                        size: 24,
                      ),
                    ),
                    if (currentItem != null)
                      Expanded(
                        child: Row(
                          children: [
                            Flexible(
                              child: ConstrainedBox(
                                constraints: BoxConstraints(
                                  maxHeight: maxHeight,
                                ),
                                child: ItemLogo(
                                  item: currentItem,
                                  imageAlignment: Alignment.topLeft,
                                  textStyle:
                                      Theme.of(context).textTheme.headlineLarge,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    if (initInputDevice == InputDevice.touch)
                      Align(
                        alignment: Alignment.centerRight,
                        child: Tooltip(
                            message: context.localized.stop,
                            child: IconButton(
                                onPressed: () => closePlayer(),
                                icon: const Icon(
                                    IconsaxPlusLinear.close_square))),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Voile haut desktop — titre/métadonnées en haut à gauche, garde
  /// [DefaultTitleBar] (chrome de fenêtre Linux : réduire/agrandir/
  /// fermer, zone de déplacement — cf. window_manager, à ne pas perdre).
  /// Pas de flèche de réduction isolée ici (retirée) : le bouton de
  /// réduction, lisible, vit à droite du titre.
  Widget desktopTopBar(BuildContext context) {
    final currentItem = ref.watch(playBackModel.select((value) => value?.item));
    final playbackModel = ref.watch(playBackModel);
    final mediaStreams = playbackModel?.mediaStreams;
    final badge = playerHdrBadgeLabel(
      mediaStreams?.displayProfile,
      mediaStreams?.resolution,
    );
    final metaParts = [
      if (currentItem != null) currentItem.detailedName(context.localized),
      playbackModel?.label(context),
      if (badge.isNotEmpty) badge,
    ].nonNulls.where((part) => part.isNotEmpty).join(' · ');

    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          // Symétrique au voile bas, mais nettement plus court : juste
          // assez pour porter le titre, cf. CLAUDE.md "texte sur image".
          colors: [
            AppColors.scrim.withValues(alpha: 0.85),
            AppColors.scrim.withValues(alpha: 0),
          ],
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const DefaultTitleBar(),
          Padding(
            padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg, AppSpacing.sm, AppSpacing.lg, AppSpacing.xl),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (currentItem != null)
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          currentItem.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context)
                              .textTheme
                              .headlineSmall
                              ?.copyWith(color: AppColors.textPrimary),
                        ),
                        if (metaParts.isNotEmpty)
                          // Reprend l'accès au détail technique de lecture
                          // (codec, débit, raison d'un éventuel transcodage)
                          // qu'ouvrait la carte "Direct"/"Transcode" dans
                          // l'ancienne disposition — pas de raison de le
                          // perdre, juste de ne plus l'afficher en carte.
                          FocusRing(
                            borderRadius: AppRadii.controlBorder,
                            onActivate: () =>
                                showVideoPlaybackInformation(context),
                            child: ExcludeFocus(
                              child: InkWell(
                                borderRadius: AppRadii.controlBorder,
                                onTap: () =>
                                    showVideoPlaybackInformation(context),
                                child: Padding(
                                  padding: const EdgeInsets.only(
                                      top: AppSpacing.xxs),
                                  child: Text(
                                    metaParts,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodyMedium
                                        ?.copyWith(
                                            color: AppColors.textPrimary
                                                .withValues(alpha: 0.75)),
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                const SizedBox(width: AppSpacing.md),
                FocusRing(
                  borderRadius: AppRadii.controlBorder,
                  onActivate: () => minimizePlayer(context),
                  child: ExcludeFocus(
                    child: Tooltip(
                      message: 'Réduire',
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.textPrimary,
                          side: const BorderSide(color: AppColors.borderStrong),
                        ),
                        onPressed: () => minimizePlayer(context),
                        icon: const Icon(Icons.keyboard_arrow_down_rounded),
                        label: const Text('Réduire'),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Voile bas desktop — barre de progression pleine largeur en tête,
  /// puis une rangée de contrôles alignée à gauche (disposition au
  /// pouce, pas centrée) : transport, puis sous-titres/audio/réglages.
  /// Volume et plein écran à droite. Raccourcis visibles en dessous, pas
  /// seulement dans les infobulles.
  Widget desktopBottomBar(BuildContext context) {
    return Consumer(builder: (context, ref, child) {
      final mediaPlayback = ref.watch(mediaPlaybackProvider);
      final playing = mediaPlayback.playing;

      return DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.bottomCenter,
            end: Alignment.topCenter,
            // 0,85 en bas vers transparent sur ~60% de la hauteur du
            // voile — cf. CLAUDE.md "texte sur image".
            stops: const [0.0, 0.6, 1.0],
            colors: [
              AppColors.scrim.withValues(alpha: 0.85),
              AppColors.scrim.withValues(alpha: 0.85 * 0.35),
              AppColors.scrim.withValues(alpha: 0),
            ],
          ),
        ),
        child: Padding(
          padding: EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.xl,
              AppSpacing.lg,
              MediaQuery.paddingOf(context).bottom + AppSpacing.sm),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              MouseRegion(
                onEnter: (_) => setState(() => _progressHovering = true),
                onExit: (_) => setState(() => _progressHovering = false),
                child: Listener(
                  // `Listener`, pas `GestureDetector` : la barre elle-même
                  // reconnaît déjà tap/glissement en interne — un second
                  // détecteur de geste au-dessus lui disputerait l'arène
                  // gestuelle. `Listener` reçoit l'évènement brut sans
                  // entrer en concurrence.
                  onPointerDown: (_) => _progressFocusNode.requestFocus(),
                  child: Focus(
                    focusNode: _progressFocusNode,
                    onFocusChange: (focused) =>
                        setState(() => _progressFocused = focused),
                    onKeyEvent: (node, event) {
                      if (event is! KeyDownEvent) return KeyEventResult.ignored;
                      switch (event.logicalKey) {
                        case LogicalKeyboardKey.arrowLeft:
                          seekBack(ref, seconds: 5);
                          return KeyEventResult.handled;
                        case LogicalKeyboardKey.arrowRight:
                          seekForward(ref, seconds: 5);
                          return KeyEventResult.handled;
                        default:
                          return KeyEventResult.ignored;
                      }
                    },
                    // La zone cliquable (SizedBox) reste large — c'est le
                    // SliderTheme ci-dessous qui affine l'apparence du
                    // trait peint, pas la cible.
                    child: SliderTheme(
                      data: SliderThemeData(
                        trackHeight:
                            _progressHovering || _progressFocused ? 5 : 3,
                      ),
                      child: SizedBox(
                        height: 20,
                        child: VideoProgressBar(
                          wasPlayingChanged: (value) => wasPlaying = value,
                          wasPlaying: wasPlaying,
                          duration: mediaPlayback.duration,
                          position: mediaPlayback.position,
                          buffer: mediaPlayback.buffer,
                          buffering: mediaPlayback.buffering,
                          timerReset: () => timer.reset(),
                          handleVisible: _progressHovering || _progressFocused,
                          hideHandleAtRest: true,
                          onPositionChanged: (position) =>
                              ref.read(videoPlayerProvider).seek(position),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.xxs),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(mediaPlayback.position.readAbleDuration,
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: AppColors.textSecondary)),
                  Text(
                      '-${(mediaPlayback.duration - mediaPlayback.position).readAbleDuration}',
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: AppColors.textSecondary)),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              Row(
                children: [
                  Expanded(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        previousButton,
                        _desktopSeekButton(
                          icon: IconsaxPlusBroken.refresh,
                          flip: false,
                          tooltip: _tooltipFor(
                              'Reculer de 10 s', VideoHotKeys.seekBack),
                          onPressed: () => seekBack(ref, seconds: 10),
                        ),
                        _desktopPlayPauseButton(playing),
                        _desktopSeekButton(
                          icon: IconsaxPlusBroken.refresh,
                          flip: true,
                          tooltip: _tooltipFor(
                              'Avancer de 10 s', VideoHotKeys.seekForward),
                          onPressed: () => seekForward(ref, seconds: 10),
                        ),
                        nextVideoButton,
                        const SizedBox(width: AppSpacing.md),
                        _desktopPopoverButton(
                          icon: IconsaxPlusLinear.subtitle,
                          tooltip: _tooltipFor(
                              'Sous-titres', VideoHotKeys.toggleSubtitles),
                          controller: _subtitlesPopover,
                          optionsBuilder: _subtitleOptions,
                        ),
                        _desktopPopoverButton(
                          icon: IconsaxPlusLinear.audio_square,
                          tooltip:
                              _tooltipFor('Audio', VideoHotKeys.openAudioPanel),
                          controller: _audioPopover,
                          optionsBuilder: _audioOptions,
                        ),
                        _desktopPopoverButton(
                          icon: Icons.aspect_ratio_rounded,
                          tooltip: 'Image',
                          controller: _imagePopover,
                          optionsBuilder: _imageOptions,
                        ),
                        _desktopPopoverButton(
                          icon: Icons.speed_rounded,
                          tooltip: 'Vitesse',
                          controller: _speedPopover,
                          optionsBuilder: _speedOptions,
                        ),
                        _desktopPopoverButton(
                          icon: IconsaxPlusLinear.speedometer,
                          tooltip: 'Qualité',
                          controller: _qualityPopover,
                          optionsBuilder: _qualityOptions,
                        ),
                      ],
                    ),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Plus discret que le groupe de transport : curseur
                      // fin (SliderTheme local, ne change rien pour les
                      // autres lecteurs qui utilisent ce même composant)
                      // et court (`width`, jusque-là un paramètre mort —
                      // corrigé au passage dans video_volume_slider.dart).
                      SliderTheme(
                        data: const SliderThemeData(trackHeight: 3),
                        child: VideoVolumeSlider(
                          width: 50,
                          onChanged: () => resetTimer(),
                        ),
                      ),
                      FocusRing(
                        borderRadius: AppRadii.controlBorder,
                        onActivate: () =>
                            fullScreenHelper.toggleFullScreen(ref),
                        child: ExcludeFocus(
                          child: Tooltip(
                            message: _tooltipFor(context.localized.fullScreen,
                                VideoHotKeys.fullScreen),
                            child: const FullScreenButton(),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    });
  }

  String _tooltipFor(String label, VideoHotKeys key) {
    final combo = ref
        .read(
            videoPlayerSettingsProvider.select((v) => v.currentShortcuts[key]))
        ?.label;
    return combo == null || combo.isEmpty ? label : '$label ($combo)';
  }

  Widget _desktopPlayPauseButton(bool playing) {
    return FocusRing(
      borderRadius: AppRadii.controlBorder,
      onActivate: () => ref.read(videoPlayerProvider).playOrPause(),
      child: ExcludeFocus(
        child: Tooltip(
          message:
              _tooltipFor(context.localized.playPause, VideoHotKeys.playPause),
          child: IconButton.filledTonal(
            iconSize: 38,
            onPressed: () => ref.read(videoPlayerProvider).playOrPause(),
            icon: Icon(playing ? IconsaxPlusBold.pause : IconsaxPlusBold.play),
          ),
        ),
      ),
    );
  }

  Widget _desktopSeekButton({
    required IconData icon,
    required bool flip,
    required String tooltip,
    required VoidCallback onPressed,
  }) {
    return FocusRing(
      borderRadius: AppRadii.controlBorder,
      onActivate: onPressed,
      child: ExcludeFocus(
        child: Tooltip(
          message: tooltip,
          child: IconButton(
            iconSize: 32,
            onPressed: onPressed,
            icon: flip
                ? Transform.flip(flipX: true, child: Icon(icon))
                : Icon(icon),
          ),
        ),
      ),
    );
  }

  /// Bouton de barre ouvrant un [AnchoredPopover] ancré sur lui — Audio,
  /// Sous-titres, Image, Vitesse, Qualité sont chacun ce motif, jamais
  /// le panneau latéral qu'ils remplacent.
  Widget _desktopPopoverButton({
    required IconData icon,
    required String tooltip,
    required AnchoredPopoverController controller,
    required List<PopoverOption> Function() optionsBuilder,
  }) {
    return AnchoredPopover(
      controller: controller,
      // Le popover est un OverlayPortal posé au-dessus de tout, y
      // compris le voile — sans ça, il resterait affiché flottant, sans
      // plus rien pour l'ancrer visuellement, une fois le voile
      // estompé par inactivité.
      onOpenChanged: (open) => open ? toggleOverlay(value: true) : resetTimer(),
      popoverBuilder: (context, close) => PopoverOptionList(
        options: optionsBuilder(),
        onSelected: close,
      ),
      child: FocusRing(
        borderRadius: AppRadii.controlBorder,
        onActivate: controller.toggle,
        child: ExcludeFocus(
          child: Tooltip(
            message: tooltip,
            child: IconButton(
              onPressed: controller.toggle,
              icon: Icon(icon, color: AppColors.textSecondary),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _selectAudio(AudioStreamModel stream) async {
    final playbackModel = ref.read(playBackModel);
    if (playbackModel == null) return;
    final player = ref.read(videoPlayerProvider);
    final newModel = await playbackModel.setAudio(stream, player);
    ref.read(playBackModel.notifier).update((state) => newModel);
    if (newModel != null) {
      await ref.read(playbackModelHelper).shouldReload(newModel);
    }
  }

  Future<void> _selectSubtitle(SubStreamModel stream) async {
    final playbackModel = ref.read(playBackModel);
    if (playbackModel == null) return;
    final player = ref.read(videoPlayerProvider);
    final newModel = await playbackModel.setSubtitle(stream, player);
    ref.read(playBackModel.notifier).update((state) => newModel);
    if (newModel != null) {
      await ref.read(playbackModelHelper).shouldReload(newModel);
    }
  }

  Future<void> _selectQuality(
      Map<Bitrate, bool> options, Bitrate chosen) async {
    final playbackModel = ref.read(playBackModel);
    final newModel = await playbackModel?.setQualityOption(
      options.map((key, value) => MapEntry(key, key == chosen)),
    );
    ref.read(playBackModel.notifier).update((state) => newModel);
    if (newModel != null) {
      await ref.read(playbackModelHelper).shouldReload(newModel);
    }
  }

  List<PopoverOption> _audioOptions() {
    // watch, pas read : la liste doit se rafraîchir si elle change
    // pendant que le popover est ouvert (ex. piste par défaut arrivée
    // après coup) — sûr ici, appelé uniquement pendant la construction
    // (popoverBuilder n'est invoqué que popover ouvert).
    final playbackModel = ref.watch(playBackModel);
    final currentIndex = playbackModel?.mediaStreams?.defaultAudioStreamIndex;
    final streams = playbackModel?.audioStreams ?? const [];
    return streams
        .map((stream) => PopoverOption(
              content: TrackLabelText(
                info: formatAudioTrackLabel(context, stream),
                selected: stream.index == currentIndex,
              ),
              selected: stream.index == currentIndex,
              onSelect: () => _selectAudio(stream),
            ))
        .toList();
  }

  List<PopoverOption> _subtitleOptions() {
    final playbackModel = ref.watch(playBackModel);
    final currentIndex = playbackModel?.mediaStreams?.defaultSubStreamIndex;
    final streams = [SubStreamModel.no(), ...?playbackModel?.subStreams];
    return streams
        .map((stream) => PopoverOption(
              content: TrackLabelText(
                info: formatSubtitleTrackLabel(context, stream),
                selected: stream.index == (currentIndex ?? -1),
              ),
              selected: stream.index == (currentIndex ?? -1),
              onSelect: () => _selectSubtitle(stream),
            ))
        .toList();
  }

  List<PopoverOption> _imageOptions() {
    final settings = ref.watch(videoPlayerSettingsProvider);
    final fitIndex = BoxFit.values.indexOf(settings.videoFit);
    return [
      PopoverOption(
        content: _PopoverSettingRow(
          label: context.localized.scale,
          value: settings.videoFit.name.toUpperCaseSplit(),
        ),
        onSelect: () => ref
            .read(videoPlayerSettingsProvider.notifier)
            .setFitType(BoxFit.values[(fitIndex + 1) % BoxFit.values.length]),
      ),
      PopoverOption(
        content: _PopoverSettingRow(
          label: context.localized.playerSettingsAmbientBlurTitle,
          // Coûteux en 4K sur RDNA2 (BackdropFilter par image) —
          // désactivé par défaut, cf. CLAUDE.md.
          value: settings.ambientBlur ? 'Activé' : 'Désactivé',
        ),
        selected: settings.ambientBlur,
        onSelect: () => ref
            .read(videoPlayerSettingsProvider.notifier)
            .setAmbientBlur(!settings.ambientBlur),
      ),
    ];
  }

  List<PopoverOption> _speedOptions() {
    final current = ref.watch(playbackRateProvider);
    return _speedPresets
        .map((speed) => PopoverOption(
              content: Text('x${speed.toStringAsFixed(2)}'),
              selected: (current - speed).abs() < 0.001,
              onSelect: () {
                ref.read(playbackRateProvider.notifier).state = speed;
                ref.read(videoPlayerProvider).setSpeed(speed);
              },
            ))
        .toList();
  }

  List<PopoverOption> _qualityOptions() {
    final options =
        ref.watch(playBackModel.select((value) => value?.bitRateOptions)) ?? {};
    final visible = <MapEntry<Bitrate, bool>>[];
    final collapsed = <MapEntry<Bitrate, bool>>[];
    for (final entry in options.entries) {
      if (entry.key == Bitrate.original || entry.key == Bitrate.auto) {
        visible.add(entry);
      } else {
        collapsed.add(entry);
      }
    }
    final result = visible
        .map((entry) => PopoverOption(
              content: Text(entry.key.label(context)),
              selected: entry.value,
              onSelect: () => _selectQuality(options, entry.key),
            ))
        .toList();
    if (collapsed.isNotEmpty) {
      result.add(PopoverOption(
        content: Row(
          children: [
            Expanded(
                child: Text('Débit limité',
                    style: Theme.of(context)
                        .textTheme
                        .bodyMedium
                        ?.copyWith(color: AppColors.textPrimary))),
            Icon(
              _qualityExpanded
                  ? Icons.expand_less_rounded
                  : Icons.expand_more_rounded,
              size: 18,
              color: AppColors.textSecondary,
            ),
          ],
        ),
        onSelect: () => setState(() => _qualityExpanded = !_qualityExpanded),
      ));
      if (_qualityExpanded) {
        result.addAll(collapsed.map((entry) => PopoverOption(
              content: Padding(
                padding: const EdgeInsets.only(left: AppSpacing.md),
                child: Text(entry.key.label(context)),
              ),
              selected: entry.value,
              onSelect: () => _selectQuality(options, entry.key),
            )));
      }
    }
    return result;
  }

  Widget bottomButtons(BuildContext context) {
    return Consumer(builder: (context, ref, child) {
      final playing =
          ref.watch(mediaPlaybackProvider.select((state) => state.playing));
      final bitRateOptions =
          ref.watch(playBackModel.select((value) => value?.bitRateOptions));
      return Container(
        key: _bottomControlsKey,
        decoration: BoxDecoration(
            gradient: LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [
            Colors.black.withValues(alpha: 0.8),
            Colors.black.withValues(alpha: 0),
          ],
        )),
        child: Padding(
          padding: MediaQuery.paddingOf(context).add(
            const EdgeInsets.symmetric(horizontal: 16).copyWith(bottom: 12),
          ),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Consumer(
                  builder: (context, ref, child) {
                    final mediaPlayback = ref.watch(mediaPlaybackProvider);
                    return progressBar(mediaPlayback);
                  },
                ),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Flexible(
                    flex: 2,
                    child: Row(
                      children: <Widget>[
                        IconButton(
                            onPressed: () => showVideoPlayerOptions(
                                context, () => minimizePlayer(context)),
                            icon: const Icon(IconsaxPlusLinear.more)),
                        if (pipPlatformSupported &&
                            MediaQuery.orientationOf(context) ==
                                Orientation.landscape)
                          IconButton(
                            tooltip: context.localized.pictureInPictureTitle,
                            onPressed: () async {
                              final ok =
                                  await ref.read(pipManagerProvider).enter();
                              if (!ok && context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                      content: Text(context.localized
                                          .pictureInPictureNotSupported)),
                                );
                              }
                            },
                            icon: const Icon(IconsaxPlusLinear.screenmirroring),
                          ),
                        if (AdaptiveLayout.layoutOf(context) ==
                            ViewSize.tablet) ...[
                          IconButton(
                            onPressed: () => showSubSelection(context),
                            icon: const Icon(IconsaxPlusLinear.subtitle),
                          ),
                          IconButton(
                            onPressed: () => showAudioSelection(context),
                            icon: const Icon(IconsaxPlusLinear.audio_square),
                          ),
                        ],
                        if (AdaptiveLayout.layoutOf(context) >=
                            ViewSize.desktop) ...[
                          Flexible(
                            child: ElevatedButton.icon(
                              onPressed: () => showSubSelection(context),
                              icon: const Icon(IconsaxPlusLinear.subtitle),
                              label: Text(
                                ref.watch(playBackModel.select((value) {
                                      final language = value?.mediaStreams
                                          ?.currentSubStream?.language;
                                      return language?.isEmpty == true
                                          ? context.localized.off
                                          : language;
                                    }))?.capitalize() ??
                                    "",
                                maxLines: 1,
                              ),
                            ),
                          ),
                          Flexible(
                            child: ElevatedButton.icon(
                              onPressed: () => showAudioSelection(context),
                              icon: const Icon(IconsaxPlusLinear.audio_square),
                              label: Text(
                                ref.watch(playBackModel.select((value) {
                                      final language = value?.mediaStreams
                                          ?.currentAudioStream?.language;
                                      return language?.isEmpty == true
                                          ? context.localized.off
                                          : language;
                                    }))?.capitalize() ??
                                    "",
                                maxLines: 1,
                              ),
                            ),
                          )
                        ],
                      ].addInBetween(const SizedBox(
                        width: 4,
                      )),
                    ),
                  ),
                  previousButton,
                  seekBackwardButton(ref),
                  IconButton.filledTonal(
                    iconSize: 38,
                    onPressed: () {
                      ref.read(videoPlayerProvider).playOrPause();
                    },
                    icon: Icon(
                      playing ? IconsaxPlusBold.pause : IconsaxPlusBold.play,
                    ),
                  ),
                  seekForwardButton(ref),
                  nextVideoButton,
                  Flexible(
                    flex: 2,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        if (initInputDevice == InputDevice.pointer ||
                            AdaptiveLayout.of(context).isDesktop)
                          Tooltip(
                            message: context.localized.stop,
                            child: IconButton(
                              onPressed: () => closePlayer(),
                              icon: const Icon(IconsaxPlusLinear.close_square),
                            ),
                          ),
                        const Spacer(),
                        if (AdaptiveLayout.viewSizeOf(context) >=
                                ViewSize.tablet &&
                            ref.read(videoPlayerProvider).hasPlayer) ...{
                          if (bitRateOptions?.isNotEmpty == true)
                            Tooltip(
                              message: context.localized.qualityOptionsTitle,
                              child: IconButton(
                                onPressed: () => openQualityOptions(context),
                                icon: const Icon(IconsaxPlusLinear.speedometer),
                              ),
                            ),
                        },
                        if ((initInputDevice == InputDevice.pointer ||
                                AdaptiveLayout.of(context).isDesktop) &&
                            AdaptiveLayout.viewSizeOf(context) >
                                ViewSize.phone) ...[
                          VideoVolumeSlider(
                            onChanged: () => resetTimer(),
                          ),
                          const FullScreenButton(),
                        ]
                      ].addInBetween(const SizedBox(width: 8)),
                    ),
                  ),
                ].addInBetween(const SizedBox(width: 6)),
              ),
            ],
          ),
        ),
      );
    });
  }

  Widget progressBar(MediaPlaybackModel mediaPlayback) {
    return Consumer(
      builder: (context, ref, child) {
        final playbackModel = ref.watch(playBackModel);
        final item = playbackModel?.item;
        final List<String?> details = [
          if (AdaptiveLayout.of(context).isDesktop)
            item?.label(context.localized),
          context.localized.endsAt(DateTime.now().add(Duration(
            milliseconds: (mediaPlayback.duration.inMilliseconds -
                    mediaPlayback.position.inMilliseconds) ~/
                ref.read(playbackRateProvider),
          )))
        ];
        return Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    details.nonNulls.join(' - '),
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.bold),
                    maxLines: 2,
                  ),
                ),
                const Spacer(),
                if (playbackModel != null)
                  InkWell(
                    onTap: () => showVideoPlaybackInformation(context),
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        child: Text(
                          playbackModel.label(context) ?? "",
                        ),
                      ),
                    ),
                  ),
                if (item != null) ...{
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      child: Text(
                        item.streamModel?.mediaInfoTag ?? "",
                      ),
                    ),
                  ),
                },
              ].addPadding(const EdgeInsets.symmetric(horizontal: 4)),
            ),
            const SizedBox(height: 4),
            SizedBox(
              height: 25,
              child: VideoProgressBar(
                wasPlayingChanged: (value) => wasPlaying = value,
                wasPlaying: wasPlaying,
                duration: mediaPlayback.duration,
                position: mediaPlayback.position,
                buffer: mediaPlayback.buffer,
                buffering: mediaPlayback.buffering,
                timerReset: () => timer.reset(),
                onPositionChanged: (position) =>
                    ref.read(videoPlayerProvider).seek(position),
              ),
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  mediaPlayback.position.readAbleDuration,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                Text(
                  "-${(mediaPlayback.duration - mediaPlayback.position).readAbleDuration}",
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  Widget get previousButton {
    return Consumer(
      builder: (context, ref, child) {
        final previousVideo =
            ref.watch(playBackModel.select((value) => value?.previousVideo));
        return Tooltip(
          message: previousVideo?.detailedName(context.localized) ?? "",
          textAlign: TextAlign.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            color:
                Theme.of(context).colorScheme.surface.withValues(alpha: 0.95),
          ),
          textStyle: Theme.of(context).textTheme.labelLarge,
          child: IconButton(
            onPressed: loadPreviousVideo(ref, video: previousVideo),
            iconSize: 30,
            icon: const Icon(
              IconsaxPlusLinear.backward,
            ),
          ),
        );
      },
    );
  }

  Function()? loadPreviousVideo(WidgetRef ref, {ItemBaseModel? video}) {
    final previousVideo = video ??
        ref.read(playBackModel.select((value) => value?.previousVideo));
    final buffering =
        ref.read(mediaPlaybackProvider.select((value) => value.buffering));
    return previousVideo != null && !buffering
        ? () => ref.read(playbackModelHelper).loadNewVideo(previousVideo)
        : null;
  }

  Widget get nextVideoButton {
    return Consumer(
      builder: (context, ref, child) {
        final nextVideo =
            ref.watch(playBackModel.select((value) => value?.nextVideo));
        return Tooltip(
          message: nextVideo?.detailedName(context.localized) ?? "",
          textAlign: TextAlign.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            color:
                Theme.of(context).colorScheme.surface.withValues(alpha: 0.95),
          ),
          textStyle: Theme.of(context).textTheme.labelLarge,
          child: IconButton(
            onPressed: loadNextVideo(ref, video: nextVideo),
            iconSize: 30,
            icon: const Icon(
              IconsaxPlusLinear.forward,
            ),
          ),
        );
      },
    );
  }

  Function()? loadNextVideo(WidgetRef ref, {ItemBaseModel? video}) {
    final nextVideo =
        video ?? ref.read(playBackModel.select((value) => value?.nextVideo));
    final buffering =
        ref.read(mediaPlaybackProvider.select((value) => value.buffering));
    return nextVideo != null && !buffering
        ? () => ref.read(playbackModelHelper).loadNewVideo(nextVideo)
        : null;
  }

  Widget seekBackwardButton(WidgetRef ref) {
    final backwardSpeed = ref.read(userProvider.select(
        (value) => value?.userSettings?.skipBackDuration.inSeconds ?? 30));
    return IconButton(
      onPressed: () => seekBack(ref, seconds: backwardSpeed),
      tooltip: "-$backwardSpeed",
      iconSize: 40,
      icon: Stack(
        alignment: Alignment.center,
        children: [
          const Icon(
            IconsaxPlusBroken.refresh,
            size: 45,
          ),
          Transform.translate(
            offset: const Offset(0, 1),
            child: Text(
              "-$backwardSpeed",
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }

  Widget seekForwardButton(WidgetRef ref) {
    final forwardSpeed = ref.read(userProvider.select(
        (value) => value?.userSettings?.skipForwardDuration.inSeconds ?? 30));
    return IconButton(
      onPressed: () => seekForward(ref, seconds: forwardSpeed),
      tooltip: forwardSpeed.toString(),
      iconSize: 40,
      icon: Stack(
        alignment: Alignment.center,
        children: [
          Transform.flip(
            flipX: true,
            child: const Icon(
              IconsaxPlusBroken.refresh,
              size: 45,
            ),
          ),
          Transform.translate(
            offset: const Offset(0, 1),
            child: Text(
              forwardSpeed.toString(),
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }

  void skipToSegmentEnd(MediaSegment? mediaSegment, String? segmentId) {
    final end = mediaSegment?.end;
    if (end != null) {
      resetTimer();
      ref.read(videoPlayerProvider).seek(end);

      if (segmentId != null) {
        Future(() {
          final currentSkipped =
              ref.read(mediaPlaybackProvider).skippedSegments;
          ref.read(mediaPlaybackProvider.notifier).update(
                (state) => state.copyWith(
                  skippedSegments: {...currentSkipped, segmentId},
                ),
              );
        });
      }
    }
  }

  void seekBack(WidgetRef ref, {int seconds = 15}) {
    _seek(ref, -seconds);
  }

  void seekForward(WidgetRef ref, {int seconds = 15}) {
    _seek(ref, seconds);
  }

  void _seek(WidgetRef ref, int seconds) {
    final mediaPlayback = ref.read(mediaPlaybackProvider);
    resetTimer();
    final newPosition = (mediaPlayback.position.inSeconds + seconds)
        .clamp(0, mediaPlayback.duration.inSeconds);
    ref.read(videoPlayerProvider).seek(Duration(seconds: newPosition));
  }

  void stepBack(WidgetRef ref) {
    _step(ref, -1);
  }

  void stepForward(WidgetRef ref) {
    _step(ref, 1);
  }

  void _step(WidgetRef ref, int frames) {
    final mediaPlayback = ref.read(mediaPlaybackProvider);
    final framerate = ref.read(playBackModel
        .select((value) => value?.mediaStreams?.videoStreams.first.frameRate));
    if (framerate == null || framerate == 0) return;

    final step = ((1000000.0 / framerate) * frames).round();
    resetTimer();
    final newPosition = (mediaPlayback.position.inMicroseconds + step)
        .clamp(0, mediaPlayback.duration.inMicroseconds);
    ref.read(videoPlayerProvider).seek(Duration(microseconds: newPosition));
  }

  void seekBackWithIndicator() {
    _seekController.seekBack();
  }

  void seekForwardWithIndicator() {
    _seekController.seekForward();
  }

  bool get _anyPopoverOpen =>
      _audioPopover.isOpen ||
      _subtitlesPopover.isOpen ||
      _imagePopover.isOpen ||
      _speedPopover.isOpen ||
      _qualityPopover.isOpen;

  // Reste affiché tant que la lecture est en pause, et tant qu'un
  // popover est ouvert — dans ces deux cas, il n'y a rien à masquer, et
  // masquer quand même laisserait le popover ou les contrôles inatteignables.
  void toggleOverlay({bool? value}) {
    final requested = value ?? !showOverlay;
    final playing = ref.read(mediaPlaybackProvider.select((v) => v.playing));
    final mustStayVisible = !playing || _anyPopoverOpen;
    final desired = mustStayVisible || requested;

    if (showOverlay != desired) {
      setState(() => showOverlay = desired);

      final desiredMode =
          desired ? SystemUiMode.edgeToEdge : SystemUiMode.immersiveSticky;
      if (_currentSystemUiMode != desiredMode) {
        _currentSystemUiMode = desiredMode;
        SystemChrome.setEnabledSystemUIMode(desiredMode, overlays: []);
      }

      SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        systemNavigationBarDividerColor: Colors.transparent,
      ));
    }

    // Repart à chaque appel plutôt que seulement au changement d'état :
    // un mouvement de souris pendant que le voile est déjà affiché doit
    // quand même repousser l'inactivité de 3s, pas la laisser courir
    // depuis la première apparition du voile.
    if (mustStayVisible) {
      timer.cancel();
    } else {
      resetTimer();
    }
  }

  void minimizePlayer(BuildContext context) {
    clearOverlaySettings();
    ref
        .read(mediaPlaybackProvider.notifier)
        .update((state) => state.copyWith(state: VideoPlayerState.minimized));
    Navigator.of(context).pop();
  }

  void resetTimer() => timer.reset();

  Future<void> closePlayer() async {
    clearOverlaySettings();
    ref.read(videoPlayerProvider).stop();
    Navigator.of(context).pop();
  }

  Future<void> clearOverlaySettings() async {
    toggleOverlay(value: true);
    if (initInputDevice != InputDevice.pointer) {
      ScreenBrightness().resetApplicationScreenBrightness();
    } else {
      disableFullScreen();
    }

    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
      statusBarIconBrightness: ref.read(clientSettingsProvider
          .select((value) => value.statusBarBrightness(context))),
    ));

    timer.cancel();
  }

  Future<void> disableFullScreen() async {
    resetTimer();
    if (AdaptiveLayout.of(context).isDesktop &&
        defaultTargetPlatform != TargetPlatform.macOS) {
      fullScreenHelper.closeFullScreen(ref);
    }
  }

  void setVolume(PointerEvent event) {
    if (event is PointerScrollEvent) {
      if (event.scrollDelta.dy > 0) {
        ref.read(videoPlayerSettingsProvider.notifier).steppedVolume(-5);
      } else {
        ref.read(videoPlayerSettingsProvider.notifier).steppedVolume(5);
      }
    }
  }

  void _activateSpeedBoost() {
    if (_speedBoostActive) return;

    final settings = ref.read(videoPlayerSettingsProvider);
    if (!settings.enableSpeedBoost) return;

    _originalSpeed = ref.read(playbackRateProvider);
    _speedBoostActive = true;
    ref.read(videoPlayerProvider).setSpeed(settings.speedBoostRate);
    ref.read(playbackRateProvider.notifier).state = settings.speedBoostRate;
  }

  void _deactivateSpeedBoost() {
    if (!_speedBoostActive) return;

    _speedBoostActive = false;
    if (_originalSpeed != null) {
      ref.read(videoPlayerProvider).setSpeed(_originalSpeed!);
      ref.read(playbackRateProvider.notifier).state = _originalSpeed!;
      _originalSpeed = null;
    }
  }

  // --- Keyboard Speed Boost Handler (Desktop) ---

  KeyEventResult _handleSpacebarEvent(KeyEvent event) {
    if (event is KeyDownEvent) {
      return KeyEventResult.handled;
    } else if (event is KeyRepeatEvent) {
      final isPlaying =
          ref.read(mediaPlaybackProvider.select((value) => value.playing));
      if (isPlaying) {
        _activateSpeedBoost();
      }
      return KeyEventResult.handled;
    } else if (event is KeyUpEvent) {
      if (_speedBoostActive) {
        _deactivateSpeedBoost();
      } else {
        ref.read(videoPlayerProvider).playOrPause();
      }
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  // --- Touch Gesture Handlers (Mobile) ---

  void _handleDoubleTapDown(TapDownDetails details) {
    final doubleTapSeekEnabled = ref.read(videoPlayerSettingsProvider
        .select((value) => value.enableDoubleTapSeek));
    if (doubleTapSeekEnabled) {
      _doubleTapPosition = details.globalPosition;
    }
  }

  void _handleDoubleTapSeek() {
    final doubleTapSeekEnabled = ref.read(videoPlayerSettingsProvider
        .select((value) => value.enableDoubleTapSeek));
    if (!doubleTapSeekEnabled) return;

    final screenWidth = MediaQuery.sizeOf(context).width;
    final tapX = _doubleTapPosition?.dx ?? screenWidth / 2;
    final zoneThird = screenWidth / 3;

    if (tapX < zoneThird) {
      seekBackWithIndicator();
    } else if (tapX > zoneThird * 2) {
      seekForwardWithIndicator();
    } else {
      ref.read(videoPlayerProvider).playOrPause();
    }
    _doubleTapPosition = null;
  }

  void _handleLongPressStart(LongPressStartDetails details) {
    final settings = ref.read(videoPlayerSettingsProvider);
    final isPlaying =
        ref.read(mediaPlaybackProvider.select((value) => value.playing));
    if (settings.enableSpeedBoost && isPlaying) {
      _activateSpeedBoost();
    }
  }

  void _handleLongPressEnd(LongPressEndDetails details) {
    _deactivateSpeedBoost();
  }

  Future<void> _handleVerticalDragStart(DragStartDetails details) async {
    final settings = ref.read(videoPlayerSettingsProvider);
    if (!settings.enableEdgeGestures) return;

    final size = MediaQuery.sizeOf(context);
    final y = details.localPosition.dy;
    // Safety margin of 10% top/bottom to avoid accidental system gestures (notification tray, home bar)
    if (y < size.height * 0.1 || y > size.height * 0.9) {
      _vDragSide = null;
      return;
    }

    final isLeft = details.localPosition.dx < size.width / 2;
    final isBrightness = settings.reverseEdgeGestures ? !isLeft : isLeft;

    _vDragSide = isBrightness ? 'brightness' : 'volume';

    if (isBrightness) {
      _vDragStartValue = settings.screenBrightness ?? 1.0;
    } else {
      final currentVolume = ({TargetPlatform.android, TargetPlatform.iOS}
              .contains(defaultTargetPlatform))
          ? (await VolumeController.instance.getVolume())
          : settings.volume / 100;
      _vDragStartValue = currentVolume;
    }
    _vDragLastValue = _vDragStartValue;
  }

  void _handleVerticalDragUpdate(DragUpdateDetails details) {
    if (_vDragSide == null || _vDragStartValue == null) return;

    final screenHeight = MediaQuery.sizeOf(context).height;
    // Slide up to increase, down to decrease.
    // details.delta.dy is positive when sliding down.
    final delta = -details.primaryDelta! /
        (screenHeight * 0.7); // 70% of screen height for full range
    final newValue = (_vDragLastValue! + delta).clamp(0.0, 1.0);

    if (newValue == _vDragLastValue) return;
    _vDragLastValue = newValue;

    if (_vDragSide == 'brightness') {
      ref
          .read(videoPlayerSettingsProvider.notifier)
          .setScreenBrightness(newValue);
    } else {
      ref.read(videoPlayerSettingsProvider.notifier).setVolume(newValue * 100);
    }
  }

  void _handleVerticalDragEnd(DragEndDetails details) {
    _vDragSide = null;
    _vDragStartValue = null;
    _vDragLastValue = null;
  }

  void _toggleSubtitles() {
    final playbackModel = ref.read(playBackModel);
    final player = ref.read(videoPlayerProvider);
    final subStreams = playbackModel?.subStreams;

    if (subStreams == null || subStreams.isEmpty) return;

    // Filter out the "off" track (index == -1)
    final availableSubtitles = subStreams.where((s) => s.index != -1).toList();
    if (availableSubtitles.isEmpty) return;

    final currentIndex =
        playbackModel?.mediaStreams?.defaultSubStreamIndex ?? -1;
    if (currentIndex != -1) {
      // Subtitles are ON -> Turn OFF and remember this index
      _lastSelectedSubtitleIndex = currentIndex;
      _setSubtitleTrack(SubStreamModel.no(), playbackModel, player);
    } else {
      // Subtitles are OFF -> Turn ON
      if (_lastSelectedSubtitleIndex != null) {
        // Use the last selected index
        final lastSub = subStreams.firstWhere(
          (s) => s.index == _lastSelectedSubtitleIndex,
          orElse: () => availableSubtitles.first,
        );
        _setSubtitleTrack(lastSub, playbackModel, player);
      } else if (availableSubtitles.length == 1) {
        // If only one subtitle is available, just use it
        _setSubtitleTrack(availableSubtitles.first, playbackModel, player);
      } else {
        // Multiple subtitles and no last selection -> Show selection dialog
        showSubSelection(context).then((_) {
          final newModel = ref.read(playBackModel);
          final selectedIndex = newModel?.mediaStreams?.defaultSubStreamIndex;
          if (selectedIndex != null && selectedIndex != -1) {
            _lastSelectedSubtitleIndex = selectedIndex;
          }
        });
      }
    }
  }

  void _setSubtitleTrack(SubStreamModel subModel, PlaybackModel? playbackModel,
      dynamic player) async {
    if (playbackModel == null) return;
    final newModel = await playbackModel.setSubtitle(subModel, player);
    ref.read(playBackModel.notifier).update((state) => newModel);
    if (newModel != null) {
      await ref.read(playbackModelHelper).shouldReload(newModel);
    }
  }

  bool _onKey(VideoHotKeys value) {
    final mediaSegments =
        ref.read(playBackModel.select((value) => value?.mediaSegments));
    final position = ref.read(mediaPlaybackProvider).position;
    final playing =
        ref.read(mediaPlaybackProvider.select((value) => value.playing));

    MediaSegment? segment = mediaSegments?.atPosition(position);

    final volume =
        ref.read(videoPlayerSettingsProvider.select((value) => value.volume));

    switch (value) {
      case VideoHotKeys.playPause:
        if (_speedBoostActive) {
          return false;
        }
        ref.read(videoPlayerProvider).playOrPause();
        return true;
      case VideoHotKeys.volumeUp:
        resetTimer();
        ref.read(videoPlayerSettingsProvider.notifier).steppedVolume(5);
        return true;
      case VideoHotKeys.volumeDown:
        resetTimer();
        ref.read(videoPlayerSettingsProvider.notifier).steppedVolume(-5);
        return true;
      case VideoHotKeys.speedUp:
        resetTimer();
        ref.read(videoPlayerSettingsProvider.notifier).steppedSpeed(0.1);
        return true;
      case VideoHotKeys.speedDown:
        resetTimer();
        ref.read(videoPlayerSettingsProvider.notifier).steppedSpeed(-0.1);
        return true;
      case VideoHotKeys.fullScreen:
        fullScreenHelper.toggleFullScreen(ref);
        return true;
      case VideoHotKeys.skipMediaSegment:
        if (segment != null) {
          skipToSegmentEnd(segment, null);
        }
        return true;
      case VideoHotKeys.exit:
        if (ModalRoute.of(context)?.isCurrent == true) {
          closePlayer();
          return true;
        }
        return false;

      case VideoHotKeys.mute:
        if (volume != 0) {
          previousVolume = volume;
        }
        ref
            .read(videoPlayerSettingsProvider.notifier)
            .setVolume(volume == 0 ? (previousVolume ?? 100) : 0);
        return true;
      case VideoHotKeys.nextVideo:
        loadNextVideo(ref)?.call();
        return true;
      case VideoHotKeys.prevVideo:
        loadPreviousVideo(ref)?.call();
        return true;
      case VideoHotKeys.nextChapter:
        ref.read(videoPlayerSettingsProvider.notifier).nextChapter();
        return true;
      case VideoHotKeys.prevChapter:
        ref.read(videoPlayerSettingsProvider.notifier).prevChapter();
        return true;
      case VideoHotKeys.toggleSubtitles:
        // Desktop : ouvre le popover Sous-titres, comme le bouton de la
        // barre. Ailleurs (pas de popover hors desktop) : bascule
        // rapide sans UI, comportement déjà en place.
        if (AdaptiveLayout.of(context).isDesktop || kIsWeb) {
          _subtitlesPopover.toggle();
        } else {
          _toggleSubtitles();
        }
        return true;
      case VideoHotKeys.openAudioPanel:
        if (AdaptiveLayout.of(context).isDesktop || kIsWeb) {
          _audioPopover.toggle();
          return true;
        }
        return false;
      case VideoHotKeys.seekForward:
        // Fixe à 10s, indépendant de la durée de saut configurée pour les
        // boutons à l'écran (cf. seekForwardInstant : même principe).
        seekForward(ref, seconds: 10);
        return true;
      case VideoHotKeys.seekBack:
        seekBack(ref, seconds: 10);
        return true;
      case VideoHotKeys.seekForwardInstant:
        seekForward(ref, seconds: 60);
        return true;
      case VideoHotKeys.seekBackInstant:
        seekBack(ref, seconds: 60);
        return true;
      case VideoHotKeys.stepForward:
        playing
            ? ref.read(videoPlayerProvider).playOrPause()
            : stepForward(ref);
        return true;
      case VideoHotKeys.stepBack:
        playing ? ref.read(videoPlayerProvider).playOrPause() : stepBack(ref);
        return true;
      default:
        return false;
    }
  }
}

const _speedPresets = [0.5, 0.75, 1.0, 1.25, 1.5, 1.75, 2.0];

class _PopoverSettingRow extends StatelessWidget {
  final String label;
  final String value;
  const _PopoverSettingRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(label,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: AppColors.textPrimary)),
        ),
        Text(value,
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: AppColors.textSecondary)),
      ],
    );
  }
}
