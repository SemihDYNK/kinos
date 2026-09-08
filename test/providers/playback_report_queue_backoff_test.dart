import 'package:flutter_test/flutter_test.dart';

import 'package:kinos/providers/playback_report_queue_provider.dart';

void main() {
  group('PlaybackReportQueueWorker.backoffForAttempts', () {
    test('grows exponentially with the attempt count', () {
      final delays = [
        for (var attempts = 0; attempts <= 5; attempts++) PlaybackReportQueueWorker.backoffForAttempts(attempts)
      ];

      for (var i = 1; i < delays.length; i++) {
        expect(delays[i], greaterThan(delays[i - 1]));
        expect(delays[i].inMilliseconds, delays[i - 1].inMilliseconds * 2);
      }
    });

    test('is capped so a stuck entry does not back off indefinitely', () {
      final farOut = PlaybackReportQueueWorker.backoffForAttempts(50);
      expect(farOut, const Duration(minutes: 5));
    });
  });
}
