# Drift schema snapshots

One JSON file per `AppDatabase.schemaVersion` that has ever shipped
(`drift_schema_v<N>.json`), used by the migration tests in
`test/database/` to verify that `AppDatabase.migration` actually produces
the schema declared by the current table definitions.

**Never edit or delete an existing snapshot.** Each one is a permanent
record of what a given `schemaVersion` looked like for users who already
have a database at that version.

## After bumping `schemaVersion`

1. Dump the new version:
   ```sh
   dart run drift_dev schema dump lib/models/syncing/database_item.dart drift_schemas/
   ```
2. Regenerate the migration-test helpers from every snapshot so far:
   ```sh
   dart run drift_dev schema generate --data-classes --companions drift_schemas/ test/drift_generated/
   ```
3. Extend `AppDatabase.migration`'s `onUpgrade` to cover the new version,
   and add a test in `test/database/app_database_migration_test.dart`
   asserting the upgrade lands on the schema declared by the current code
   (`verifier.migrateAndValidate`).
