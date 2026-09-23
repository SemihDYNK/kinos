import 'package:kinos/recommendations/models/trait.dart';

/// Cœur d'un titre, débarrassé des indices de suite les plus courants —
/// sous-titre après ':' (ex. "Kill Bill: Volume 2" -> "kill bill"),
/// numérotation finale arabe ou romaine, "Part N" (ex. "Moi, moche et
/// méchant 3" -> "moi, moche et méchant"). Purement heuristique : deux
/// titres qui ne partagent ni préfixe ni mot-clé (ex. les films James
/// Bond, dont les titres n'ont rien en commun) ne seront pas regroupés
/// par ce seul mécanisme — cf. `franchiseKeysFor`, qui ajoute aussi les
/// mots-clés partagés pour couvrir ce cas.
String normalizeFranchiseTitle(String title) {
  var t = title.trim().toLowerCase();
  final colonIndex = t.indexOf(':');
  if (colonIndex > 0) t = t.substring(0, colonIndex);
  t = t.replaceAll(RegExp(r'\s*(part\s+)?\b(\d+|[ivxlcdm]+)\b\s*$'), '');
  return t.trim();
}

/// Clés de franchise d'un candidat — cf. `CandidateItem.franchiseKeys`.
/// Combine trois sources, chacune préfixée pour ne jamais se confondre
/// entre elles :
/// - la collection TMDB, quand elle est connue (la plus fiable — Radarr
///   l'expose directement sur ses ressources film) ;
/// - le titre normalisé (cf. [normalizeFranchiseTitle]) ;
/// - chaque mot-clé (`TraitKind.keyword`) du candidat — c'est ce qui
///   attrape une franchise dont les titres ne se ressemblent pas (James
///   Bond : "Skyfall", "Spectre"...), à condition que le mot-clé lui-même
///   identifie la franchise (ex. "james bond"), ce qui n'est pas garanti
///   pour tous les mots-clés génériques — heuristique, pas une garantie.
List<String> franchiseKeysFor(
  String title,
  List<TraitKey> traits, {
  String? tmdbCollectionId,
}) {
  final keys = <String>{
    'title:${normalizeFranchiseTitle(title)}',
    for (final t in traits)
      if (t.kind == TraitKind.keyword) 'keyword:${t.value}',
  };
  if (tmdbCollectionId != null && tmdbCollectionId.isNotEmpty) {
    keys.add('tmdb-collection:$tmdbCollectionId');
  }
  return keys.toList();
}
