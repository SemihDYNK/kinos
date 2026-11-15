import 'package:kinos/widgets/shared/frosted_surface.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'package:auto_route/auto_route.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:kinos/providers/incognito_mode_provider.dart';
import 'package:kinos/providers/settings/client_settings_provider.dart';
import 'package:kinos/providers/shared_provider.dart';
import 'package:kinos/recommendations/providers/recommendation_providers.dart';
import 'package:kinos/routes/auto_router.gr.dart';
import 'package:kinos/screens/settings/client_sections/client_settings_advanced.dart';
import 'package:kinos/screens/settings/client_sections/client_settings_dashboard.dart';
import 'package:kinos/screens/settings/client_sections/client_settings_download.dart';
import 'package:kinos/screens/settings/client_sections/client_settings_shortcuts.dart';
import 'package:kinos/screens/settings/client_sections/client_settings_visual.dart';
import 'package:kinos/screens/settings/settings_list_tile.dart';
import 'package:kinos/screens/settings/settings_scaffold.dart';
import 'package:kinos/screens/settings/widgets/settings_label_divider.dart';
import 'package:kinos/screens/settings/widgets/settings_list_group.dart';
import 'package:kinos/screens/shared/kinos_notification_overlay.dart';
import 'package:kinos/theme/app_theme.dart';
import 'package:kinos/util/adaptive_layout/adaptive_layout.dart';
import 'package:kinos/util/localization_helper.dart';
import 'package:kinos/util/simple_duration_picker.dart';

@RoutePage()
class ClientSettingsPage extends ConsumerStatefulWidget {
  const ClientSettingsPage({super.key});

  @override
  ConsumerState<ConsumerStatefulWidget> createState() =>
      _ClientSettingsPageState();
}

class _ClientSettingsPageState extends ConsumerState<ClientSettingsPage> {
  late final nextUpDaysEditor = TextEditingController(
      text: ref
          .read(clientSettingsProvider
              .select((value) => value.nextUpDateCutoff?.inDays ?? 14))
          .toString());

  late final libraryPageSizeController = TextEditingController(
      text: ref
              .read(clientSettingsProvider
                  .select((value) => value.libraryPageSize))
              ?.toString() ??
          "");

  bool _recomputingRecommendations = false;

  Future<void> _forceRecommendationRecompute() async {
    if (_recomputingRecommendations) return;
    setState(() => _recomputingRecommendations = true);
    try {
      await forceRecommendationRecompute(ref);
      if (!mounted) return;
      KinosSnack.show(
          'Recommandations : nouveau calcul au prochain retour à l\'accueil',
          context: context);
    } finally {
      if (mounted) setState(() => _recomputingRecommendations = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final clientSettings = ref.watch(clientSettingsProvider);
    final notifier = ref.read(clientSettingsProvider.notifier);

    return SettingsScaffold(
      label: context.localized.managementApplication,
      items: [
        ...buildClientSettingsVisual(context, ref, libraryPageSizeController),
        ...buildClientSettingsDashboard(
          context,
          ref,
          nextUpDaysEditor: nextUpDaysEditor,
          recomputingRecommendations: _recomputingRecommendations,
          onRecomputeRecommendations: _forceRecommendationRecompute,
        ),
        ...settingsListGroup(
          context,
          SettingsLabelDivider(label: context.localized.controls),
          [
            SettingsListTileCheckbox(
              label: Text(context.localized.settingsEnableOsMediaControls),
              subLabel: Text(context.localized.settingsEnableOsMediaControlsDesc),
              value: clientSettings.enableMediaKeys,
              onChanged: (value) => notifier.setMediaKeys(value ?? !clientSettings.enableMediaKeys),
            ),
            if (AdaptiveLayout.inputDeviceOf(context) == InputDevice.pointer)
              SettingsListTileCheckbox(
                label: Text(context.localized.mouseDragSupport),
                value: clientSettings.mouseDragSupport,
                onChanged: (value) => notifier
                    .update((current) => current.copyWith(mouseDragSupport: value ?? !current.mouseDragSupport)),
              ),
            SettingsListTileCheckbox(
              label: Text(context.localized.incognitoModeGlobal),
              subLabel: Text(context.localized.incognitoModeDesc),
              value: ref.watch(incognitoModeProvider),
              onChanged: (value) => ref.read(incognitoModeProvider.notifier).state = value ?? !ref.read(incognitoModeProvider),
            ),
            SettingsListTile(
              label: Text(context.localized.lockscreen),
              subLabel: Text(context.localized.timeOut),
              valueAsTrailing: false,
              trailing: Text(timePickerString(context, clientSettings.timeOut)),
              onTap: () async {
                final timePicker = await showSimpleDurationPicker(
                  context: context,
                  initialValue: clientSettings.timeOut ?? const Duration(),
                );

                if (timePicker == null) return;

                notifier.setTimeOut(timePicker != Duration.zero
                    ? Duration(minutes: timePicker.inMinutes, seconds: timePicker.inSeconds % 60)
                    : null);
              },
            ),
          ],
        ),
        if (AdaptiveLayout.inputDeviceOf(context) != InputDevice.touch) ...buildClientSettingsShortCuts(context, ref),
        ...buildClientSettingsDownload(context, ref, setState),
        ...buildClientSettingsAdvanced(context, ref),
        if (kDebugMode) ...[
          const SizedBox(height: AppSpacing.xxl),
          SettingsListTile(
            label: const Text(
              "Clear cache",
            ),
            contentColor: AppColors.error,
            onTap: () {
              PaintingBinding.instance.imageCache.clear();
            },
          ),
          SettingsListTile(
            label: Text(
              context.localized.clearAllSettings,
            ),
            contentColor: AppColors.error,
            onTap: () {
              showDialog(
                context: context,
                builder: (context) => GlassDialog(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          context.localized.clearAllSettingsQuestion,
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          context.localized.unableToReverseAction,
                        ),
                        const SizedBox(height: 16),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            FilledButton(
                              onPressed: () => Navigator.of(context).pop(),
                              child: Text(context.localized.cancel),
                            ),
                            const SizedBox(width: 8),
                            ElevatedButton(
                              onPressed: () async {
                                await ref
                                    .read(sharedPreferencesProvider)
                                    .clear();
                                context.router.push(LoginRoute());
                              },
                              child: Text(context.localized.clear),
                            )
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ],
    );
  }
}
