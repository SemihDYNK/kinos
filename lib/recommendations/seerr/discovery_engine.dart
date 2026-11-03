import 'package:kinos/recommendations/engine/taste_profile_builder.dart';
import 'package:kinos/recommendations/engine/recommendation_scorer.dart';
import 'package:kinos/recommendations/models/library_trait_stats.dart';
import 'package:kinos/recommendations/models/watch_event.dart';
import 'discovery_models.dart';

List<DiscoveryKey> selectDiscoverySeeds(
    List<WatchEvent> events, Map<String, DiscoveryKey> identities, DateTime now,
    {int perTypeLimit = 15}) {
  final weights = <DiscoveryKey, double>{};
  for (final event in events) {
    final key = identities[event.itemId];
    if (key == null || event.baseWeight <= 0 || event.traits.isEmpty) {
      continue;
    }
    final weight = event.baseWeight * decayFactor(event.occurredAt, now);
    // Multiple Jellyfin editions never increase a work's contribution.
    if (weight > (weights[key] ?? 0)) weights[key] = weight;
  }
  final keys = weights.keys.toList()
    ..sort((a, b) {
      final comparison = weights[b]!.compareTo(weights[a]!);
      return comparison != 0 ? comparison : a.identity.compareTo(b.identity);
    });
  final counts = <String, int>{};
  return keys.where((key) {
    if ((counts[key.type] ?? 0) >= perTypeLimit) return false;
    counts.update(key.type, (count) => count + 1, ifAbsent: () => 1);
    return true;
  }).toList();
}

/// Round-robin across seed/endpoint lists, before any detail requests.
List<DiscoveryKey> balancedDiscoveryPool(
    List<List<DiscoveryKey>> lists, Set<String> excluded,
    {int limit = 60}) {
  final seen = {...excluded};
  final result = <DiscoveryKey>[];
  for (var index = 0; lists.any((list) => index < list.length); index++) {
    for (final list in lists) {
      if (index < list.length && seen.add(list[index].identity)) {
        result.add(list[index]);
        if (result.length >= limit) return result;
      }
    }
  }
  return result;
}

class DiscoveryExclusions {
  final Set<String> identities;
  final Set<String> tvdbIds;
  final Set<String> imdbIds;
  const DiscoveryExclusions(
      {required this.identities, required this.tvdbIds, required this.imdbIds});
  bool contains(DiscoveryItem item) =>
      identities.contains(item.key.identity) ||
      (item.key.type == 'tv' &&
          item.tvdbId != null &&
          tvdbIds.contains(item.tvdbId)) ||
      (item.imdbId != null && imdbIds.contains(item.imdbId));
}

/// CPU-only input, safe to send to Isolate.run (no Ref, client or DB).
class DiscoveryScoreInput {
  final List<WatchEvent> events;
  final LibraryTraitStats stats;
  final List<DiscoveryItem> items;
  final DateTime now;
  const DiscoveryScoreInput(this.events, this.stats, this.items, this.now);
}

List<DiscoveryItem> rankDiscovery(DiscoveryScoreInput input) {
  final profile = const TasteProfileBuilder()
      .build(input.events, libraryStats: input.stats, now: input.now);
  final scorer = RecommendationScorer(libraryStats: input.stats);
  final byId = {for (final item in input.items) item.key.identity: item};
  final eligible = input.items
      .map((i) => i.candidate)
      .where((c) => scorer.scoreCandidate(profile, c).score > 0)
      .toList();
  return scorer.score(profile, eligible).map((c) => byId[c.item.id]!).toList();
}
