import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:kinos/screens/shared/startup_aurora.dart';

void main() {
  testWidgets('l\'horloge de l\'aurore avance tant qu\'elle est montée',
      (tester) async {
    await tester.pumpWidget(const StartupAuroraTicker());
    final before = StartupAurora.time.value;
    // Le temps réel s'écoule entre deux images (Stopwatch) : on attend un
    // peu de vrai temps avant l'image suivante.
    await tester
        .runAsync(() => Future<void>.delayed(const Duration(milliseconds: 30)));
    await tester.pump(const Duration(milliseconds: 16));
    expect(StartupAurora.time.value, greaterThan(before));
    await tester.pumpWidget(const SizedBox());
  });

  test('les taches ont des couleurs distinctes', () {
    final colors = StartupAurora.colorsFor(const Color(0xFF1E3550));
    expect(colors.toSet().length, colors.length);
  });
}
