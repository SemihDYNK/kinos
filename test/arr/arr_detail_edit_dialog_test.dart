import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fladder/arr/models/arr_media_detail.dart';
import 'package:fladder/arr/screens/widgets/arr_detail_edit_dialog.dart';

void main() {
  ArrDetailEntry entry() {
    final movie = ArrMovieDetail.fromJson(
      {
        'id': 1,
        'title': 'Dune',
        'monitored': false,
        'qualityProfileId': 1,
        'rootFolderPath': '/movies/',
      },
      baseUrl: 'https://radarr.example.com',
      apiKey: 'key',
    );
    return ArrDetailEntry.movie(movie);
  }

  Widget harness(
      ArrDetailEntry entry, ValueChanged<ArrDetailEditResult?> onResult) {
    return MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              final result = await showArrDetailEditDialog(
                context,
                entry: entry,
                qualityProfiles: const [
                  ArrQualityProfile(id: 1, name: 'HD-1080p'),
                  ArrQualityProfile(id: 2, name: 'Ultra-HD'),
                ],
                rootFolders: const [
                  ArrRootFolder(id: 1, path: '/movies/'),
                  ArrRootFolder(id: 2, path: '/movies-4k/'),
                ],
              );
              onResult(result);
            },
            child: const Text('Ouvrir'),
          ),
        ),
      ),
    );
  }

  testWidgets('cancel returns null, changes nothing', (tester) async {
    ArrDetailEditResult? captured;
    await tester.pumpWidget(harness(entry(), (r) => captured = r));

    await tester.tap(find.text('Ouvrir'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Annuler'));
    await tester.pumpAndSettle();

    expect(captured, isNull);
  });

  testWidgets(
      'changing quality profile, root folder and monitored saves the new values',
      (tester) async {
    ArrDetailEditResult? captured;
    await tester.pumpWidget(harness(entry(), (r) => captured = r));

    await tester.tap(find.text('Ouvrir'));
    await tester.pumpAndSettle();

    // Valeurs de départ affichées.
    expect(find.text('HD-1080p'), findsOneWidget);
    expect(find.text('/movies/'), findsWidgets);

    // Profil de qualité -> Ultra-HD.
    await tester.tap(find.text('HD-1080p'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ultra-HD'));
    await tester.pumpAndSettle();

    // Dossier racine -> /movies-4k/.
    await tester.tap(find.text('/movies/').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('/movies-4k/'));
    await tester.pumpAndSettle();

    // Surveillé.
    await tester.tap(find.byType(Checkbox));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Enregistrer'));
    await tester.pumpAndSettle();

    expect(captured, isNotNull);
    expect(captured!.qualityProfileId, 2);
    expect(captured!.rootFolderPath, '/movies-4k/');
    expect(captured!.monitored, isTrue);
  });
}
