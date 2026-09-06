import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
// ignore: depend_on_referenced_packages
import 'package:uuid/uuid.dart';

import 'package:fladder/jellyfin/jellyfin_open_api.enums.swagger.dart';
import 'package:fladder/models/settings/home_row_model.dart';
import 'package:fladder/providers/api_provider.dart';
import 'package:fladder/providers/database_provider.dart';

const _homeRowsSettingKey = 'home_rows';
const _homeRowsSettingScope = 'dashboard';

/// Distinct de `_homeRowsSettingKey` : une liste vide persistée (l'utilisateur
/// a tout supprimé) est une valeur légitime, pas une absence de configuration.
/// Ce drapeau, lui, ne veut dire qu'une chose : l'initialisation par défaut a
/// déjà eu lieu — elle ne doit jamais se reproduire, même si l'utilisateur
/// vide la liste ensuite.
const _homeRowsInitializedKey = 'home_rows_initialized';

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
      // lieu — seul l'état de la liste a changé depuis).
      if (initialized == null) await _seedDefaults();
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
        order: 1,
      ),
      HomeRowModel(
        id: _uuid.v4(),
        type: HomeRowType.rediscover,
        title: HomeRowType.rediscover.defaultTitle(null),
        order: 2,
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

    state = rows;
    final db = ref.read(appDatabaseProvider);
    await db.setSetting(_homeRowsInitializedKey, '1',
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
