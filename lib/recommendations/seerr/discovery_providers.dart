import 'dart:convert';
import 'package:kinos/util/kinos_config.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kinos/arr/models/arr_library_entry.dart';
import 'package:kinos/arr/models/arr_library_item.dart';
import 'package:kinos/arr/models/arr_service.dart';
import 'package:kinos/arr/providers/arr_providers.dart'
    show arrCredentialsStoreProvider;
import 'package:kinos/arr/services/arr_api_client.dart';
import 'package:kinos/jellyfin/jellyfin_open_api.enums.swagger.dart';
import 'package:kinos/models/item_base_model.dart';
import 'package:kinos/providers/api_provider.dart';
import 'package:kinos/providers/database_provider.dart';
import 'package:kinos/providers/user_provider.dart';
import 'package:kinos/recommendations/adapters/jellyfin_watch_event_adapter.dart';
import 'package:kinos/recommendations/adapters/jellyfin_trait_extraction.dart';
import 'package:kinos/recommendations/models/library_trait_stats.dart';
import 'package:kinos/recommendations/models/watch_event.dart';
import 'package:kinos/recommendations/models/trait.dart';
import 'discovery_cache.dart';
import 'discovery_debug.dart';
import 'discovery_library.dart';
import 'discovery_client.dart';
import 'discovery_engine.dart';
import 'discovery_models.dart';
import 'discovery_repository.dart';

String discoveryServerUrl(String configured) =>
    (KinosConfig.seerrBaseUrl ?? configured).trim();

String discoveryAccountScope(String serverId, String userId, String url) =>
    jsonEncode([
      serverId,
      userId,
      Uri.parse(discoveryServerUrl(url))
          .replace(userInfo: '', query: '', fragment: '')
          .toString(),
    ]);

/// Observed only by this row; retained while its detail/request route is open.
final discoveryRequestedProvider =
    StateProvider.autoDispose.family<Set<String>, String>((ref, scope) => {});

final seerrDiscoveryProvider = FutureProvider.autoDispose
    .family<List<DiscoveryItem>, DiscoveryScope>((ref, scope) async {
  final debug = DiscoveryDebug()..step('démarrage');
  // Profile refreshes (name, avatar, lastUsed...) do not change this job's
  // connection. Only identity/credentials changes should cancel its snapshot.
  ref.watch(userProvider.select((account) => (
        account?.id,
        account?.credentials,
        account?.seerrCredentials,
      )));
  final account = ref.read(userProvider);
  final credentials = account?.seerrCredentials;
  if (account == null ||
      credentials == null ||
      !credentials.isConfigured ||
      account.id != scope.userId ||
      account.credentials.serverId != scope.serverId ||
      discoveryServerUrl(credentials.serverUrl) != scope.seerrUrl) {
    debug.step('arrêt : configuration absente ou profil différent');
    return const [];
  }

  final client = DiscoveryClient(baseUrl: Uri.parse(scope.seerrUrl), headers: {
    if (credentials.apiKey.trim().isNotEmpty)
      'X-Api-Key': credentials.apiKey.trim()
    else if (credentials.sessionCookie.trim().isNotEmpty)
      'Cookie': credentials.sessionCookie.trim(),
    ...credentials.customHeaders,
  });
  var disposed = false;
  var unobserved = false;
  ref.onCancel(() {
    unobserved = true;
    debug.note('plus aucun observateur');
  });
  ref.onResume(() {
    unobserved = false;
    debug.note('observateur revenu');
  });
  ref.onDispose(() {
    disposed = true;
    debug.note(
        'provider libéré motif=${unobserved ? 'sans observateur' : 'dépendance ou invalidation'}');
    client.close();
  });
  ref.listen(userProvider, (previous, next) {
    if (previous?.id != next?.id ||
        previous?.credentials != next?.credentials ||
        previous?.seerrCredentials != next?.seerrCredentials) {
      debug.note('identité ou connexion du profil modifiée');
    }
  });
  final db = ref.read(appDatabaseProvider);
  final api = ref.read(jellyApiProvider);
  final store = ref.read(arrCredentialsStoreProvider);
  final cache =
      DiscoveryCache(db, scope.cacheScope, Duration(days: scope.cacheDays));
  try {
    if (await cache.read('backoff') != null) {
      debug.step('pause après échec : cache de temporisation actif');
      return const [];
    }
    debug.step('bibliothèque Jellyfin');
    client.check();
    final snapshot = await loadDiscoveryLibrary(api,
        check: client.check, debug: debug, cache: cache);
    final library =
        snapshot.map((item) => ItemBaseModel.fromBaseDto(item, ref)).toList();
    debug.step('bibliothèque reçue', counts: {'titres': library.length});
    final identities = <String>{};
    final tvdbIds = <String>{};
    final imdbIds = <String>{};
    final seedIdentities = <String, DiscoveryKey>{};
    for (final item in library) {
      final type = item.type == KinosItemType.movie ? 'movie' : 'tv';
      final id = int.tryParse(item.overview.tmdbId ?? '');
      if (id != null && id > 0) {
        final key = (type: type, id: id);
        identities.add(key.identity);
        seedIdentities[item.id] = key;
      }
      if (type == 'tv' && item.overview.tvdbId != null) {
        tvdbIds.add(item.overview.tvdbId!);
      }
      if (item.overview.imdbId != null) imdbIds.add(item.overview.imdbId!);
    }
    for (final service in ArrService.values) {
      debug.step('exclusions ${service.name}');
      final creds = await store.read(service);
      client.check();
      if (creds == null || !creds.isConfigured) {
        debug.step('${service.name} non configuré');
        continue;
      }
      final ArrApiClient arr = service == ArrService.radarr
          ? RadarrApiClient(baseUrl: creds.baseUrl, apiKey: creds.apiKey)
          : SonarrApiClient(baseUrl: creds.baseUrl, apiKey: creds.apiKey);
      ref.onDispose(arr.close);
      try {
        final entries = <ArrLibraryEntry>[];
        if (arr is RadarrApiClient) {
          final response = await arr.searchMovies('');
          if (response is! ArrSuccess<List<ArrMovie>>) {
            throw const DiscoveryUnavailable();
          }
          entries.addAll(response.data.map(ArrLibraryEntry.movie));
        } else if (arr is SonarrApiClient) {
          final response = await arr.searchSeries('');
          if (response is! ArrSuccess<List<ArrSeries>>) {
            throw const DiscoveryUnavailable();
          }
          entries.addAll(response.data.map(ArrLibraryEntry.series));
        }
        client.check();
        debug.step('${service.name} reçu', counts: {'titres': entries.length});
        for (final entry in entries) {
          if (entry.tmdbId != null) {
            identities
                .add('tmdb:${entry.isMovie ? 'movie' : 'tv'}:${entry.tmdbId}');
          }
          if (!entry.isMovie && entry.tvdbId != null) {
            tvdbIds.add(entry.tvdbId!);
          }
          if (entry.imdbId != null) imdbIds.add(entry.imdbId!);
        }
      } finally {
        arr.close();
      }
    }
    final now = DateTime.now();
    debug.step('historique Jellyfin');
    final resumeResponse = await api.usersUserIdItemsResumeGet(
      mediaTypes: [MediaType.video],
      fields: [
        ItemFields.genres,
        ItemFields.people,
        ItemFields.studios,
        ItemFields.tags,
        ItemFields.providerids
      ],
      enableTotalRecordCount: false,
      enableUserData: true,
      limit: 200,
    ).timeout(const Duration(seconds: 30));
    client.check();
    if (!resumeResponse.isSuccessful || resumeResponse.body?.items == null) {
      throw const DiscoveryUnavailable();
    }
    final resumable = resumeResponse.body!.items!
        .map((item) => ItemBaseModel.fromBaseDto(item, ref))
        .toList();
    final events = buildJellyfinWatchEvents([
      ...library.where((item) => item.userData.played),
      ...resumable,
    ], now: now)
        .map((event) => WatchEvent(
              itemId: event.itemId,
              signal: event.signal,
              occurredAt: event.occurredAt,
              traits: event.traits.map(discoveryTrait).toSet().toList(),
            ))
        .toList();
    final frequencies = <TraitKey, int>{};
    for (final item in library) {
      for (final trait
          in traitsFromOverview(item.overview).map(discoveryTrait).toSet()) {
        frequencies.update(trait, (count) => count + 1, ifAbsent: () => 1);
      }
    }
    final stats = LibraryTraitStats(
        librarySize: library.length, traitDocFrequency: frequencies);
    final seeds = selectDiscoverySeeds(events, seedIdentities, now);
    debug.step('profil calculé', counts: {
      'événements': events.length,
      'graines': seeds.length,
      'grainesFilms': seeds.where((s) => s.type == 'movie').length,
      'grainesSéries': seeds.where((s) => s.type == 'tv').length,
      'exclusionsTMDB': identities.length,
    });
    final result = await DiscoveryRepository(client, cache, scope.language)
        .load(
            seeds: seeds,
            events: events,
            stats: stats,
            debug: debug,
            exclusions: DiscoveryExclusions(
                identities: identities, tvdbIds: tvdbIds, imdbIds: imdbIds));
    client.check();
    debug.step('terminé', counts: {
      'titres': result.length,
      'films': result.where((i) => i.key.type == 'movie').length,
      'séries': result.where((i) => i.key.type == 'tv').length,
    });
    return result;
  } catch (error) {
    debug.failure(error, cancelled: disposed);
    if (!client.isClosed) {
      try {
        if (await cache.read('backoff') == null) {
          await cache.write('backoff', const {'failed': true},
              ttl: const Duration(minutes: 5));
        }
      } catch (_) {/* Cache failure must remain silent too. */}
    }
    // This row has no error surface. In particular never reuse previous data
    // when the latest eligibility check failed.
    return const [];
  } finally {
    client.close();
  }
});
