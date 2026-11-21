import 'package:logging/logging.dart';

import 'letterboxd_friends_client.dart';
import 'letterboxd_friends_parser.dart';
import 'letterboxd_friends_store.dart';
import 'letterboxd_reviews.dart';

final _log = Logger('LetterboxdFriends');

/// Profil Letterboxd introuvable (pseudo erroné ou compte supprimé).
class LetterboxdProfileNotFound implements Exception {
  const LetterboxdProfileNotFound();
}

/// Rapatrie les notes des comptes suivis.
///
/// Premier passage complet ; ensuite, pour chaque ami, les pages de notes
/// (des plus récentes aux plus anciennes) jusqu'à la première qui
/// n'apporte rien de neuf. Un passage complet tous les [fullEvery] tient
/// compte des notes retirées.
class LetterboxdFriendsSync {
  LetterboxdFriendsSync(this.client, this.store,
      {this.fullEvery = const Duration(days: 30),
      this.maxPages = 150,
      this.reviewPagesPerPass = 10});
  final LetterboxdFriendsClient client;
  final LetterboxdFriendsStore store;
  final Duration fullEvery;
  final int maxPages;

  /// Pages de critiques lues par passage complet (~12 par page) : les plus
  /// récentes suffisent, les suivantes arrivent au fil des passes.
  final int reviewPagesPerPass;

  /// [onFriend] est appelé après chaque ami enregistré (fait, total).
  Future<void> run(String username,
      {required bool Function() cancelled,
      void Function(int done, int total)? onFriend}) async {
    final friends = await client.following(username, cancelled: cancelled);
    if (friends == null) throw const LetterboxdProfileNotFound();
    if (cancelled()) return;
    final previous = await store.friends();
    await store.saveFriends(friends);
    final kept = {for (final f in friends) f.username};
    for (final gone in previous.where((f) => !kept.contains(f.username))) {
      await store.removeRatings(gone.username);
      await store.removeReviews(gone.username);
    }
    // Ses propres notes d'abord : affichées sur les fiches, à côté de
    // celles des amis.
    await syncFriend(LetterboxdFriend(username: username, name: username),
        cancelled: cancelled);
    onFriend?.call(0, friends.length);
    for (final (i, friend) in friends.indexed) {
      if (cancelled()) return;
      await syncFriend(friend, cancelled: cancelled);
      onFriend?.call(i + 1, friends.length);
    }
    if (cancelled()) return;
    final known = await store.account();
    await store.saveAccount(LetterboxdFriendsAccount(
        username: username,
        syncedAt: DateTime.now(),
        friendCount: friends.length,
        avatarUrl: known?.username == username ? known?.avatarUrl : null));
  }

  Future<void> syncFriend(LetterboxdFriend friend,
      {required bool Function() cancelled}) async {
    await _syncRatings(friend, cancelled: cancelled);
    if (cancelled()) return;
    // Les critiques sont un plus : leur échec n'arrête pas les notes des
    // autres amis, il est consigné et retenté à la prochaine passe.
    try {
      await syncReviews(friend, cancelled: cancelled);
    } on LetterboxdPaused {
      // Letterboxd demande une pause : on arrête tout, pas seulement lui.
      rethrow;
    } catch (error) {
      _log.warning('Critiques de ${friend.username} illisibles : $error');
    }
  }

  /// Critiques écrites : même principe que les notes — complet la première
  /// fois (et tous les [fullEvery]), puis jusqu'à la première page sans
  /// nouveauté.
  Future<void> syncReviews(LetterboxdFriend friend,
      {required bool Function() cancelled}) async {
    final cached = await store.reviews(friend.username);
    final fullAt = cached?.fullAt;
    final full = cached == null ||
        fullAt == null ||
        DateTime.now().difference(fullAt) > fullEvery;
    final known = {
      for (final r in cached?.reviews.values ?? const <LetterboxdReview>[]) r.id
    };
    final fetched = <String, LetterboxdReview>{};
    var complete = false;
    final pages = full ? reviewPagesPerPass : maxPages;
    for (var page = 1; page <= pages; page++) {
      if (cancelled()) return;
      final result = await client.reviews(friend.username, page);
      for (final review in result.items) {
        // La plus récente d'abord : une critique plus ancienne du même
        // film ne la remplace pas.
        fetched.putIfAbsent(review.slug, () => review);
      }
      final nothingNew =
          !full && result.items.every((r) => known.contains(r.id));
      // Un passage complet s'arrête au plafond : les critiques plus
      // anciennes sont laissées, le passage compte comme terminé.
      if (!result.hasNext || nothingNew || (full && page == pages)) {
        complete = true;
        break;
      }
    }
    if (full && complete) {
      await store.saveReviews(
          friend.username, FriendReviews(fetched, fullAt: DateTime.now()));
    } else {
      await store.saveReviews(
          friend.username,
          FriendReviews({...?cached?.reviews, ...fetched},
              fullAt: complete && full ? DateTime.now() : fullAt));
    }
  }

  Future<void> _syncRatings(LetterboxdFriend friend,
      {required bool Function() cancelled}) async {
    final cached = await store.ratings(friend.username);
    final fullAt = cached?.fullAt;
    final full = cached == null ||
        fullAt == null ||
        DateTime.now().difference(fullAt) > fullEvery;
    final fetched = <String, int>{};
    var complete = false;
    for (var page = 1; page <= maxPages; page++) {
      if (cancelled()) return;
      final result = await client.ratings(friend.username, page);
      fetched.addAll(result.items);
      final nothingNew = !full &&
          result.items.entries.every((e) => cached.ratings[e.key] == e.value);
      if (!result.hasNext || nothingNew) {
        complete = true;
        break;
      }
    }
    // Un passage complet interrompu ne doit pas effacer les notes connues.
    if (full && complete) {
      await store.saveRatings(
          friend.username, FriendRatings(fetched, fullAt: DateTime.now()));
    } else {
      await store.saveRatings(
          friend.username,
          FriendRatings({...?cached?.ratings, ...fetched},
              fullAt: complete && full ? DateTime.now() : fullAt));
    }
  }
}
