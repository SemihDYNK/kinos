import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:fladder/models/syncing/database_item.dart';

/// Single shared [AppDatabase] instance for the whole app.
///
/// Drift supports opening more than one [GeneratedDatabase] around the same
/// sqlite file, but warns against it (concurrent instances race on the same
/// connection) - route every consumer through this provider instead of
/// constructing `AppDatabase(ref)` directly.
final appDatabaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase(ref);
  ref.onDispose(db.close);
  return db;
});
