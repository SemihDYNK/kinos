import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:kinos/letterboxd/letterboxd_model.dart';
import 'package:kinos/letterboxd/letterboxd_providers.dart'
    show letterboxdScopeProvider;
import 'package:kinos/models/syncing/database_item.dart';
import 'package:kinos/providers/database_provider.dart';
import 'package:kinos/recommendations/models/watch_event.dart';

/// D'où vient une note.
enum RatingSource {
  /// Donnée dans Kinos : elle l'emporte toujours.
  kinos,

  /// Reprise de Letterboxd (import, journal) tant qu'on ne l'a pas changée.
  letterboxd,
}

/// Une note personnelle, sur 10 (cinq étoiles par demi-étoile).
class KinosRating {
  const KinosRating(this.value, {required this.at, required this.source});
  final int value;
  final DateTime at;
  final RatingSource source;

  /// 4,5 étoiles pour 9.
  double get stars => value / 2;

  Map<String, Object?> toJson() =>
      {'r': value, 't': at.millisecondsSinceEpoch, 's': source.name};

  static KinosRating? fromJson(Object? json) {
    if (json is! Map) return null;
    final r = json['r'], t = json['t'];
    if (r is! int || r < 1 || r > 10 || t is! int) return null;
    return KinosRating(r,
        at: DateTime.fromMillisecondsSinceEpoch(t),
        source:
            RatingSource.values.asNameMap()[json['s']] ?? RatingSource.kinos);
  }
}

/// Identité d'une œuvre notée : `tmdb:movie:<id>`, `tmdb:tv:<id>`, sinon
/// `jellyfin:<id>`.
String ratingIdentity(
        {required bool movie, String? tmdbId, required String jellyfinId}) =>
    tmdbId != null && tmdbId.isNotEmpty
        ? 'tmdb:${movie ? 'movie' : 'tv'}:$tmdbId'
        : 'jellyfin:$jellyfinId';

/// Les notes Letterboxd d'un import, à reprendre : identité → (note sur 10,
/// date).
Map<String, (int, DateTime)> letterboxdRatings(LetterboxdSnapshot snapshot) {
  final ratings = <String, (int, DateTime)>{};
  for (final record in snapshot.records) {
    final rating = record.film.rating;
    final work = record.work;
    if (rating == null || work == null) continue;
    final identity = work.tmdbIdentity != null
        ? work.tmdbIdentity!
        : work.jellyfinId != null
            ? 'jellyfin:${work.jellyfinId}'
            : null;
    if (identity == null) continue;
    final at = record.film.ratedAt ?? record.film.watchedAt ?? DateTime(2000);
    final known = ratings[identity];
    if (known == null || at.isAfter(known.$2)) {
      ratings[identity] = ((rating * 2).round().clamp(1, 10), at);
    }
  }
  return ratings;
}

/// Poids d'une note dans le profil de goût, comme une note Letterboxd :
/// 3 étoiles est neutre, 5 étoiles très positif, une demi-étoile très
/// négatif.
double ratingWeight(int value) => (value / 2 - 3) * .75;

/// Les notes Kinos remplacent le poids des visionnages correspondants dans
/// les recommandations. [identityOf] relie un identifiant d'événement
/// (Jellyfin) à l'identité de la note.
List<WatchEvent> applyKinosRatings(
    List<WatchEvent> events,
    Map<String, KinosRating> ratings,
    String? Function(String itemId) identityOf) {
  if (ratings.isEmpty) return events;
  return [
    for (final event in events)
      if ((ratings[event.itemId] ??
              switch (identityOf(event.itemId)) {
                final id? => ratings[id],
                null => null,
              })
          case final rating?)
        WatchEvent(
            itemId: event.itemId,
            traits: event.traits,
            signal: event.signal,
            explicitWeight: ratingWeight(rating.value),
            occurredAt: event.occurredAt)
      else
        event
  ];
}

class KinosRatingStore {
  KinosRatingStore(this.db, String profileScope)
      : scope = '$profileScope:ratings:v1';
  final AppDatabase db;
  final String scope;

  Future<Map<String, KinosRating>> all() async => {
        for (final row in await db.getSettingsForScope(scope).get())
          if (KinosRating.fromJson(_decode(row.value)) case final rating?)
            row.key: rating
      };

  Future<void> set(String identity, KinosRating? rating) => rating == null
      ? db.deleteSetting(identity, scope: scope)
      : db.setSetting(identity, jsonEncode(rating.toJson()), scope: scope);

  static Object? _decode(String value) {
    try {
      return jsonDecode(value);
    } on FormatException {
      return null;
    }
  }
}

final kinosRatingStoreProvider = Provider.autoDispose<KinosRatingStore?>((ref) {
  final scope = ref.watch(letterboxdScopeProvider);
  return scope == null
      ? null
      : KinosRatingStore(ref.watch(appDatabaseProvider),
          scope.replaceFirst('letterboxd:', 'kinos:'));
});

/// Les notes du profil actif, identité → note.
final kinosRatingsProvider = StateNotifierProvider.autoDispose<
    KinosRatingsController, Map<String, KinosRating>>((ref) {
  ref.keepAlive();
  return KinosRatingsController(ref.watch(kinosRatingStoreProvider));
});

class KinosRatingsController extends StateNotifier<Map<String, KinosRating>> {
  KinosRatingsController(this.store) : super(const {}) {
    store?.all().then((ratings) {
      if (mounted) state = {...ratings, ...state};
    });
  }

  final KinosRatingStore? store;

  /// Note [identity] (de 1 à 10), ou retire sa note avec null.
  Future<void> set(String identity, int? value) async {
    final rating = value == null
        ? null
        : KinosRating(value.clamp(1, 10),
            at: DateTime.now(), source: RatingSource.kinos);
    state = {
      for (final e in state.entries)
        if (e.key != identity) e.key: e.value,
      if (rating != null) identity: rating,
    };
    await store?.set(identity, rating);
  }

  /// Reprend les notes Letterboxd, sans jamais écraser une note donnée
  /// dans Kinos.
  Future<void> seed(Map<String, (int, DateTime)> ratings) async {
    final store = this.store;
    if (store == null) return;
    final known = await store.all();
    final next = {...known};
    for (final MapEntry(key: identity, value: (value, at)) in ratings.entries) {
      final current = known[identity];
      if (current?.source == RatingSource.kinos) continue;
      if (current?.value == value) continue;
      final rating =
          KinosRating(value, at: at, source: RatingSource.letterboxd);
      next[identity] = rating;
      await store.set(identity, rating);
    }
    if (mounted) state = next;
  }
}
