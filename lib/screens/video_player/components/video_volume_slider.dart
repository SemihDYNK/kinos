import 'package:kinos/theme/app_icons.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:kinos/providers/settings/video_player_settings_provider.dart';
import 'package:kinos/theme/app_theme.dart';
import 'package:kinos/util/localization_helper.dart';
import 'package:kinos/widgets/shared/segmented_track.dart';

/// Barre de volume — même grammaire visuelle que la barre de progression
/// (`video_progress_bar.dart`) : piste unique [SegmentedTrack], pas le
/// rendu "pilule" à trou de [KinosSlider]/`GappedContainerShape`
/// (l'ancien rendu, hors DA — un `KinosSlider` sans couleurs explicites
/// retombe sur les couleurs Material par défaut, jamais les jetons).
class VideoVolumeSlider extends ConsumerStatefulWidget {
  final Function()? onChanged;
  const VideoVolumeSlider({this.onChanged, super.key});

  @override
  ConsumerState<ConsumerStatefulWidget> createState() =>
      _VideoVolumeSliderState();
}

class _VideoVolumeSliderState extends ConsumerState<VideoVolumeSlider> {
  bool _hovering = false;
  bool _dragging = false;
  bool _focused = false;
  double? _previousVolume;
  final _focusNode = FocusNode(debugLabel: 'VideoVolumeSlider');

  /// 96 px en bureau (`AppSpacing.md` × 6) — pas de jeton dédié à cette
  /// largeur précise, dérivée du seul jeton d'espacement disponible
  /// plutôt qu'un littéral isolé.
  static const _trackWidth = AppSpacing.md * 6;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(_onFocusChange);
  }

  void _onFocusChange() {
    setState(() => _focused = _focusNode.hasFocus);
  }

  @override
  void dispose() {
    _focusNode.removeListener(_onFocusChange);
    _focusNode.dispose();
    super.dispose();
  }

  void _updateVolume(double value) {
    if (!{TargetPlatform.android, TargetPlatform.iOS}
        .contains(defaultTargetPlatform)) {
      ref
          .read(videoPlayerSettingsProvider.notifier)
          .setVolume(value.clamp(0.0, 100.0));
    }
    widget.onChanged?.call();
  }

  void _toggleMute(double volume) {
    if (volume != 0) _previousVolume = volume;
    _updateVolume(volume == 0 ? (_previousVolume ?? 100) : 0);
  }

  void _handlePointer(Offset localPosition) {
    _updateVolume((localPosition.dx / _trackWidth) * 100);
  }

  KeyEventResult _handleKey(FocusNode node, KeyEvent event, double volume) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
      _updateVolume(volume - 5);
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
      _updateVolume(volume + 5);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final volume =
        ref.watch(videoPlayerSettingsProvider.select((value) => value.volume));
    final isVisible = _hovering || _dragging || _focused;
    final density = context.tokens.density;
    final trackHeight =
        isVisible ? SegmentedTrack.heightHover : SegmentedTrack.heightRest;

    return Row(
      mainAxisSize: MainAxisSize.min,
      spacing: AppSpacing.xxs,
      children: [
        FocusRing(
          borderRadius: AppRadii.controlBorder,
          onActivate: () => _toggleMute(volume),
          child: ExcludeFocus(
            child: Tooltip(
              // Pas de clé `unmute` existante côté l10n (seule `mute`
              // existe) — même convention que 'Réduire'/'Image'/
              // 'Vitesse'/'Qualité' juste au-dessus dans
              // `video_player_controls.dart` : chaîne française directe
              // plutôt qu'une nouvelle clé à traduire dans chaque .arb
              // pour ce seul libellé.
              message:
                  volume == 0 ? 'Rétablir le son' : context.localized.mute,
              child: IconButton(
                onPressed: () => _toggleMute(volume),
                icon: Icon(volumeIcon(volume)),
              ),
            ),
          ),
        ),
        // `Focus` externe pour les flèches ±5 : `FocusRing` ne mappe en
        // interne qu'Entrée/Espace (bascule muet, sans action ici — la
        // piste n'a pas d'"activation" au sens de FocusRing) ; un
        // événement clavier non consommé par ses raccourcis remonte
        // naturellement à cet ancêtre, sans avoir à modifier le widget
        // partagé pour ce seul besoin.
        Focus(
          onKeyEvent: (node, event) => _handleKey(node, event, volume),
          child: FocusRing(
            focusNode: _focusNode,
            borderRadius: AppRadii.controlBorder,
            child: MouseRegion(
              onEnter: (_) => setState(() => _hovering = true),
              onExit: (_) => setState(() => _hovering = false),
              child: Listener(
                onPointerDown: (event) {
                  _focusNode.requestFocus();
                  setState(() => _dragging = true);
                  _handlePointer(event.localPosition);
                },
                onPointerMove: (event) => _handlePointer(event.localPosition),
                onPointerUp: (_) => setState(() => _dragging = false),
                // Cible tactile suffisante en mode salon
                // (`AppDensity.couch`, `density.minTarget`) même si la
                // piste elle-même reste fine — même principe que la
                // barre de progression (zone interactive plus grande
                // que le trait peint).
                child: SizedBox(
                  width: _trackWidth,
                  height: density.minTarget,
                  child: Stack(
                    alignment: Alignment.center,
                    clipBehavior: Clip.none,
                    children: [
                      AnimatedContainer(
                        duration: AppDurations.hover,
                        height: trackHeight,
                        width: _trackWidth,
                        child: SegmentedTrack(
                          height: trackHeight,
                          primaryFraction: volume / 100,
                        ),
                      ),
                      // Pouce — visible seulement au survol/glissement/
                      // focus (`isVisible`), même traitement que la
                      // barre de progression.
                      Positioned(
                        left: (_trackWidth * volume / 100)
                            .clamp(0, _trackWidth),
                        child: Transform.translate(
                          offset: const Offset(-AppSpacing.xxs / 2, 0),
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
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        SizedBox(
          width: 32,
          child: Text(
            volume.toStringAsFixed(0),
            textAlign: TextAlign.center,
            style: AppTypography.meta.copyWith(
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ),
      ],
    );
  }
}

IconData volumeIcon(double value) {
  if (value <= 0) {
    return AppIcons.muted;
  }
  if (value < 50) {
    return AppIcons.volumeLow;
  }
  return AppIcons.volumeHigh;
}
