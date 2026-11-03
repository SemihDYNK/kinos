import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kinos/widgets/shared/ambient_blur.dart';

void main() {
  testWidgets('ambient image comes from player, without capturing its texture',
      (tester) async {
    final bytes =
        File('test/widgets/fixtures/rest/movie-desktop.png').readAsBytesSync();
    var captures = 0;
    await tester
        .pumpWidget(MaterialApp(home: SizedBox.expand(child: AmbientBlur(
      captureFrame: () async {
        captures++;
        return bytes;
      },
    ))));
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 250));
    });
    await tester.pump();
    expect(captures, 1);
    expect(find.byType(RawImage), findsWidgets);
    await tester.pumpWidget(const SizedBox.shrink());
    expect(tester.takeException(), isNull);
  });

  testWidgets('an unavailable first video frame can be retried',
      (tester) async {
    var captures = 0;
    await tester.pumpWidget(MaterialApp(
        home: SizedBox.expand(
            child: AmbientBlur(
      duration: const Duration(milliseconds: 100),
      captureFrame: () async {
        captures++;
        return null;
      },
    ))));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 101));
    await tester.pump();
    expect(captures, greaterThan(1));
    await tester.pumpWidget(const SizedBox.shrink());
    expect(tester.takeException(), isNull);
  });

  testWidgets('closing during capture does not update a disposed widget',
      (tester) async {
    final capture = Future<Uint8List?>.delayed(
        const Duration(milliseconds: 20), () => null);
    await tester.pumpWidget(MaterialApp(
        home:
            SizedBox.expand(child: AmbientBlur(captureFrame: () => capture))));
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 30));
    expect(tester.takeException(), isNull);
  });
}
