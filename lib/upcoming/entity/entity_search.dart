import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:kinos/letterboxd/letterboxd_import_controller.dart'
    show letterboxdDiscoveryClient;
import 'package:kinos/providers/user_provider.dart';

import '../upcoming_models.dart';
import '../upcoming_strings.dart';

/// Une personne ou un studio trouvé par la recherche.
class EntityResult {
  const EntityResult(
      {required this.kind,
      required this.id,
      required this.name,
      this.image,
      this.detail = ''});
  final UpcomingFollowKind kind;
  final int id;
  final String name;

  /// Photo ou logo (chemin TMDB).
  final String? image;

  /// « Interprétation · Dune, Wonka », « Studio · US ».
  final String detail;
}

/// Seuls les plus connus : la recherche rapide reste une courte liste.
const _people = 4;
const _companies = 2;

/// Personnes et studios de TMDB (par Seerr) pour la recherche de la
/// capsule. Vide sans Seerr ; une erreur ne prive jamais des autres
/// résultats.
final entitySearchProvider = FutureProvider.autoDispose
    .family<List<EntityResult>, ({String query, String language})>(
        (ref, search) async {
  final query = search.query.trim();
  if (query.length < 2) return const [];
  final client = letterboxdDiscoveryClient(
      ref.read(userProvider)?.seerrCredentials,
      interval: Duration.zero);
  if (client == null) return const [];
  ref.onDispose(client.close);
  List<Map<String, dynamic>> list(Object? value) => value is List
      ? value.whereType<Map<String, dynamic>>().toList()
      : const [];
  // Seerr valide la requête après l'avoir décodée : elle part encodée,
  // comme pour la recherche de titres.
  final encoded = Uri.encodeComponent(query);
  final language = search.language.split('-').first;
  try {
    final (people, companies) = await (
      client.get('search',
          query: {'query': encoded, 'page': '1'}, language: language),
      client.get('search/company', query: {'query': encoded, 'page': '1'}),
    ).wait;
    return [
      for (final p in list(people['results'])
          .where((r) => r['mediaType'] == 'person' && r['id'] is int)
          .take(_people))
        EntityResult(
            kind: UpcomingFollowKind.person,
            id: p['id'] as int,
            name: p['name'] as String? ?? '',
            image: tmdbPath(p['profilePath']),
            detail: [
              switch (EntityStrings.department(
                  p['knownForDepartment'] as String?)) {
                '' => EntityStrings.person,
                final department => department,
              },
              [
                for (final k in list(p['knownFor']).take(2))
                  if ((k['title'] ?? k['name']) case final String t) t
              ].join(', '),
            ].where((s) => s.isNotEmpty).join(' · ')),
      for (final c in list(companies['results'])
          .where((r) => r['id'] is int)
          .take(_companies))
        EntityResult(
            kind: UpcomingFollowKind.company,
            id: c['id'] as int,
            name: c['name'] as String? ?? '',
            image: tmdbPath(c['logoPath']),
            detail: [
              EntityStrings.studio,
              if (c['originCountry'] case final String country
                  when country.isNotEmpty)
                country,
            ].join(' · ')),
    ];
  } catch (_) {
    return const [];
  }
});
