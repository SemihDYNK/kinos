import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kinos/models/syncing/database_item.dart';
import 'package:kinos/models/settings/home_row_model.dart';
import 'package:kinos/providers/database_provider.dart';
import 'package:kinos/providers/settings/home_rows_provider.dart';

void main() {
  test('installs once, persists TTL, and never restores a removed row',
      () async {
    final container = ProviderContainer(overrides: [
      appDatabaseProvider
          .overrideWith((ref) => AppDatabase(ref, NativeDatabase.memory())),
    ]);
    addTearDown(container.dispose);
    final db = container.read(appDatabaseProvider);
    addTearDown(db.close);
    for (final key in [
      'home_rows_initialized',
      'home_rows_recommendation_migration',
      'home_rows_catalog_migration'
    ]) {
      await db.setSetting(key, '1', scope: 'dashboard');
    }
    final subscription = container.listen(homeRowsProvider, (_, __) {});
    addTearDown(subscription.close);
    // Wait for the asynchronous settings load/migration without network calls.
    for (var i = 0; i < 100 && container.read(homeRowsProvider).isEmpty; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 5));
    }
    final row = container.read(homeRowsProvider).single;
    expect(row.type, HomeRowType.seerrDiscovery);
    expect(row.params['cacheDays'], '7');
    final notifier = container.read(homeRowsProvider.notifier);
    await notifier.setDiscoveryCacheDays(row.id, 14);
    expect((await db.getSetting('home_rows', scope: 'dashboard'))!.value,
        contains('14'));
    await notifier.toggle(row.id);
    expect(container.read(homeRowsProvider).single.enabled, false);
    await notifier.remove(row.id);
    container.invalidate(homeRowsProvider);
    await Future<void>.delayed(const Duration(milliseconds: 30));
    expect(container.read(homeRowsProvider), isEmpty);
  });
}
