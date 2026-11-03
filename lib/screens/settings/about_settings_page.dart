import 'package:flutter/material.dart';

import 'package:auto_route/auto_route.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import 'package:kinos/screens/crash_screen/crash_screen.dart';
import 'package:kinos/screens/settings/settings_scaffold.dart';
import 'package:kinos/screens/settings/widgets/settings_update_information.dart';
import 'package:kinos/screens/shared/kinos_icon.dart';
import 'package:kinos/screens/shared/kinos_logo.dart';
import 'package:kinos/screens/shared/media/external_urls.dart';
import 'package:kinos/util/application_info.dart';
import 'package:kinos/util/list_padding.dart';
import 'package:kinos/util/localization_helper.dart';

class _Socials {
  final String label;
  final String url;
  final FaIconData icon;

  const _Socials(this.label, this.url, this.icon);
}

const socials = [
  // TODO (hors dépôt) : remplacer par l'URL réelle du dépôt Kinos une
  // fois publié.
  _Socials(
    'Github',
    'https://github.com/DonutWare/Fladder',
    FontAwesomeIcons.githubAlt,
  ),
  // Pas d'équivalent Weblate pour Kinos — le lien menait au projet de
  // traduction communautaire de Fladder, pas au tien.
];

@RoutePage()
class AboutSettingsPage extends ConsumerWidget {
  const AboutSettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final applicationInfo = ref.watch(applicationInfoProvider);

    return SettingsScaffold(
      label: "",
      items: [
        const KinosLogo(),
        Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(context.localized.aboutVersion(applicationInfo.versionAndPlatform)),
            Text(context.localized.aboutBuild(applicationInfo.buildNumber)),
            const SizedBox(height: 16),
            Text(context.localized.aboutCreatedBy),
          ],
        ),
        const FractionallySizedBox(
          widthFactor: 0.25,
          child: Divider(
            indent: 16,
            endIndent: 16,
          ),
        ),
        const _SocialsSection(),
        // Pas de section sponsors ici : les liens de funding_model.dart
        // mènent aux comptes personnels des mainteneurs de Fladder —
        // les afficher sous "Kinos" laisserait croire qu'ils financent
        // ce fork. Le modèle reste disponible si tu veux y mettre les
        // tiens et rebrancher une section équivalente.
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            FilledButton.tonal(
              onPressed: () => showLicensePage(
                context: context,
                applicationIcon: const KinosIcon(size: 55),
                applicationVersion: applicationInfo.versionPlatformBuild,
                applicationLegalese: "Kinos — fork de Fladder par DonutWare",
                useRootNavigator: true,
              ),
              child: Text(context.localized.aboutLicenses),
            )
          ],
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            FilledButton.tonal(
              onPressed: () => showDialog(
                context: context,
                builder: (context) => const CrashScreen(),
              ),
              child: Text(context.localized.errorLogs),
            )
          ],
        ),
        const SettingsUpdateInformation(),
      ].addInBetween(const SizedBox(height: 16)),
    );
  }
}

class _SocialsSection extends StatelessWidget {
  const _SocialsSection();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          context.localized.aboutSocials,
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 6),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: socials
              .map(
                (e) => IconButton.filledTonal(
                  onPressed: () => launchUrl(context, e.url),
                  icon: Column(
                    children: [
                      FaIcon(e.icon),
                      Text(e.label),
                    ],
                  ),
                ),
              )
              .toList()
              .addInBetween(const SizedBox(width: 16)),
        )
      ],
    );
  }
}
