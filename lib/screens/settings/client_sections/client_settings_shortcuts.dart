import 'package:flutter/material.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:kinos/models/settings/client_settings_model.dart';
import 'package:kinos/providers/settings/client_settings_provider.dart';
import 'package:kinos/screens/settings/settings_list_tile.dart';
import 'package:kinos/screens/settings/widgets/key_listener.dart';
import 'package:kinos/screens/settings/widgets/settings_label_divider.dart';
import 'package:kinos/screens/settings/widgets/settings_list_group.dart';
import 'package:kinos/util/localization_helper.dart';

List<Widget> buildClientSettingsShortCuts(
  BuildContext context,
  WidgetRef ref,
) {
  final clientSettings = ref.watch(clientSettingsProvider);
  return settingsListGroup(
    context,
    SettingsLabelDivider(label: context.localized.keyboardShortCuts),
    [
      ...GlobalHotKeys.values.map(
        (entry) => SettingsShortcutRow(
          label: entry.label(context),
          keyWidget: KeyCombinationWidget(
            currentKey: clientSettings.shortcuts[entry],
            defaultKey: clientSettings.defaultShortCuts[entry]!,
            onChanged: (value) => ref.read(clientSettingsProvider.notifier).setShortcuts(MapEntry(entry, value)),
          ),
        ),
      )
    ],
  );
}
