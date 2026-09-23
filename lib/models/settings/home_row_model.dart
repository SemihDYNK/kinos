import 'package:flutter/foundation.dart';

/// Type de source d'une rangée configurable de l'accueil. Toutes reposent
/// sur des requêtes `/Items` (ou `/Persons`, `/Items/{id}/Similar`) déjà
/// exposées par [JellyService] — aucun plugin serveur requis.
///
/// Exception : [forYou] et [setAside] (lot B du système de
/// recommandation) — leur contenu vient de `recommendationResultProvider`
/// (`lib/recommendations/`), pas d'une requête `/Items` filtrée. Ce sont
/// des types "système" au même titre que [topRated]/[unwatched] (pas de
/// paramètre, singuliers), mais leur rendu ne passe pas par
/// `homeRowItemsProvider`/`HomeRowSection` comme les autres — cf.
/// `dashboard_screen.dart`, qui les route vers `ForYouRowSection`/
/// `SetAsideRowSection` (`lib/screens/dashboard/recommendation_row_section.dart`).
/// Ils restent dans ce même modèle et ce même provider (`homeRowsProvider`)
/// pour hériter gratuitement de l'activation/désactivation et du
/// réordonnancement déjà en place.
///
/// Même exception, même raison, pour [tasteSeeds]/[catalogWellRated]/
/// [catalogNarrowGenres]/[catalogDecades]/[catalogLongFilms] (lot des
/// rangées par graine + inventaire du catalogue) — leur contenu vient de
/// `homeSeedRowsResultProvider`/`homeCatalogInventoryResultProvider`.
/// Chacun est un type par **catégorie**, pas
/// par instance : le nombre réel de rangées (graines retenues, genres
/// étroits, décennies) varie d'une session à l'autre selon le profil et
/// la bibliothèque, un `HomeRowModel` par instance dynamique n'aurait pas
/// de sens à persister. Activer/désactiver/réordonner porte donc sur la
/// catégorie entière ; [title] n'est alors utilisé que dans l'écran de
/// configuration, jamais affiché tel quel sur l'accueil (chaque
/// sous-rangée calcule son propre titre — œuvre source, nom du genre,
/// nom de la décennie...).
enum HomeRowType {
  genre,
  topRated,
  director,
  studio,
  unwatched,
  rediscover,
  decade,
  similar,
  collection,
  forYou,
  setAside,
  tasteSeeds,
  catalogWellRated,
  catalogNarrowGenres,
  catalogDecades,
  catalogLongFilms;

  /// Vrai si ce type a besoin d'un paramètre choisi par l'utilisateur
  /// (genre, personne, studio, décennie ou collection).
  bool get needsParam => switch (this) {
        HomeRowType.genre ||
        HomeRowType.director ||
        HomeRowType.studio ||
        HomeRowType.decade ||
        HomeRowType.collection =>
          true,
        HomeRowType.topRated ||
        HomeRowType.unwatched ||
        HomeRowType.rediscover ||
        HomeRowType.similar ||
        HomeRowType.forYou ||
        HomeRowType.setAside ||
        HomeRowType.tasteSeeds ||
        HomeRowType.catalogWellRated ||
        HomeRowType.catalogNarrowGenres ||
        HomeRowType.catalogDecades ||
        HomeRowType.catalogLongFilms =>
          false,
      };

  /// Libellé affiché dans l'écran de configuration.
  String get label => switch (this) {
        HomeRowType.genre => 'Genre',
        HomeRowType.topRated => 'Les mieux notés',
        HomeRowType.director => 'Réalisateur',
        HomeRowType.studio => 'Studio',
        HomeRowType.unwatched => 'Jamais vus',
        HomeRowType.rediscover => 'À redécouvrir',
        HomeRowType.decade => 'Décennie',
        HomeRowType.similar => 'Parce que vous avez aimé...',
        HomeRowType.collection => 'Collection',
        HomeRowType.forYou => 'Pour vous',
        HomeRowType.setAside => 'Vous l\'aviez mis de côté',
        HomeRowType.tasteSeeds => 'Rangées par graine',
        HomeRowType.catalogWellRated => 'Bien notés, jamais vus',
        HomeRowType.catalogNarrowGenres => 'Genres étroits',
        HomeRowType.catalogDecades => 'Décennies',
        HomeRowType.catalogLongFilms => 'Plus de 2h30',
      };

  /// Titre par défaut proposé pour une nouvelle rangée de ce type, en
  /// fonction du paramètre choisi (nom du genre, de la personne, etc.).
  String defaultTitle(String? paramLabel) => switch (this) {
        HomeRowType.genre => paramLabel ?? label,
        HomeRowType.director =>
          paramLabel != null ? 'Réalisé par $paramLabel' : label,
        HomeRowType.studio => paramLabel ?? label,
        HomeRowType.decade => paramLabel != null ? 'Les $paramLabel' : label,
        HomeRowType.collection => paramLabel ?? label,
        HomeRowType.topRated => 'Les mieux notés',
        HomeRowType.unwatched => 'Jamais vus',
        HomeRowType.rediscover => 'À redécouvrir',
        HomeRowType.similar => 'Parce que vous avez aimé...',
        HomeRowType.forYou => 'Pour vous',
        HomeRowType.setAside => 'Vous l\'aviez mis de côté',
        HomeRowType.tasteSeeds => 'Rangées par graine',
        HomeRowType.catalogWellRated => 'Bien notés, jamais vus',
        HomeRowType.catalogNarrowGenres => 'Genres étroits',
        HomeRowType.catalogDecades => 'Décennies',
        HomeRowType.catalogLongFilms => 'Plus de 2h30',
      };
}

/// Une rangée configurable de l'accueil.
///
/// Persisté en JSON dans la table `settings` (clé/valeur, lot 0) — pas de
/// nouvelle table Drift pour un simple tableau de préférences utilisateur.
@immutable
class HomeRowModel {
  final String id;
  final HomeRowType type;
  final String title;

  /// Paramètres bruts de la requête : `genreId`/`personId`/`studioId`/
  /// `boxSetId`/`decade` selon [type]. Volontairement un `Map<String,String>`
  /// plutôt qu'une classe par type — évite neuf sous-modèles pour un simple
  /// identifiant + son libellé d'affichage (`...Name`).
  final Map<String, String> params;

  final int order;
  final bool enabled;

  const HomeRowModel({
    required this.id,
    required this.type,
    required this.title,
    this.params = const {},
    required this.order,
    this.enabled = true,
  });

  HomeRowModel copyWith({
    String? title,
    Map<String, String>? params,
    int? order,
    bool? enabled,
  }) =>
      HomeRowModel(
        id: id,
        type: type,
        title: title ?? this.title,
        params: params ?? this.params,
        order: order ?? this.order,
        enabled: enabled ?? this.enabled,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type.name,
        'title': title,
        'params': params,
        'order': order,
        'enabled': enabled,
      };

  factory HomeRowModel.fromJson(Map<String, dynamic> json) => HomeRowModel(
        id: json['id'] as String,
        type: HomeRowType.values.firstWhere(
          (t) => t.name == json['type'],
          orElse: () => HomeRowType.unwatched,
        ),
        title: json['title'] as String? ?? '',
        params: Map<String, String>.from(json['params'] as Map? ?? const {}),
        order: json['order'] as int? ?? 0,
        enabled: json['enabled'] as bool? ?? true,
      );

  @override
  bool operator ==(Object other) =>
      other is HomeRowModel &&
      other.id == id &&
      other.type == type &&
      other.title == title &&
      other.order == order &&
      other.enabled == enabled &&
      mapEquals(other.params, params);

  @override
  int get hashCode => Object.hash(
        id,
        type,
        title,
        order,
        enabled,
        Object.hashAllUnordered(
            params.entries.map((e) => Object.hash(e.key, e.value))),
      );
}
