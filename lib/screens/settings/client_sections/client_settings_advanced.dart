import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:kinos/providers/settings/client_settings_provider.dart';
import 'package:kinos/providers/settings/home_settings_provider.dart';
import 'package:kinos/screens/settings/settings_list_tile.dart';
import 'package:kinos/screens/settings/widgets/settings_label_divider.dart';
import 'package:kinos/screens/settings/widgets/settings_list_group.dart';
import 'package:kinos/screens/settings/widgets/settings_message_box.dart';
import 'package:kinos/theme/app_theme.dart';
import 'package:kinos/util/adaptive_layout/adaptive_layout.dart';
import 'package:kinos/util/localization_helper.dart';
import 'package:kinos/util/option_dialogue.dart';

List<Widget> buildClientSettingsAdvanced(BuildContext context, WidgetRef ref) {
  final enabledSizes = ref.watch(homeSettingsProvider.select((value) => value.layoutStates));
  final enabledModes = ref.watch(homeSettingsProvider.select((value) => value.screenLayouts));
  final currentSize = AdaptiveLayout.viewSizeOf(context);
  final currentMode = AdaptiveLayout.layoutModeOf(context);

  return settingsListGroup(
    context,
    SettingsLabelDivider(label: context.localized.advanced),
    [
      SettingsListTile(
        label: Text(context.localized.settingsLayoutSizesTitle),
        subLabel: Text(context.localized.settingsLayoutSizesDesc),
        onTap: () async {
          final newItems = await openMultiSelectOptions<ViewSize>(
            context,
            label: context.localized.settingsLayoutSizesTitle,
            items: ViewSize.values,
            allowMultiSelection: true,
            selected: enabledSizes.toList(),
            itemBuilder: (type, selected, tap) => CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              value: selected,
              onChanged: (value) => tap(),
              title: Text(type.label(context)),
            ),
          );
          ref.read(homeSettingsProvider.notifier).setViewSize(newItems.toSet());
        },
        trailing: _LayoutSummary(
          labels: [
            for (final size in ViewSize.values)
              if (enabledSizes.contains(size)) (size.label(context), size == currentSize),
          ],
        ),
      ),
      SettingsListTile(
        label: Text(context.localized.settingsLayoutModesTitle),
        subLabel: Text(context.localized.settingsLayoutModesDesc),
        onTap: () async {
          final newItems = await openMultiSelectOptions<LayoutMode>(
            context,
            label: context.localized.settingsLayoutModesTitle,
            items: LayoutMode.values,
            allowMultiSelection: true,
            selected: enabledModes.toList(),
            itemBuilder: (type, selected, tap) => CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              value: selected,
              onChanged: (value) => tap(),
              title: Text(type.label(context)),
            ),
          );
          ref.read(homeSettingsProvider.notifier).setLayoutModes(newItems.toSet());
        },
        trailing: _LayoutSummary(
          labels: [
            for (final mode in LayoutMode.values)
              if (enabledModes.contains(mode)) (mode.label(context), mode == currentMode),
          ],
        ),
      ),
      if (AdaptiveLayout.inputDeviceOf(context) == InputDevice.dPad)
        SettingsListTileCheckbox(
          label: Text(context.localized.clientSettingsUseSystemIMETitle),
          subLabel: Text(context.localized.clientSettingsUseSystemIMEDesc),
          value: ref.watch(clientSettingsProvider.select((value) => value.useSystemIME)),
          onChanged: (value) => ref.read(clientSettingsProvider.notifier).useSystemIME(value),
        ),
      if (defaultTargetPlatform == TargetPlatform.android) ...[
        SettingsListTileCheckbox(
          label: Text(context.localized.leanBackModeTitle),
          subLabel: Text(context.localized.leanBackModeDesc),
          value: ref.watch(clientSettingsProvider.select((value) => value.forceLeanBackMode)),
          onChanged: (value) => ref.read(clientSettingsProvider.notifier).setForceLeanBackMode(value ?? false),
        ),
        SettingsMessageBox(context.localized.leanBackModeInfo),
      ],
    ],
  );
}

/// Valeurs autorisées, la disposition en cours en texte principal.
class _LayoutSummary extends StatelessWidget {
  final List<(String, bool)> labels;
  const _LayoutSummary({required this.labels});

  @override
  Widget build(BuildContext context) {
    return Text.rich(
      TextSpan(children: [
        for (final (index, (label, current)) in labels.indexed) ...[
          if (index > 0) const TextSpan(text: ' · '),
          TextSpan(
            text: label,
            style: TextStyle(color: current ? AppColors.textPrimary : AppColors.textSecondary),
          ),
        ],
      ]),
      textAlign: TextAlign.end,
      style: AppTypography.meta,
    );
  }
}
