import 'package:flutter/material.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:overflow_view/overflow_view.dart';

import 'package:kinos/models/media_playback_model.dart';
import 'package:kinos/providers/video_player_provider.dart';
import 'package:kinos/screens/shared/flat_button.dart';
import 'package:kinos/theme/app_theme.dart';
import 'package:kinos/util/adaptive_layout/adaptive_layout.dart';
import 'package:kinos/util/duration_extensions.dart';
import 'package:kinos/widgets/shared/fladder_slider.dart';
import 'package:kinos/widgets/shared/item_actions.dart';

const videoPlayerHeroTag = "HeroPlayer";

class FloatingPlayerBarPreview extends StatelessWidget {
  const FloatingPlayerBarPreview({
    super.key,
    this.ratio = 1.0,
    required this.showExpandButton,
    required this.onShowExpandButton,
    required this.openFullScreenPlayer,
    required this.child,
  });

  final double ratio;
  final bool showExpandButton;
  final ValueChanged<bool> onShowExpandButton;
  final VoidCallback openFullScreenPlayer;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: AspectRatio(
        aspectRatio: ratio,
        child: MouseRegion(
          onEnter: (_) => onShowExpandButton(true),
          onExit: (_) => onShowExpandButton(false),
          child: Stack(
            children: [
              Hero(
                tag: videoPlayerHeroTag,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: child,
                ),
              ),
              Positioned.fill(
                child: Tooltip(
                  message: "Expand player",
                  waitDuration: const Duration(milliseconds: 500),
                  child: AnimatedOpacity(
                    opacity: showExpandButton ? 1 : 0,
                    duration: const Duration(milliseconds: 125),
                    child: Container(
                      color: AppColors.scrim.withValues(alpha: 0.6),
                      child: FlatButton(
                        onTap: openFullScreenPlayer,
                        child: const Icon(Icons.keyboard_arrow_up_rounded),
                      ),
                    ),
                  ),
                ),
              )
            ],
          ),
        ),
      ),
    );
  }
}

class FloatingPlayerBarTitle extends StatelessWidget {
  const FloatingPlayerBarTitle({
    super.key,
    required this.title,
    required this.subtitle,
    this.onTap,
  });

  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: Text(
              title,
              style: Theme.of(context).textTheme.titleMedium,
              maxLines: 1,
            ),
          ),
          if (subtitle.isNotEmpty)
            Flexible(
              child: Text(
                subtitle,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: 0.65),
                    ),
                maxLines: 1,
              ),
            ),
        ],
      ),
    );
  }
}

class FloatingPlayerBarActionsRow extends StatelessWidget {
  const FloatingPlayerBarActionsRow({
    super.key,
    required this.constraints,
    required this.playbackInfo,
    required this.lastPosition,
    required this.onPlayPause,
    required this.itemActions,
  });

  final BoxConstraints constraints;
  final MediaPlaybackModel playbackInfo;
  final Duration lastPosition;
  final VoidCallback onPlayPause;
  final List<ItemActionButton> itemActions;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        if (constraints.maxWidth > 500)
          Flexible(
            child: Text(
                "${lastPosition.readAbleDuration} / ${playbackInfo.duration.readAbleDuration}"),
          ),
        Flexible(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: IconButton.filledTonal(
              onPressed: onPlayPause,
              icon: playbackInfo.playing
                  ? const Icon(Icons.pause_rounded)
                  : const Icon(Icons.play_arrow_rounded),
            ),
          ),
        ),
        Flexible(
          child: OverflowView.flexible(
            builder: (context, remainingItemCount) => PopupMenuButton(
              iconColor: Theme.of(context)
                  .colorScheme
                  .onSurface
                  .withValues(alpha: 0.45),
              padding: EdgeInsets.zero,
              itemBuilder: (context) => itemActions
                  .sublist(itemActions.length - remainingItemCount)
                  .map((e) => e.toPopupMenuItem(useIcons: true))
                  .toList(),
            ),
            children: itemActions.map((e) => e.toButton()).toList(),
          ),
        )
      ],
    );
  }
}

class FloatingPlayerBarProgress extends ConsumerStatefulWidget {
  const FloatingPlayerBarProgress({
    super.key,
    required this.onSeek,
    this.height = 8,
    this.activeColor,
    this.inactiveColor,
  });

  final Future<void> Function(Duration) onSeek;

  /// Hauteur de la barre — 8 par défaut (lecteur musique, inchangé) ;
  /// le lecteur vidéo réduit en passe une plus fine explicitement (cf.
  /// VideoFloatingPlayerBarContent), c'est l'information principale de
  /// ce bandeau, pas un détail secondaire, mais elle ne doit pas
  /// rivaliser avec le contenu de la ligne du dessous.
  final double height;

  /// `null` conserve l'apparence historique (couleur primaire du thème
  /// ambiant) — seul le lecteur vidéo réduit passe les jetons du projet
  /// explicitement, pour ne rien changer côté musique (hors périmètre
  /// de cette réécriture).
  final Color? activeColor;
  final Color? inactiveColor;

  @override
  ConsumerState<FloatingPlayerBarProgress> createState() =>
      _FloatingPlayerBarProgressState();
}

class _FloatingPlayerBarProgressState
    extends ConsumerState<FloatingPlayerBarProgress> {
  Duration? _dragPosition;

  @override
  Widget build(BuildContext context) {
    final playback = ref.watch(mediaPlaybackProvider.select((s) => (
          position: s.position,
          duration: s.duration,
        )));
    final position = _dragPosition ?? playback.position;
    final activeColor =
        widget.activeColor ?? Theme.of(context).colorScheme.primary;
    final inactiveColor =
        widget.inactiveColor ?? Colors.black.withValues(alpha: 0.25);

    return AdaptiveLayout.inputDeviceOf(context) == InputDevice.pointer
        ? SizedBox(
            height: widget.height,
            child: FladderSlider(
              value: position.inMilliseconds.toDouble(),
              min: 0.0,
              max: playback.duration.inMilliseconds.toDouble(),
              thumbWidth: widget.height,
              activeTrackColor: activeColor,
              inactiveTrackColor: inactiveColor,
              onChangeStart: (value) => setState(
                  () => _dragPosition = Duration(milliseconds: value.toInt())),
              onChanged: (value) => setState(
                  () => _dragPosition = Duration(milliseconds: value.toInt())),
              onChangeEnd: (value) async {
                final seekPos = Duration(milliseconds: value.toInt());
                setState(() => _dragPosition = seekPos);
                await widget.onSeek(seekPos);
                if (mounted) setState(() => _dragPosition = null);
              },
            ),
          )
        : LinearProgressIndicator(
            minHeight: widget.height,
            backgroundColor: inactiveColor,
            color: activeColor,
            value: playback.duration.inMilliseconds > 0
                ? (position.inMilliseconds / playback.duration.inMilliseconds)
                    .clamp(0, 1)
                : 0,
          );
  }
}
