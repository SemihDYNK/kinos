import 'package:flutter/material.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:kinos/l10n/generated/app_localizations.dart';
import 'package:kinos/providers/settings/client_settings_provider.dart';
import 'package:kinos/screens/settings/settings_list_tile.dart';
import 'package:kinos/screens/settings/widgets/settings_label_divider.dart';
import 'package:kinos/screens/settings/widgets/settings_list_group.dart';
import 'package:kinos/screens/shared/input_fields.dart';
import 'package:kinos/services/startup_sounds.dart';
import 'package:kinos/util/adaptive_layout/adaptive_layout.dart';
import 'package:kinos/util/localization_helper.dart';
import 'package:kinos/widgets/shared/item_actions.dart';

/// Langue et affichage des jaquettes.
///
/// Le thème est unique (sombre, sans accent) : ni mode, ni couleur, ni
/// variante de schéma ne sont proposés. Les réglages du fond flouté et de la
/// barre du haut ne concernent que l'ancienne disposition TV et ne sont plus
/// exposés.
List<Widget> buildClientSettingsVisual(
  BuildContext context,
  WidgetRef ref,
  TextEditingController libraryPageSizeController,
) {
  final clientSettings = ref.watch(clientSettingsProvider);
  final notifier = ref.read(clientSettingsProvider.notifier);
  Locale currentLocale = WidgetsBinding.instance.platformDispatcher.locale;
  return settingsListGroup(
    context,
    SettingsLabelDivider(label: context.localized.settingsVisual),
    [
      SettingsListTileEnum(
        label: Text(context.localized.displayLanguage),
        currentWidget: Localizations.override(
          context: context,
          locale: ref.watch(clientSettingsProvider.select((value) => (value.selectedLocale ?? currentLocale))),
          child: Builder(builder: (context) {
            String language = "English";
            try {
              language = context.localized.nativeName;
            } catch (_) {}
            return Text(language);
          }),
        ),
        itemBuilder: (context) {
          return [
            ...AppLocalizations.supportedLocales.map(
              (entry) => ItemActionButton(
                label: Localizations.override(
                  context: context,
                  locale: entry,
                  child: Builder(builder: (context) {
                    return Text("${context.localized.nativeName} (${entry.toDisplayCode()})");
                  }),
                ),
                action: () => notifier.update((state) => state.copyWith(selectedLocale: entry)),
              ),
            )
          ];
        },
      ),
      SettingsListTileCheckbox(
        label: Text(context.localized.settingsStartupSoundTitle),
        subLabel: Text(context.localized.settingsStartupSoundDesc),
        value: ref.watch(startupSoundProvider),
        onChanged: (value) =>
            setStartupSound(ref, value ?? !ref.read(startupSoundProvider)),
      ),
      SettingsListTileCheckbox(
        label: Text(context.localized.settingsBlurredPlaceholderTitle),
        subLabel: Text(context.localized.settingsBlurredPlaceholderDesc),
        value: clientSettings.blurPlaceHolders,
        onChanged: (value) => notifier.setBlurPlaceholders(value ?? !clientSettings.blurPlaceHolders),
      ),
      SettingsListTileCheckbox(
        label: Text(context.localized.settingsBlurEpisodesTitle),
        subLabel: Text(context.localized.settingsBlurEpisodesDesc),
        value: clientSettings.blurUpcomingEpisodes,
        onChanged: (value) => notifier.setBlurEpisodes(value ?? !clientSettings.blurUpcomingEpisodes),
      ),
      SettingsListTileCheckbox(
        label: Text(AdaptiveLayout.of(context).isDesktop
            ? context.localized.settingsShowScaleSlider
            : context.localized.settingsPosterPinch),
        value: clientSettings.pinchPosterZoom,
        onChanged: (value) => notifier.update(
          (current) => current.copyWith(pinchPosterZoom: value ?? !current.pinchPosterZoom),
        ),
      ),
      SettingsSliderTile(
        label: Text(context.localized.settingsPosterSize),
        valueLabel: "${(clientSettings.posterSize * 100).round()} %",
        min: 0.5,
        max: 1.5,
        divisions: 20,
        value: clientSettings.posterSize,
        onChanged: (value) => notifier.update((current) => current.copyWith(posterSize: value)),
      ),
      SettingsListTile(
        label: Text(context.localized.libraryPageSizeTitle),
        subLabel: Text(context.localized.libraryPageSizeDesc),
        trailing: IntInputField(
          controller: libraryPageSizeController,
          placeHolder: "500",
          onSubmitted: (value) => notifier.update(
            (current) => current.copyWith(libraryPageSize: value),
          ),
        ),
      ),
    ],
  );
}
