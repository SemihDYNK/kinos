import 'dart:convert';
import 'dart:isolate';
import 'mapping.dart';

class CatalogSnapshot {
  final String json;
  final DateTime fetchedAt;
  const CatalogSnapshot(this.json, this.fetchedAt);
}

AnilistCatalogIndex _decode(String json) =>
    AnilistCatalogIndex.fromJson(jsonDecode(json));

class AnilistCatalog {
  final Future<CatalogSnapshot?> Function() read;
  final Future<void> Function(CatalogSnapshot) write;
  final Future<String> Function() fetch;
  final DateTime Function() clock;
  Future<AnilistCatalogIndex>? _pending;
  AnilistCatalogIndex? _last;
  DateTime? _fetchedAt;
  AnilistCatalog(
      {required this.read,
      required this.write,
      required this.fetch,
      DateTime Function()? clock})
      : clock = clock ?? DateTime.now;
  Future<AnilistCatalogIndex> load() {
    if (_last != null &&
        _fetchedAt != null &&
        clock().difference(_fetchedAt!) < const Duration(days: 1)) {
      return Future.value(_last);
    }
    return _pending ??= _load().whenComplete(() => _pending = null);
  }

  Future<AnilistCatalogIndex> _load() async {
    if (_last == null) {
      try {
        final cached = await read();
        if (cached != null) {
          final raw = cached.json;
          _last = await Isolate.run(() => _decode(raw));
          _fetchedAt = cached.fetchedAt;
        }
      } on Exception {
        /* An unreadable cache is replaced only by validated data. */
      }
    }
    if (_last != null &&
        _fetchedAt != null &&
        clock().difference(_fetchedAt!) < const Duration(days: 1)) {
      return _last!;
    }
    try {
      final raw = await fetch();
      if (utf8.encode(raw).length > 32 * 1024 * 1024) {
        throw const FormatException('Mapping catalog too large');
      }
      final parsed = await Isolate.run(() => _decode(raw));
      final date = clock();
      await write(CatalogSnapshot(raw, date));
      _last = parsed;
      _fetchedAt = date;
      return parsed;
    } on Exception {
      if (_last != null) return _last!;
      rethrow;
    }
  }
}
