import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:kinos/theme/app_theme.dart';
import 'package:kinos/widgets/shared/poster_lift_room.dart';

void main() {
  testWidgets(
      'la rangée garde sa taille, le défilement déborde de la marge et '
      'les jaquettes restent à leur place', (tester) async {
    const room = AppMotion.posterLiftRoom;
    await tester.pumpWidget(Directionality(
      textDirection: TextDirection.ltr,
      child: Align(
        alignment: Alignment.topLeft,
        child: SizedBox(
          width: 400,
          child: PosterLiftRoom(
            height: 100,
            builder: (context, padding) => SingleChildScrollView(
              key: const Key('scroll'),
              scrollDirection: Axis.horizontal,
              padding: padding,
              child:
                  const SizedBox(key: Key('poster'), width: 120, height: 100),
            ),
          ),
        ),
      ),
    ));

    expect(tester.getSize(find.byType(PosterLiftRoom)), const Size(400, 100));
    expect(tester.getSize(find.byKey(const Key('scroll'))),
        const Size(400 + 2 * room, 100 + 2 * room));
    expect(tester.getTopLeft(find.byKey(const Key('poster'))), Offset.zero);
  });
}
