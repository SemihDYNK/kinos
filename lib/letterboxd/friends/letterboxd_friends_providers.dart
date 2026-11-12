import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:kinos/letterboxd/letterboxd_providers.dart';
import 'package:kinos/providers/dashboard/hero_items_provider.dart';
import 'package:kinos/providers/database_provider.dart';

import 'letterboxd_friends_client.dart';
import 'letterboxd_friends_parser.dart';
import 'letterboxd_friends_store.dart';
import 'letterboxd_friends_sync.dart';

/// Délai minimal entre deux synchronisations automatiques.
const letterboxdFriendsRefresh = Duration(hours: 12);

/// Durée avant de redemander un film que Letterboxd ne connaissait pas.
const _unknownFilmRetry = Duration(days: 7);

/// Client partagé : une seule file de requêtes pour toute l'app.
final letterboxdFriendsClientProvider =
    Provider<LetterboxdFriendsClient>((ref) {
  final client = LetterboxdFriendsClient();
  ref.onDispose(client.close);
  return client;
});

final letterboxdFriendsStoreProvider =
    Provider.autoDispose<LetterboxdFriendsStore?>((ref) {
  final scope = ref.watch(letterboxdScopeProvider);
  return scope == null
      ? null
      : LetterboxdFriendsStore(ref.watch(appDatabaseProvider), scope);
});

final letterboxdFriendsAccountProvider =
    FutureProvider.autoDispose<LetterboxdFriendsAccount?>(
        (ref) async => ref.watch(letterboxdFriendsStoreProvider)?.account());

/// Index slug → notes des amis, relu après chaque synchronisation.
final letterboxdFriendsIndexProvider =
    FutureProvider.autoDispose<Map<String, List<FriendRating>>>((ref) async {
  final store = ref.watch(letterboxdFriendsStoreProvider);
  if (store == null) return const {};
  final index = await store.index();
  ref.keepAlive();
  return index;
});

/// Ses propres notes (slug → note sur 10), lues sur son profil public.
final letterboxdMyRatingsProvider =
    FutureProvider.autoDispose<Map<String, int>>((ref) async {
  final store = ref.watch(letterboxdFriendsStoreProvider);
  final account = await ref.watch(letterboxdFriendsAccountProvider.future);
  if (store == null || account == null) return const {};
  final ratings = (await store.ratings(account.username))?.ratings ?? const {};
  ref.keepAlive();
  return ratings;
});

/// Notes sur un film, par identifiant TMDB : slug Letterboxd, notes des
/// amis de la meilleure à la moins bonne, et sa propre note (profil
/// Letterboxd, sinon import). Null sans compte relié ou si Letterboxd ne
/// connaît pas le film.
final letterboxdFriendsFilmProvider = FutureProvider.autoDispose
    .family<({String slug, List<FriendRating> ratings, int? mine})?, String>(
        (ref, tmdbId) async {
  // Import Letterboxd lu avant toute attente (note sur 5, demi-points).
  final imported = ref
      .watch(letterboxdSnapshotProvider)
      .valueOrNull
      ?.records
      .where((r) => '${r.work?.tmdbId}' == tmdbId)
      .map((r) => r.film.rating)
      .nonNulls
      .firstOrNull;
  final store = ref.watch(letterboxdFriendsStoreProvider);
  final account = await ref.watch(letterboxdFriendsAccountProvider.future);
  if (store == null || account == null) return null;
  var cached = await store.slug(tmdbId, maxAge: _unknownFilmRetry);
  if (cached == null) {
    final slug =
        await ref.read(letterboxdFriendsClientProvider).filmSlug(tmdbId);
    await store.saveSlug(tmdbId, slug);
    cached = (slug: slug);
  }
  final slug = cached.slug;
  if (slug == null) return null;
  final index = await ref.watch(letterboxdFriendsIndexProvider.future);
  final ratings = [...?index[slug]]
    ..sort((a, b) => b.rating.compareTo(a.rating));
  final mine = (await ref.watch(letterboxdMyRatingsProvider.future))[slug] ??
      (imported == null ? null : (imported * 2).round());
  return (slug: slug, ratings: ratings, mine: mine);
});

/// État de la synchronisation en cours, s'il y en a une.
class LetterboxdFriendsSyncState {
  const LetterboxdFriendsSyncState(
      {this.running = false, this.done = 0, this.total = 0, this.error});
  final bool running;
  final int done;
  final int total;

  /// « profile » (pseudo introuvable) ou « network ».
  final String? error;
}

// autoDispose pour pouvoir suivre le profil actif, mais gardé en vie : une
// synchronisation continue quand on quitte l'écran qui l'a lancée.
final letterboxdFriendsSyncProvider = StateNotifierProvider.autoDispose<
    LetterboxdFriendsSyncController, LetterboxdFriendsSyncState>((ref) {
  ref.keepAlive();
  return LetterboxdFriendsSyncController(ref);
});

class LetterboxdFriendsSyncController
    extends StateNotifier<LetterboxdFriendsSyncState> {
  LetterboxdFriendsSyncController(this.ref)
      : super(const LetterboxdFriendsSyncState()) {
    // Un changement de profil interrompt la synchronisation de l'ancien.
    ref.listen(letterboxdScopeProvider, (previous, next) {
      if (previous != next) _generation++;
      if (mounted) state = const LetterboxdFriendsSyncState();
    });
  }

  final Ref ref;
  int _generation = 0;

  /// Relie [rawUsername] au profil et lance une première synchronisation.
  /// Faux si le pseudo n'est pas valide.
  Future<bool> link(String rawUsername) async {
    final username = normalizeLetterboxdUsername(rawUsername);
    final store = ref.read(letterboxdFriendsStoreProvider);
    if (username == null || store == null) return false;
    final current = await store.account();
    if (current?.username != username) {
      await store.clear();
      await store.saveAccount(LetterboxdFriendsAccount(username: username));
      ref.invalidate(letterboxdFriendsAccountProvider);
      ref.invalidate(letterboxdFriendsIndexProvider);
      ref.invalidate(letterboxdMyRatingsProvider);
    }
    await sync(force: true);
    return true;
  }

  Future<void> unlink() async {
    _generation++;
    await ref.read(letterboxdFriendsStoreProvider)?.clear();
    if (mounted) state = const LetterboxdFriendsSyncState();
    ref.invalidate(letterboxdFriendsAccountProvider);
    ref.invalidate(letterboxdFriendsIndexProvider);
    ref.invalidate(letterboxdMyRatingsProvider);
  }

  /// Synchronise si un compte est relié et que la dernière synchronisation
  /// date de plus de [letterboxdFriendsRefresh] (ou toujours, si [force]).
  Future<void> sync({bool force = false}) async {
    if (state.running) return;
    final store = ref.read(letterboxdFriendsStoreProvider);
    final account = await store?.account();
    if (store == null || account == null) return;
    final last = account.syncedAt;
    if (!force &&
        last != null &&
        DateTime.now().difference(last) < letterboxdFriendsRefresh) {
      return;
    }
    final generation = ++_generation;
    bool cancelled() => !mounted || generation != _generation;
    state = const LetterboxdFriendsSyncState(running: true);
    final sync =
        LetterboxdFriendsSync(ref.read(letterboxdFriendsClientProvider), store);
    try {
      await sync.run(account.username, cancelled: cancelled,
          onFriend: (done, total) {
        if (cancelled()) return;
        state =
            LetterboxdFriendsSyncState(running: true, done: done, total: total);
        // Les notes apparaissent au fil de l'eau, par lots.
        if (done % 5 == 0 || done == total) {
          ref.invalidate(letterboxdFriendsIndexProvider);
          ref.invalidate(letterboxdMyRatingsProvider);
        }
      });
      if (cancelled()) return;
      state = const LetterboxdFriendsSyncState();
    } on LetterboxdProfileNotFound {
      if (!cancelled()) {
        state = const LetterboxdFriendsSyncState(error: 'profile');
      }
    } catch (_) {
      if (!cancelled()) {
        state = const LetterboxdFriendsSyncState(error: 'network');
      }
    } finally {
      if (!cancelled()) {
        ref.invalidate(letterboxdFriendsAccountProvider);
        ref.invalidate(letterboxdFriendsIndexProvider);
        ref.invalidate(letterboxdMyRatingsProvider);
      }
    }
  }
}

/// Précharge les notes des amis pour les films du carrousel de l'accueil :
/// leur fiche s'ouvre avec le bloc Letterboxd déjà prêt. Les films restent
/// en mémoire tant que l'accueil est monté (il l'est sous une fiche).
final letterboxdHeroPreloadProvider = Provider.autoDispose<void>((ref) {
  final account = ref.watch(letterboxdFriendsAccountProvider).valueOrNull;
  if (account == null) return;
  final items = ref.watch(heroItemsProvider).valueOrNull ?? const [];
  for (final item in items) {
    if (item.overview.tmdbId case final tmdbId?) {
      ref.watch(letterboxdFriendsFilmProvider(tmdbId));
    }
  }
});
