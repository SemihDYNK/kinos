import 'package:flutter_test/flutter_test.dart';

import 'package:fladder/models/playback/playback_report_conflict.dart';

void main() {
  group('PlaybackConflictResolver', () {
    test('sends the queued position when it is ahead of the server and the item is not played', () {
      final decision = PlaybackConflictResolver.resolve(
        queuedPositionTicks: 500000,
        serverPositionTicks: 100000,
        serverPlayed: false,
      );

      expect(decision, const PlaybackReportDecision.send(500000));
    });

    test('sends the server position when it is ahead of the queued one and the item is not played', () {
      // e.g. the item kept playing on another device while this one was offline.
      final decision = PlaybackConflictResolver.resolve(
        queuedPositionTicks: 100000,
        serverPositionTicks: 500000,
        serverPlayed: false,
      );

      expect(decision, const PlaybackReportDecision.send(500000));
    });

    test('sends the shared position when queued and server positions are equal', () {
      final decision = PlaybackConflictResolver.resolve(
        queuedPositionTicks: 250000,
        serverPositionTicks: 250000,
        serverPlayed: false,
      );

      expect(decision, const PlaybackReportDecision.send(250000));
    });

    test('treats a missing server position as 0, so the queued position always wins', () {
      // e.g. the item was never reported to this server before going offline.
      final decision = PlaybackConflictResolver.resolve(
        queuedPositionTicks: 300000,
        serverPositionTicks: null,
        serverPlayed: false,
      );

      expect(decision, const PlaybackReportDecision.send(300000));
    });

    test('sends position 0 when both queued and server positions are 0', () {
      final decision = PlaybackConflictResolver.resolve(
        queuedPositionTicks: 0,
        serverPositionTicks: 0,
        serverPlayed: false,
      );

      expect(decision, const PlaybackReportDecision.send(0));
    });

    test(
        'skips the queued report when the server already marked the item as played, '
        'even if the queued position is far ahead of the server one', () {
      final decision = PlaybackConflictResolver.resolve(
        queuedPositionTicks: 900000,
        serverPositionTicks: 100000,
        serverPlayed: true,
      );

      expect(decision, const PlaybackReportDecision.skip());
      expect(decision.shouldSend, isFalse);
    });

    test(
        'skips the queued report when the server already marked the item as played, '
        'even if the queued position is behind the server one', () {
      final decision = PlaybackConflictResolver.resolve(
        queuedPositionTicks: 100000,
        serverPositionTicks: 900000,
        serverPlayed: true,
      );

      expect(decision, const PlaybackReportDecision.skip());
    });

    test('skips the queued report when the server marked the item as played and reports no position', () {
      final decision = PlaybackConflictResolver.resolve(
        queuedPositionTicks: 100000,
        serverPositionTicks: null,
        serverPlayed: true,
      );

      expect(decision, const PlaybackReportDecision.skip());
    });
  });
}
