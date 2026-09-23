import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
// ignore: depend_on_referenced_packages
import 'package:uuid/uuid.dart';

import 'package:kinos/jellyfin/jellyfin_open_api.enums.swagger.dart';
import 'package:kinos/models/settings/home_row_model.dart';
import 'package:kinos/providers/api_provider.dart';
import 'package:kinos/providers/database_provider.dart';

const _homeRowsSettingKey = 'home_rows';
const _homeRowsSettingScope = 'dashboard';

/// Distinct de `_homeRowsSettingKey` : une liste vide persistée (l'utilisateur
/// a tout supprimé) est une valeur légitime, pas une absence de configuration.
/// Ce drapeau, lui, ne veut dire qu'une chose : l'initialisation par défaut a
/// déjà eu lieu — elle ne doit jamais se reproduire, même si l'utilisateur
/// vide la liste ensuite.
const _homeRowsInitializedKey = 'home_rows_initialized';

/// Migration ponctuelle (lot B du système de recommandation) : ajoute
/// les rangées [HomeRowType.forYou]/[HomeRowType.setAside] à une
/// installation déjà en place (qui n'a donc jamais passé par
/// [_seedDefaults], seul endroit où elles sont ajoutées d'origine).
/// Même principe que [_homeRowsInitializedKey] : ne doit jamais se
/// reproduire, même si l'utilisateur retire ensuite ces deux rangées.
const _recommendationRowsMigrationKey = 'home_rows_recommendation_migration';

/// Migration ponctuelle (lot des rangées par graine + inventaire du
/// catalogue) — même principe que [_recommendationRowsMigrationKey],
/// pour les cinq nouveaux types catégorie ([HomeRowType.tasteSeeds] et
/// les quatre [HomeRowType.catalogWellRated]/[HomeRowType.catalogNarrowGenres]/
/// [HomeRowType.catalogDecades]/[HomeRowType.catalogLongFilms]).
const _catalogRowsMigrationKey = 'home_rows_catalog_migration';

/// Ordre par défaut des cinq nouveaux types catégorie — cf. spec :
/// rangées par graine, puis l'inventaire dans l'ordre bien notés →
/// genres étroits → décennies → longs métrages.
const _defaultCatalogRowTypes = [
  HomeRowType.tasteSeeds,
  HomeRowType.catalogWellRated,
  HomeRowType.catalogNarrowGenres,
  HomeRowType.catalogDecades,
  HomeRowType.catalogLongFilms,
];

/// Genres/films et séries uniquement (cf. CLAUDE.md § Périmètre).
const _defaultRowItemTypes = [BaseItemKind.movie, BaseItemKind.series];

/// Nombre de rangées de genre proposées par défaut.
const _defaultGenreRowCount = 2;

/// Rangées configurables de l'accueil, triées par [HomeRowModel.order].
/// Persistées dans la table `settings` (clé/valeur, lot 0) — pas de nouvelle
/// table pour un simple tableau de préférences.
final homeRowsProvider =
    StateNotifierProvider<HomeRowsNotifier, List<HomeRowModel>>((ref) {
  return HomeRowsNotifier(ref);
});

class HomeRowsNotifier extends StateNotifier<List<HomeRowModel>> {
  HomeRowsNotifier(this.ref) : super(const []) {
    _load();
  }

  final Ref ref;
  static const _uuid = Uuid();

  Future<void> _load() async {
    final db = ref.read(appDatabaseProvider);
    final setting =
        await db.getSetting(_homeRowsSettingKey, scope: _homeRowsSettingScope);
    if (setting == null) {
      final initialized = await db.getSetting(_homeRowsInitializedKey,
          scope: _homeRowsSettingScope);
      // Premier lancement seulement : jamais si l'utilisateur a déjà
      // supprimé toutes ses rangées (l'initialisation, elle, a bien eu
      // lieu — seul l'état de la liste a changé depuis). Dans ce
      // dernier cas, la migration ci-dessous s'applique quand même : une
      // liste vidée par l'utilisateur ne doit pas bloquer l'arrivée des
      // deux nouvelles rangées système.
      if (initialized == null) {
        await _seedDefaults();
      } else {
        await _ensureRecommendationRows();
        await _ensureCatalogRows();
      }
      return;
    }
    try {
      final decoded = jsonDecode(setting.value) as List;
      final rows = decoded
          .map((e) => HomeRowModel.fromJson(e as Map<String, dynamic>))
          .toList()
        ..sort((a, b) => a.order.compareTo(b.order));
      state = rows;
    } catch (_) {
      // Préférence corrompue : on repart d'une liste vide plutôt que de
      // planter le tableau de bord.
    }
    await _ensureRecommendationRows();
    await _ensureCatalogRows();
  }

  /// Ajoute [HomeRowType.forYou]/[HomeRowType.setAside] en tête de liste
  /// si elles n'y sont pas déjà — une seule fois, jamais reproduit (cf.
  /// [_recommendationRowsMigrationKey]). Sans effet pour une installation
  /// qui vient de passer par [_seedDefaults] (elle les inclut déjà et
  /// pose le même indicateur, cf. plus bas).
  Future<void> _ensureRecommendationRows() async {
    final db = ref.read(appDatabaseProvider);
    final migrated = await db.getSetting(_recommendationRowsMigrationKey,
        scope: _homeRowsSettingScope);
    if (migrated != null) return;

    final hasForYou = state.any((r) => r.type == HomeRowType.forYou);
    final hasSetAside = state.any((r) => r.type == HomeRowType.setAside);
    if (!hasForYou || !hasSetAside) {
      final newRows = [
        if (!hasForYou)
          HomeRowModel(
            id: _uuid.v4(),
            type: HomeRowType.forYou,
            title: HomeRowType.forYou.defaultTitle(null),
            order: 0,
          ),
        if (!hasSetAside)
          HomeRowModel(
            id: _uuid.v4(),
            type: HomeRowType.setAside,
            title: HomeRowType.setAside.defaultTitle(null),
            order: 0,
          ),
      ];
      await _reindexAndPersist([...newRows, ...state]);
    }

    await db.setSetting(_recommendationRowsMigrationKey, '1',
        scope: _homeRowsSettingScope);
  }

  /// Ajoute les cinq types catégorie du lot graines/inventaire (cf.
  /// [_defaultCatalogRowTypes]) juste après [HomeRowType.setAside] si
  /// absents — une seule fois, jamais reproduit (cf.
  /// [_catalogRowsMigrationKey]). Même motif que
  /// [_ensureRecommendationRows].
  Future<void> _ensureCatalogRows() async {
    final db = ref.read(appDatabaseProvider);
    final migrated = await db.getSetting(_catalogRowsMigrationKey,
        scope: _homeRowsSettingScope);
    if (migrated != null) return;

    final missing = _defaultCatalogRowTypes
        .where((type) => state.every((r) => r.type != type))
        .toList();
    if (missing.isNotEmpty) {
      final setAsideIndex =
          state.indexWhere((r) => r.type == HomeRowType.setAside);
      final insertAt = setAsideIndex == -1 ? 0 : setAsideIndex + 1;
      final newRows = [
        for (final type in missing)
          HomeRowModel(
            id: _uuid.v4(),
            type: type,
            title: type.defaultTitle(null),
            order: 0,
          ),
      ];
      final list = [...state];
      list.insertAll(insertAt, newRows);
      await _reindexAndPersist(list);
    }

    await db.setSetting(_catalogRowsMigrationKey, '1',
        scope: _homeRowsSettingScope);
  }

  /// Jeu de rangées par défaut au tout premier lancement : jamais vus, les
  /// mieux notés, à redécouvrir, puis une ou deux rangées de genre choisies
  /// parmi les genres les plus représentés dans la médiathèque de
  /// l'utilisateur (requête au serveur — jamais une liste codée en dur).
  ///
  /// Entièrement modifiable et supprimable ensuite depuis l'écran de
  /// configuration ; ne se reproduit jamais, cf. [_homeRowsInitializedKey].
  Future<void> _seedDefaults() async {
    final rows = [
      // Recommandations (lot B) en tête — cf. spec : "entre Continuer à
      // regarder et Ajouts récents", donc avant tout le reste dans
      // l'ordre persistant aussi (même si leur zone d'affichage réelle
      // est fixe, cf. dashboard_screen.dart).
      HomeRowModel(
        id: _uuid.v4(),
        type: HomeRowType.forYou,
        title: HomeRowType.forYou.defaultTitle(null),
        order: 0,
      ),
      HomeRowModel(
        id: _uuid.v4(),
        type: HomeRowType.setAside,
        title: HomeRowType.setAside.defaultTitle(null),
        order: 1,
      ),
      // Graines + inventaire du catalogue, juste après les deux
      // rangées ci-dessus (cf. _defaultCatalogRowTypes).
      for (final type in _defaultCatalogRowTypes)
        HomeRowModel(
          id: _uuid.v4(),
          type: type,
          title: type.defaultTitle(null),
          order: 0,
        ),
      HomeRowModel(
        id: _uuid.v4(),
        type: HomeRowType.unwatched,
        title: HomeRowType.unwatched.defaultTitle(null),
        order: 0,
      ),
      HomeRowModel(
        id: _uuid.v4(),
        type: HomeRowType.topRated,
        title: HomeRowType.topRated.defaultTitle(null),
        order: 0,
      ),
      HomeRowModel(
        id: _uuid.v4(),
        type: HomeRowType.rediscover,
        title: HomeRowType.rediscover.defaultTitle(null),
        order: 0,
      ),
    ];

    try {
      final topGenres = await _fetchTopGenres(ref, _defaultGenreRowCount);
      for (final (id, name) in topGenres) {
        rows.add(HomeRowModel(
          id: _uuid.v4(),
          type: HomeRowType.genre,
          title: HomeRowType.genre.defaultTitle(name),
          params: {'genreId': id, 'genreName': name},
          order: rows.length,
        ));
      }
    } catch (_) {
      // Hors ligne, médiathèque vide, ou requête en échec : les trois
      // premières rangées suffisent, l'accueil ne doit pas en dépendre.
    }

    // Réindexé par position : les entrées ci-dessus portent un `order`
    // provisoire (0 pour la plupart, cf. leur construction), seul
    // l'ordre de la liste compte ici.
    state = [for (var i = 0; i < rows.length; i++) rows[i].copyWith(order: i)];
    final db = ref.read(appDatabaseProvider);
    await db.setSetting(_homeRowsInitializedKey, '1',
        scope: _homeRowsSettingScope);
    // Déjà incluses ci-dessus : les migrations n'ont rien à faire pour
    // une installation qui vient de démarrer.
    await db.setSetting(_recommendationRowsMigrationKey, '1',
        scope: _homeRowsSettingScope);
    await db.setSetting(_catalogRowsMigrationKey, '1',
        scope: _homeRowsSettingScope);
    await _persist();
  }

  Future<void> _persist() async {
    final db = ref.read(appDatabaseProvider);
    await db.setSetting(
      _homeRowsSettingKey,
      jsonEncode(state.map((r) => r.toJson()).toList()),
      scope: _homeRowsSettingScope,
    );
  }

  Future<void> add({
    required HomeRowType type,
    required String title,
    Map<String, String> params = const {},
  }) async {
    final row = HomeRowModel(
      id: _uuid.v4(),
      type: type,
      title: title,
      params: params,
      order: state.length,
    );
    state = [...state, row];
    await _persist();
  }

  Future<void> remove(String id) async {
    state = state.where((r) => r.id != id).toList();
    await _persist();
  }

  Future<void> toggle(String id) async {
    state = [
      for (final r in state)
        if (r.id == id) r.copyWith(enabled: !r.enabled) else r,
    ];
    await _persist();
  }

  Future<void> rename(String id, String title) async {
    state = [
      for (final r in state)
        if (r.id == id) r.copyWith(title: title) else r,
    ];
    await _persist();
  }

  /// Glisser-déposer (souris) — `newIndex` suit la convention
  /// [ReorderableListView] (index cible *avant* retrait de l'élément).
  Future<void> reorder(int oldIndex, int newIndex) async {
    final list = [...state];
    if (newIndex > oldIndex) newIndex -= 1;
    final row = list.removeAt(oldIndex);
    list.insert(newIndex, row);
    await _reindexAndPersist(list);
  }

  /// Équivalent clavier du glisser-déposer.
  Future<void> moveUp(String id) => _moveBy(id, -1);
  Future<void> moveDown(String id) => _moveBy(id, 1);

  Future<void> _moveBy(String id, int delta) async {
    final list = [...state];
    final index = list.indexWhere((r) => r.id == id);
    final target = index + delta;
    if (index == -1 || target < 0 || target >= list.length) return;
    final row = list.removeAt(index);
    list.insert(target, row);
    await _reindexAndPersist(list);
  }

  Future<void> _reindexAndPersist(List<HomeRowModel> list) async {
    state = [for (var i = 0; i < list.length; i++) list[i].copyWith(order: i)];
    await _persist();
  }
}

/// Les [count] genres les mieux représentés (films et séries confondus)
/// dans la médiathèque de l'utilisateur, comptage inclus.
///
/// Un aller-retour pour le catalogue des genres, puis un comptage par genre
/// en parallèle (`Future.wait`) — coût acceptable pour une initialisation
/// unique, contrairement au budget de démarrage à froid des rangées
/// elles-mêmes (cf. `homeRowItemsProvider`).
Future<List<(String id, String name)>> _fetchTopGenres(
    Ref ref, int count) async {
  final api = ref.read(jellyApiProvider);

  final catalog = await api.genresGet(sortBy: [ItemSortBy.sortname]);
  final genres = (catalog.body?.items ?? [])
      .map((e) => (id: e.id ?? '', name: e.name ?? ''))
      .where((e) => e.id.isNotEmpty && e.name.isNotEmpty)
      .toList();
  if (genres.isEmpty) return const [];

  final counts = await Future.wait(genres.map((genre) async {
    final response = await api.usersUserIdItemsGet(
      genreIds: [genre.id],
      includeItemTypes: _defaultRowItemTypes,
      recursive: true,
      limit: 0,
      enableTotalRecordCount: true,
    );
    return (
      id: genre.id,
      name: genre.name,
      count: response.body?.totalRecordCount ?? 0,
    );
  }));

  final ranked = counts.where((g) => g.count > 0).toList()
    ..sort((a, b) => b.count.compareTo(a.count));

  return ranked.take(count).map((g) => (g.id, g.name)).toList();
}
