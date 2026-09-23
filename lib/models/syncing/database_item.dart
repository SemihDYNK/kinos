import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'package:kinos/models/item_base_model.dart';
import 'package:kinos/models/items/chapters_model.dart';
import 'package:kinos/models/items/images_models.dart';
import 'package:kinos/models/items/item_shared_models.dart';
import 'package:kinos/models/items/media_segments_model.dart';
import 'package:kinos/models/items/media_streams_model.dart';
import 'package:kinos/models/items/trick_play_model.dart';
import 'package:kinos/models/syncing/local_settings_table.dart';
import 'package:kinos/models/syncing/palette_cache_table.dart';
import 'package:kinos/models/syncing/playback_queue_table.dart';
import 'package:kinos/models/syncing/recommendation_cache_table.dart';
import 'package:kinos/models/syncing/sync_item.dart';
import 'package:kinos/providers/user_provider.dart';

export 'package:kinos/models/syncing/local_settings_table.dart';
export 'package:kinos/models/syncing/palette_cache_table.dart';
export 'package:kinos/models/syncing/playback_queue_table.dart';
export 'package:kinos/models/syncing/recommendation_cache_table.dart';

part 'database_item.g.dart';

const _databseName = 'syncedDatabase';

@TableIndex(name: 'database_id', columns: {#userId, #id})
class DatabaseItems extends Table {
  TextColumn get userId => text().withLength(min: 1)();
  TextColumn get id => text().withLength(min: 1)();
  BoolColumn get syncing => boolean().withDefault(const Constant(false))();
  TextColumn get sortName => text().nullable()();
  TextColumn get parentId => text().nullable()();
  TextColumn get path => text().nullable()();
  IntColumn get fileSize => integer().nullable()();
  TextColumn get videoFileName => text().nullable()();
  TextColumn get trickPlayModel => text().nullable()();
  TextColumn get mediaSegments => text().nullable()();
  TextColumn get images => text().nullable()();
  TextColumn get chapters => text().nullable()();
  TextColumn get subtitles => text().nullable()();
  BoolColumn get unSyncedData => boolean().withDefault(const Constant(false))();
  TextColumn get userData => text().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {userId, id};
}

@DriftDatabase(tables: [
  DatabaseItems,
  PlaybackQueue,
  PaletteCache,
  Settings,
  RecommendationCacheEntries,
])
class AppDatabase extends _$AppDatabase {
  AppDatabase(this.ref, [QueryExecutor? executor]) : super(executor ?? _openConnection());

  final Ref ref;

  String get userId => ref.read(userProvider.select((value) => value?.id ?? ""));

  @override
  int get schemaVersion => 3;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (Migrator m) async {
          await m.createAll();
        },
        onUpgrade: (Migrator m, int from, int to) async {
          if (from < 2 && to >= 2) {
            await m.createTable(playbackQueue);
            await m.createIndex(playbackQueueUserItem);
            await m.createIndex(playbackQueuePending);
            await m.createTable(paletteCache);
            await m.createTable(settings);
            await m.createIndex(settingsScope);
          }
          // `to >= 3`, pas seulement `from < 3` : SchemaVerifier
          // (`migrateAndValidate`, tests de migration) peut demander une
          // migration vers une version antérieure à `schemaVersion` actuel
          // pour valider une étape intermédiaire (ex. v1 -> v2, alors que
          // `AppDatabase` déclare déjà v3) — sans ce garde-fou, cette étape
          // s'exécutait quand même (elle ne regardait que `from`), créant
          // la table hors de la version ciblée par le test et provoquant
          // une double création détectée en pratique ("index already
          // exists") sur le test "v1 -> v2 preserves existing
          // database_items rows" une fois `schemaVersion` passé à 3.
          if (from < 3 && to >= 3) {
            await m.createTable(recommendationCacheEntries);
            await m.createIndex(recommendationCacheUserRow);
          }
        },
      );

  Future<void> clearDatabase() async {
    final dbPath = await getApplicationSupportDirectory();
    final dbFile = File(p.join(dbPath.path, '$_databseName.sqlite'));

    if (await dbFile.exists()) {
      await dbFile.delete(recursive: true);
    }
  }

  Selectable<SyncedItem> getItem(String id) =>
      (select(databaseItems)..where((tbl) => tbl.id.equals(id) & tbl.userId.equals(userId))).map(databaseConverter);

  Selectable<SyncedItem> getParent(String id) =>
      (select(databaseItems)..where((tbl) => tbl.parentId.equals(id) & tbl.userId.equals(userId)))
          .map(databaseConverter);

  Selectable<SyncedItem> get getParentItems =>
      ((select(databaseItems)..where((tbl) => (tbl.parentId.isNull() & tbl.userId.equals(userId))))
            ..orderBy([(t) => OrderingTerm(expression: t.sortName)]))
          .map(databaseConverter);

  Selectable<SyncedItem> get getAllItems => ((select(databaseItems)..where((tbl) => tbl.userId.equals(userId)))
        ..orderBy([(t) => OrderingTerm(expression: t.sortName)]))
      .map(databaseConverter);

  Selectable<SyncedItem> getChildren(String parentId) =>
      ((select(databaseItems)..where((tbl) => (tbl.parentId.equals(parentId) & tbl.userId.equals(userId))))
            ..orderBy([(t) => OrderingTerm(expression: t.sortName)]))
          .map(databaseConverter);

  Future<int> insertItem(SyncedItem item) async {
    final itemExists = await getItem(item.id).getSingleOrNull();
    if (itemExists != null) {
      return (update(databaseItems)..where((tbl) => tbl.id.equals(item.id) & tbl.userId.equals(userId)))
          .write(toDataBaseItem(item));
    } else {
      return into(databaseItems).insert(toDataBaseItem(item));
    }
  }

  Future<List<SyncedItem>> getNestedChildren(SyncedItem root) async {
    final itemType = root.createItemModel(ref)?.type;

    if (itemType == null) return [];

    final int maxDepth = switch (itemType) {
      KinosItemType.season => 1,
      KinosItemType.series => 2,
      KinosItemType.musicArtist => 2,
      KinosItemType.musicAlbum => 1,
      _ => 0,
    };

    final all = <SyncedItem>[];
    List<SyncedItem> toProcess = [root];

    if (maxDepth == 0) {
      return [];
    }

    for (var i = 0; i < maxDepth; i++) {
      final futures = toProcess.map((item) => getChildren(item.id).get());
      final resultsList = await Future.wait(futures);

      final children = resultsList.expand((r) => r).toList();

      if (children.isEmpty) break;

      all.addAll(children);
      toProcess = children;
    }

    return all;
  }

  Future<void> insertMultipleEntries(List<SyncedItem> items) async {
    await batch((batch) {
      batch.insertAll(
        databaseItems,
        items.map(toDataBaseItem),
        mode: InsertMode.insertOrReplace,
      );
    });
  }

  Future<void> deleteAllItems(List<SyncedItem> items) async {
    await batch((batch) {
      batch.deleteWhere(databaseItems, (tbl) => tbl.id.isIn(items.map((e) => e.id)) & tbl.userId.equals(userId));
    });
  }

  DatabaseItemsCompanion toDataBaseItem(SyncedItem item) {
    return DatabaseItemsCompanion(
      id: Value(item.id),
      parentId: Value(item.parentId),
      syncing: Value(item.syncing),
      userId: Value(userId),
      path: Value(item.path),
      fileSize: Value(item.fileSize),
      sortName: Value(item.sortName),
      videoFileName: Value(item.videoFileName),
      trickPlayModel: Value(item.fTrickPlayModel != null ? jsonEncode(item.fTrickPlayModel?.toJson()) : null),
      mediaSegments: Value(item.mediaSegments != null ? jsonEncode(item.mediaSegments?.toJson()) : null),
      images: Value(item.fImages != null ? jsonEncode(item.fImages?.toJson()) : null),
      chapters: Value(jsonEncode(item.fChapters.map((e) => e.toJson()).toList())),
      subtitles: Value(jsonEncode(item.subtitles.map((e) => e.toJson()).toList())),
      userData: Value(item.userData != null ? jsonEncode(item.userData?.toJson()) : null),
      unSyncedData: Value(item.unSyncedData),
    );
  }

  SyncedItem databaseConverter(DatabaseItem dataItem) {
    final syncedItem = SyncedItem(
      id: dataItem.id,
      userId: dataItem.userId,
      parentId: dataItem.parentId,
      sortName: dataItem.sortName,
      syncing: dataItem.syncing,
      path: dataItem.path,
      fileSize: dataItem.fileSize,
      videoFileName: dataItem.videoFileName,
      fTrickPlayModel:
          dataItem.trickPlayModel != null ? TrickPlayModel.fromJson(jsonDecode(dataItem.trickPlayModel!)) : null,
      mediaSegments:
          dataItem.mediaSegments != null ? MediaSegmentsModel.fromJson(jsonDecode(dataItem.mediaSegments!)) : null,
      fImages: dataItem.images != null ? ImagesData.fromJson(jsonDecode(dataItem.images!)) : null,
      fChapters: (dataItem.chapters != null && dataItem.chapters!.isNotEmpty)
          ? (jsonDecode(dataItem.chapters!) as List).map((e) => Chapter.fromJson(e)).toList()
          : [],
      subtitles: (dataItem.subtitles != null && dataItem.subtitles!.isNotEmpty)
          ? (jsonDecode(dataItem.subtitles!) as List).map((e) => SubStreamModel.fromJson(e)).toList()
          : [],
      userData: dataItem.userData != null ? UserData.fromJson(jsonDecode(dataItem.userData!)) : null,
      unSyncedData: dataItem.unSyncedData,
    );

    return syncedItem.copyWith(
      itemModel: syncedItem.createItemModel(ref),
    );
  }

  // --- playback_queue: offline outbox for start/progress/stop reports ---

  Future<int> enqueuePlaybackEvent({
    required String itemId,
    required PlaybackQueueEventType eventType,
    required int positionTicks,
  }) =>
      into(playbackQueue).insert(PlaybackQueueCompanion.insert(
        userId: userId,
        itemId: itemId,
        eventType: eventType,
        positionTicks: Value(positionTicks),
      ));

  Selectable<PlaybackQueueEntry> get getPendingPlaybackEvents =>
      ((select(playbackQueue)..where((tbl) => tbl.userId.equals(userId)))
        ..orderBy([(t) => OrderingTerm(expression: t.createdAt)]));

  Future<void> recordPlaybackEventFailure(int id, String error) =>
      (update(playbackQueue)..where((tbl) => tbl.id.equals(id))).write(
        PlaybackQueueCompanion(lastError: Value(error)),
      );

  Future<void> incrementPlaybackEventAttempts(int id) async {
    final entry = await (select(playbackQueue)..where((tbl) => tbl.id.equals(id))).getSingleOrNull();
    if (entry == null) return;
    await (update(playbackQueue)..where((tbl) => tbl.id.equals(id)))
        .write(PlaybackQueueCompanion(attempts: Value(entry.attempts + 1)));
  }

  Future<void> deletePlaybackEvent(int id) => (delete(playbackQueue)..where((tbl) => tbl.id.equals(id))).go();

  // --- palette_cache: cached dominant color per item ---

  Future<PaletteCacheEntry?> getPalette(String itemId) =>
      (select(paletteCache)..where((tbl) => tbl.itemId.equals(itemId))).getSingleOrNull();

  Future<void> savePalette(String itemId, int argb) => into(paletteCache).insertOnConflictUpdate(
        PaletteCacheCompanion.insert(itemId: itemId, argb: argb),
      );

  Future<void> deletePalette(String itemId) => (delete(paletteCache)..where((tbl) => tbl.itemId.equals(itemId))).go();

  // --- settings: key/value preferences scoped per screen output ---

  Future<Setting?> getSetting(String key, {String scope = 'global'}) =>
      (select(settings)..where((tbl) => tbl.key.equals(key) & tbl.scope.equals(scope))).getSingleOrNull();

  Selectable<Setting> getSettingsForScope(String scope) => select(settings)..where((tbl) => tbl.scope.equals(scope));

  Future<void> setSetting(String key, String value, {String scope = 'global'}) => into(settings).insertOnConflictUpdate(
        SettingsCompanion.insert(key: key, value: value, scope: scope),
      );

  Future<void> deleteSetting(String key, {String scope = 'global'}) =>
      (delete(settings)..where((tbl) => tbl.key.equals(key) & tbl.scope.equals(scope))).go();

  // --- recommendation_cache_entries: dernier calcul de recommandations
  // affiché en attendant qu'un nouveau aboutisse en arrière-plan, cf.
  // `recommendation_cache_table.dart` ---

  /// [userId] explicite, jamais [userId] (le getter ambiant ci-dessus) :
  /// cf. le commentaire sur `RecommendationCacheEntries.userId` — une
  /// fuite entre profils ici est le défaut précis que ce paramètre
  /// explicite empêche.
  Future<void> replaceRecommendationCache({
    required String userId,
    required RecommendationRowKind rowKind,
    required List<RecommendationCacheEntriesCompanion> entries,
  }) async {
    await batch((batch) {
      batch.deleteWhere(
          recommendationCacheEntries,
          (tbl) =>
              tbl.userId.equals(userId) & tbl.rowKind.equalsValue(rowKind));
      batch.insertAll(recommendationCacheEntries, entries);
    });
  }

  /// N'inclut jamais une entrée plus vieille que [maxAge] (cf.
  /// [defaultRecommendationCacheMaxAge]) : un cache de plusieurs mois
  /// affiché comme s'il était frais vaudrait moins que rien. [now]
  /// explicite (comme partout ailleurs dans le module recommandations)
  /// pour un calcul de fraîcheur reproductible en test — `DateTime.now()`
  /// par défaut en dehors des tests.
  Selectable<RecommendationCacheEntry> getRecommendationCache({
    required String userId,
    required RecommendationRowKind rowKind,
    Duration maxAge = defaultRecommendationCacheMaxAge,
    DateTime? now,
  }) {
    final cutoff = (now ?? DateTime.now()).subtract(maxAge);
    return (select(recommendationCacheEntries)
      ..where((tbl) =>
          tbl.userId.equals(userId) &
          tbl.rowKind.equalsValue(rowKind) &
          tbl.capturedAt.isBiggerOrEqualValue(cutoff))
      ..orderBy([(t) => OrderingTerm(expression: t.position)]));
  }

  static QueryExecutor _openConnection() {
    return driftDatabase(
      name: _databseName,
      native: const DriftNativeOptions(
        databaseDirectory: getApplicationSupportDirectory,
      ),
      web: DriftWebOptions(
        sqlite3Wasm: Uri.parse('sqlite3.wasm'),
        driftWorker: Uri.parse('drift_worker.dart.js'),
      ),
    );
  }
}
