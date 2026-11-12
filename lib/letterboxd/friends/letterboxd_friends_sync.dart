import 'letterboxd_friends_client.dart';
import 'letterboxd_friends_parser.dart';
import 'letterboxd_friends_store.dart';

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
      {this.fullEvery = const Duration(days: 30), this.maxPages = 150});
  final LetterboxdFriendsClient client;
  final LetterboxdFriendsStore store;
  final Duration fullEvery;
  final int maxPages;

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
    await store.saveAccount(LetterboxdFriendsAccount(
        username: username,
        syncedAt: DateTime.now(),
        friendCount: friends.length));
  }

  Future<void> syncFriend(LetterboxdFriend friend,
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
