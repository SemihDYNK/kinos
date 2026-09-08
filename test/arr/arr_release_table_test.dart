import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:kinos/arr/models/arr_grab_status.dart';
import 'package:kinos/arr/models/arr_release.dart';
import 'package:kinos/arr/screens/widgets/arr_release_table.dart';

ArrRelease _release({String? infoUrl, String title = 'Movie.Title.2024'}) {
  return ArrRelease(
    guid: 'guid-1',
    indexerId: 1,
    indexer: 'SomeIndexer',
    title: title,
    infoUrl: infoUrl,
    size: 1000,
    ageDays: 1,
    seeders: 5,
    leechers: 1,
    protocol: ArrReleaseProtocol.torrent,
    qualityName: 'Bluray-1080p',
    languages: const ['French'],
    customFormatScore: 0,
    rejected: false,
    rejections: const [],
  );
}

Widget _harness(ArrRelease release) {
  return MaterialApp(
    home: Scaffold(
      body: SizedBox(
        width: 1400,
        child: ArrReleaseTable(
          releases: [release],
          grabStatuses: const {},
          onGrab: (_) {},
        ),
      ),
    ),
  );
}

void main() {
  group('ArrReleaseTable — title link', () {
    testWidgets(
        'infoUrl present: the title shows a hand cursor and a domain tooltip',
        (tester) async {
      await tester.pumpWidget(_harness(_release(
        infoUrl: 'https://indexer.example/details/123',
      )));
      await tester.pumpAndSettle();

      final mouseRegion = tester.widget<MouseRegion>(find.ancestor(
        of: find.text('Movie.Title.2024'),
        matching: find.byType(MouseRegion),
      ));
      expect(mouseRegion.cursor, SystemMouseCursors.click);

      final tooltip = tester.widget<Tooltip>(find.ancestor(
        of: find.text('Movie.Title.2024'),
        matching: find.byType(Tooltip),
      ));
      expect(tooltip.message, 'Ouvrir sur indexer.example');

      // Un tap consomme le vrai plugin url_launcher (non disponible en
      // test) — on vérifie seulement que le titre porte bien un
      // gestionnaire de tap, pas qu'il s'exécute. Plusieurs
      // GestureDetector sont ancêtres du titre (celui du titre lui-même,
      // et celui — clic droit seulement — de la ligne) : au moins un doit
      // porter onTap.
      final gestures = tester.widgetList<GestureDetector>(find.ancestor(
        of: find.text('Movie.Title.2024'),
        matching: find.byType(GestureDetector),
      ));
      expect(gestures.any((g) => g.onTap != null), isTrue);
    });

    testWidgets(
        'infoUrl absent: plain text, full-title tooltip, no click affordance',
        (tester) async {
      await tester.pumpWidget(_harness(_release(infoUrl: null)));
      await tester.pumpAndSettle();

      expect(
        find.ancestor(
            of: find.text('Movie.Title.2024'),
            matching: find.byType(MouseRegion)),
        findsNothing,
      );

      final tooltip = tester.widget<Tooltip>(find.ancestor(
        of: find.text('Movie.Title.2024'),
        matching: find.byType(Tooltip),
      ));
      expect(tooltip.message, 'Movie.Title.2024');
    });

    testWidgets('infoUrl empty string is treated like absent', (tester) async {
      await tester.pumpWidget(_harness(_release(infoUrl: '')));
      await tester.pumpAndSettle();

      expect(
        find.ancestor(
            of: find.text('Movie.Title.2024'),
            matching: find.byType(MouseRegion)),
        findsNothing,
      );
    });
  });

  group('ArrReleaseTable — context menu', () {
    Future<void> rightClickRow(WidgetTester tester) async {
      // Fenêtre large : la ligne de test est volontairement plus large
      // que l'écran par défaut (table à 9 colonnes) — sans cette marge,
      // le clic droit atterrirait trop près du bord et `showMenu`
      // compresserait le menu au point de le rendre inutilisable ici.
      tester.view.physicalSize = const Size(1800, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final gesture = await tester.startGesture(
        tester.getCenter(find.text('Movie.Title.2024')),
        kind: PointerDeviceKind.mouse,
        buttons: kSecondaryMouseButton,
      );
      await tester.pump();
      await gesture.up();
      await tester.pumpAndSettle();
    }

    testWidgets(
        '"Ouvrir la page de l\'indexeur" is enabled when infoUrl is present',
        (tester) async {
      await tester.pumpWidget(_harness(_release(
        infoUrl: 'https://indexer.example/details/123',
      )));
      await tester.pumpAndSettle();

      await rightClickRow(tester);

      final item = tester.widget<PopupMenuItem<void>>(find.widgetWithText(
          PopupMenuItem<void>, 'Ouvrir la page de l\'indexeur'));
      expect(item.enabled, isTrue);
    });

    testWidgets(
        '"Ouvrir la page de l\'indexeur" is disabled when infoUrl is absent',
        (tester) async {
      await tester.pumpWidget(_harness(_release(infoUrl: null)));
      await tester.pumpAndSettle();

      await rightClickRow(tester);

      final item = tester.widget<PopupMenuItem<void>>(find.widgetWithText(
          PopupMenuItem<void>, 'Ouvrir la page de l\'indexeur'));
      expect(item.enabled, isFalse);
    });
  });
}
