import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iconsax_plus/iconsax_plus.dart';
import 'package:window_manager/window_manager.dart';

import 'package:kinos/models/items/audio_model.dart';
import 'package:kinos/models/media_playback_model.dart';
import 'package:kinos/providers/settings/video_player_settings_provider.dart';
import 'package:kinos/providers/user_provider.dart';
import 'package:kinos/providers/video_player_provider.dart';
import 'package:kinos/screens/shared/kinos_notification_overlay.dart';
import 'package:kinos/screens/video_player/video_player.dart';
import 'package:kinos/theme.dart';
import 'package:kinos/util/adaptive_layout/adaptive_layout.dart';
import 'package:kinos/util/localization_helper.dart';
import 'package:kinos/util/refresh_state.dart';
import 'package:kinos/widgets/navigation_scaffold/components/music_player_bar_content.dart';
import 'package:kinos/widgets/navigation_scaffold/components/video_player_bar_content.dart';
import 'package:kinos/widgets/shared/item_actions.dart';

double floatingPlayerHeight(BuildContext context) =>
    switch (AdaptiveLayout.viewSizeOf(context)) {
      ViewSize.phone => 75,
      ViewSize.tablet => 85,
      ViewSize.desktop => 95,
      ViewSize.television => 105,
    };

class FloatingPlayerBar extends ConsumerStatefulWidget {
  const FloatingPlayerBar({super.key});

  @override
  ConsumerState<ConsumerStatefulWidget> createState() =>
      _CurrentlyPlayingBarState();
}

class _CurrentlyPlayingBarState extends ConsumerState<FloatingPlayerBar> {
  bool showExpandButton = false;
  bool _opening = false;

  Future<void> openFullScreenPlayer() async {
    if (_opening) return;
    setState(() => showExpandButton = false);
    final item = ref.read(playBackModel.select((value) => value?.item));
    if (item is AudioModel) {
      ref.read(mediaPlaybackProvider.notifier).update(
          (state) => state.copyWith(state: VideoPlayerState.fullScreen));
      if (mounted) {
        await context.refreshData();
      }
      return;
    }
    final isDesktop = AdaptiveLayout.of(context).isDesktop || kIsWeb;
    _opening = true;
    try {
      await Navigator.of(context, rootNavigator: true).push(
        MaterialPageRoute(
          // Keep both the mini player and the full-size texture live.
          allowSnapshotting: false,
          builder: (context) => const VideoPlayer(),
        ),
      );
    } finally {
      _opening = false;
    }
    if (isDesktop) {
      final fullScreen = await windowManager.isFullScreen();
      if (fullScreen) {
        await windowManager.setFullScreen(false);
      }
    }
    if (mounted) {
      await context.refreshData();
    }
  }

  void _setShowExpandButton(bool value) {
    if (showExpandButton != value) {
      setState(() => showExpandButton = value);
    }
  }

  @override
  Widget build(BuildContext context) {
    final item = ref.watch(playBackModel.select((value) => value?.item));
    final isFavourite = item?.userData.isFavourite == true;
    final isDesktop = AdaptiveLayout.of(context).isDesktop;

    final volumeAction = ItemActionButton(
        label: Text(context.localized.audio(1)),
        icon: Consumer(
          builder: (context, ref, child) {
            final playerVolume = ref.watch(
                videoPlayerSettingsProvider.select((value) => value.volume));
            return Icon(playerVolume == 0
                ? IconsaxPlusBold.volume_cross
                : IconsaxPlusBold.volume_high);
          },
        ),
        action: () {
          final playerVolume = ref.read(
              videoPlayerSettingsProvider.select((value) => value.volume));
          final volume = playerVolume == 0 ? 100.0 : 0.0;
          ref.read(videoPlayerSettingsProvider.notifier).setVolume(volume);
        });
    final favouriteAction = ItemActionButton(
      label: Text(isFavourite
          ? context.localized.removeAsFavorite
          : context.localized.addAsFavorite),
      icon: Icon(
        color: isFavourite ? Colors.red : null,
        isFavourite ? IconsaxPlusBold.heart : IconsaxPlusLinear.heart,
      ),
      action: () async {
        final result = (await ref.read(userProvider.notifier).setAsFavorite(
                  !isFavourite,
                  item?.id ?? "",
                ))
            ?.body;

        if (result != null) {
          ref
              .read(playBackModel.notifier)
              .update((state) => state?.updateUserData(result));
        }
      },
    );
    final stopAction = ItemActionButton(
      label: Text(context.localized.stop),
      action: () async => ref.read(videoPlayerProvider).stop(),
      icon: const Icon(IconsaxPlusBold.stop),
    );

    // Musique : inchangé (favori compris). Vidéo : pas de cœur ici —
    // c'est une action de catalogue, déjà sur la fiche juste au-dessus.
    final itemActions = [volumeAction, favouriteAction, stopAction];
    final videoItemActions = [volumeAction, stopAction];

    // La barre latérale est un calque semi-transparent posé par-dessus un
    // contenu plein cadre (cf. CLAUDE.md) : ce bandeau doit s'arrêter
    // avant sa largeur, sinon il passe dessous — même débordement déjà
    // rencontré une fois sur le bandeau teinté du tableau de bord.
    final sideBarInset =
        isDesktop ? AdaptiveLayout.of(context).sideBarWidth : 0.0;

    return Padding(
      padding: MediaQuery.paddingOf(context).copyWith(
        left: isDesktop ? sideBarInset : 8,
        right: isDesktop ? 0 : 8,
        top: 0,
        bottom: isDesktop ? 0 : MediaQuery.paddingOf(context).bottom,
      ),
      child: Dismissible(
        key: const Key("CurrentlyPlayingBar"),
        confirmDismiss: (direction) async {
          if (direction == DismissDirection.up) {
            await openFullScreenPlayer();
          } else {
            await ref.read(videoPlayerProvider).stop();
          }
          return false;
        },
        direction: DismissDirection.vertical,
        child: InkWell(
          onLongPress: () => KinosSnack.show(
              "Swipe up/down to open/close the player",
              context: context),
          child: Container(
            height: floatingPlayerHeight(context),
            clipBehavior: Clip.hardEdge,
            decoration: BoxDecoration(
              // Musique : inchangée (aplat surfaceContainerLow, hors
              // périmètre de cette refonte). Vidéo : sa propre décoration
              // (voile AppColors.scrim), posée par
              // VideoFloatingPlayerBarContent lui-même.
              color: item is AudioModel
                  ? Theme.of(context).colorScheme.surfaceContainerLow
                  : null,
              borderRadius: KinosTheme.defaultShape.borderRadius,
            ),
            child: LayoutBuilder(builder: (context, constraints) {
              return switch (item) {
                AudioModel audioItem => MusicFloatingPlayerBarContent(
                    constraints: constraints,
                    item: audioItem,
                    itemActions: itemActions,
                    showExpandButton: showExpandButton,
                    onShowExpandButton: _setShowExpandButton,
                    openFullScreenPlayer: openFullScreenPlayer,
                  ),
                _ => VideoFloatingPlayerBarContent(
                    constraints: constraints,
                    item: item,
                    itemActions: videoItemActions,
                    showExpandButton: showExpandButton,
                    onShowExpandButton: _setShowExpandButton,
                    openFullScreenPlayer: openFullScreenPlayer,
                  ),
              };
            }),
          ),
        ),
      ),
    );
  }
}
