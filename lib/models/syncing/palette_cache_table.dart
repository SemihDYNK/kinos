import 'package:drift/drift.dart';

/// Cached dominant color (ARGB) extracted from an item's artwork, keyed by
/// item id, so palette extraction doesn't have to be redone on every
/// appearance of that item (e.g. ambient backgrounds, theming).
@DataClassName('PaletteCacheEntry')
class PaletteCache extends Table {
  TextColumn get itemId => text().withLength(min: 1)();
  IntColumn get argb => integer()();
  DateTimeColumn get extractedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column<Object>> get primaryKey => {itemId};
}
