import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'package:auto_route/auto_route.dart';
import 'package:collection/collection.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:kinos/models/items/media_segments_model.dart';
import 'package:kinos/models/settings/video_player_settings.dart';
import 'package:kinos/providers/arguments_provider.dart';
import 'package:kinos/providers/connectivity_provider.dart';
import 'package:kinos/providers/settings/video_player_settings_provider.dart';
import 'package:kinos/providers/user_provider.dart';
import 'package:kinos/providers/video_player_provider.dart';
import 'package:kinos/screens/settings/settings_list_tile.dart';
import 'package:kinos/screens/settings/settings_scaffold.dart';
import 'package:kinos/screens/settings/widgets/key_listener.dart';
import 'package:kinos/screens/settings/widgets/settings_label_divider.dart';
import 'package:kinos/screens/settings/widgets/settings_list_group.dart';
import 'package:kinos/screens/settings/widgets/settings_message_box.dart';
import 'package:kinos/screens/settings/widgets/subtitle_editor.dart';
import 'package:kinos/screens/shared/input_fields.dart';
import 'package:kinos/screens/video_player/components/video_player_options_sheet.dart';
import 'package:kinos/theme/app_theme.dart';
import 'package:kinos/util/adaptive_layout/adaptive_layout.dart';
import 'package:kinos/util/bitrate_helper.dart';
import 'package:kinos/util/box_fit_extension.dart';
import 'package:kinos/util/localization_helper.dart';
import 'package:kinos/widgets/shared/item_actions.dart';
import 'package:kinos/wrappers/pip_manager.dart';

@RoutePage()
class PlayerSettingsPage extends ConsumerStatefulWidget {
  const PlayerSettingsPage({super.key});

  @override
  ConsumerState<ConsumerStatefulWidget> createState() => _PlayerSettingsPageState();
}

class _PlayerSettingsPageState extends ConsumerState<PlayerSettingsPage> {
  @override
  Widget build(BuildContext context) {
    final videoSettings = ref.watch(videoPlayerSettingsProvider);
    final provider = ref.read(videoPlayerSettingsProvider.notifier);

    final connectionState = ref.watch(connectivityStatusProvider);

    final userSettings = ref.watch(userProvider.select((value) => value?.userSettings));

    final currentPlayer = videoSettings.wantedPlayer;

    // Sous Linux, mpv est le seul moteur autorisé : pas de sélecteur.
    final showBackendPicker =
        PlayerOptions.available.length != 1 && (kIsWeb || defaultTargetPlatform != TargetPlatform.linux);

    return SettingsScaffold(
      label: context.localized.settingsPlayerTitle,
      items: [
        ...settingsListGroup(
          context,
          const SettingsLabelDivider(label: 'Lecture'),
          [
            if (!AdaptiveLayout.of(context).isDesktop && !kIsWeb) ...[
              SettingsListTileCheckbox(
                label: Text(context.localized.videoScalingFillScreenTitle),
                subLabel: Text(context.localized.videoScalingFillScreenDesc),
                value: videoSettings.fillScreen,
                onChanged: (value) => provider.setFillScreen(value ?? !videoSettings.fillScreen),
              ),
              if (videoSettings.fillScreen)
                SettingsMessageBox(
                  context.localized.videoScalingFillScreenNotif,
                  messageType: MessageType.warning,
                ),
            ],
            if (pipPlatformSupported)
              SettingsListTileCheckbox(
                label: Text(context.localized.pictureInPictureAutoTitle),
                subLabel: Text(context.localized.pictureInPictureSubtitle),
                value: videoSettings.enablePictureInPicture,
                onChanged: (value) =>
                    provider.setEnablePictureInPicture(value ?? !videoSettings.enablePictureInPicture),
              ),
            SettingsListTileEnum(
              label: Text(context.localized.videoScaling),
              current: videoSettings.videoFit.label(context),
              itemBuilder: (context) => BoxFit.values
                  .map(
                    (entry) => ItemActionButton(
                      label: Text(entry.label(context)),
                      action: () => provider.setFitType(entry),
                    ),
                  )
                  .toList(),
            ),
            SettingsListTileEnum(
              label: Text(context.localized.settingsAutoNextTitle),
              subLabel: Text(context.localized.settingsAutoNextDesc),
              current: videoSettings.nextVideoType.label(context),
              itemBuilder: (context) => AutoNextType.values
                  .map(
                    (entry) => ItemActionButton(
                      label: Text(entry.label(context)),
                      action: () => provider.state = videoSettings.copyWith(nextVideoType: entry),
                    ),
                  )
                  .toList(),
            ),
            if (videoSettings.nextVideoType == AutoNextType.smart || videoSettings.nextVideoType == AutoNextType.static)
              SettingsMessageBox(videoSettings.nextVideoType.desc(context)),
            if (currentPlayer == PlayerOptions.libMPV)
              SettingsListTileCheckbox(
                label: Text(context.localized.settingsPlayerPlayPauseFadeTitle),
                subLabel: Text(context.localized.settingsPlayerPlayPauseFadeDesc),
                value: videoSettings.enablePlayPauseFade,
                onChanged: (value) => provider.setEnablePlayPauseFade(value ?? !videoSettings.enablePlayPauseFade),
              ),
            if (!kIsWeb && currentPlayer != PlayerOptions.nativePlayer) ...[
              SettingsListTileCheckbox(
                label: Text(context.localized.playerSettingsAmbientBlurTitle),
                subLabel: Text(context.localized.playerSettingsAmbientBlurDesc),
                value: videoSettings.ambientBlur,
                onChanged: (value) => provider.setAmbientBlur(value ?? !videoSettings.ambientBlur),
              ),
              if (videoSettings.ambientBlur)
                SettingsMessageBox(
                  context.localized.playerSettingsAmbientBlurDescWarning,
                  messageType: MessageType.warning,
                ),
            ],
          ],
        ),
        ...settingsListGroup(
          context,
          const SettingsLabelDivider(label: 'Qualité de diffusion'),
          [
            SettingsListTileEnum(
              label: _StatusIndicator(
                homeInternet: connectionState.homeInternet,
                label: Text(context.localized.homeStreamingQualityTitle),
              ),
              subLabel: Text(context.localized.homeStreamingQualityDesc),
              current: videoSettings.maxHomeBitrate.label(context),
              itemBuilder: (context) => Bitrate.values
                  .map(
                    (entry) => ItemActionButton(
                      label: Text(entry.label(context)),
                      action: () => provider.state = videoSettings.copyWith(maxHomeBitrate: entry),
                    ),
                  )
                  .toList(),
            ),
            SettingsListTileEnum(
              label: _StatusIndicator(
                homeInternet: !connectionState.homeInternet,
                label: Text(context.localized.internetStreamingQualityTitle),
              ),
              subLabel: Text(context.localized.internetStreamingQualityDesc),
              current: videoSettings.maxInternetBitrate.label(context),
              itemBuilder: (context) => Bitrate.values
                  .map(
                    (entry) => ItemActionButton(
                      label: Text(entry.label(context)),
                      action: () => provider.state = videoSettings.copyWith(maxInternetBitrate: entry),
                    ),
                  )
                  .toList(),
            ),
          ],
        ),
        ...settingsListGroup(context, SettingsLabelDivider(label: context.localized.mediaSegmentActions), [
          ...videoSettings.segmentSkipSettings.entries.sorted((a, b) => b.key.index.compareTo(a.key.index)).map(
                (entry) => SettingsListTileEnum(
                  label: Text(entry.key.label(context)),
                  current: entry.value.label(context),
                  itemBuilder: (context) => SegmentSkip.values
                      .map(
                        (value) => ItemActionButton(
                          label: Text(value.label(context)),
                          action: () {
                            final newEntries = videoSettings.segmentSkipSettings
                                .map((key, currentValue) => MapEntry(key, key == entry.key ? value : currentValue));
                            provider.state = videoSettings.copyWith(segmentSkipSettings: newEntries);
                          },
                        ),
                      )
                      .toList(),
                ),
              ),
        ]),
        ...settingsListGroup(
          context,
          const SettingsLabelDivider(label: 'Pistes et sous-titres'),
          [
            SettingsListTileCheckbox(
              label: Text(context.localized.rememberAudioSelections),
              subLabel: Text(context.localized.rememberAudioSelectionsDesc),
              value: ref.watch(userProvider.select(
                (value) => value?.userConfiguration?.rememberAudioSelections ?? true,
              )),
              onChanged: (_) => ref.read(userProvider.notifier).setRememberAudioSelections(),
            ),
            SettingsListTileCheckbox(
              label: Text(context.localized.rememberSubtitleSelections),
              subLabel: Text(context.localized.rememberSubtitleSelectionsDesc),
              value: ref.watch(userProvider.select(
                (value) => value?.userConfiguration?.rememberSubtitleSelections ?? true,
              )),
              onChanged: (_) => ref.read(userProvider.notifier).setRememberSubtitleSelections(),
            ),
            SettingsListTile(
              label: Text(context.localized.settingsPlayerCustomSubtitlesTitle),
              subLabel: Text(context.localized.settingsPlayerCustomSubtitlesDesc),
              trailing: const Icon(Icons.chevron_right, color: AppColors.textSecondary),
              onTap: () {
                showDialog(
                  context: context,
                  barrierDismissible: true,
                  useSafeArea: false,
                  builder: (context) => const SubtitleEditor(),
                );
              },
            ),
          ],
        ),
        ...settingsListGroup(
          context,
          SettingsLabelDivider(label: context.localized.navigation),
          [
            if (userSettings != null) ...[
              SettingsListTile(
                label: Text(context.localized.skipBackLength),
                trailing: IntInputField(
                  suffix: context.localized.seconds(10),
                  value: userSettings.skipBackDuration.inSeconds,
                  onSubmitted: (value) {
                    if (value != null) {
                      ref.read(userProvider.notifier).setBackwardSpeed(value);
                    }
                  },
                ),
              ),
              SettingsListTile(
                label: Text(context.localized.skipForwardLength),
                trailing: IntInputField(
                  suffix: context.localized.seconds(10),
                  value: userSettings.skipForwardDuration.inSeconds,
                  onSubmitted: (value) {
                    if (value != null) {
                      ref.read(userProvider.notifier).setForwardSpeed(value);
                    }
                  },
                ),
              ),
            ],
            SettingsListTileCheckbox(
              label: Text(context.localized.enableSpeedBoostTitle),
              subLabel: Text(context.localized.enableSpeedBoostDesc),
              value: videoSettings.enableSpeedBoost,
              onChanged: (value) => provider.setEnableSpeedBoost(value ?? !videoSettings.enableSpeedBoost),
            ),
            if (videoSettings.enableSpeedBoost)
              SettingsSliderTile(
                label: Text(context.localized.speedBoostRateTitle),
                subLabel: context.localized.speedBoostRateDesc.isNotEmpty
                    ? Text(context.localized.speedBoostRateDesc)
                    : null,
                valueLabel: "${videoSettings.speedBoostRate.toStringAsFixed(2)}×",
                min: 0.25,
                max: 3.0,
                divisions: 55,
                value: videoSettings.speedBoostRate,
                onChanged: (value) => provider.setSpeedBoostRate(value),
              ),
            if (AdaptiveLayout.inputDeviceOf(context) == InputDevice.touch) ...[
              SettingsListTileCheckbox(
                label: Text(context.localized.enableDoubleTapSeekTitle),
                subLabel: Text(context.localized.enableDoubleTapSeekDesc),
                value: videoSettings.enableDoubleTapSeek,
                onChanged: (value) => provider.setEnableDoubleTapSeek(value ?? !videoSettings.enableDoubleTapSeek),
              ),
              SettingsListTileCheckbox(
                label: Text(context.localized.enableEdgeGesturesTitle),
                subLabel: Text(context.localized.enableEdgeGesturesDesc),
                value: videoSettings.enableEdgeGestures,
                onChanged: (value) => provider.setEnableEdgeGestures(value ?? !videoSettings.enableEdgeGestures),
              ),
              SettingsListTileCheckbox(
                label: Text(context.localized.reverseEdgeGesturesTitle),
                subLabel: Text(context.localized.reverseEdgeGesturesDesc),
                value: videoSettings.reverseEdgeGestures,
                onChanged: (value) => provider.setReverseEdgeGestures(value ?? !videoSettings.reverseEdgeGestures),
              ),
            ],
          ],
        ),
        if (AdaptiveLayout.inputDeviceOf(context) != InputDevice.touch)
          ...settingsListGroup(
            context,
            SettingsLabelDivider(label: context.localized.keyboardShortCuts),
            [
              ...VideoHotKeys.values.map(
                (entry) => SettingsShortcutRow(
                  label: entry.label(context),
                  keyWidget: KeyCombinationWidget(
                    currentKey: videoSettings.hotKeys[entry],
                    defaultKey: videoSettings.defaultShortCuts[entry]!,
                    onChanged: (value) => provider.setShortcuts(MapEntry(entry, value)),
                  ),
                ),
              ),
            ],
          ),
        ...settingsListGroup(
          context,
          SettingsLabelDivider(label: context.localized.advanced),
          [
            if (showBackendPicker)
              SettingsListTileEnum(
                label: Text(context.localized.playerSettingsBackendTitle),
                subLabel: Text(context.localized.playerSettingsBackendDesc),
                current: videoSettings.playerOptions == null
                    ? "${context.localized.defaultLabel} (${PlayerOptions.platformDefaults.label(context)})"
                    : videoSettings.wantedPlayer.label(context),
                itemBuilder: (context) => [
                  ItemActionButton(
                    label: Text("${context.localized.defaultLabel} (${PlayerOptions.platformDefaults.label(context)})"),
                    action: () => provider.state = videoSettings.copyWith(playerOptions: null),
                  ),
                  ...PlayerOptions.available.map(
                    (entry) => ItemActionButton(
                      label: Text(entry.label(context)),
                      action: () => provider.state = videoSettings.copyWith(playerOptions: entry),
                    ),
                  )
                ],
              ),
            if (currentPlayer == PlayerOptions.libMPV) ...[
              SettingsListTileCheckbox(
                label: Text(context.localized.settingsPlayerVideoHWAccelTitle),
                subLabel: Text(context.localized.settingsPlayerVideoHWAccelDesc),
                value: videoSettings.hardwareAccel,
                onChanged: (value) => provider.setHardwareAccel(value ?? !videoSettings.hardwareAccel),
              ),
              if (!kIsWeb)
                SettingsListTileCheckbox(
                  label: Text(context.localized.settingsPlayerNativeLibassAccelTitle),
                  subLabel: Text(context.localized.settingsPlayerNativeLibassAccelDesc),
                  value: videoSettings.useLibass,
                  onChanged: (value) => provider.setUseLibass(value ?? !videoSettings.useLibass),
                ),
            ],
            if (currentPlayer == PlayerOptions.nativePlayer)
              SettingsListTileCheckbox(
                label: Text(context.localized.mediaTunnelingTitle),
                subLabel: Text(context.localized.mediaTunnelingDesc),
                value: videoSettings.enableTunneling,
                onChanged: (value) => provider.setMediaTunneling(value ?? !videoSettings.enableTunneling),
              ),
            if (ref.read(argumentsStateProvider).leanBackMode)
              SettingsListTileEnum(
                label: Text(context.localized.playerSettingsScreensaverTitle),
                subLabel: Text(context.localized.playerSettingsScreensaverDesc),
                current: videoSettings.screensaver.label(context),
                itemBuilder: (context) => Screensaver.values
                    .map(
                      (entry) => ItemActionButton(
                        label: Text(entry.label(context)),
                        action: () => provider.setScreensaver(entry),
                      ),
                    )
                    .toList(),
              ),
            if (currentPlayer == PlayerOptions.libMDK)
              SettingsListTileCheckbox(
                label: Text(context.localized.advancedVideoOptionsTitle),
                subLabel: Text(context.localized.advancedVideoOptionsDesc),
                value: videoSettings.enableAdvancedVideoOptions,
                onChanged: (value) {
                  provider.setEnableAdvancedVideoOptions(value ?? !videoSettings.enableAdvancedVideoOptions);
                  ref.read(videoPlayerProvider.notifier).init();
                },
              ),
            if (!AdaptiveLayout.of(context).isDesktop && !kIsWeb && !ref.read(argumentsStateProvider).htpcMode)
              SettingsListTile(
                label: Text(context.localized.playerSettingsOrientationTitle),
                subLabel: Text(context.localized.playerSettingsOrientationDesc),
                onTap: () => showOrientationOptions(context, ref),
              ),
          ],
        ),
      ],
    );
  }
}

class _StatusIndicator extends StatelessWidget {
  final bool homeInternet;
  final Widget label;
  const _StatusIndicator({required this.homeInternet, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        if (homeInternet) ...[
          Container(
            width: AppManagementLayout.statusDotSize,
            height: AppManagementLayout.statusDotSize,
            decoration: const BoxDecoration(
              color: AppColors.success,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: AppSpacing.xs),
        ],
        Flexible(child: label),
      ],
    );
  }
}
