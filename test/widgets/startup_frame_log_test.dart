import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:logging/logging.dart';

import 'package:kinos/screens/shared/startup_frame_log.dart';

void main() {
  testWidgets('le relevé s\'arrête après la révélation, avec un bilan',
      (tester) async {
    final records = <LogRecord>[];
    final subscription = startupFrameLogger.onRecord.listen(records.add);
    addTearDown(subscription.cancel);
    Logger.root.level = Level.ALL;

    StartupFrameLog.start();
    StartupFrameLog.phase(StartupPhase.aurora);
    StartupFrameLog.phase(StartupPhase.beam);
    await tester.pumpWidget(const SizedBox());
    StartupFrameLog.stop();
    await tester.pump(const Duration(seconds: 2));

    final summary = records.where((r) => r.message.startsWith('Démarrage'));
    expect(summary, hasLength(1));
    expect(summary.single.level, Level.WARNING);
    // Arrêté : un nouveau bilan ne repart pas sans nouveau départ.
    StartupFrameLog.stop();
    await tester.pump(const Duration(seconds: 2));
    expect(
        records.where((r) => r.message.startsWith('Démarrage')), hasLength(1));
  });
}
