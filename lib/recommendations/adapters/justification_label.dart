import 'package:kinos/recommendations/models/trait.dart';

/// Traductions de mots-clés TMDb connus pour apparaître comme
/// justification — l'API ne renvoie ces mots-clés qu'en anglais (cf.
/// spec du lot B). Liste de démarrage, pas exhaustive — un mot-clé
/// absent d'ici retombe sur une mise en forme de l'anglais d'origine
/// (cf. [justificationLabel]) plutôt que de bloquer l'affichage.
const defaultKeywordTranslations = {
  'neo-noir': 'Thriller néo-noir',
  'film noir': 'Film noir',
  'based on novel or book': 'Adapté d\'un roman',
  'based on novel': 'Adapté d\'un roman',
  'based on true story': 'Inspiré de faits réels',
  'based on comic': 'Adapté d\'un comic',
  'superhero': 'Super-héros',
  'time travel': 'Voyage dans le temps',
  'artificial intelligence': 'Intelligence artificielle',
  'post-apocalyptic': 'Post-apocalyptique',
  'dystopia': 'Dystopie',
  'space opera': 'Space opera',
  'space travel': 'Voyage spatial',
  'coming of age': 'Passage à l\'âge adulte',
  'revenge': 'Vengeance',
  'heist': 'Casse',
  'martial arts': 'Arts martiaux',
  'sequel': 'Suite',
  'anti hero': 'Anti-héros',
  'psychological thriller': 'Thriller psychologique',
  'serial killer': 'Tueur en série',
  'kidnapping': 'Enlèvement',
  'undercover': 'Infiltration',
  'spy': 'Espionnage',
  'world war ii': 'Seconde Guerre mondiale',
  'zombie': 'Zombies',
  'monster': 'Monstres',
  'alien': 'Extraterrestres',
  'sword and sorcery': 'Fantasy épique',
  'live action and animation': 'Animation et prises de vue réelles',
};

/// Justification affichable en français d'un trait — cf. spec du lot B :
/// "Parce que vous avez regardé X" pour un réalisateur ou un acteur,
/// "Thriller néo-noir" pour un mot-clé. `null` en entrée -> `null` en
/// sortie (aucune justification crédible, cf. `RecommendationScorer` —
/// ne jamais afficher de texte de remplacement à la place).
///
/// Un mot-clé absent de [keywordTranslations] retombe aussi sur `null`,
/// jamais sur une mise en forme de l'anglais d'origine : un dictionnaire
/// exhaustif de tous les mots-clés TMDb n'est pas réaliste (des
/// centaines de valeurs possibles, cf. [defaultKeywordTranslations],
/// une liste de démarrage), et un libellé anglais brut irait contre la
/// même règle que "aucune justification crédible" — mieux vaut une
/// jaquette sans justification qu'une justification illisible pour
/// l'utilisateur visé.
String? justificationLabel(
  TraitKey? trait, {
  Map<String, String> keywordTranslations = defaultKeywordTranslations,
}) {
  if (trait == null) return null;
  final name = _titleCase(trait.value);
  return switch (trait.kind) {
    TraitKind.director ||
    TraitKind.actor =>
      'Parce que vous avez regardé $name',
    TraitKind.studio => 'Produit par $name',
    TraitKind.decade => 'Des années ${trait.value}',
    TraitKind.genre => name,
    TraitKind.keyword => keywordTranslations[trait.value],
  };
}

/// Mise en forme de secours pour un nom/mot-clé sans casse propre — les
/// [TraitKey] sont normalisés en minuscules pour la comparaison (cf.
/// `lib/recommendations/models/trait.dart`), la casse d'origine n'est
/// pas conservée. Une majuscule par mot est une approximation
/// raisonnable pour la plupart des noms ("denis villeneuve" -> "Denis
/// Villeneuve"), imparfaite pour des cas particuliers (particules,
/// apostrophes) — accepté plutôt que de faire remonter la casse
/// d'origine jusqu'ici (changerait le modèle du moteur pour un seul
/// besoin d'affichage).
/// Titre d'une rangée par graine — cf. spec du lot : le titre vient de
/// l'œuvre vue qui a le plus contribué à ce trait
/// ([sourceEventForTrait] dans `taste_profile_builder.dart`), jamais du
/// nom du trait lui-même ("Car vous avez aimé Skyfall", pas "james
/// bond").
String seedRowTitle(String sourceTitle) => 'Car vous avez aimé $sourceTitle';

String _titleCase(String value) => value
    .split(' ')
    .map((word) =>
        word.isEmpty ? word : word[0].toUpperCase() + word.substring(1))
    .join(' ');
