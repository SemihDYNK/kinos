import 'package:drift/drift.dart';

/// Durée de validité par défaut d'une entrée de cache — au-delà, elle
/// n'est plus affichée du tout (cf. `AppDatabase.getRecommendationCache`)
/// plutôt que montrée comme si elle était fraîche. Paramétrable (un
/// appelant peut passer une autre valeur) : cette constante n'est que le
/// défaut éditorial, pas une valeur gravée dans le calcul.
const defaultRecommendationCacheMaxAge = Duration(days: 7);

/// Les deux rangées de recommandation dont le contenu est mis en cache —
/// mêmes valeurs que `HomeRowType.forYou`/`.setAside`
/// (`lib/models/settings/home_row_model.dart`), dupliquées ici plutôt que
/// réutilisées : cette table ne doit rien connaître de la couche
/// providers/settings, même principe que le reste du module
/// recommandations ("le moteur ne touche pas à l'affichage").
///
/// Vit dans `lib/models/syncing/` (comme `playback_queue_table.dart`/
/// `palette_cache_table.dart`), pas dans `lib/recommendations/` : une
/// table Drift référencée depuis `database_item.dart` mais définie hors
/// de ce dossier n'a pas généré son code (`drift_dev` échouait à
/// résoudre `@DriftDatabase(tables: [...])`, silencieusement replié sur
/// une base sans aucune table) — constaté à l'implémentation, pas une
/// contrainte connue d'avance. La table reste inconnue du reste du
/// module recommandations (aucun fichier sous `lib/recommendations/` ne
/// l'importe), c'est seulement son fichier qui vit à côté de ses trois
/// tables sœurs pour que la génération fonctionne.
enum RecommendationRowKind { forYou, setAside }

/// D'où vient une entrée mise en cache — décide quelles colonnes
/// (`jellyfinItemId`/`jellyfinItemType` ou `arrId`/`arrService`) sont
/// renseignées. Même principe "l'un ou l'autre, jamais les deux" que
/// `CandidateSource`/`ArrLibraryEntry`.
enum RecommendationEntrySource { jellyfin, arr }

/// Version figée d'une entrée de rangée de recommandation, assez
/// complète pour être réaffichée sans aucun accès réseau — jaquette et
/// navigation reconstruites depuis le seul id (cf. le commentaire sur
/// [jellyfinItemId]), justification déjà traduite. Sert de repli affiché
/// le temps qu'un nouveau calcul aboutisse en arrière-plan (écrit et lu
/// via `AppDatabase.replaceRecommendationCache`/`getRecommendationCache`,
/// `database_item.dart`, branché sur `recommendationResultProvider` et
/// les rangées d'accueil — `recommendation_providers.dart`,
/// `recommendation_row_section.dart`), jamais de source de vérité :
/// entièrement remplacée à chaque calcul réussi, jamais mise à jour ligne
/// à ligne.
///
/// Scope utilisateur explicite ([userId], colonne, pas une valeur
/// implicite lue depuis `AppDatabase.userId`) : ce cache est strictement
/// par profil Jellyfin — afficher les recommandations d'un profil chez
/// un autre, même une fraction de seconde avant qu'un recalcul
/// n'aboutisse, est exactement la fuite entre profils que ce client
/// évite ailleurs. Un paramètre explicite à chaque appel rend cette
/// règle impossible à oublier à un site d'appel, et triviale à tester
/// (`AppDatabase` en général lit `userId` de façon ambiante via
/// `ref.read(userProvider...)`, ce qui aurait demandé de simuler toute
/// une session de connexion rien que pour vérifier l'étanchéité entre
/// deux profils).
@TableIndex(
    name: 'recommendation_cache_user_row',
    columns: {#userId, #rowKind, #position})
@DataClassName('RecommendationCacheEntry')
class RecommendationCacheEntries extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get userId => text().withLength(min: 1)();
  TextColumn get rowKind => textEnum<RecommendationRowKind>()();

  /// Rang dans la rangée (0 = premier) — l'ordre du calcul n'est pas
  /// autrement garanti par SQLite sans `ORDER BY` explicite sur cette
  /// colonne.
  IntColumn get position => integer()();

  TextColumn get source => textEnum<RecommendationEntrySource>()();

  /// Id Jellyfin — présent seulement si [source] est `jellyfin`. Seul
  /// nécessaire pour reconstruire à la fois la jaquette
  /// (`imageUtilityProvider.getItemsImageUrl(id)`, vérifié : aucun tag
  /// d'image requis) et la destination du clic — aucune donnée Jellyfin
  /// plus riche n'est persistée.
  TextColumn get jellyfinItemId => text().nullable()();

  /// `'movie'` ou `'series'` — présent seulement si [source] est
  /// `jellyfin`, nécessaire pour router le clic sans recharger l'item
  /// complet au préalable.
  TextColumn get jellyfinItemType => text().nullable()();

  /// Id Radarr/Sonarr — présent seulement si [source] est `arr`.
  IntColumn get arrId => integer().nullable()();

  /// `'radarr'` ou `'sonarr'` — présent seulement si [source] est
  /// `arr`. Pas d'URL de jaquette persistée ici : elle se reconstruit à
  /// la lecture avec les identifiants Arr *actuels* (cf.
  /// `resolveArrPosterUrl`) plutôt que de garder une clé API embarquée
  /// dans une URL sur disque, potentiellement périmée en plus d'y être
  /// exposée.
  TextColumn get arrService => text().nullable()();

  TextColumn get title => text().withLength(min: 1)();
  IntColumn get year => integer().nullable()();

  /// Déjà traduit et mis en forme (`justificationLabel`, cf.
  /// `justification_label.dart`) — une entrée figée n'a besoin d'aucune
  /// autre donnée du moteur (`TraitKey`, profil...) pour s'afficher.
  /// `null` : même règle que partout ailleurs, aucune justification
  /// affichée plutôt qu'un texte de remplacement.
  TextColumn get justification => text().nullable()();

  /// Horodatage du calcul qui a produit cette entrée — base de la durée
  /// de validité (cf. [defaultRecommendationCacheMaxAge] et
  /// `AppDatabase.getRecommendationCache`) : un cache trop vieux n'est
  /// plus affiché du tout plutôt que de montrer une recommandation
  /// obsolète comme si elle était fraîche.
  DateTimeColumn get capturedAt =>
      dateTime().withDefault(currentDateAndTime)();
}
