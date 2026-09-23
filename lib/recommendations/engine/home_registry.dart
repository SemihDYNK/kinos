/// Registre de déduplication des titres affichés sur l'accueil — un
/// titre montré dans une rangée plus haute sur la page ne doit jamais
/// réapparaître dans une rangée plus basse (cf. spec : les rangées par
/// graine et l'inventaire du catalogue viennent après "Pour vous"/"Vous
/// l'aviez mis de côté"/"Ajouts récents", et ne doivent répéter aucun de
/// leurs titres).
library;

/// Les [reserve] premiers identifiants de [items], dans l'ordre — la
/// grille visible n'affiche jamais plus de colonnes que ça à l'échelle
/// de cette UI (cf. CLAUDE.md, "grilles à 6–8 colonnes"), et la largeur
/// d'écran réelle n'est connue qu'au rendu, jamais dans un provider :
/// réserver systématiquement le maximum plausible garantit qu'aucun
/// doublon ne peut apparaître, au prix d'exclure occasionnellement un
/// titre qui n'aurait en fait jamais été visible sur un écran étroit —
/// compromis délibéré, jamais l'inverse (un doublon visible).
Set<String> reserveIds<T>(
  Iterable<T> items,
  String Function(T) idOf, {
  int reserve = 8,
}) {
  return items.take(reserve).map(idOf).toSet();
}

/// [items] filtrés de tout ce qui figure déjà dans [registry].
List<T> excludeKnown<T>(
  List<T> items,
  String Function(T) idOf,
  Set<String> registry,
) {
  return items.where((item) => !registry.contains(idOf(item))).toList();
}
