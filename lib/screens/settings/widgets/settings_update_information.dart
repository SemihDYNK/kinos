import 'package:flutter/material.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:markdown_widget/widget/markdown.dart';

import 'package:kinos/providers/settings/client_settings_provider.dart';
import 'package:kinos/providers/update_provider.dart';
import 'package:kinos/screens/settings/settings_list_tile.dart';
import 'package:kinos/screens/shared/media/external_urls.dart';
import 'package:kinos/util/list_padding.dart';
import 'package:kinos/util/localization_helper.dart';
import 'package:kinos/util/update_checker.dart';
import 'package:kinos/theme/app_theme.dart';

class SettingsUpdateInformation extends ConsumerStatefulWidget {
  const SettingsUpdateInformation({super.key});

  @override
  ConsumerState<ConsumerStatefulWidget> createState() => _SettingsUpdateInformationState();
}

class _SettingsUpdateInformationState extends ConsumerState<SettingsUpdateInformation> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((value) {
      final latestRelease = ref.read(updateProvider.select((value) => value.latestRelease));
      if (latestRelease == null) return;
      final lastViewedUpdate = ref.read(clientSettingsProvider.select((value) => value.lastViewedUpdate));
      if (lastViewedUpdate != latestRelease.version) {
        ref
            .read(clientSettingsProvider.notifier)
            .update((value) => value.copyWith(lastViewedUpdate: latestRelease.version));
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final updates = ref.watch(updateProvider);
    final latestRelease = updates.latestRelease;
    final otherReleases = updates.lastRelease;
    final checkForUpdate = ref.watch(clientSettingsProvider.select((value) => value.checkForUpdates));

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: ListView(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        children: [
          const Divider(color: AppColors.border),
          SettingsListTile(
            label: Text(context.localized.latestReleases),
            subLabel: Text(context.localized.autoCheckForUpdates),
            onTap: () => ref
                .read(clientSettingsProvider.notifier)
                .update((value) => value.copyWith(checkForUpdates: !checkForUpdate)),
            trailing: Switch(
              value: checkForUpdate,
              onChanged: (value) => ref
                  .read(clientSettingsProvider.notifier)
                  .update((value) => value.copyWith(checkForUpdates: !checkForUpdate)),
            ),
          ),
          if (latestRelease != null)
            UpdateInformation(
              releaseInfo: latestRelease,
              expanded: true,
            ),
          ...otherReleases.where((element) => element != latestRelease).map(
                (value) => UpdateInformation(releaseInfo: value),
              ),
        ],
      ),
    );
  }
}

class UpdateInformation extends StatelessWidget {
  final ReleaseInfo releaseInfo;
  final bool expanded;
  const UpdateInformation({
    required this.releaseInfo,
    this.expanded = false,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return ExpansionTile(
      backgroundColor: AppColors.surface,
      collapsedBackgroundColor: releaseInfo.isNewerThanCurrent ? AppColors.surfaceHigh : AppColors.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: AppRadii.controlBorder, side: BorderSide(color: AppColors.borderStrong)),
      collapsedShape: RoundedRectangleBorder(
          borderRadius: AppRadii.controlBorder,
          side: BorderSide(color: releaseInfo.isNewerThanCurrent ? AppColors.borderStrong : AppColors.border)),
      iconColor: AppColors.textPrimary,
      collapsedIconColor: AppColors.textSecondary,
      title: Text(releaseInfo.version, style: AppTypography.cardTitle),
      initiallyExpanded: expanded,
      childrenPadding: const EdgeInsets.all(AppSpacing.md),
      expandedCrossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        MarkdownWidget(
          data: releaseInfo.changelog,
          shrinkWrap: true,
        ),
        ...releaseInfo.preferredDownloads.entries.map(
          (entry) {
            return FilledButton(
              onPressed: () => launchUrl(context, entry.value),
              child: Text(
                entry.key.prettifyKey(),
              ),
            );
          },
        ),
        const Divider(color: AppColors.border),
        ...releaseInfo.otherDownloads.entries.map(
          (entry) {
            return OutlinedButton(
              onPressed: () => launchUrl(context, entry.value),
              child: Text(
                entry.key.prettifyKey(),
              ),
            );
          },
        )
      ].addInBetween(const SizedBox(height: AppSpacing.sm)),
    );
  }
}
