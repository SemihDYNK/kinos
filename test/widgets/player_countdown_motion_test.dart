import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kinos/widgets/shared/progress_floating_button.dart';
import 'package:square_progress_indicator/square_progress_indicator.dart';
import 'package:wakelock_plus_platform_interface/wakelock_plus_platform_interface.dart';

class _Wakelock extends WakelockPlusPlatformInterface {
  @override
  Future<void> toggle({required bool enable}) async {}
  @override
  Future<bool> get enabled async => false;
}

void main() {
  testWidgets(
      'countdown interpolates between ticks and stops safely when paused',
      (tester) async {
    WakelockPlusPlatformInterface.instance = _Wakelock();
    var elapsed = 0;
    final controller = RestartableTimerController(
        const Duration(seconds: 1), const Duration(milliseconds: 100),
        onTimeout: () => elapsed++);
    await tester.pumpWidget(ProviderScope(
        child: MaterialApp(
            home: SizedBox.square(
                dimension: 60,
                child: ProgressFloatingButton(controller: controller)))));
    controller.play();
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(
        tester
            .widget<SquareProgressIndicator>(
                find.byType(SquareProgressIndicator))
            .value,
        inExclusiveRange(.9, 1));
    expect(elapsed, 0);
    controller.cancel();
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 2));
    expect(elapsed, 0);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
