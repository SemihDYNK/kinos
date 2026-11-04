import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:kinos/models/item_base_model.dart';
import 'package:kinos/models/items/season_model.dart';
import 'package:kinos/jellyfin/jellyfin_open_api.swagger.dart' as dto;
import 'package:kinos/providers/api_provider.dart';
import 'package:kinos/providers/database_provider.dart';
import 'package:kinos/providers/user_provider.dart';
import 'anilist_catalog.dart';
import 'anilist_client.dart';
import 'anilist_store.dart';
import 'jellyfin_target.dart';
import 'mapping.dart';

const _catalogUrl =
    'https://raw.githubusercontent.com/Fribb/anime-lists/master/anime-list-full.json';
final anilistCatalogProvider = Provider<AnilistCatalog>((ref) {
  final cache = CacheManager(Config('anilistMappings',
      stalePeriod: const Duration(days: 1), maxNrOfCacheObjects: 1));
  ref.onDispose(cache.dispose);
  return AnilistCatalog(read: () async {
    final file = await cache.getFileFromCache(_catalogUrl);
    if (file == null || !await file.file.exists()) return null;
    return CatalogSnapshot(await file.file.readAsString(),
        file.validTill.subtract(const Duration(days: 1)));
  }, write: (snapshot) async {
    await cache.putFile(
        _catalogUrl, Uint8List.fromList(utf8.encode(snapshot.json)),
        maxAge: const Duration(days: 1), fileExtension: 'json');
  }, fetch: () async {
    final client = http.Client();
    try {
      return await (() async {
        final response =
            await client.send(http.Request('GET', Uri.parse(_catalogUrl)));
        if (response.statusCode != 200 ||
            (response.contentLength ?? 0) > 32 * 1024 * 1024) {
          throw const AnilistUnavailable();
        }
        final bytes = BytesBuilder(copy: false);
        var size = 0;
        await for (final chunk in response.stream) {
          size += chunk.length;
          if (size > 32 * 1024 * 1024) throw const AnilistUnavailable();
          bytes.add(chunk);
        }
        return utf8.decode(bytes.takeBytes());
      })()
          .timeout(const Duration(seconds: 15));
    } finally {
      client.close();
    }
  });
});

class AnilistPanelState {
  final AnilistTarget target;
  final AnilistMatch match;
  final bool busy;
  final bool failed;
  final List<AnilistMedia> searchResults;
  final int? selectedId;
  final int? savedId;
  final DateTime? retryAt;
  const AnilistPanelState(
      {required this.target,
      this.match = const AnilistMatch(AnilistMatchStatus.notFound),
      this.busy = false,
      this.failed = false,
      this.searchResults = const [],
      this.selectedId,
      this.savedId,
      this.retryAt});
  AnilistPanelState copyWith(
          {AnilistTarget? target,
          AnilistMatch? match,
          bool? busy,
          bool? failed,
          List<AnilistMedia>? searchResults,
          int? selectedId,
          int? savedId,
          bool clearSelection = false,
          bool clearSaved = false,
          DateTime? retryAt}) =>
      AnilistPanelState(
          target: target ?? this.target,
          match: match ?? this.match,
          busy: busy ?? this.busy,
          failed: failed ?? this.failed,
          searchResults: searchResults ?? this.searchResults,
          selectedId: clearSelection ? null : selectedId ?? this.selectedId,
          savedId: clearSaved ? null : savedId ?? this.savedId,
          retryAt: failed == false ? null : retryAt ?? this.retryAt);
}

class AnilistMappingController extends StateNotifier<AnilistPanelState> {
  final AnilistClient client;
  final AnilistCatalog catalog;
  final AnilistStore store;
  final bool Function() isCurrent;
  final Future<AnilistTarget> Function()? loadTarget;
  int _generation = 0;
  AnilistMappingController(
      {required AnilistTarget target,
      required this.client,
      required this.catalog,
      required this.store,
      required this.isCurrent,
      this.loadTarget})
      : super(AnilistPanelState(target: target));
  bool get _active => mounted && isCurrent();
  bool _valid(int generation) => _active && generation == _generation;
  @override
  void dispose() {
    _generation++;
    client.close();
    super.dispose();
  }

  void select(int id) {
    if (_active && !state.busy) {
      state = state.copyWith(selectedId: id, failed: false);
    }
  }

  void _failure(int generation, Object error) {
    if (_valid(generation)) {
      state = state.copyWith(
          busy: false,
          failed: true,
          retryAt: error is AnilistUnavailable ? error.retryAt : null);
    }
  }

  Future<void> resolve() async {
    if (!_active) return;
    final generation = ++_generation;
    state = state.copyWith(
        busy: true, failed: false, searchResults: [], clearSelection: true);
    try {
      final target = loadTarget == null ? state.target : await loadTarget!();
      if (!_valid(generation)) return;
      state = state.copyWith(target: target);
      final saved = await store.read(target);
      if (!_valid(generation)) return;
      if (saved != null) {
        final media = await client.media(id: saved.id);
        if (!_valid(generation)) return;
        state = state.copyWith(
            busy: false,
            savedId: saved.id,
            selectedId: saved.id,
            match: AnilistMatch(
                saved.confirmed && media != null
                    ? AnilistMatchStatus.exact
                    : AnilistMatchStatus.needsConfirmation,
                [
                  AnilistCandidate(saved.id, {'manual'}, media: media)
                ],
                media == null
                    ? AnilistMatchReason.invalidSource
                    : saved.confirmed
                        ? null
                        : AnilistMatchReason.changedIds));
        return;
      }
      final verified = <int, AnilistMedia>{};
      final malLookup = <int, int>{};
      final direct = positiveId(target.ids.values['anilist']);
      final mal = positiveId(target.ids.values['mal']);
      for (final query in [
        if (direct != null) (id: direct, malId: null),
        if (mal != null) (id: null, malId: mal)
      ]) {
        final value = await client.media(id: query.id, malId: query.malId);
        if (!_valid(generation)) return;
        if (value == null) {
          state = state.copyWith(
              busy: false,
              match: const AnilistMatch(AnilistMatchStatus.needsConfirmation,
                  [], AnilistMatchReason.invalidSource));
          return;
        }
        verified[value.id] = value;
        if (query.malId != null) malLookup[query.malId!] = value.id;
      }
      final needCatalog = target.ids.values.keys
              .any((key) => !['anilist', 'mal'].contains(key)) ||
          target.parentIds.values.isNotEmpty;
      final index =
          needCatalog ? await catalog.load() : AnilistCatalogIndex.empty;
      if (!_valid(generation)) return;
      var match = resolveAnilistTarget(target, index, malLookup: malLookup);
      final missing = match.candidates
          .where((c) => !verified.containsKey(c.id))
          .map((c) => c.id)
          .toList();
      if (missing.isNotEmpty) {
        for (final media in await client.mediaByIds(missing)) {
          verified[media.id] = media;
        }
      }
      if (!_valid(generation)) return;
      final candidates = [
        for (final c in match.candidates) c.withMedia(verified[c.id])
      ];
      if (candidates.any((c) => c.media == null)) {
        match = AnilistMatch(AnilistMatchStatus.needsConfirmation, candidates,
            AnilistMatchReason.invalidSource);
      } else {
        match = AnilistMatch(match.status, candidates, match.reason);
      }
      state = state.copyWith(busy: false, match: match, clearSaved: true);
    } on Exception catch (error) {
      _failure(generation, error);
    }
  }

  Future<void> search(String title) async {
    if (!_active || title.trim().isEmpty) return;
    final generation = ++_generation;
    state = state.copyWith(busy: true, failed: false);
    try {
      final results = await client.search(title);
      if (_valid(generation)) {
        state = state.copyWith(
            busy: false,
            searchResults: results,
            clearSelection:
                !results.any((media) => media.id == state.selectedId));
      }
    } on Exception catch (error) {
      _failure(generation, error);
    }
  }

  Future<void> confirm(int id) async {
    if (!_active || id <= 0) return;
    final generation = ++_generation;
    state = state.copyWith(busy: true, failed: false);
    try {
      final known = [
        for (final candidate in state.match.candidates)
          if (candidate.id == id) candidate.media,
        for (final media in state.searchResults)
          if (media.id == id) media,
      ].whereType<AnilistMedia>().toList();
      final media = known.isNotEmpty ? known.first : await client.media(id: id);
      if (!_valid(generation)) return;
      if (media == null) throw const AnilistUnavailable();
      await store.save(state.target, id, isCurrent: () => _valid(generation));
      if (_valid(generation)) {
        state = state.copyWith(
            busy: false,
            savedId: id,
            selectedId: id,
            match: AnilistMatch(AnilistMatchStatus.exact, [
              AnilistCandidate(id, {'manual'}, media: media)
            ]));
      }
    } on Exception catch (error) {
      _failure(generation, error);
    }
  }

  Future<void> remove() async {
    if (!_active) return;
    final generation = ++_generation;
    state = state.copyWith(busy: true, failed: false);
    try {
      await store.remove(state.target, isCurrent: () => _valid(generation));
      if (_valid(generation)) {
        state = state.copyWith(clearSaved: true, clearSelection: true);
        await resolve();
      }
    } on Exception catch (error) {
      _failure(generation, error);
    }
  }
}

String? _scope(Ref ref) {
  final user = ref.read(userProvider);
  if (user == null) return null;
  return anilistProfileScope(
      serverId: user.credentials.serverId,
      url: user.credentials.url,
      userId: user.id);
}

final anilistMappingProvider = StateNotifierProvider.autoDispose
    .family<AnilistMappingController, AnilistPanelState, ItemBaseModel>(
        (ref, item) {
  ref.watch(userProvider.select(
      (user) => (user?.id, user?.credentials.serverId, user?.credentials.url)));
  final scope = _scope(ref);
  final api = ref.read(jellyApiProvider);
  var alive = true;
  ref.onDispose(() => alive = false);
  final controller = AnilistMappingController(
      target: anilistTargetFromItem(item),
      client: AnilistClient(),
      catalog: ref.watch(anilistCatalogProvider),
      store: AnilistStore(
          ref.watch(appDatabaseProvider), scope ?? 'anilist:unavailable'),
      isCurrent: () => alive && scope != null && _scope(ref) == scope,
      loadTarget: () async {
        final response =
            await api.usersUserIdItemsItemIdGetBaseItem(itemId: item.id);
        if (!alive || _scope(ref) != scope) throw const AnilistScopeChanged();
        final source = response.body;
        if (source == null) throw const AnilistUnavailable();
        dto.BaseItemDto? parent;
        if (item is SeasonModel && item.seriesId.isNotEmpty) {
          final response = await api.usersUserIdItemsItemIdGetBaseItem(
              itemId: item.seriesId);
          if (!alive || _scope(ref) != scope) throw const AnilistScopeChanged();
          parent = response.body;
          if (parent == null) throw const AnilistUnavailable();
        }
        return anilistTargetFromItem(item,
            source: source, parentSource: parent);
      });
  return controller;
});
