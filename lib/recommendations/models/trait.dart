/// Catégorie d'un trait de goût — genre, réalisateur, acteur (parmi les
/// 3-4 premiers crédités), décennie, studio, ou mot-clé. Jellyfin
/// n'expose pas de "mots-clés" distincts des tags libres : `tags` fait
/// office de mots-clés ici, faute de mieux dans l'API.
enum TraitKind { genre, director, actor, decade, studio, keyword }

/// Clé d'un trait dans un vecteur de goût — un genre précis, un
/// réalisateur précis, etc. Type record : égalité structurelle gratuite
/// (deux [TraitKey] avec les mêmes `kind`/`value` sont `==`), utilisable
/// tel quel comme clé de `Map` sans classe dédiée ni `hashCode` à écrire
/// à la main.
typedef TraitKey = ({TraitKind kind, String value});

/// Fabrique une clé normalisée — la casse ne doit jamais faire compter
/// deux fois le même trait ("Science Fiction" et "science fiction" sont
/// le même genre). La valeur d'affichage d'origine est perdue par la
/// normalisation ; ce n'est pas un problème pour le moteur (qui ne fait
/// que comparer des clés), seulement pour un futur affichage, hors
/// périmètre de ce lot.
TraitKey trait(TraitKind kind, String rawValue) =>
    (kind: kind, value: rawValue.trim().toLowerCase());

/// Décennie d'une année de production (1999 -> 1990, 2003 -> 2000).
/// `null` si [year] est absent — une œuvre sans année connue ne
/// contribue simplement pas ce trait, plutôt qu'une fausse décennie.
TraitKey? decadeTrait(int? year) {
  if (year == null) return null;
  final decade = (year ~/ 10) * 10;
  return trait(TraitKind.decade, decade.toString());
}
