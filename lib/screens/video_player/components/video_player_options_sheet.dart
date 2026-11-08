import 'dart:async';

import 'package:kinos/widgets/shared/frosted_surface.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:collection/collection.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iconsax_plus/iconsax_plus.dart';

import 'package:kinos/models/item_base_model.dart';
import 'package:kinos/models/items/episode_model.dart';
import 'package:kinos/models/playback/direct_playback_model.dart';
import 'package:kinos/models/playback/offline_playback_model.dart';
import 'package:kinos/models/playback/playback_model.dart';
import 'package:kinos/models/playback/transcode_playback_model.dart';
import 'package:kinos/models/settings/video_player_settings.dart';
import 'package:kinos/providers/settings/video_player_settings_provider.dart';
import 'package:kinos/providers/settings/subtitle_settings_provider.dart';
import 'package:kinos/providers/remote_subtitles_provider.dart';
import 'package:kinos/providers/user_provider.dart';
import 'package:kinos/providers/video_player_provider.dart';
import 'package:kinos/screens/collections/add_to_collection.dart';
import 'package:kinos/screens/metadata/info_screen.dart';
import 'package:kinos/screens/playlists/add_to_playlists.dart';
import 'package:kinos/screens/video_player/components/video_player_quality_controls.dart';
import 'package:kinos/screens/video_player/components/video_player_queue.dart';
import 'package:kinos/screens/video_player/components/video_subtitle_controls.dart';
import 'package:kinos/theme/app_theme.dart';
import 'package:kinos/util/adaptive_layout/adaptive_layout.dart';
import 'package:kinos/util/device_orientation_extension.dart';
import 'package:kinos/util/list_padding.dart';
import 'package:kinos/util/localization_helper.dart';
import 'package:kinos/util/map_bool_helper.dart';
import 'package:kinos/util/refresh_state.dart';
import 'package:kinos/util/string_extensions.dart';
import 'package:kinos/widgets/shared/enum_selection.dart';
import 'package:kinos/widgets/shared/kinos_slider.dart';
import 'package:kinos/widgets/shared/item_actions.dart';
import 'package:kinos/widgets/shared/labeled_selector.dart';
import 'package:kinos/widgets/shared/modal_bottom_sheet.dart';
import 'package:kinos/widgets/shared/spaced_list_tile.dart';

Future<void> showVideoPlayerOptions(
    BuildContext context, Function() minimizePlayer) {
  return showBottomSheetPill(
    context: context,
    content: (context, scrollController) {
      return VideoOptions(
        controller: scrollController,
        minimizePlayer: minimizePlayer,
      );
    },
  );
}

class VideoOptions extends ConsumerStatefulWidget {
  final ScrollController controller;
  final Function() minimizePlayer;
  const VideoOptions(
      {required this.controller, required this.minimizePlayer, super.key});

  @override
  ConsumerState<ConsumerStatefulWidget> createState() =>
      _VideoOptionsMobileState();
}

class _VideoOptionsMobileState extends ConsumerState<VideoOptions> {
  late int page = 0;

  @override
  Widget build(BuildContext context) {
    final currentItem = ref.watch(playBackModel.select((value) => value?.item));
    final videoSettings = ref.watch(videoPlayerSettingsProvider);
    final currentMediaStreams =
        ref.watch(playBackModel.select((value) => value?.mediaStreams));
    final bitRateOptions =
        ref.watch(playBackModel.select((value) => value?.bitRateOptions));

    Widget mainPage() {
      return ListView(
        key: const Key("mainPage"),
        shrinkWrap: true,
        controller: widget.controller,
        children: [
          InkWell(
            onTap: () => setState(() => page = 2),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  Column(
                    mainAxisSize: MainAxisSize.max,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        currentItem?.title ?? "",
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ],
                  ),
                  const Spacer(),
                  const Opacity(
                      opacity: 0.1, child: Icon(Icons.info_outline_rounded))
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          const Divider(height: 1),
          const SizedBox(height: 12),
          if (!AdaptiveLayout.of(context).isDesktop)
            ListTile(
              title: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Flexible(
                      flex: 1, child: Text(context.localized.screenBrightness)),
                  Flexible(
                    child: Row(
                      children: [
                        Flexible(
                          child: Opacity(
                            opacity: videoSettings.screenBrightness == null
                                ? 0.5
                                : 1,
                            child: Slider(
                              value: videoSettings.screenBrightness ?? 1.0,
                              min: 0,
                              max: 1,
                              onChanged: (value) => ref
                                  .read(videoPlayerSettingsProvider.notifier)
                                  .setScreenBrightness(value),
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: () => ref
                              .read(videoPlayerSettingsProvider.notifier)
                              .setScreenBrightness(null),
                          icon: Opacity(
                            opacity: videoSettings.screenBrightness != null
                                ? 0.5
                                : 1,
                            child: Icon(
                              IconsaxPlusBold.autobrightness,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ),
                        )
                      ],
                    ),
                  ),
                ],
              ),
            ),
          SpacedListTile(
            title: Text(context.localized.subtitles),
            content: Text(
                currentMediaStreams?.currentSubStream?.label(context) ??
                    context.localized.off),
            onTap: currentMediaStreams?.subStreams.isNotEmpty == true
                ? () => showSubSelection(context)
                : null,
          ),
          SpacedListTile(
            title: Text(context.localized.audio(1)),
            content: Text(
                currentMediaStreams?.currentAudioStream?.label(context) ??
                    context.localized.off),
            onTap: currentMediaStreams?.audioStreams.isNotEmpty == true
                ? () => showAudioSelection(context)
                : null,
          ),
          ListTile(
            title: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: EnumSelection(
                    label: Text(context.localized.scale),
                    current: videoSettings.videoFit.name.toUpperCaseSplit(),
                    itemBuilder: (context) => BoxFit.values
                        .map((value) => ItemActionButton(
                              label: Text(value.name.toUpperCaseSplit()),
                              action: () => ref
                                  .read(videoPlayerSettingsProvider.notifier)
                                  .setFitType(value),
                            ))
                        .toList(),
                  ),
                ),
              ],
            ),
          ),
          SwitchListTile(
            title: Text(context.localized.playerSettingsAmbientBlurTitle),
            value: videoSettings.ambientBlur,
            onChanged: (value) {
              ref
                  .read(videoPlayerSettingsProvider.notifier)
                  .setAmbientBlur(value == true);
            },
          ),
          if (!AdaptiveLayout.of(context).isDesktop)
            ListTile(
              onTap: () => ref
                  .read(videoPlayerSettingsProvider.notifier)
                  .setFillScreen(!videoSettings.fillScreen),
              title: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Expanded(
                    flex: 3,
                    child: Text(context.localized.videoScalingFill),
                  ),
                  const Spacer(),
                  Switch(
                    value: videoSettings.fillScreen,
                    onChanged: (value) => ref
                        .read(videoPlayerSettingsProvider.notifier)
                        .setFillScreen(value),
                  )
                ],
              ),
            ),
          if (!AdaptiveLayout.of(context).isDesktop && !kIsWeb)
            SpacedListTile(
              title: Text(context.localized.playerSettingsOrientationTitle),
              onTap: () => showOrientationOptions(context, ref),
            ),
          ListTile(
            onTap: () {
              Navigator.of(context).pop();
              showPlaybackSpeed(context);
            },
            title: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Expanded(
                  flex: 3,
                  child: Text(context.localized.playbackRate),
                ),
                const Spacer(),
                Text("x${ref.watch(playbackRateProvider)}")
              ],
            ),
          ),
          if (bitRateOptions?.isNotEmpty == true)
            ListTile(
              title: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Expanded(
                    flex: 3,
                    child: Text(context.localized.qualityOptionsTitle),
                  ),
                  const Spacer(),
                  Text(bitRateOptions?.enabledFirst.keys.firstOrNull
                          ?.label(context) ??
                      "")
                ],
              ),
              onTap: () {
                Navigator.of(context).pop();
                openQualityOptions(context);
              },
            )
        ],
      );
    }

    Widget playbackSettings() {
      final playbackState = ref.watch(playBackModel);
      return ListView(
        key: const Key("PlaybackSettings"),
        shrinkWrap: true,
        controller: widget.controller,
        children: [
          navTitle(context.localized.playBackSettings, null),
          if (playbackState?.queue.isNotEmpty == true)
            ListTile(
              leading: const Icon(Icons.video_collection_rounded),
              title: const Text("Show queue"),
              onTap: () {
                Navigator.of(context).pop();
                ref.read(videoPlayerProvider).pause();
                showFullScreenItemQueue(
                  context,
                  items: playbackState?.queue ?? [],
                  currentItem: playbackState?.item,
                  onSectionReorder: (section, oldIndex, newIndex) {
                    return ref
                        .read(videoPlayerProvider.notifier)
                        .reorderAudioQueueSection(
                          section,
                          oldIndex,
                          newIndex,
                        );
                  },
                  playSelected:
                      ref.read(videoPlayerProvider.notifier).playAudioQueueItem,
                );
              },
            )
        ],
      );
    }

    return Column(
      children: [
        AnimatedSize(
          duration: const Duration(milliseconds: 250),
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            child: switch (page) {
              1 => playbackSettings(),
              2 => itemInfo(currentItem, context),
              _ => mainPage(),
            },
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  ListView itemInfo(ItemBaseModel? currentItem, BuildContext context) {
    return ListView(
      shrinkWrap: true,
      controller: widget.controller,
      children: [
        navTitle(
            currentItem?.title, currentItem?.subTextShort(context.localized)),
        if (currentItem != null) ...{
          if (currentItem.type == KinosItemType.episode)
            ListTile(
              onTap: () {
                Navigator.of(context).pop();
                widget.minimizePlayer();
                (this as EpisodeModel).parentBaseModel.navigateTo(context);
              },
              title: Text(context.localized.openShow),
            ),
          ListTile(
            onTap: () async {
              Navigator.of(context).pop();
              widget.minimizePlayer();
              await currentItem.navigateTo(context);
            },
            title: Text(context.localized.showDetails),
          ),
          if (currentItem.type != KinosItemType.boxset)
            ListTile(
              onTap: () async {
                await addItemToCollection(context, [currentItem]);
                if (context.mounted) {
                  context.refreshData();
                }
              },
              title: Text(context.localized.addToCollection),
            ),
          if (currentItem.type != KinosItemType.playlist)
            ListTile(
              onTap: () async {
                await addItemToPlaylist(context, [currentItem]);
                if (context.mounted) {
                  context.refreshData();
                }
              },
              title: Text(context.localized.addToPlaylist),
            ),
          ListTile(
            onTap: () async {
              final response = await ref
                  .read(userProvider.notifier)
                  .setAsFavorite(!(currentItem.userData.isFavourite == true),
                      currentItem.id);
              final newItem = currentItem.copyWith(userData: response?.body);
              final playbackModel = switch (ref.read(playBackModel)) {
                DirectPlaybackModel value => value.copyWith(item: newItem),
                TranscodePlaybackModel value => value.copyWith(item: newItem),
                OfflinePlaybackModel value => value.copyWith(item: newItem),
                _ => null
              };
              ref.read(playBackModel.notifier).update((state) => playbackModel);
              Navigator.of(context).pop();
            },
            title: Text(currentItem.userData.isFavourite == true
                ? context.localized.removeAsFavorite
                : context.localized.addAsFavorite),
          ),
          ListTile(
            onTap: () {
              Navigator.of(context).pop();
              showInfoScreen(context, currentItem);
            },
            title: Text(context.localized.info),
          ),
        }
      ],
    );
  }

  Widget navTitle(String? title, String? subText) {
    return Column(
      children: [
        Row(
          children: [
            const SizedBox(width: 8),
            BackButton(
              onPressed: () => setState(() => page = 0),
            ),
            const SizedBox(width: 16),
            Column(
              children: [
                if (title != null)
                  Text(
                    title,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                if (subText != null)
                  Text(
                    subText,
                    style: Theme.of(context).textTheme.titleMedium,
                  )
              ],
            ),
          ],
        ),
        const SizedBox(height: 12),
        const Divider(height: 1),
        const SizedBox(height: 12),
      ],
    );
  }
}

Future<void> showSubSelection(BuildContext context) {
  return showDialog(
    context: context,
    builder: (context) {
      return Consumer(
        builder: (context, ref, child) {
          final playbackModel = ref.watch(playBackModel);
          final player = ref.watch(videoPlayerProvider);
          return GlassSimpleDialog(
            contentPadding: const EdgeInsets.only(top: 8, bottom: 24),
            title: Row(
              children: [
                Text(context.localized.subtitle),
                const Spacer(),
                IconButton.outlined(
                  tooltip: 'Rechercher des sous-titres',
                  onPressed: () {
                    Navigator.pop(context);
                    showRemoteSubtitleSearch(context);
                  },
                  icon: const Icon(Icons.search_rounded),
                ),
                if (player.backend == PlayerOptions.libMPV ||
                    player.backend == PlayerOptions.libMDK)
                  IconButton.outlined(
                      onPressed: () {
                        Navigator.pop(context);
                        showSubtitleControls(
                          context: context,
                          label: context.localized.subtitleConfiguration,
                        );
                      },
                      icon: const Icon(Icons.display_settings_rounded))
              ],
            ),
            children: playbackModel?.subStreams?.mapIndexed(
              (index, subModel) {
                final selected =
                    playbackModel.mediaStreams?.defaultSubStreamIndex ==
                        subModel.index;
                return ListTile(
                  title: Text(subModel.label(context)),
                  tileColor: selected
                      ? Theme.of(context)
                          .colorScheme
                          .primary
                          .withValues(alpha: 0.3)
                      : null,
                  subtitle: subModel.language.isNotEmpty
                      ? Opacity(
                          opacity: 0.6,
                          child: Text(subModel.language.capitalize()))
                      : null,
                  onTap: () async {
                    final newModel =
                        await playbackModel.setSubtitle(subModel, player);
                    ref
                        .read(playBackModel.notifier)
                        .update((state) => newModel);
                    if (newModel != null) {
                      await ref
                          .read(playbackModelHelper)
                          .shouldReload(newModel);
                    }
                  },
                );
              },
            ).toList(),
          );
        },
      );
    },
  );
}

Future<void> showSubtitleQuickControls(
  BuildContext context, {
  required Duration initialDelay,
  required ValueChanged<Duration> onDelayChanged,
}) {
  return showDialog(
    context: context,
    builder: (context) => _SubtitleQuickControlsDialog(
      initialDelay: initialDelay,
      onDelayChanged: onDelayChanged,
    ),
  );
}

class _SubtitleQuickControlsDialog extends ConsumerStatefulWidget {
  const _SubtitleQuickControlsDialog({
    required this.initialDelay,
    required this.onDelayChanged,
  });

  final Duration initialDelay;
  final ValueChanged<Duration> onDelayChanged;

  @override
  ConsumerState<_SubtitleQuickControlsDialog> createState() =>
      _SubtitleQuickControlsDialogState();
}

class _SubtitleQuickControlsDialogState
    extends ConsumerState<_SubtitleQuickControlsDialog> {
  late Duration _delay = widget.initialDelay;

  void _setDelay(Duration delay) {
    setState(() => _delay = delay);
    widget.onDelayChanged(delay);
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(subtitleSettingsProvider);
    final notifier = ref.read(subtitleSettingsProvider.notifier);
    final delayLabel =
        '${_delay.isNegative ? '' : '+'}${_delay.inMilliseconds} ms';

    return GlassAlertDialog(
      title: const Text('Personnaliser les sous-titres'),
      content: SizedBox(
        width: 440,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Décalage', style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: AppSpacing.xs),
            Row(
              children: [
                Text(delayLabel,
                    style: Theme.of(context).textTheme.titleMedium),
                const Spacer(),
                IconButton.outlined(
                  tooltip: 'Retarder de 50 ms',
                  onPressed: () =>
                      _setDelay(_delay - const Duration(milliseconds: 50)),
                  icon: const Icon(Icons.remove_rounded),
                ),
                TextButton(
                  onPressed: () => _setDelay(Duration.zero),
                  child: const Text('Réinitialiser'),
                ),
                IconButton.filledTonal(
                  tooltip: 'Avancer de 50 ms',
                  onPressed: () =>
                      _setDelay(_delay + const Duration(milliseconds: 50)),
                  icon: const Icon(Icons.add_rounded),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            Text('Taille', style: Theme.of(context).textTheme.labelLarge),
            Row(
              children: [
                const Icon(Icons.format_size_rounded),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: KinosSlider(
                    min: 8,
                    max: 160,
                    value: settings.fontSize.clamp(8.0, 160.0).toDouble(),
                    onChanged: (value) =>
                        notifier.setFontSize(value.roundToDouble()),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Text(settings.fontSize.toStringAsFixed(0)),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            Text('Position verticale',
                style: Theme.of(context).textTheme.labelLarge),
            Row(
              children: [
                const Icon(Icons.height_rounded),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: KinosSlider(
                    min: 0,
                    max: 1,
                    divisions: 80,
                    value: settings.verticalOffset.clamp(0.0, 1.0).toDouble(),
                    onChanged: notifier.setVerticalOffset,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.of(context).pop();
            showSubtitleControls(context: context, label: 'Réglages avancés');
          },
          child: const Text('Réglages avancés'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Terminé'),
        ),
      ],
    );
  }
}

Future<void> showRemoteSubtitleSearch(
  BuildContext context, {
  String? itemId,
  Future<void> Function()? onDownloaded,
}) {
  return showDialog(
    context: context,
    builder: (context) => _RemoteSubtitleSearchDialog(
      itemId: itemId,
      onDownloaded: onDownloaded,
    ),
  );
}

class _RemoteSubtitleSearchDialog extends ConsumerStatefulWidget {
  const _RemoteSubtitleSearchDialog({this.itemId, this.onDownloaded});

  final String? itemId;
  final Future<void> Function()? onDownloaded;

  @override
  ConsumerState<_RemoteSubtitleSearchDialog> createState() =>
      _RemoteSubtitleSearchDialogState();
}

class _RemoteSubtitleSearchDialogState
    extends ConsumerState<_RemoteSubtitleSearchDialog> {
  static const _languages = <String, String>{
    'fre': 'Français',
    'eng': 'Anglais',
    'spa': 'Espagnol',
    'deu': 'Allemand',
    'ita': 'Italien',
    'jpn': 'Japonais',
  };

  late String _language;
  String? _downloadingId;

  @override
  void initState() {
    super.initState();
    _language = _initialLanguage();
  }

  String _initialLanguage() {
    final preferred =
        ref.read(userProvider)?.userConfiguration?.subtitleLanguagePreference;
    return _languages.containsKey(preferred) ? preferred! : 'fre';
  }

  Future<void> _refreshDownloadedSubtitles() async {
    try {
      await widget.onDownloaded?.call();
    } catch (_) {
      // Le fichier est déjà enregistré par Jellyfin ; un rafraîchissement de
      // fiche raté ne doit pas le nier.
    }
  }

  @override
  Widget build(BuildContext context) {
    final itemId = widget.itemId ?? ref.watch(playBackModel)?.item.id;
    if (itemId == null) {
      return const GlassAlertDialog(
        content:
            Text('Aucun film ou épisode n’est disponible pour la recherche.'),
      );
    }

    return GlassAlertDialog(
      title: const Text('Rechercher des sous-titres'),
      content: SizedBox(
        width: 640,
        height: 520,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Langue des sous-titres',
                style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 8),
            SizedBox(
              width: 240,
              child: LabeledSelector(
                label: '',
                value: _languages[_language]!,
                options: _languages.entries
                    .map(
                      (entry) => (
                        label: entry.value,
                        selected: entry.key == _language,
                        onSelect: () => setState(() => _language = entry.key),
                        subtitle: null,
                      ),
                    )
                    .toList(),
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: FutureBuilder(
                future: ref
                    .read(remoteSubtitleServiceProvider)
                    .search(itemId, _language),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError) {
                    return const Center(
                        child: Text(
                            'Recherche indisponible. Réessaie plus tard.'));
                  }
                  final subtitles = snapshot.data ?? const [];
                  if (subtitles.isEmpty) {
                    return const Center(
                        child:
                            Text('Aucun sous-titre trouvé pour cette langue.'));
                  }
                  return ListView.separated(
                    itemCount: subtitles.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final subtitle = subtitles[index];
                      final details = [
                        _languages[
                            subtitle.threeLetterISOLanguageName?.toLowerCase()],
                        subtitle.providerName,
                        subtitle.format?.toUpperCase(),
                      ].whereType<String>().join(' · ');
                      final score = [
                        if (subtitle.communityRating != null)
                          '★ ${subtitle.communityRating!.toStringAsFixed(1)}',
                        if (subtitle.downloadCount != null)
                          '${subtitle.downloadCount} téléchargements',
                      ].join(' · ');
                      return ListTile(
                        contentPadding: const EdgeInsets.symmetric(vertical: 6),
                        title: Text(subtitle.name ?? 'Sous-titre'),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (details.isNotEmpty) Text(details),
                            if (score.isNotEmpty) Text(score),
                            if (subtitle.isHashMatch == true ||
                                subtitle.forced == true ||
                                subtitle.hearingImpaired == true)
                              Wrap(
                                spacing: 6,
                                children: [
                                  if (subtitle.isHashMatch == true)
                                    const Chip(
                                        label: Text('Correspondance exacte')),
                                  if (subtitle.forced == true)
                                    const Chip(label: Text('Forcé')),
                                  if (subtitle.hearingImpaired == true)
                                    const Chip(label: Text('SDH')),
                                ],
                              ),
                          ],
                        ),
                        trailing: FocusRing(
                          borderRadius: AppRadii.controlBorder,
                          child: FrostedSurface(
                            borderRadius: AppRadii.controlBorder,
                            child: TextButton(
                              onPressed: subtitle.id == null ||
                                      _downloadingId != null
                                  ? null
                                  : () async {
                                      setState(
                                          () => _downloadingId = subtitle.id);
                                      final messenger =
                                          ScaffoldMessenger.of(context);
                                      final navigator = Navigator.of(context,
                                          rootNavigator: true);
                                      try {
                                        await ref
                                            .read(remoteSubtitleServiceProvider)
                                            .download(itemId, subtitle.id!);
                                      } catch (_) {
                                        if (mounted) {
                                          setState(() => _downloadingId = null);
                                        }
                                        messenger.showSnackBar(
                                          const SnackBar(
                                            content: Text(
                                                'Le téléchargement a échoué.'),
                                          ),
                                        );
                                        return;
                                      }
                                      if (!mounted) return;
                                      navigator.pop();
                                      messenger.showSnackBar(const SnackBar(
                                        content: Text(
                                            'Sous-titre téléchargé et liste actualisée.'),
                                      ));
                                      unawaited(_refreshDownloadedSubtitles());
                                    },
                              style: TextButton.styleFrom(
                                foregroundColor: AppColors.textPrimary,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: AppSpacing.md,
                                  vertical: AppSpacing.sm,
                                ),
                                shape: const RoundedRectangleBorder(
                                  borderRadius: AppRadii.controlBorder,
                                ),
                              ),
                              child: Text(
                                _downloadingId == subtitle.id
                                    ? 'Téléchargement…'
                                    : 'Télécharger',
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

Future<void> showAudioSelection(BuildContext context) {
  return showDialog(
    context: context,
    builder: (context) {
      return Consumer(
        builder: (context, ref, child) {
          final playbackModel = ref.watch(playBackModel);
          final player = ref.watch(videoPlayerProvider);
          return GlassSimpleDialog(
            contentPadding: const EdgeInsets.only(top: 8, bottom: 24),
            title: Row(
              children: [
                Text(context.localized.audio(1)),
              ],
            ),
            children: playbackModel?.audioStreams?.mapIndexed(
              (index, audioStream) {
                final selected =
                    playbackModel.mediaStreams?.defaultAudioStreamIndex ==
                        audioStream.index;
                return ListTile(
                    title: Text(audioStream.label(context)),
                    tileColor: selected
                        ? Theme.of(context)
                            .colorScheme
                            .primary
                            .withValues(alpha: 0.3)
                        : null,
                    subtitle: audioStream.language.isNotEmpty
                        ? Opacity(
                            opacity: 0.6,
                            child: Text(audioStream.language.capitalize()))
                        : null,
                    onTap: () async {
                      final newModel =
                          await playbackModel.setAudio(audioStream, player);
                      ref
                          .read(playBackModel.notifier)
                          .update((state) => newModel);
                      if (newModel != null) {
                        await ref
                            .read(playbackModelHelper)
                            .shouldReload(newModel);
                      }
                    });
              },
            ).toList(),
          );
        },
      );
    },
  );
}

Future<void> showPlaybackSpeed(BuildContext context) {
  return showDialog(
    context: context,
    builder: (context) {
      return StatefulBuilder(builder: (context, setState) {
        return Consumer(
          builder: (context, ref, child) {
            final player = ref.watch(videoPlayerProvider);
            final lastSpeed = ref.watch(playbackRateProvider);
            return GlassSimpleDialog(
              contentPadding: const EdgeInsets.only(top: 8, bottom: 24),
              title: Row(children: [Text(context.localized.playbackRate)]),
              children: [
                const Divider(),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12)
                      .copyWith(top: 6),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Text("${context.localized.speed}: "),
                      Flexible(
                        child: SizedBox(
                          width: 250,
                          child: KinosSlider(
                            min: 0.25,
                            max: 3,
                            value: lastSpeed,
                            divisions: 55,
                            onChanged: (value) {
                              ref.read(playbackRateProvider.notifier).state =
                                  value;
                              player.setSpeed(value);
                            },
                          ),
                        ),
                      ),
                      Text("x${lastSpeed.toStringAsFixed(2)}")
                    ].addInBetween(const SizedBox(width: 8)),
                  ),
                )
              ],
            );
          },
        );
      });
    },
  );
}

Future<void> showOrientationOptions(BuildContext context, WidgetRef ref) async {
  Set<DeviceOrientation> orientations = ref
      .read(videoPlayerSettingsProvider.select((value) =>
          value.allowedOrientations ?? Set.from(DeviceOrientation.values)))
      .toSet();

  void toggleOrientation(DeviceOrientation orientation) {
    if (orientations.contains(orientation) && orientations.length > 1) {
      orientations.remove(orientation);
    } else {
      orientations.add(orientation);
    }
  }

  await showDialog(
    context: context,
    builder: (context) {
      return StatefulBuilder(builder: (context, state) {
        return GlassSimpleDialog(
          contentPadding: const EdgeInsets.only(top: 8, bottom: 24),
          title: Row(children: [
            Text(context.localized.playerSettingsOrientationTitle)
          ]),
          children: [
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12).copyWith(top: 6),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const Divider(),
                  ...DeviceOrientation.values.map(
                    (orientation) => CheckboxListTile(
                      title: Text(orientation.label(context)),
                      value: orientations.contains(orientation),
                      onChanged: (value) {
                        state(() => toggleOrientation(orientation));
                      },
                    ),
                  ),
                  const Divider(),
                  Row(
                    mainAxisSize: MainAxisSize.max,
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      ElevatedButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: Text(context.localized.cancel),
                      ),
                      FilledButton(
                        onPressed: () {
                          Navigator.of(context).pop();
                          ref
                              .read(videoPlayerSettingsProvider.notifier)
                              .toggleOrientation(orientations);
                        },
                        child: Text(context.localized.save),
                      ),
                    ].addInBetween(const SizedBox(width: 8)),
                  )
                ].addInBetween(const SizedBox(width: 8)),
              ),
            )
          ],
        );
      });
    },
  );
}
