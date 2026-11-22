import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';

import 'package:kinos/jellyfin/jellyfin_open_api.swagger.dart';
import 'package:kinos/letterboxd/letterboxd_providers.dart';
import 'package:kinos/models/syncing/database_item.dart';
import 'package:kinos/providers/api_provider.dart';
import 'package:kinos/providers/database_provider.dart';

import 'wikiquote.dart';

final _log = Logger('Wrapped');

/// Les citations déjà cherchées, une portée par profil : trouvées ou non,
/// elles ne sont redemandées qu'après [maxAge].
class WrappedQuoteStore {
  WrappedQuoteStore(this.db, String profileScope)
      : scope = '$profileScope:quotes:v1';
  final AppDatabase db;
  final String scope;

  static const maxAge = Duration(days: 90);

  /// `(quote: null)` : cherchée sans succès ; null : jamais cherchée.
  Future<({WrappedQuote? quote})?> read(String key) async {
    final row = await db.getSetting(key, scope: scope);
    if (row == null) return null;
    try {
      final json = jsonDecode(row.value);
      if (json is! Map || json['t'] is! int) return null;
      final at = DateTime.fromMillisecondsSinceEpoch(json['t'] as int);
      if (DateTime.now().difference(at) > maxAge) return null;
      return (quote: WrappedQuote.fromJson(json['q']));
    } on FormatException {
      return null;
    }
  }

  Future<void> save(String key, WrappedQuote? quote) => db.setSetting(
      key,
      jsonEncode({
        't': DateTime.now().millisecondsSinceEpoch,
        if (quote != null) 'q': quote.toJson(),
      }),
      scope: scope);
}

final wrappedQuoteStoreProvider =
    Provider.autoDispose<WrappedQuoteStore?>((ref) {
  final scope = ref.watch(letterboxdScopeProvider);
  return scope == null
      ? null
      : WrappedQuoteStore(ref.watch(appDatabaseProvider),
          scope.replaceFirst('letterboxd:', 'kinos:'));
});

/// La citation d'un réalisateur (`director|Nom`) ou la réplique d'un acteur
/// dans un de ses films de l'année (`actor|Nom|id Jellyfin,…`), cherchée
/// sur Wikiquote (français, puis anglais) et gardée en cache.
final wrappedQuoteProvider =
    FutureProvider.autoDispose.family<WrappedQuote?, String>((ref, key) async {
  final parts = key.split('|');
  final kind = parts.first, name = parts[1];
  final store = ref.watch(wrappedQuoteStoreProvider);
  final cacheKey = '$kind:$name';
  final cached = await store?.read(cacheKey);
  if (cached != null) return cached.quote;
  final client = WikiquoteClient();
  ref.onDispose(client.close);
  WrappedQuote? quote;
  try {
    quote = kind == 'director'
        ? await _personQuote(client, name)
        : await _actorLine(ref, client, name,
            parts.length > 2 ? parts[2].split(',') : const []);
  } catch (error) {
    _log.fine('Citation de $name introuvable : $error');
    return null;
  }
  await store?.save(cacheKey, quote);
  ref.keepAlive();
  return quote;
});

Future<WrappedQuote?> _personQuote(WikiquoteClient client, String name) async {
  for (final language in const ['fr', 'en']) {
    final page = await client.page(language, name);
    final text = page == null ? null : personQuote(page);
    if (text != null) return WrappedQuote(text, language: language);
  }
  return null;
}

/// Le rôle de l'acteur dans chaque film (Jellyfin), puis la page du film
/// sur Wikiquote : son titre français, sinon son titre original.
Future<WrappedQuote?> _actorLine(
    Ref ref, WikiquoteClient client, String name, List<String> ids) async {
  if (ids.isEmpty) return null;
  final response = await ref.read(jellyApiProvider).usersUserIdItemsGet(
      ids: ids.take(3).toList(),
      fields: const [ItemFields.people, ItemFields.originaltitle],
      enableImages: false,
      enableUserData: false);
  for (final dto in response.body?.items ?? const <BaseItemDto>[]) {
    final role = (dto.people ?? const <BaseItemPerson>[])
        .where((p) => p.name == name && (p.role?.isNotEmpty ?? false))
        .firstOrNull
        ?.role;
    if (role == null) continue;
    final titles = [
      ('fr', dto.name),
      ('en', dto.originalTitle ?? dto.name),
    ];
    for (final (language, title) in titles) {
      if (title == null || title.isEmpty) continue;
      final found = await client.search(language,
          language == 'en' ? '$title ${dto.productionYear ?? ''} film' : title);
      if (found == null || !sameTitle(found, title)) continue;
      final page = await client.page(language, found);
      if (page == null) continue;
      final line = bestLine(characterLines(page, role), role);
      if (line != null) {
        return WrappedQuote(line,
            language: language,
            film: dto.name,
            role: role.split('/').first.trim());
      }
    }
  }
  return null;
}
