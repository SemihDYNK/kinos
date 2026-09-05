/// What to do with a playback report queued in `playback_queue` once we're
/// back online and can compare it against the server's current state for
/// that item.
enum PlaybackReportAction { send, skip }

/// Result of reconciling a locally queued playback report with the server's
/// current knowledge of the item, right before the report is (re)sent.
class PlaybackReportDecision {
  final PlaybackReportAction action;

  /// The position to actually report. Only meaningful when [action] is
  /// [PlaybackReportAction.send] - always 0 for [PlaybackReportAction.skip].
  final int positionTicks;

  const PlaybackReportDecision._(this.action, this.positionTicks);

  const PlaybackReportDecision.send(int positionTicks) : this._(PlaybackReportAction.send, positionTicks);

  const PlaybackReportDecision.skip() : this._(PlaybackReportAction.skip, 0);

  bool get shouldSend => action == PlaybackReportAction.send;

  @override
  String toString() => 'PlaybackReportDecision($action, positionTicks: $positionTicks)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PlaybackReportDecision && other.action == action && other.positionTicks == positionTicks);

  @override
  int get hashCode => Object.hash(action, positionTicks);
}

/// Resolves a playback report queued while offline against the server's
/// state for the same item, once connectivity returns.
///
/// Rule: the most advanced position wins - except when the server has
/// already marked the item as played/watched, in which case the queued
/// report is dropped entirely instead of resurrecting an earlier, less
/// complete state (e.g. a stale "still at 40%" progress report arriving
/// after the item was finished, possibly from another device, while this
/// one was offline).
class PlaybackConflictResolver {
  const PlaybackConflictResolver._();

  static PlaybackReportDecision resolve({
    required int queuedPositionTicks,
    required int? serverPositionTicks,
    required bool serverPlayed,
  }) {
    if (serverPlayed) return const PlaybackReportDecision.skip();

    final serverPosition = serverPositionTicks ?? 0;
    final resolvedPosition = queuedPositionTicks > serverPosition ? queuedPositionTicks : serverPosition;

    return PlaybackReportDecision.send(resolvedPosition);
  }
}
