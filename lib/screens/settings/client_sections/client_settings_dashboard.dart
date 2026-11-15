import 'package:flutter/material.dart';

import 'package:auto_route/auto_route.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:kinos/providers/settings/client_settings_provider.dart';
import 'package:kinos/routes/auto_router.gr.dart';
import 'package:kinos/screens/settings/settings_list_tile.dart';
import 'package:kinos/screens/settings/widgets/settings_label_divider.dart';
import 'package:kinos/screens/settings/widgets/settings_list_group.dart';
import 'package:kinos/screens/shared/input_fields.dart';
import 'package:kinos/theme/app_theme.dart';
import 'package:kinos/util/localization_helper.dart';

/// Réglages de l'accueil.
///
/// Le bandeau, ses informations et la disposition « À suivre » de l'ancien
/// accueil amont ne sont plus lus depuis la réécriture du tableau de bord :
/// ils ne sont plus proposés.
List<Widget> buildClientSettingsDashboard(
  BuildContext context,
  WidgetRef ref, {
  required TextEditingController nextUpDaysEditor,
  required bool recomputingRecommendations,
  required VoidCallback onRecomputeRecommendations,
}) {
  final clientSettings = ref.watch(clientSettingsProvider);
  final notifier = ref.read(clientSettingsProvider.notifier);
  return settingsListGroup(
    context,
    SettingsLabelDivider(label: context.localized.dashboard),
    [
      SettingsListTile(
        label: const Text('Rangées de l\'accueil'),
        subLabel: const Text('Genre, réalisateur, studio, collection…'),
        onTap: () => context.router.push(const HomeRowsSettingsRoute()),
        trailing: const Icon(Icons.chevron_right, color: AppColors.textSecondary),
      ),
      SettingsListTile(
        label: Text(context.localized.settingsNextUpCutoffDays),
        trailing: IntInputField(
          suffix: context.localized.days(clientSettings.nextUpDateCutoff?.inDays ?? 1),
          controller: nextUpDaysEditor,
          onSubmitted: (value) {
            if (value != null) {
              notifier.update((current) => current.copyWith(nextUpDateCutoff: Duration(days: value)));
            }
          },
        ),
      ),
      SettingsListTileCheckbox(
        label: Text(context.localized.clientSettingsShowAllCollectionsTitle),
        subLabel: Text(context.localized.clientSettingsShowAllCollectionsDesc),
        value: clientSettings.showAllCollectionTypes,
        onChanged: (value) => notifier.update(
          (current) => current.copyWith(showAllCollectionTypes: value ?? !current.showAllCollectionTypes),
        ),
      ),
      SettingsListTile(
        label: Text(recomputingRecommendations
            ? 'Recommandations : nouveau calcul demandé…'
            : 'Recalculer les recommandations'),
        subLabel: const Text(
            'Force un nouveau calcul complet au prochain retour à l\'accueil — sinon, le cache existant est réutilisé jusqu\'à 24 h.'),
        onTap: recomputingRecommendations ? null : onRecomputeRecommendations,
      ),
    ],
  );
}
