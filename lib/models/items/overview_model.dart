import 'package:dart_mappable/dart_mappable.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:kinos/jellyfin/jellyfin_open_api.swagger.dart';
import 'package:kinos/models/items/chapters_model.dart';
import 'package:kinos/models/items/item_shared_models.dart';
import 'package:kinos/models/items/trick_play_model.dart';
import 'package:kinos/util/duration_extensions.dart';

part 'overview_model.mapper.dart';

@MappableClass()
class OverviewModel with OverviewModelMappable {
  final Duration? runTime;
  final String summary;
  final int? yearAired;
  final DateTime? dateAdded;
  final String? parentalRating;
  final int? productionYear;
  final double? criticRating;
  final double? communityRating;
  final Map<String, TrickPlayModel>? trickPlayInfo;
  final List<Chapter>? chapters;
  final List<ExternalUrls>? externalUrls;
  final List<Studio> studios;
  final List<String> genres;
  final List<GenreItems> genreItems;
  final List<String> tags;
  final List<Person> people;
  final String? seerrUrl;

  /// Pays de production — affiché dans le panneau "Informations" de
  /// l'écran de détail.
  final List<String> productionLocations;

  /// Identifiants des fournisseurs de métadonnées externes tels que
  /// Jellyfin les porte (`ProviderIds`, ex. `{"Tmdb": "755898", "Imdb":
  /// "tt0092991"}`) — appariement exact avec Radarr/Sonarr (qui portent
  /// `tmdbId`/`imdbId`/`tvdbId`), cf. `arr_jellyfin_dedup.dart` : un
  /// identifiant partagé prime sur tout rapprochement de titre, sensible
  /// à la langue et à la notation (chiffres romains, articles...).
  /// N'est renseigné que si la requête a explicitement demandé
  /// `ItemFields.providerids` (même principe que `studios`/`people`/
  /// `tags` ci-dessus) — `null` sinon, pas une liste vide : distingue
  /// "non demandé" de "l'item n'a aucun identifiant".
  final Map<String, String>? providerIds;

  const OverviewModel({
    this.runTime,
    this.summary = "",
    this.yearAired,
    this.dateAdded,
    this.parentalRating,
    this.productionYear,
    this.criticRating,
    this.communityRating,
    this.trickPlayInfo,
    this.chapters,
    this.externalUrls,
    this.studios = const [],
    this.genres = const [],
    this.genreItems = const [],
    this.tags = const [],
    this.people = const [],
    this.seerrUrl,
    this.productionLocations = const [],
    this.providerIds,
  });

  /// Recherche insensible à la casse dans [providerIds] — Jellyfin utilise
  /// systématiquement une clé capitalisée ("Tmdb", "Imdb", "Tvdb"), mais
  /// rien ne garantit cette casse exacte selon la version du serveur ou
  /// le plugin de métadonnées.
  String? _providerId(String key) {
    final ids = providerIds;
    if (ids == null) return null;
    for (final entry in ids.entries) {
      if (entry.key.toLowerCase() == key) return entry.value;
    }
    return null;
  }

  String? get tmdbId => _providerId('tmdb');
  String? get imdbId => _providerId('imdb');
  String? get tvdbId => _providerId('tvdb');

  List<Person> get directors {
    return people
        .where((element) => element.type == PersonKind.director)
        .toList();
  }

  List<Person> get writers {
    return people
        .where((element) => element.type == PersonKind.writer)
        .toList();
  }

  factory OverviewModel.fromBaseItemDto(BaseItemDto item, Ref? ref) {
    final trickPlayItem = item.trickplay;
    return OverviewModel(
      runTime: item.runTimeDuration,
      yearAired: item.productionYear,
      parentalRating: item.officialRating,
      summary: item.overview ?? "",
      genres: item.genres ?? [],
      criticRating: item.criticRating,
      communityRating: item.communityRating,
      tags: item.tags ?? [],
      dateAdded: item.dateCreated,
      trickPlayInfo: trickPlayItem != null && trickPlayItem.isNotEmpty
          ? TrickPlayModel.toTrickPlayMap(trickPlayItem)
          : null,
      chapters: (ref != null && item.id != null)
          ? Chapter.chaptersFromInfo(item.id ?? "", item.chapters ?? [], ref)
          : null,
      studios: item.studios
              ?.map((e) => Studio(id: e.id ?? "", name: e.name ?? ""))
              .toList() ??
          [],
      genreItems: item.genreItems
              ?.map((e) => GenreItems(id: e.id ?? "", name: e.name ?? ""))
              .toList() ??
          [],
      externalUrls: ExternalUrls.fromDto(item.externalUrls ?? []),
      people: ref != null
          ? Person.peopleFromDto(item.people ?? [], ref)
          : <Person>[],
      productionLocations: item.productionLocations ?? [],
      providerIds: item.providerIds
          ?.map((key, value) => MapEntry(key, value.toString())),
    );
  }
}
