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

import 'package:fladder/models/item_base_model.dart';
import 'package:fladder/models/items/media_segments_model.dart';
import 'package:fladder/models/items/media_streams_model.dart';
import 'package:fladder/models/media_playback_model.dart';
import 'package:fladder/models/playback/playback_model.dart';
import 'package:fladder/models/settings/video_player_settings.dart';
import 'package:fladder/providers/pip_provider.dart';
import 'package:fladder/providers/settings/client_settings_provider.dart';
import 'package:fladder/providers/settings/video_player_settings_provider.dart';
import 'package:fladder/providers/user_provider.dart';
import 'package:fladder/providers/video_player_provider.dart';
import 'package:fladder/screens/shared/default_title_bar.dart';
import 'package:fladder/screens/shared/media/components/item_logo.dart';
import 'package:fladder/screens/video_player/components/video_playback_information.dart';
import 'package:fladder/screens/video_player/components/video_player_brightness_indicator.dart';
import 'package:fladder/screens/video_player/components/video_player_controls_extras.dart';
import 'package:fladder/screens/video_player/components/video_player_options_sheet.dart';
import 'package:fladder/screens/video_player/components/video_player_quality_controls.dart';
import 'package:fladder/screens/video_player/components/video_player_screenshot_indicator.dart';
import 'package:fladder/screens/video_player/components/video_player_seek_indicator.dart';
import 'package:fladder/screens/video_player/components/video_player_speed_indicator.dart';
import 'package:fladder/screens/video_player/components/video_player_volume_indicator.dart';
import 'package:fladder/screens/video_player/components/video_progress_bar.dart';
import 'package:fladder/screens/video_player/components/video_quality_badge.dart';
import 'package:fladder/screens/video_player/components/video_side_panel.dart';
import 'package:fladder/screens/video_player/components/video_volume_slider.dart';
import 'package:fladder/theme/app_theme.dart';
import 'package:fladder/util/adaptive_layout/adaptive_layout.dart';
import 'package:fladder/util/duration_extensions.dart';
import 'package:fladder/util/input_handler.dart';
import 'package:fladder/util/list_padding.dart';
import 'package:fladder/util/localization_helper.dart';
import 'package:fladder/util/string_extensions.dart';
import 'package:fladder/widgets/full_screen_helpers/full_screen_wrapper.dart';
import 'package:fladder/wrappers/pip_manager.dart';

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

  // Panneau unique (audio/sous-titres/image/vitesse/qualité) — desktop
  // uniquement. `_panelReturnFocus` retient le contrôle actif avant
  // l'ouverture, pour lui rendre le focus à la fermeture (Échap).
  VideoPanelSection? _openPanelSection;
  FocusNode? _panelReturnFocus;

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
                // Panneau unique — glisse par-dessus la vidéo sans la
                // recentrer, jamais affiché hors desktop (pas de place
                // pour un panneau latéral fixe en dessous de cette taille
                // d'écran, et aucun bouton n'y ouvre).
                if (isDesktop)
                  AnimatedPositioned(
                    duration: fadeDuration,
                    top: 0,
                    bottom: 0,
                    right: _openPanelSection != null ? 0 : -videoSidePanelWidth,
                    child: _openPanelSection == null
                        ? const SizedBox.shrink()
                        : VideoSidePanel(
                            initialSection: _openPanelSection!,
                            onClose: _closePanel,
                          ),
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
                        _desktopPanelButton(
                          icon: IconsaxPlusLinear.subtitle,
                          tooltip: _tooltipFor(
                              'Sous-titres', VideoHotKeys.toggleSubtitles),
                          section: VideoPanelSection.subtitles,
                        ),
                        _desktopPanelButton(
                          icon: IconsaxPlusLinear.audio_square,
                          tooltip:
                              _tooltipFor('Audio', VideoHotKeys.openAudioPanel),
                          section: VideoPanelSection.audio,
                        ),
                        _desktopPanelButton(
                          icon: Icons.tune_rounded,
                          tooltip: 'Réglages (image, vitesse, qualité)',
                          section: VideoPanelSection.quality,
                        ),
                      ],
                    ),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      VideoVolumeSlider(onChanged: () => resetTimer()),
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
              const SizedBox(height: AppSpacing.xs),
              _shortcutsHintRow(context),
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

  Widget _desktopPanelButton({
    required IconData icon,
    required String tooltip,
    required VideoPanelSection section,
  }) {
    final isOpen = _openPanelSection == section;
    return FocusRing(
      borderRadius: AppRadii.controlBorder,
      onActivate: () => isOpen ? _closePanel() : _openPanel(section),
      child: ExcludeFocus(
        child: Tooltip(
          message: tooltip,
          child: IconButton(
            isSelected: isOpen,
            onPressed: () => isOpen ? _closePanel() : _openPanel(section),
            icon: Icon(icon,
                color:
                    isOpen ? AppColors.textPrimary : AppColors.textSecondary),
          ),
        ),
      ),
    );
  }

  /// Raccourcis affichés en clair, pas seulement dans les infobulles —
  /// règle explicite de cette refonte.
  Widget _shortcutsHintRow(BuildContext context) {
    const hints = [
      ('Espace', 'Lecture/pause'),
      ('←/→', '±10 s'),
      ('Maj+←/→', '±60 s'),
      ('↑/↓', 'Volume'),
      ('M', 'Muet'),
      ('S', 'Sous-titres'),
      ('A', 'Audio'),
      ('F', 'Plein écran'),
      ('Échap', 'Quitter'),
    ];
    return Wrap(
      spacing: AppSpacing.md,
      runSpacing: AppSpacing.xxs,
      children: [
        for (final (key, action) in hints)
          Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: '$key ',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.textPrimary.withValues(alpha: 0.75)),
                ),
                TextSpan(
                  text: action,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.textPrimary.withValues(alpha: 0.5)),
                ),
              ],
            ),
          ),
      ],
    );
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

  // Reste affiché tant que la lecture est en pause, et tant que le
  // panneau est ouvert — dans ces deux cas, il n'y a rien à masquer, et
  // masquer quand même laisserait le panneau ou les contrôles inatteignables.
  void toggleOverlay({bool? value}) {
    final requested = value ?? !showOverlay;
    final playing = ref.read(mediaPlaybackProvider.select((v) => v.playing));
    final mustStayVisible = !playing || _openPanelSection != null;
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

  /// Ouvre le panneau sur [section] — retient le contrôle qui avait le
  /// focus (une seule fois, `??=` : plusieurs changements de section
  /// pendant que le panneau est ouvert ne doivent pas écraser le point de
  /// retour d'origine) pour le lui rendre à la fermeture.
  void _openPanel(VideoPanelSection section) {
    _panelReturnFocus ??= FocusManager.instance.primaryFocus;
    setState(() => _openPanelSection = section);
    toggleOverlay(value: true);
  }

  void _closePanel() {
    setState(() => _openPanelSection = null);
    final returnFocus = _panelReturnFocus;
    _panelReturnFocus = null;
    if (returnFocus != null && returnFocus.canRequestFocus) {
      returnFocus.requestFocus();
    }
    resetTimer();
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
        // Desktop : ouvre le panneau sur Sous-titres, comme le bouton de
        // la barre — cohérent avec "tout passe par le même panneau".
        // Ailleurs (le panneau n'existe pas hors desktop) : bascule
        // rapide sans UI, comportement déjà en place.
        if (AdaptiveLayout.of(context).isDesktop || kIsWeb) {
          _openPanel(VideoPanelSection.subtitles);
        } else {
          _toggleSubtitles();
        }
        return true;
      case VideoHotKeys.openAudioPanel:
        if (AdaptiveLayout.of(context).isDesktop || kIsWeb) {
          _openPanel(VideoPanelSection.audio);
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
