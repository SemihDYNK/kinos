import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// Ce test ne monte pas l'écran détail complet (ça exigerait tout
// l'appareillage AutoRoute + Riverpod) : il vérifie le mécanisme Flutter
// dont `ArrLibraryScreen._openDetail` dépend — que pousser puis dépiler
// une route restaure de lui-même le focus sur le nœud qui l'avait avant
// (ici, tel qu'utilisé par `ArrLibraryGrid` : `_focusNode.requestFocus()`
// est appelé juste avant `context.router.push(...)`), sans code de
// restauration explicite à écrire. Si ce test échouait, il faudrait
// ajouter une reprise de focus manuelle après le `pop`.
void main() {
  testWidgets(
      'popping a pushed route restores focus to the node focused just before the push',
      (tester) async {
    final gridFocusNode = FocusNode(debugLabel: 'grid');
    addTearDown(gridFocusNode.dispose);

    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: Focus(
            focusNode: gridFocusNode,
            child: TextButton(
              key: const Key('tile'),
              onPressed: () {
                // Même séquence qu'ArrLibraryGrid._ArrLibraryTile.onTap :
                // le focus est repris explicitement AVANT de pousser la
                // route détail.
                gridFocusNode.requestFocus();
                Navigator.of(context).push(MaterialPageRoute(
                  builder: (context) => Scaffold(
                    body: TextButton(
                      key: const Key('back'),
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Retour'),
                    ),
                  ),
                ));
              },
              child: const Text('Ouvrir la fiche'),
            ),
          ),
        ),
      ),
    ));

    await tester.tap(find.byKey(const Key('tile')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('back')), findsOneWidget);
    await tester.tap(find.byKey(const Key('back')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('tile')), findsOneWidget);
    expect(gridFocusNode.hasFocus, isTrue,
        reason: 'Flutter restaure le focus scope de la route précédente au pop '
            '— pas besoin de le redemander manuellement.');
  });
}
