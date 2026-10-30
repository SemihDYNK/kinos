import 'package:kinos/jellyfin/jellyfin_open_api.swagger.dart';
import 'package:kinos/providers/service_provider.dart';
import 'discovery_cache.dart';
import 'discovery_client.dart';
import 'discovery_debug.dart';

const _metadataFields = [
  ItemFields.genres,
  ItemFields.people,
  ItemFields.studios,
  ItemFields.tags,
  ItemFields.providerids,
  ItemFields.originaltitle
];

/// Persist only scoring metadata: never paths, streams, URLs or user history.
Map<String, dynamic> _metadata(BaseItemDto item) {
  final json = item.toJson();
  return {
    for (final key in [
      'Id',
      'Name',
      'Type',
      'ProviderIds',
      'ProductionYear',
      'Genres',
      'People',
      'Studios',
      'Tags',
      'OriginalTitle',
      'DateCreated',
      'DateLastMediaAdded'
    ])
      if (json.containsKey(key)) key: json[key]
  };
}

/// Fresh ownership/history, cached traits, and metadata deltas. An incomplete
/// inventory is never accepted as an exclusion snapshot.
Future<List<BaseItemDto>> loadDiscoveryLibrary(JellyService api,
    {required void Function() check,
    DiscoveryDebug? debug,
    DiscoveryCache? cache}) async {
  final started = cache?.now() ?? DateTime.now();
  Future<List<BaseItemDto>> fetch(
      {bool lean = false, DateTime? since, List<String>? ids}) async {
    final size = lean ? 500 : 50;
    final result = <BaseItemDto>[];
    var start = 0;
    while (true) {
      check();
      debug?.step(
          lean
              ? 'inventaire léger Jellyfin'
              : since != null
                  ? 'métadonnées modifiées Jellyfin'
                  : 'métadonnées Jellyfin',
          counts: {'début': start, 'limite': size});
      final response = await api
          .usersUserIdItemsGet(
            recursive: true,
            includeItemTypes: [BaseItemKind.movie, BaseItemKind.series],
            fields: lean ? [ItemFields.providerids] : _metadataFields,
            enableImages: false,
            enableUserData: true,
            enableTotalRecordCount: true,
            startIndex: start,
            limit: size,
            ids: ids,
            minDateLastSaved: since,
          )
          .timeout(const Duration(seconds: 30));
      check();
      if (!response.isSuccessful || response.body?.items == null) {
        throw const DiscoveryUnavailable();
      }
      final items = response.body!.items!;
      if (items.any((item) => item.id == null || item.id!.isEmpty)) {
        throw const DiscoveryUnavailable();
      }
      debug?.step('page Jellyfin reçue', counts: {
        'début': start,
        'titres': items.length,
        if (response.body!.totalRecordCount != null)
          'total': response.body!.totalRecordCount!
      });
      result.addAll(items);
      start += items.length;
      final total = response.body!.totalRecordCount;
      if (total != null && start >= total) break;
      if (items.isEmpty) {
        if (total != null && start < total) throw const DiscoveryUnavailable();
        break;
      }
      if (total == null && items.length < size) break;
    }
    if (result.map((item) => item.id).toSet().length != result.length) {
      throw const DiscoveryUnavailable();
    }
    return result;
  }

  final saved = await cache?.read('jellyfin-metadata:v1');
  Map<String, BaseItemDto>? metadata;
  DateTime? synced;
  try {
    if (saved != null && saved['items'] is List) {
      synced = DateTime.parse(saved['syncedAt'] as String);
      final items = (saved['items'] as List)
          .map((e) => BaseItemDto.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
      if (items.any((i) => i.id == null || i.id!.isEmpty)) {
        throw const FormatException('Invalid metadata IDs');
      }
      metadata = {for (final item in items) item.id!: item};
      if (metadata.length != items.length) {
        throw const FormatException('Duplicate IDs');
      }
    }
  } catch (_) {
    metadata = null;
    synced = null;
  }

  List<BaseItemDto> library;
  if (metadata == null || synced == null) {
    debug?.step('cache métadonnées absent : synchronisation initiale');
    library = await fetch();
  } else {
    debug
        ?.step('cache métadonnées chargé', counts: {'titres': metadata.length});
    final inventory = await fetch(lean: true);
    final updated =
        await fetch(since: synced.subtract(const Duration(minutes: 5)));
    for (final item in updated) {
      metadata[item.id!] = item;
    }
    final missing = inventory
        .where((i) => !metadata!.containsKey(i.id))
        .map((i) => i.id!)
        .toList();
    for (var i = 0; i < missing.length; i += 50) {
      final batch = missing.sublist(i, (i + 50).clamp(0, missing.length));
      final additions = await fetch(ids: batch);
      for (final item in additions) {
        if (!batch.contains(item.id)) throw const DiscoveryUnavailable();
        metadata[item.id!] = item;
      }
    }
    if (inventory.any((i) => !metadata!.containsKey(i.id))) {
      throw const DiscoveryUnavailable();
    }
    // History and external IDs must come from today's inventory, never the cache.
    library = [
      for (final fresh in inventory)
        BaseItemDto.fromJson({
          ..._metadata(metadata[fresh.id]!),
          'Id': fresh.id,
          'Name': fresh.name,
          'Type': fresh.toJson()['Type'],
          'ProviderIds': fresh.providerIds,
          'UserData': fresh.userData?.toJson(),
        })
    ];
  }
  check();
  await cache?.write('jellyfin-metadata:v1', {
    'syncedAt': started.toUtc().toIso8601String(),
    'items': library.map(_metadata).toList(),
  });
  return library;
}
