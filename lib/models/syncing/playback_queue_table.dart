import 'package:drift/drift.dart';

/// The kind of session event a queued [PlaybackQueue] row represents.
///
/// Mirrors the three Jellyfin session endpoints Fladder reports to
/// (`Sessions/Playing`, `Sessions/Playing/Progress`, `Sessions/Playing/Stopped`).
enum PlaybackQueueEventType { start, progress, stop }

/// Outbox of playback session reports (start/progress/stop) that still need
/// to reach the Jellyfin server.
///
/// Reporting these events to the server is currently fire-and-forget: if the
/// network is unavailable when a report is sent, it is silently lost. This
/// table lets a future retry worker persist pending reports and drain them
/// once connectivity returns, instead of dropping them.
@TableIndex(name: 'playback_queue_user_item', columns: {#userId, #itemId})
@TableIndex(name: 'playback_queue_pending', columns: {#attempts, #createdAt})
@DataClassName('PlaybackQueueEntry')
class PlaybackQueue extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get userId => text().withLength(min: 1)();
  TextColumn get itemId => text().withLength(min: 1)();
  TextColumn get eventType => textEnum<PlaybackQueueEventType>()();
  IntColumn get positionTicks => integer().withDefault(const Constant(0))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  IntColumn get attempts => integer().withDefault(const Constant(0))();
  TextColumn get lastError => text().nullable()();
}
