import 'package:drift/drift.dart';

/// The kind of session event a queued [PlaybackQueue] row represents.
///
/// Mirrors the three Jellyfin session endpoints Kinos reports to
/// (`Sessions/Playing`, `Sessions/Playing/Progress`, `Sessions/Playing/Stopped`).
enum PlaybackQueueEventType { start, progress, stop }

/// Outbox of playback session reports (start/progress/stop) that still need
/// to reach the Jellyfin server.
///
/// Reporting these events used to be fire-and-forget: if the network was
/// unavailable when a report was sent, it was silently lost. This table
/// lets `PlaybackReportQueueWorker` (`playback_report_queue_provider.dart`)
/// persist pending reports and drain them once connectivity returns,
/// instead of dropping them.
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
