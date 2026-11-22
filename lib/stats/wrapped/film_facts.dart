import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';

import 'package:kinos/letterboxd/letterboxd_import_controller.dart'
    show letterboxdDiscoveryClient;
import 'package:kinos/letterboxd/letterboxd_providers.dart';
import 'package:kinos/models/syncing/database_item.dart';
import 'package:kinos/providers/database_provider.dart';
import 'package:kinos/providers/user_provider.dart';

final _log = Logger('Wrapped');

/// Ce que le public sait d'un film (TMDB, par Seerr) : sa note sur 10, le
/// nombre de votes, la langue originale et l'année de sortie.
class FilmFacts {
  const FilmFacts(
      {this.publicRating,
      this.votes,
      this.language,
      this.year,
      this.poster,
      this.backdrop});
  final double? publicRating;
  final int? votes;
  final String? language;
  final int? year;

  /// Chemins TMDB de l'affiche et de l'image de fond : les images des films
  /// vus hors de la bibliothèque.
  final String? poster;
  final String? backdrop;

  Map<String, Object?> toJson() => {
        if (publicRating != null) 'r': publicRating,
        if (votes != null) 'v': votes,
        if (language != null) 'l': language,
        if (year != null) 'y': year,
        if (poster != null) 'p': poster,
        if (backdrop != null) 'b': backdrop,
      };

  static FilmFacts fromJson(Map json) => FilmFacts(
        publicRating: (json['r'] as num?)?.toDouble(),
        votes: json['v'] as int?,
        language: json['l'] as String?,
        year: json['y'] as int?,
        poster: json['p'] as String?,
        backdrop: json['b'] as String?,
      );

  /// Depuis la fiche film brute de Seerr (`movie/<id>`). Une note sans
  /// vote n'en est pas une.
  static FilmFacts fromSeerr(Map<String, dynamic> json) {
    final votes = json['voteCount'] is int ? json['voteCount'] as int : null;
    final rating = (json['voteAverage'] as num?)?.toDouble();
    final release = json['releaseDate'];
    return FilmFacts(
      publicRating: votes == null || votes == 0 ? null : rating,
      votes: votes,
      language: json['originalLanguage'] is String
          ? json['originalLanguage'] as String
          : null,
      year: release is String && release.length >= 4
          ? int.tryParse(release.substring(0, 4))
          : null,
      poster:
          json['posterPath'] is String ? json['posterPath'] as String : null,
      backdrop: json['backdropPath'] is String
          ? json['backdropPath'] as String
          : null,
    );
  }
}

/// Le cache des faits par film TMDB, dans la table `Settings`, une portée
/// par profil. Les faits bougent peu : relus après [maxAge].
class FilmFactsStore {
  FilmFactsStore(this.db, String profileScope)
      : scope = '$profileScope:film-facts:v1';
  final AppDatabase db;
  final String scope;

  static const maxAge = Duration(days: 30);

  Future<Map<int, FilmFacts>> all() async {
    final facts = <int, FilmFacts>{};
    final now = DateTime.now();
    for (final row in await db.getSettingsForScope(scope).get()) {
      final id = int.tryParse(row.key);
      if (id == null) continue;
      try {
        final json = jsonDecode(row.value);
        if (json is! Map || json['t'] is! int) continue;
        final at = DateTime.fromMillisecondsSinceEpoch(json['t'] as int);
        if (now.difference(at) > maxAge) continue;
        facts[id] = FilmFacts.fromJson(json);
      } on FormatException {
        continue;
      }
    }
    return facts;
  }

  Future<void> saveAll(Map<int, FilmFacts> facts) => db.transaction(() async {
        final t = DateTime.now().millisecondsSinceEpoch;
        for (final e in facts.entries) {
          await db.setSetting(
              '${e.key}', jsonEncode({...e.value.toJson(), 't': t}),
              scope: scope);
        }
      });
}

final filmFactsStoreProvider = Provider.autoDispose<FilmFactsStore?>((ref) {
  final scope = ref.watch(letterboxdScopeProvider);
  return scope == null
      ? null
      : FilmFactsStore(ref.watch(appDatabaseProvider),
          scope.replaceFirst('letterboxd:', 'kinos:'));
});

/// Les faits des films [tmdbIds] (« 1,2,3 ») : le cache, complété par Seerr
/// pour ce qui manque. Sans Seerr, le cache seul ; une erreur n'en prive
/// jamais les autres.
final filmFactsProvider = FutureProvider.autoDispose
    .family<Map<int, FilmFacts>, String>((ref, ids) async {
  final store = ref.watch(filmFactsStoreProvider);
  if (store == null || ids.isEmpty) return const {};
  final wanted = ids.split(',').map(int.parse).toSet();
  final known = await store.all();
  final missing = wanted.difference(known.keys.toSet()).toList();
  final client = letterboxdDiscoveryClient(
      ref.read(userProvider)?.seerrCredentials,
      interval: const Duration(milliseconds: 120),
      concurrency: 4);
  if (client != null && missing.isNotEmpty) {
    ref.onDispose(client.close);
    final fetched = <int, FilmFacts>{};
    await Future.wait([
      for (final id in missing)
        client
            .get('movie/$id')
            .then((json) => fetched[id] = FilmFacts.fromSeerr(json))
            .catchError((Object error) {
          _log.fine('Faits du film $id indisponibles : $error');
          return const FilmFacts();
        }),
    ]);
    if (fetched.isNotEmpty) await store.saveAll(fetched);
    known.addAll(fetched);
  }
  ref.keepAlive();
  return {
    for (final id in wanted)
      if (known[id] case final facts?) id: facts
  };
});
