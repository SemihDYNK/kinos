import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:kinos/jellyfin/jellyfin_open_api.enums.swagger.dart';
import 'package:kinos/providers/api_provider.dart';

typedef ArrJellyfinLinkQuery = ({String title, int? year, bool isMovie});
typedef ArrJellyfinLinkMatch = ({String id, String name});

/// Correspondance Jellyfin d'un titre suivi par Radarr/Sonarr — recherche
/// par titre (et année si connue) via l'API Jellyfin déjà en place,
/// jamais par identifiant externe (TMDB/TVDB) : ce client généré
/// (`JellyService.itemsGet`) n'expose pas de filtre équivalent à
/// `AnyProviderIdEquals`. Best-effort : seul un titre normalisé
/// strictement identique est retenu comme correspondance ; sinon `null`
/// (jamais de redirection automatique — cf. ArrDetailScreen, un bouton
/// seulement, sur lequel l'utilisateur clique lui-même). Toute erreur
/// réseau se replie aussi sur `null` : ce lien est une aide, pas une
/// donnée dont l'absence doit se voir comme une panne.
final arrJellyfinLinkProvider = FutureProvider.family
    .autoDispose<ArrJellyfinLinkMatch?, ArrJellyfinLinkQuery>(
        (ref, query) async {
  if (query.title.trim().isEmpty) return null;
  try {
    final api = ref.read(jellyApiProvider);
    final response = await api.itemsGet(
      recursive: true,
      searchTerm: query.title,
      includeItemTypes: [
        query.isMovie ? BaseItemKind.movie : BaseItemKind.series
      ],
      years: query.year != null ? [query.year!] : null,
      limit: 10,
    );
    final items = response.body?.items ?? const [];
    final normalizedTitle = _normalize(query.title);
    for (final item in items) {
      if (_normalize(item.name) == normalizedTitle) {
        return (id: item.id, name: item.name);
      }
    }
    return null;
  } catch (_) {
    return null;
  }
});

String _normalize(String value) => value.trim().toLowerCase();
