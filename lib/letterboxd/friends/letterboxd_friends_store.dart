import 'dart:convert';

import 'package:kinos/models/syncing/database_item.dart';

import 'letterboxd_friends_parser.dart';
import 'letterboxd_reviews.dart';

/// Compte Letterboxd relié au profil (pseudo public, aucun secret) et état
/// de sa dernière synchronisation.
class LetterboxdFriendsAccount {
  const LetterboxdFriendsAccount(
      {required this.username,
      this.syncedAt,
      this.friendCount = 0,
      this.avatarUrl});
  final String username;
  final DateTime? syncedAt;
  final int friendCount;

  /// Ta photo de profil Letterboxd, lue une fois sur ta page publique.
  final String? avatarUrl;

  Map<String, Object?> toJson() => {
        'u': username,
        if (syncedAt != null) 't': syncedAt!.millisecondsSinceEpoch,
        'n': friendCount,
        if (avatarUrl != null) 'a': avatarUrl,
      };

  static LetterboxdFriendsAccount? fromJson(Object? json) {
    if (json is! Map || json['u'] is! String) return null;
    final t = json['t'], n = json['n'], a = json['a'];
    return LetterboxdFriendsAccount(
        username: json['u'] as String,
        syncedAt: t is int ? DateTime.fromMillisecondsSinceEpoch(t) : null,
        friendCount: n is int ? n : 0,
        avatarUrl: a is String ? a : null);
  }
}

/// Notes d'un ami, slug → note sur 10.
class FriendRatings {
  const FriendRatings(this.ratings, {this.fullAt});
  final Map<String, int> ratings;
  final DateTime? fullAt;
}

/// Une note d'ami sur un film.
typedef FriendRating = ({LetterboxdFriend friend, int rating});

/// Persistance dans la table `Settings`, une portée par profil Kinos.
class LetterboxdFriendsStore {
  LetterboxdFriendsStore(this.db, String profileScope)
      : scope = '$profileScope:friends:v1';
  final AppDatabase db;
  final String scope;

  static const _ratingsPrefix = 'ratings:';

  Future<Object?> _json(String key) async {
    final row = await db.getSetting(key, scope: scope);
    if (row == null) return null;
    try {
      return jsonDecode(row.value);
    } on FormatException {
      return null;
    }
  }

  Future<void> _put(String key, Object value) =>
      db.setSetting(key, jsonEncode(value), scope: scope);

  Future<LetterboxdFriendsAccount?> account() async =>
      LetterboxdFriendsAccount.fromJson(await _json('account'));

  Future<void> saveAccount(LetterboxdFriendsAccount account) =>
      _put('account', account.toJson());

  /// Entrées du journal déjà reprises (identifiants du flux RSS) : une
  /// entrée n'est appliquée qu'une fois, même si on la démarque ensuite
  /// dans Jellyfin.
  Future<({Set<String> seen, DateTime? syncedAt})> diary() async {
    final json = await _json('diary');
    if (json is! Map) return (seen: <String>{}, syncedAt: null);
    final t = json['t'];
    return (
      seen: {
        if (json['g'] is List)
          for (final g in json['g'] as List)
            if (g is String) g
      },
      syncedAt: t is int ? DateTime.fromMillisecondsSinceEpoch(t) : null,
    );
  }

  Future<void> saveDiary(Iterable<String> seen, DateTime syncedAt) =>
      _put('diary', {
        'g': seen.toList(),
        't': syncedAt.millisecondsSinceEpoch,
      });

  /// Délie le compte et efface tout ce qui en venait.
  Future<void> clear() => db.transaction(() async {
        for (final row in await db.getSettingsForScope(scope).get()) {
          await db.deleteSetting(row.key, scope: scope);
        }
      });

  Future<List<LetterboxdFriend>> friends() async {
    final json = await _json('friends');
    if (json is! List) return const [];
    return json.map(LetterboxdFriend.fromJson).nonNulls.toList();
  }

  Future<void> saveFriends(List<LetterboxdFriend> friends) =>
      _put('friends', [for (final f in friends) f.toJson()]);

  Future<FriendRatings?> ratings(String username) async {
    final json = await _json('$_ratingsPrefix$username');
    if (json is! Map || json['r'] is! Map) return null;
    final at = json['f'];
    return FriendRatings({
      for (final e in (json['r'] as Map).entries)
        if (e.key is String && e.value is int) e.key as String: e.value as int
    }, fullAt: at is int ? DateTime.fromMillisecondsSinceEpoch(at) : null);
  }

  Future<void> saveRatings(String username, FriendRatings ratings) =>
      _put('$_ratingsPrefix$username', {
        'r': ratings.ratings,
        if (ratings.fullAt != null) 'f': ratings.fullAt!.millisecondsSinceEpoch,
      });

  Future<void> removeRatings(String username) =>
      db.deleteSetting('$_ratingsPrefix$username', scope: scope);

  static const _reviewsPrefix = 'reviews:';

  Future<FriendReviews?> reviews(String username) async {
    final json = await _json('$_reviewsPrefix$username');
    if (json is! Map || json['r'] is! Map) return null;
    final at = json['f'];
    return FriendReviews({
      for (final e in (json['r'] as Map).entries)
        if (e.key is String)
          if (LetterboxdReview.fromJson(e.value) case final review?)
            e.key as String: review
    }, fullAt: at is int ? DateTime.fromMillisecondsSinceEpoch(at) : null);
  }

  Future<void> saveReviews(String username, FriendReviews reviews) =>
      _put('$_reviewsPrefix$username', {
        'r': {
          for (final e in reviews.reviews.entries) e.key: e.value.toJson()
        },
        if (reviews.fullAt != null) 'f': reviews.fullAt!.millisecondsSinceEpoch,
      });

  Future<void> removeReviews(String username) =>
      db.deleteSetting('$_reviewsPrefix$username', scope: scope);

  /// Index slug → critiques des amis (pseudo → critique).
  Future<Map<String, Map<String, LetterboxdReview>>> reviewsIndex() async {
    final index = <String, Map<String, LetterboxdReview>>{};
    for (final row in await db.getSettingsForScope(scope).get()) {
      if (!row.key.startsWith(_reviewsPrefix)) continue;
      final username = row.key.substring(_reviewsPrefix.length);
      try {
        final json = jsonDecode(row.value);
        final reviews = json is Map ? json['r'] : null;
        if (reviews is! Map) continue;
        for (final e in reviews.entries) {
          final review = LetterboxdReview.fromJson(e.value);
          if (e.key is String && review != null) {
            (index[e.key as String] ??= {})[username] = review;
          }
        }
      } on FormatException {
        continue;
      }
    }
    return index;
  }

  /// Texte complet d'une critique, gardé une fois lu.
  Future<String?> reviewText(String id) async {
    final json = await _json('reviewtext:$id');
    return json is String ? json : null;
  }

  Future<void> saveReviewText(String id, String text) =>
      _put('reviewtext:$id', text);

  /// Slug déjà résolu pour un film TMDB : `(slug: null)` si Letterboxd ne
  /// le connaît pas, null si jamais demandé ou trop ancien.
  Future<({String? slug})?> slug(String tmdbId,
      {required Duration maxAge}) async {
    final json = await _json('slug:$tmdbId');
    if (json is! Map || json['t'] is! int) return null;
    final at = DateTime.fromMillisecondsSinceEpoch(json['t'] as int);
    final slug = json['s'];
    // Un film introuvable peut apparaître plus tard ; un slug trouvé, non.
    if (slug == null && DateTime.now().difference(at) > maxAge) return null;
    return (slug: slug is String ? slug : null);
  }

  Future<void> saveSlug(String tmdbId, String? slug) => _put('slug:$tmdbId', {
        't': DateTime.now().millisecondsSinceEpoch,
        if (slug != null) 's': slug
      });

  /// Index slug → notes des amis suivis, pour un affichage instantané.
  Future<Map<String, List<FriendRating>>> index() async {
    final known = {for (final f in await friends()) f.username: f};
    final index = <String, List<FriendRating>>{};
    for (final row in await db.getSettingsForScope(scope).get()) {
      if (!row.key.startsWith(_ratingsPrefix)) continue;
      final friend = known[row.key.substring(_ratingsPrefix.length)];
      if (friend == null) continue;
      try {
        final json = jsonDecode(row.value);
        final ratings = json is Map ? json['r'] : null;
        if (ratings is! Map) continue;
        for (final e in ratings.entries) {
          if (e.key is String && e.value is int) {
            (index[e.key as String] ??= [])
                .add((friend: friend, rating: e.value as int));
          }
        }
      } on FormatException {
        continue;
      }
    }
    return index;
  }
}
