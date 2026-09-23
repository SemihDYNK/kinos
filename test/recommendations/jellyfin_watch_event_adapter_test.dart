import 'package:flutter_test/flutter_test.dart';

import 'package:kinos/models/item_base_model.dart';
import 'package:kinos/models/items/item_shared_models.dart';
import 'package:kinos/models/items/overview_model.dart';
import 'package:kinos/recommendations/adapters/jellyfin_watch_event_adapter.dart';
import 'package:kinos/recommendations/models/watch_classification.dart';
import 'package:kinos/recommendations/models/watch_signal.dart';

ItemBaseModel _item({required UserData userData, List<String> genres = const ['Drama']}) {
  return ItemBaseModel(
    name: 'Item',
    id: 'id1',
    overview: OverviewModel(genres: genres),
    parentId: null,
    playlistId: null,
    images: null,
    childCount: null,
    primaryRatio: null,
    userData: userData,
    canDownload: null,
    canDelete: null,
    jellyType: null,
  );
}

void main() {
  final now = DateTime(2025, 6, 1);

  group('classifyWatch — completed', () {
    test('played once, not a favourite -> completedNeutral', () {
      expect(
        classifyWatch(const UserData(played: true, playCount: 1), now: now),
        WatchClassification.completedNeutral,
      );
    });

    test('played once and favourited -> completedFavorite', () {
      expect(
        classifyWatch(
            const UserData(played: true, playCount: 1, isFavourite: true),
            now: now),
        WatchClassification.completedFavorite,
      );
    });

    test('played exactly twice -> not rewatched (a single resumed watch can '
        'bump playCount to 2 without being a true rewatch)', () {
      expect(
        classifyWatch(const UserData(played: true, playCount: 2), now: now),
        WatchClassification.completedNeutral,
      );
    });

    test('played 3+ times -> rewatched, regardless of favourite', () {
      expect(
        classifyWatch(const UserData(played: true, playCount: 3), now: now),
        WatchClassification.rewatched,
      );
      expect(
        classifyWatch(
            const UserData(played: true, playCount: 3, isFavourite: true),
            now: now),
        WatchClassification.rewatched,
      );
    });
  });

  group('classifyWatch — never started', () {
    test('no position at all -> neverStarted', () {
      expect(classifyWatch(const UserData(), now: now),
          WatchClassification.neverStarted);
    });
  });

  group('classifyWatch — resumable, staleness-gated', () {
    test('low progress, played very recently -> tooRecentToJudge, not abandoned',
        () {
      final threeDaysAgo = now.subtract(const Duration(days: 3));
      expect(
        classifyWatch(
          UserData(
              played: false,
              playbackPositionTicks: 1000,
              progress: 8,
              lastPlayed: threeDaysAgo),
          now: now,
        ),
        WatchClassification.tooRecentToJudge,
        reason: 'un film à 8% ouvert il y a trois jours est probablement '
            'encore en cours, pas abandonné',
      );
    });

    test('low progress, stale lastPlayed -> abandonedEarly', () {
      final sixMonthsAgo = now.subtract(const Duration(days: 180));
      expect(
        classifyWatch(
          UserData(
              played: false,
              playbackPositionTicks: 1000,
              progress: 8,
              lastPlayed: sixMonthsAgo),
          now: now,
        ),
        WatchClassification.abandonedEarly,
      );
    });

    test('high progress, stale lastPlayed -> abandonedLate', () {
      final sixMonthsAgo = now.subtract(const Duration(days: 180));
      expect(
        classifyWatch(
          UserData(
              played: false,
              playbackPositionTicks: 1000,
              progress: 95,
              lastPlayed: sixMonthsAgo),
          now: now,
        ),
        WatchClassification.abandonedLate,
      );
    });

    test('grey zone progress (20-80%), stale -> greyZone, not guessed', () {
      final sixMonthsAgo = now.subtract(const Duration(days: 180));
      expect(
        classifyWatch(
          UserData(
              played: false,
              playbackPositionTicks: 1000,
              progress: 50,
              lastPlayed: sixMonthsAgo),
          now: now,
        ),
        WatchClassification.greyZone,
      );
    });

    test('missing lastPlayed on a resumable item -> tooRecentToJudge, by caution',
        () {
      expect(
        classifyWatch(
          const UserData(
              played: false, playbackPositionTicks: 1000, progress: 8),
          now: now,
        ),
        WatchClassification.tooRecentToJudge,
      );
    });

    test('exactly at the staleness threshold counts as stale', () {
      final exactlyThreshold = now.subtract(defaultAbandonmentStaleness);
      expect(
        classifyWatch(
          UserData(
              played: false,
              playbackPositionTicks: 1000,
              progress: 8,
              lastPlayed: exactlyThreshold),
          now: now,
        ),
        WatchClassification.abandonedEarly,
      );
    });

    test('a custom abandonmentStaleness is honored', () {
      final tenDaysAgo = now.subtract(const Duration(days: 10));
      expect(
        classifyWatch(
          UserData(
              played: false,
              playbackPositionTicks: 1000,
              progress: 8,
              lastPlayed: tenDaysAgo),
          now: now,
          abandonmentStaleness: const Duration(days: 5),
        ),
        WatchClassification.abandonedEarly,
        reason: '10 jours dépasse un seuil personnalisé de 5 jours',
      );
      expect(
        classifyWatch(
          UserData(
              played: false,
              playbackPositionTicks: 1000,
              progress: 8,
              lastPlayed: tenDaysAgo),
          now: now,
          abandonmentStaleness: const Duration(days: 20),
        ),
        WatchClassification.tooRecentToJudge,
        reason: '10 jours reste sous un seuil personnalisé de 20 jours',
      );
    });
  });

  group('WatchClassification.signal', () {
    test('only the five signal-bearing classifications map to a WatchSignal',
        () {
      expect(WatchClassification.rewatched.signal, WatchSignal.rewatched);
      expect(WatchClassification.completedFavorite.signal,
          WatchSignal.completedFavorite);
      expect(WatchClassification.completedNeutral.signal,
          WatchSignal.completedNeutral);
      expect(WatchClassification.abandonedEarly.signal,
          WatchSignal.abandonedEarly);
      expect(
          WatchClassification.abandonedLate.signal, WatchSignal.abandonedLate);
      expect(WatchClassification.neverStarted.signal, isNull);
      expect(WatchClassification.tooRecentToJudge.signal, isNull);
      expect(WatchClassification.greyZone.signal, isNull);
    });
  });

  group('buildJellyfinWatchEvents', () {
    test('skips items with no usable signal', () {
      final events = buildJellyfinWatchEvents([
        _item(userData: const UserData()), // jamais lancé
      ], now: now);

      expect(events, isEmpty);
    });

    test('skips items with a signal but no extractable traits', () {
      final events = buildJellyfinWatchEvents([
        _item(userData: const UserData(played: true), genres: const []),
      ], now: now);

      expect(events, isEmpty);
    });

    test('skips a resumable item that is not stale enough yet', () {
      final threeDaysAgo = now.subtract(const Duration(days: 3));
      final events = buildJellyfinWatchEvents([
        _item(
          userData: UserData(
              played: false,
              playbackPositionTicks: 1000,
              progress: 5,
              lastPlayed: threeDaysAgo),
        ),
      ], now: now);

      expect(events, isEmpty);
    });

    test('carries the item id, traits and lastPlayed date through', () {
      final lastPlayed = DateTime(2024, 6, 1);
      final events = buildJellyfinWatchEvents([
        _item(
          userData: UserData(played: true, isFavourite: true, lastPlayed: lastPlayed),
        ),
      ], now: now);

      expect(events, hasLength(1));
      expect(events.single.itemId, 'id1');
      expect(events.single.signal, WatchSignal.completedFavorite);
      expect(events.single.occurredAt, lastPlayed);
      expect(events.single.traits, isNotEmpty);
    });

    test('a stale low-progress resumable item produces an abandonedEarly event',
        () {
      final sixMonthsAgo = now.subtract(const Duration(days: 180));
      final events = buildJellyfinWatchEvents([
        _item(
          userData: UserData(
              played: false,
              playbackPositionTicks: 1000,
              progress: 8,
              lastPlayed: sixMonthsAgo),
        ),
      ], now: now);

      expect(events, hasLength(1));
      expect(events.single.signal, WatchSignal.abandonedEarly);
    });
  });
}
