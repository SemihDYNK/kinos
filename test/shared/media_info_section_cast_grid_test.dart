import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:kinos/l10n/generated/app_localizations.dart';
import 'package:kinos/localization_delegates.dart';
import 'package:kinos/models/items/item_shared_models.dart';
import 'package:kinos/screens/details_screens/components/media_info_section.dart';
import 'package:kinos/theme/app_theme.dart';

/// Régression pour le même bug que `season_episode_section_test.dart` :
/// `_CastTile` partage exactement la construction fautive (`FocusRing`
/// enrobant un `Column` non flexible, hauteur de rangée calculée sans
/// budgéter le padding de `FocusRing`) — corrigée en même temps, ici
/// masquée en pratique par un `ClipRect` qui existe pour une autre
/// raison (cf. commentaire dans `media_info_section.dart`), donc jamais
/// visible en debug malgré le même défaut de calcul.
void main() {
  for (final width in [900.0, 1280.0, 1920.0]) {
    testWidgets(
        'grille de casting, largeur $width : aucun débordement de la '
        'rangée', (tester) async {
      final people = [
        for (var i = 0; i < 10; i++)
          Person(id: 'p$i', name: 'Acteur avec un nom assez long $i'),
      ];

      await tester.pumpWidget(ProviderScope(
        child: MaterialApp(
          theme: buildAppTheme(),
          localizationsDelegates: KinosLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: MediaQuery(
            data: MediaQueryData(size: Size(width, 1200)),
            child: Scaffold(
              body: SingleChildScrollView(
                child: MediaInfoSection(
                  people: people,
                  info: const [],
                  contentPadding: const EdgeInsets.symmetric(horizontal: 24),
                ),
              ),
            ),
          ),
        ),
      ));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });
  }
  for (final width in [900.0, 1280.0, 1920.0]) {
    testWidgets(
        'cinematic casting keeps names and roles inside grid at $width and 150%',
        (tester) async {
      tester.view.physicalSize = Size(width, 1100);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(ProviderScope(
          child: MaterialApp(
        theme: buildAppTheme(),
        localizationsDelegates: KinosLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: MediaQuery(
            data: MediaQueryData(
                size: Size(width, 1100),
                padding: const EdgeInsets.only(top: 40),
                textScaler: const TextScaler.linear(1.5)),
            child: Scaffold(
                body: SingleChildScrollView(
                    child: MediaInfoSection(
              cinematic: true,
              people: List.generate(
                  10,
                  (i) => Person(
                      id: 'p$i',
                      name: 'Camille Moreau $i',
                      role: 'Personnage $i')),
              info: const [
                (
                  label: 'Réalisation',
                  value: 'Une personne avec un nom particulièrement long'
                )
              ],
              contentPadding: const EdgeInsets.all(24),
            )))),
      )));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      final grid = tester.getRect(find.byType(GridView));
      expect(tester.getRect(find.text('Camille Moreau 0')).bottom,
          lessThanOrEqualTo(grid.bottom));
      expect(tester.getRect(find.text('Personnage 0')).bottom,
          lessThanOrEqualTo(grid.bottom));
      expect(
          tester.getRect(find.text('Personnage 0')).top, greaterThan(grid.top));
    });
  }
}
