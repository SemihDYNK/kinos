import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:kinos/letterboxd/letterboxd_import_controller.dart'
    show letterboxdDiscoveryClient;
import 'package:kinos/models/items/person_model.dart';
import 'package:kinos/providers/api_provider.dart';
import 'package:kinos/providers/settings/client_settings_provider.dart';
import 'package:kinos/providers/user_provider.dart';
import 'package:kinos/recommendations/seerr/discovery_client.dart';

import '../upcoming_logic.dart' show isMainRole;
import '../upcoming_models.dart';
import '../upcoming_providers.dart';
import '../upcoming_store.dart';
import 'entity_models.dart';

/// Une page à suivre : personne, studio, chaîne ou saga.
typedef EntityKey = ({UpcomingFollowKind kind, int id});

/// Ordre du catalogue d'un studio ou d'une chaîne.
enum EntitySort { recent, rated, popular }

class EntityState {
  const EntityState({
    this.header,
    this.acting = const [],
    this.directing = const [],
    this.upcoming = const [],
    this.catalogue = const [],
    this.main = const {},
    this.loading = true,
    this.failed = false,
    this.checking = 0,
    this.sort = EntitySort.recent,
    this.hasMore = false,
    this.loadingMore = false,
  });

  final EntityHeader? header;

  /// Personne : ses rôles et ses réalisations.
  final List<EntityTitle> acting;
  final List<EntityTitle> directing;

  /// Studio, chaîne : les sorties à venir, puis le catalogue.
  final List<EntityTitle> upcoming;

  /// Studio, chaîne : le catalogue, page après page ; saga : ses films.
  final List<EntityTitle> catalogue;

  /// Rôles d'une personne vérifiés comme principaux, par identité.
  final Map<String, bool> main;
  final bool loading;
  final bool failed;

  /// Fiches de films encore à lire pour trier les rôles.
  final int checking;
  final EntitySort sort;
  final bool hasMore;
  final bool loadingMore;

  EntityState copyWith({
    EntityHeader? header,
    List<EntityTitle>? acting,
    List<EntityTitle>? directing,
    List<EntityTitle>? upcoming,
    List<EntityTitle>? catalogue,
    Map<String, bool>? main,
    bool? loading,
    bool? failed,
    int? checking,
    EntitySort? sort,
    bool? hasMore,
    bool? loadingMore,
  }) =>
      EntityState(
        header: header ?? this.header,
        acting: acting ?? this.acting,
        directing: directing ?? this.directing,
        upcoming: upcoming ?? this.upcoming,
        catalogue: catalogue ?? this.catalogue,
        main: main ?? this.main,
        loading: loading ?? this.loading,
        failed: failed ?? this.failed,
        checking: checking ?? this.checking,
        sort: sort ?? this.sort,
        hasMore: hasMore ?? this.hasMore,
        loadingMore: loadingMore ?? this.loadingMore,
      );

  /// Un rôle d'interprétation compte comme principal : vérifié sur la
  /// fiche du film (principal en attendant) ; une série, d'après son
  /// nombre d'épisodes.
  bool isMain(EntityTitle title) =>
      !isAppearance(title) && (main[title.identity] ?? true);
}

final entityProvider = StateNotifierProvider.autoDispose
    .family<EntityController, EntityState, EntityKey>(
        (ref, key) => EntityController(ref, key));

class EntityController extends StateNotifier<EntityState> {
  EntityController(this.ref, this.key) : super(const EntityState()) {
    _client = letterboxdDiscoveryClient(
        ref.read(userProvider)?.seerrCredentials,
        interval: const Duration(milliseconds: 120),
        concurrency: 4);
    _load();
  }

  final Ref ref;
  final EntityKey key;
  DiscoveryClient? _client;
  int _page = 0;

  String get _language => (ref.read(clientSettingsProvider).selectedLocale ??
          WidgetsBinding.instance.platformDispatcher.locale)
      .languageCode;

  UpcomingStore? get _store => ref.read(upcomingStoreProvider);

  @override
  void dispose() {
    _client?.close();
    super.dispose();
  }

  Future<Map<String, dynamic>> _get(String path,
      {Map<String, String> query = const {}}) {
    final client = _client;
    if (client == null) throw const DiscoveryUnavailable();
    // Sur `discover`, Seerr prend `language` pour la langue d'origine.
    return client.get(path,
        query: query,
        language: path.startsWith('discover/') ? null : _language);
  }

  static List<Map<String, dynamic>> _list(Object? value) => value is List
      ? value.whereType<Map<String, dynamic>>().toList()
      : const [];

  static String _year(Object? date) =>
      date is String && date.length >= 4 ? date.substring(0, 4) : '';

  Future<void> _load() async {
    try {
      switch (key.kind) {
        case UpcomingFollowKind.person:
          await _loadPerson();
        case UpcomingFollowKind.company:
        case UpcomingFollowKind.network:
          await _loadCatalogueOwner();
        case UpcomingFollowKind.collection:
          await _loadCollection();
        case UpcomingFollowKind.tv:
          break;
      }
    } catch (_) {
      if (mounted) state = state.copyWith(loading: false, failed: true);
    }
  }

  /// Titres d'une liste Seerr, sans doublon (une série où l'on a tenu
  /// deux rôles), du plus récent au plus ancien, les annoncés d'abord.
  static List<EntityTitle> _titles(Iterable<Map<String, dynamic>> credits) {
    final seen = <String, EntityTitle>{};
    for (final credit in credits) {
      final title = EntityTitle.fromJson(credit);
      if (title == null) continue;
      final known = seen[title.identity];
      if (known == null ||
          (title.episodes ?? 0) > (known.episodes ?? 0) ||
          (known.character == null && title.character != null)) {
        seen[title.identity] = title;
      }
    }
    return seen.values.toList()
      ..sort((a, b) {
        final da = a.date, db = b.date;
        if (da == null || db == null) {
          return da == db ? 0 : (da == null ? -1 : 1);
        }
        return db.compareTo(da);
      });
  }

  Future<void> _loadPerson() async {
    final details = await _get('person/${key.id}');
    final credits = await _get('person/${key.id}/combined_credits');
    final born = _year(details['birthday']);
    final knownFor = details['knownForDepartment'] as String?;
    final acting = _titles(_list(credits['cast']));
    final directing =
        _titles(_list(credits['crew']).where((c) => c['job'] == 'Director'));
    final main = await _store?.roles(key.id) ?? {};
    if (!mounted) return;
    state = state.copyWith(
        loading: false,
        header: EntityHeader(
            name: details['name'] as String? ?? '',
            image: tmdbPath(details['profilePath']),
            biography: details['biography'] as String?,
            knownFor: knownFor,
            context: [
              switch (knownFor) {
                'Directing' => 'Réalisation',
                'Acting' => 'Interprétation',
                'Writing' => 'Scénario',
                'Production' => 'Production',
                _ => null,
              },
              if (born.isNotEmpty) 'né·e en $born',
              if (directing.isNotEmpty) '${directing.length} réalisations',
              if (acting.isNotEmpty) '${acting.length} rôles',
            ].nonNulls.join(' · ')),
        acting: acting,
        directing: directing,
        main: main);
    await _checkRoles(acting, main);
  }

  /// Lit la fiche de chaque film pour savoir si le rôle est principal
  /// (cinq premiers du générique, ou personnage nommé parmi les huit).
  Future<void> _checkRoles(
      List<EntityTitle> acting, Map<String, bool> known) async {
    final client = _client;
    final pending = [
      for (final t in acting)
        if (t.isMovie && !isAppearance(t) && !known.containsKey(t.identity)) t
    ];
    if (client == null || pending.isEmpty) return;
    final main = {...known};
    state = state.copyWith(checking: pending.length);
    var done = 0;
    await client.map<EntityTitle, void>(pending, (title) async {
      try {
        final details = await _get('movie/${title.id}');
        main[title.identity] = isMainRole(details, key.id);
      } catch (_) {
        // Non vérifié : compté comme principal, revu la prochaine fois.
      }
      done++;
      if (mounted && (done % 8 == 0 || done == pending.length)) {
        state =
            state.copyWith(main: {...main}, checking: pending.length - done);
      }
    });
    if (!mounted) return;
    state = state.copyWith(main: main, checking: 0);
    await _store?.saveRoles(key.id, main);
  }

  bool get _network => key.kind == UpcomingFollowKind.network;

  String _today() {
    final d = DateTime.now();
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }

  Map<String, String> get _owner =>
      _network ? {'network': '${key.id}'} : {'studio': '${key.id}'};

  String get _discover => _network ? 'discover/tv' : 'discover/movies';
  String get _dateGte => _network ? 'firstAirDateGte' : 'primaryReleaseDateGte';
  String get _dateLte => _network ? 'firstAirDateLte' : 'primaryReleaseDateLte';

  Future<void> _loadCatalogueOwner() async {
    final details = await _get('${_network ? 'network' : 'studio'}/${key.id}');
    final upcoming = await _get(_discover, query: {
      ..._owner,
      _dateGte: _today(),
      'sortBy': _network ? 'first_air_date.asc' : 'primary_release_date.asc',
    });
    if (!mounted) return;
    final country = details['originCountry'] as String?;
    state = state.copyWith(
        header: EntityHeader(
            name: details['name'] as String? ?? '',
            image: tmdbPath(details['logoPath']),
            context: [
              _network ? 'Chaîne' : 'Studio',
              if (country != null && country.isNotEmpty) country,
            ].join(' · ')),
        upcoming: _list(upcoming['results'])
            .map(
                (r) => EntityTitle.fromJson(r, type: _network ? 'tv' : 'movie'))
            .nonNulls
            .toList());
    await _loadPage(reset: true);
  }

  Future<void> _loadPage({bool reset = false}) async {
    if (reset) _page = 0;
    final page = _page + 1;
    final sort = state.sort;
    final found = await _get(_discover, query: {
      ..._owner,
      'page': '$page',
      'sortBy': switch (sort) {
        EntitySort.recent =>
          _network ? 'first_air_date.desc' : 'primary_release_date.desc',
        EntitySort.rated => 'vote_average.desc',
        EntitySort.popular => 'popularity.desc',
      },
      if (sort == EntitySort.rated) 'voteCountGte': '200',
      if (sort == EntitySort.recent) _dateLte: _today(),
    });
    if (!mounted || sort != state.sort) return;
    _page = page;
    final titles = _list(found['results'])
        .map((r) => EntityTitle.fromJson(r, type: _network ? 'tv' : 'movie'))
        .nonNulls
        .toList();
    final total = found['totalPages'];
    state = state.copyWith(
        loading: false,
        loadingMore: false,
        catalogue: [if (!reset) ...state.catalogue, ...titles],
        hasMore: total is int && page < total);
  }

  Future<void> loadMore() async {
    if (state.loadingMore || !state.hasMore) return;
    state = state.copyWith(loadingMore: true);
    try {
      await _loadPage();
    } catch (_) {
      if (mounted) state = state.copyWith(loadingMore: false);
    }
  }

  Future<void> setSort(EntitySort sort) async {
    if (sort == state.sort) return;
    state = state.copyWith(sort: sort, catalogue: const [], loadingMore: true);
    try {
      await _loadPage(reset: true);
    } catch (_) {
      if (mounted) state = state.copyWith(loadingMore: false);
    }
  }

  Future<void> _loadCollection() async {
    final details = await _get('collection/${key.id}');
    final parts = _list(details['parts'])
        .map((r) => EntityTitle.fromJson(r, type: 'movie'))
        .nonNulls
        .toList()
      ..sort((a, b) {
        final da = a.date, db = b.date;
        if (da == null || db == null) {
          return da == db ? 0 : (da == null ? 1 : -1);
        }
        return da.compareTo(db);
      });
    if (!mounted) return;
    state = state.copyWith(
        loading: false,
        header: EntityHeader(
            name: details['name'] as String? ?? '',
            image: tmdbPath(details['posterPath']),
            backdrop: tmdbPath(details['backdropPath']),
            biography: details['overview'] as String?,
            context: 'Saga · ${parts.length} films'),
        catalogue: parts);
  }
}

/// Identifiant TMDB d'une personne de Jellyfin, pour ouvrir sa page.
final jellyfinPersonTmdbProvider =
    FutureProvider.autoDispose.family<int?, String>((ref, personId) async {
  final response = await ref
      .read(jellyApiProvider)
      .usersUserIdItemsItemIdGet(itemId: personId);
  final person = response.body;
  if (person is! PersonModel) return null;
  final ids = person.providerIds ?? const <String, dynamic>{};
  for (final MapEntry(:key, :value) in ids.entries) {
    if (key.toLowerCase() == 'tmdb') return int.tryParse('$value');
  }
  return null;
});
