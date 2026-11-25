import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:kinos/screens/shared/startup_aurora.dart';

void main() {
  testWidgets('the aurora painted small looks the same as at full size',
      (tester) async {
    await tester.runAsync(() async {
      const size = Size(1920, 1080);
      final colors = StartupAurora.colorsFor(const Color(0xFF2A4A6A));
      Future<List<int>> render(bool low) async {
        final recorder = ui.PictureRecorder();
        final canvas = Canvas(recorder);
        if (low) {
          StartupAurora.paint(canvas, Offset.zero & size,
              colors: colors, intensity: 1);
        } else {
          StartupAurora.debugPaintFull(canvas, Offset.zero & size,
              colors: colors, intensity: 1);
        }
        final image = await recorder
            .endRecording()
            .toImage(size.width.toInt(), size.height.toInt());
        final data = await image.toByteData();
        return data!.buffer.asUint8List();
      }

      final a = await render(false);
      final b = await render(true);
      var sum = 0, worst = 0;
      for (var i = 0; i < a.length; i++) {
        final d = (a[i] - b[i]).abs();
        sum += d;
        if (d > worst) worst = d;
      }
      expect(sum / a.length, lessThan(1));
      expect(worst, lessThanOrEqualTo(8));
    });
  });
}
