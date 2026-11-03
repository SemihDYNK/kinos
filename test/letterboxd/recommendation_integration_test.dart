import 'package:kinos/models/items/media_streams_model.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kinos/arr/models/arr_credentials.dart';
import 'package:kinos/arr/models/arr_service.dart';
import 'package:kinos/arr/providers/arr_providers.dart';
import 'package:kinos/arr/services/arr_credentials_store.dart';
import 'package:kinos/models/items/movie_model.dart';
import 'package:kinos/models/items/item_shared_models.dart';
import 'package:kinos/models/items/overview_model.dart';
import 'package:kinos/models/syncing/database_item.dart';
import 'package:kinos/providers/database_provider.dart';
import 'package:kinos/providers/user_provider.dart';
import 'package:kinos/letterboxd/letterboxd_model.dart';
import 'package:kinos/letterboxd/letterboxd_providers.dart';
import 'package:kinos/recommendations/providers/recommendation_providers.dart';
import '../recommendations/discovery_connection_test.dart' show Profile;

class NoArr extends ArrCredentialsStore {
  @override
  Future<ArrCredentials?> read(ArrService service) async => null;
}

MovieModel movie(String id, String title) => MovieModel(
    originalTitle: title,
    premiereDate: DateTime(2000),
    sortName: title,
    status: '',
    name: title,
    id: id,
    overview: const OverviewModel(genres: ['Drama'], yearAired: 2000),
    parentId: null,
    playlistId: null,
    images: null,
    childCount: null,
    primaryRatio: null,
    userData: const UserData(),
    parentImages: null,
    mediaStreams: MediaStreamsModel(versionStreams: []),
    canDownload: null,
    canDelete: null);
void main() {
  test('For You excludes Letterboxd watches even while Jellyfin says unwatched',
      () async {
    final watched = movie('seen', 'Film');
    final unseen = movie('new', 'New film');
    final container = ProviderContainer(overrides: [
      userProvider.overrideWith(Profile.new),
      letterboxdScopeProvider.overrideWithValue('account'),
      appDatabaseProvider
          .overrideWith((ref) => AppDatabase(ref, NativeDatabase.memory())),
      arrCredentialsStoreProvider.overrideWithValue(NoArr()),
      playedItemsProvider.overrideWith((ref) async => []),
      resumableItemsProvider.overrideWith((ref) async => []),
      unwatchedLibraryProvider.overrideWith((ref) async => [watched, unseen]),
      letterboxdSnapshotProvider.overrideWithValue(AsyncData(
          LetterboxdSnapshot(updatedAt: DateTime.now(), records: const [
        LetterboxdRecord(LetterboxdFilm(
            uri: 'https://boxd.it/a', title: 'Film', year: 2000, rating: 5))
      ]))),
    ]);
    final db = container.read(appDatabaseProvider);
    try {
      final result = await container.read(recommendationResultProvider.future);
      expect(result.candidates.map((c) => c.item.id), isNot(contains('seen')));
      expect(result.candidates.map((c) => c.item.id), contains('new'));
      // Background cache writes finish without delaying the result.
      await Future<void>.delayed(const Duration(milliseconds: 30));
    } finally {
      container.dispose();
      await db.close();
    }
  });
  test('cache freshness is isolated by account and invalidated after an import',
      () async {
    final snapshot =
        StateProvider<LetterboxdSnapshot>((ref) => const LetterboxdSnapshot());
    final scope = StateProvider<String>((ref) => 'account');
    final container = ProviderContainer(overrides: [
      userProvider.overrideWith(Profile.new),
      appDatabaseProvider
          .overrideWith((ref) => AppDatabase(ref, NativeDatabase.memory())),
      letterboxdScopeProvider.overrideWith((ref) => ref.watch(scope)),
      letterboxdSnapshotProvider
          .overrideWith((ref) => AsyncData(ref.watch(snapshot))),
    ]);
    final db = container.read(appDatabaseProvider);
    final sub =
        container.listen(recommendationRecomputeNeededProvider, (_, __) {});
    try {
      final now = DateTime.now();
      await db.replaceRecommendationCache(
          userId: 'user',
          rowKind: RecommendationRowKind.forYou,
          entries: [
            RecommendationCacheEntriesCompanion.insert(
                userId: 'user',
                rowKind: RecommendationRowKind.forYou,
                position: 0,
                source: RecommendationEntrySource.jellyfin,
                title: 'Old result'),
          ]);
      await db.setSetting(
          'recommendation_last_computed_at', now.toIso8601String(),
          scope: recommendationSettingsScope);
      expect(await container.read(recommendationRecomputeNeededProvider.future),
          isTrue);
      await db.setSetting(
          recommendationLastComputedSettingKey, now.toIso8601String(),
          scope: '$recommendationSettingsScope:account');
      container.invalidate(recommendationRecomputeNeededProvider);
      expect(await container.read(recommendationRecomputeNeededProvider.future),
          isFalse);
      container.read(snapshot.notifier).state =
          LetterboxdSnapshot(updatedAt: now.add(const Duration(seconds: 1)));
      expect(await container.read(recommendationRecomputeNeededProvider.future),
          isTrue);
      container.read(snapshot.notifier).state = const LetterboxdSnapshot();
      container.read(scope.notifier).state = 'other-account';
      expect(await container.read(recommendationRecomputeNeededProvider.future),
          isTrue);
    } finally {
      sub.close();
      container.dispose();
      await db.close();
    }
  });
}
