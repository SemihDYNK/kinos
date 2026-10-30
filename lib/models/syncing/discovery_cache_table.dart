import 'package:drift/drift.dart';

/// Non-secret, versioned discovery payloads. Scope includes server, profile,
/// Seerr instance and language. Empty successful lists are cacheable too.
class DiscoveryCacheEntries extends Table {
  TextColumn get scope => text()();
  TextColumn get cacheKey => text()();
  TextColumn get payload => text()();
  DateTimeColumn get capturedAt => dateTime()();
  DateTimeColumn get expiresAt => dateTime()();
  @override
  Set<Column<Object>> get primaryKey => {scope, cacheKey};
}
