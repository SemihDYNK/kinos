import 'package:drift/drift.dart';

/// Key/value preferences scoped by [scope] (e.g. a specific screen output or
/// display identifier), so the same preference key can hold a different
/// value per output instead of a single global one.
///
/// Row class name defaults to [Setting] (trailing "s" stripped), matching the
/// `DatabaseItems` -> `DatabaseItem` convention already used in this folder.
@TableIndex(name: 'settings_scope', columns: {#scope})
class Settings extends Table {
  TextColumn get key => text().withLength(min: 1)();
  TextColumn get value => text()();
  TextColumn get scope => text().withLength(min: 1)();

  @override
  Set<Column<Object>> get primaryKey => {key, scope};
}
