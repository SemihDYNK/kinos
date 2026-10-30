import 'dart:isolate';
import 'package:kinos/recommendations/models/library_trait_stats.dart';
import 'package:kinos/recommendations/models/watch_event.dart';
import 'discovery_cache.dart';
import 'discovery_debug.dart';
import 'discovery_client.dart';
import 'discovery_engine.dart';
import 'discovery_models.dart';

/// The server may have changed since metadata was cached. Only detail responses
/// fetched during this run can establish eligibility, never persisted statuses.
class DiscoveryRepository {
  final DiscoveryClient client;
  final DiscoveryCache cache;
  final String language;
  final int candidateLimit;
  final int perTypeLimit;
  DiscoveryRepository(this.client, this.cache, this.language,
      {this.candidateLimit = 60, this.perTypeLimit = 15});

  Future<List<DiscoveryItem>> load(
      {required List<DiscoveryKey> seeds,
      required List<WatchEvent> events,
      required LibraryTraitStats stats,
      DiscoveryDebug? debug,
      required DiscoveryExclusions exclusions}) async {
    if (seeds.isEmpty) {
      debug?.step('aucune graine éligible');
      return const [];
    }
    final backoff = await cache.read('backoff');
    if (backoff != null) return const [];
    try {
      await cache.prune();
      final jobs = [
        for (final seed in seeds)
          for (final endpoint in ['similar', 'recommendations'])
            (seed: seed, endpoint: endpoint)
      ];
      var cachedLists = 0;
      debug?.step('similaires et recommandations',
          counts: {'listes': jobs.length});
      final lists = await client.map(jobs, (job) async {
        final key = 'list:v1:${job.seed.identity}:${job.endpoint}';
        final cached = await cache.read(key);
        if (cached != null) {
          cachedLists++;
          return objects(cached['items'])
              .map((e) => (type: job.seed.type, id: e['id'] as int))
              .toList();
        }
        final json = await client.get(
            '${job.seed.type}/${job.seed.id}/${job.endpoint}',
            language: language,
            query: const {'page': '1'});
        if (json['results'] is! List) {
          throw const FormatException('Missing results');
        }
        final items = <DiscoveryKey>[];
        for (final result in objects(json['results'])) {
          if (result['id'] is! int || (result['id'] as int) <= 0) continue;
          if (knownToSeerr(result)) continue;
          items.add((type: job.seed.type, id: result['id'] as int));
        }
        client.check();
        await cache.write(key, {
          'items': [
            for (final item in items) {'id': item.id}
          ]
        });
        return items;
      });
      final pool = balancedDiscoveryPool(
          lists, {...exclusions.identities, ...seeds.map((s) => s.identity)},
          limit: candidateLimit);
      debug?.step('enrichissement', counts: {
        'listesEnCache': cachedLists,
        'candidats': pool.length,
      });
      var cachedDetails = 0;
      final checked = <String>{};
      final details = await client.map(pool, (key) async {
        final cacheKey = 'detail:v1:${key.identity}';
        final cached = await cache.read(cacheKey);
        if (cached != null) {
          try {
            final item = DiscoveryItem.fromJson(cached);
            cachedDetails++;
            return item;
          } on FormatException {
            /* Re-fetch invalid/versioned entries. */
          } on TypeError {/* Same for corrupted data. */} on ArgumentError {
            /* Unknown trait kind. */
          }
        }
        final json =
            await client.get('${key.type}/${key.id}', language: language);
        if (knownToSeerr(json)) return null;
        final item = DiscoveryItem.fromDetails(key, json);
        checked.add(key.identity);
        client.check();
        await cache.write(cacheKey, item.toJson());
        return item;
      });
      final eligible = details
          .whereType<DiscoveryItem>()
          .where((item) => !exclusions.contains(item))
          .toList();
      final input =
          DiscoveryScoreInput(events, stats, eligible, DateTime.now());
      debug?.step('scoring', counts: {
        'éligibles': eligible.length,
        'fichesEnCache': cachedDetails,
      });
      final ranked = await _scoreInBackground(input);
      debug?.step('vérification des statuts Seerr',
          counts: {'classés': ranked.length});
      client.check();
      final output = <DiscoveryItem>[];
      final counts = <String, int>{};
      // At most one validation per enriched candidate; fill holes after exclusions.
      for (final item in ranked) {
        if ((counts[item.key.type] ?? 0) >= perTypeLimit) continue;
        if (!checked.contains(item.key.identity)) {
          final json = await client.get('${item.key.type}/${item.key.id}',
              language: language);
          if (knownToSeerr(json)) continue;
          final current = DiscoveryItem.fromDetails(item.key, json);
          if (exclusions.contains(current)) continue;
        }
        output.add(item);
        counts.update(item.key.type, (count) => count + 1, ifAbsent: () => 1);
        if (output.length >= perTypeLimit * 2) break;
      }
      return output;
    } catch (error) {
      final now = DateTime.now();
      final retryAt = error is DiscoveryUnavailable ? error.retryAt : null;
      final delay = retryAt != null &&
              retryAt.isAfter(now.add(const Duration(minutes: 5)))
          ? retryAt.difference(now)
          : const Duration(minutes: 5);
      // Do not cache cancellation caused by navigation/profile changes.
      // A network failure may have closed the worker pool: retain its backoff.
      if (client.failed || !client.isClosed) {
        try {
          await cache.write('backoff', const {'failed': true}, ttl: delay);
        } catch (_) {/* Best effort. */}
      }
      rethrow;
    }
  }
}

// A top-level capture boundary prevents the closure from also capturing the
// repository's client/Futures, which are not sendable between isolates.
Future<List<DiscoveryItem>> _scoreInBackground(DiscoveryScoreInput input) =>
    Isolate.run(() => rankDiscovery(input));
