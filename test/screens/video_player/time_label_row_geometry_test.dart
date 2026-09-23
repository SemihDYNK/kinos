import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:kinos/theme/app_theme.dart';

/// Recrée isolément la Row temps écoulé / temps restant de
/// `desktopBottomBar` (`video_player_controls.dart`) — même structure
/// exacte (`Row(mainAxisAlignment: spaceBetween, children: [Flexible,
/// Flexible])`), pour vérifier par la géométrie (RenderBox) que le
/// temps restant reste bien collé au bord droit.
///
/// Root cause mesurée de la régression rapportée ("-50:33 vers 36 % de
/// la largeur au lieu du bord droit") : la version précédente utilisait
/// `Row(children: [Flexible(gauche), Spacer(), Flexible(droite)])`.
/// `Spacer` (flex:1, fit tight) réclame TOUJOURS son tiers de largeur
/// complet, mais les deux `Flexible` (fit loose) rétrécissent à leur
/// texte sans que cet espace inutilisé leur soit redistribué — mesuré :
/// le texte de droite finissait avec un bord droit à ~54 % de la
/// largeur totale, jamais à 100 %. `spaceBetween` avec deux `Flexible`
/// seuls (sans `Spacer`) calcule l'espace restant une fois les deux
/// textes posés à leur taille réelle et le place entièrement entre eux.
Widget _timeRow({
  required double width,
  required String left,
  required String right,
}) {
  return MaterialApp(
    theme: buildAppTheme(),
    home: Scaffold(
      body: SizedBox(
        width: width,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Flexible(
              child: Text(
                left,
                key: const Key('left'),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
                style: const TextStyle(
                    fontFeatures: [FontFeature.tabularFigures()]),
              ),
            ),
            Flexible(
              child: Text(
                right,
                key: const Key('right'),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
                textAlign: TextAlign.right,
                style: const TextStyle(
                    fontFeatures: [FontFeature.tabularFigures()]),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

void main() {
  for (final width in [900.0, 1280.0, 1920.0]) {
    testWidgets(
        'largeur $width : le temps restant reste collé au bord droit '
        '(±0,5 px)', (tester) async {
      await tester.pumpWidget(
          _timeRow(width: width, left: '01:29', right: '-50:33'));
      await tester.pump();

      final rowBox = tester.renderObject<RenderBox>(find.byType(Row));
      final rowRight =
          tester.getTopLeft(find.byType(Row)).dx + rowBox.size.width;
      final rightTopLeft = tester.getTopLeft(find.byKey(const Key('right')));
      final rightSize = tester.getSize(find.byKey(const Key('right')));
      final rightEdge = rightTopLeft.dx + rightSize.width;

      expect(rightEdge, closeTo(rowRight, 0.5));
      expect(tester.getTopLeft(find.byKey(const Key('left'))).dx, 0.0);
      expect(tester.takeException(), isNull);
    });

    testWidgets('largeur $width : ne déborde jamais, même sur un film long',
        (tester) async {
      await tester.pumpWidget(
          _timeRow(width: width, left: '02:14:07', right: '-1:23:45'));
      await tester.pump();

      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
      'largeur pathologique (100 px) : dégrade proprement (ellipsis), '
      'jamais de débordement dur', (tester) async {
    await tester.pumpWidget(
        _timeRow(width: 100, left: '01:29', right: '-50:33'));
    await tester.pump();

    expect(tester.takeException(), isNull);
  });
}
