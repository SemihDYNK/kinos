import 'package:flutter/material.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:overflow_view/overflow_view.dart';

import 'package:kinos/models/item_base_model.dart';
import 'package:kinos/models/media_playback_model.dart';
import 'package:kinos/providers/video_player_provider.dart';
import 'package:kinos/theme/app_theme.dart';
import 'package:kinos/util/duration_extensions.dart';
import 'package:kinos/util/localization_helper.dart';
import 'package:kinos/widgets/navigation_scaffold/components/shared/player_bar_shared.dart';
import 'package:kinos/widgets/shared/item_actions.dart';

/// Lecteur réduit (bandeau du bas, visible pendant une lecture minimisée)
/// — même langage visuel que le lecteur plein écran : voile
/// [AppColors.scrim], pas un aplat gris posé sur le contenu.
class VideoFloatingPlayerBarContent extends ConsumerWidget {
  const VideoFloatingPlayerBarContent({
    super.key,
    required this.constraints,
    required this.item,
    required this.itemActions,
    required this.showExpandButton,
    required this.onShowExpandButton,
    required this.openFullScreenPlayer,
  });

  final BoxConstraints constraints;
  final ItemBaseModel? item;
  final List<ItemActionButton> itemActions;
  final bool showExpandButton;
  final ValueChanged<bool> onShowExpandButton;
  final VoidCallback openFullScreenPlayer;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playbackState = ref.watch(mediaPlaybackProvider.select((state) => (
          state: state.state,
          duration: state.duration,
          playing: state.playing,
        )));
    final player = ref.read(videoPlayerProvider);

    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            AppColors.scrim.withValues(alpha: 0.75),
            AppColors.scrim.withValues(alpha: 0.92),
          ],
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Information principale de ce bandeau — pleine largeur, en
          // tête, avant même le titre. Cliquable et manipulable au
          // clavier une fois focalisée (KinosSlider, cf. player_bar_
          // shared.dart).
          FloatingPlayerBarProgress(
            height: 3,
            activeColor: AppColors.textPrimary,
            inactiveColor: AppColors.progressTrack,
            onSeek: (pos) async {
              final player = ref.read(videoPlayerProvider);
              await player.seek(pos);
              await Future.delayed(const Duration(milliseconds: 250));
              if (player.lastState?.playing == true) {
                player.play();
              }
            },
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(6),
              child: Row(
                spacing: 12,
                mainAxisSize: MainAxisSize.max,
                mainAxisAlignment: MainAxisAlignment.start,
                children: [
                  if (playbackState.state == VideoPlayerState.minimized)
                    FloatingPlayerBarPreview(
                      ratio: 16 / 9,
                      showExpandButton: showExpandButton,
                      onShowExpandButton: onShowExpandButton,
                      openFullScreenPlayer: openFullScreenPlayer,
                      child: player.videoWidget(
                            const ValueKey("mini_player_video"),
                            BoxFit.fitHeight,
                          ) ??
                          const SizedBox.shrink(),
                    ),
                  Expanded(
                    child: FloatingPlayerBarTitle(
                      title: item?.title ?? "",
                      subtitle: item?.detailedName(context.localized) ?? "",
                      onTap: () => item?.navigateTo(context),
                    ),
                  ),
                  Expanded(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        if (constraints.maxWidth > 500)
                          Consumer(
                            builder: (context, ref, _) {
                              final pos = ref.watch(mediaPlaybackProvider
                                  .select((s) => s.position));
                              return Flexible(
                                child: Text(
                                  "${pos.readAbleDuration} / ${playbackState.duration.readAbleDuration}",
                                  // Typographie tabulaire : chaque
                                  // chiffre a la même largeur, le
                                  // compteur ne saute plus latéralement
                                  // à chaque seconde.
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodySmall
                                      ?.copyWith(
                                    color: AppColors.textPrimary
                                        .withValues(alpha: 0.75),
                                    fontFeatures: const [
                                      FontFeature.tabularFigures()
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        Flexible(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            child: FocusRing(
                              borderRadius: AppRadii.controlBorder,
                              onActivate: () =>
                                  ref.read(videoPlayerProvider).playOrPause(),
                              child: ExcludeFocus(
                                child: IconButton.filledTonal(
                                  onPressed: () => ref
                                      .read(videoPlayerProvider)
                                      .playOrPause(),
                                  icon: playbackState.playing
                                      ? const Icon(Icons.pause_rounded)
                                      : const Icon(Icons.play_arrow_rounded),
                                ),
                              ),
                            ),
                          ),
                        ),
                        Flexible(
                          child: OverflowView.flexible(
                            builder: (context, remainingItemCount) =>
                                PopupMenuButton(
                              iconColor:
                                  AppColors.textPrimary.withValues(alpha: 0.6),
                              padding: EdgeInsets.zero,
                              itemBuilder: (context) => itemActions
                                  .sublist(
                                      itemActions.length - remainingItemCount)
                                  .map((e) => e.toPopupMenuItem(useIcons: true))
                                  .toList(),
                            ),
                            children:
                                itemActions.map((e) => e.toButton()).toList(),
                          ),
                        ),
                        // Retour au plein écran — toujours visible et
                        // atteignable au clavier (contrairement au survol
                        // de la vignette, réservé à la souris) ; symétrique
                        // du bouton "Réduire" du lecteur plein écran.
                        FocusRing(
                          borderRadius: AppRadii.controlBorder,
                          onActivate: openFullScreenPlayer,
                          child: ExcludeFocus(
                            child: Tooltip(
                              message: 'Plein écran',
                              child: IconButton(
                                onPressed: openFullScreenPlayer,
                                icon: const Icon(Icons.fullscreen_rounded),
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
