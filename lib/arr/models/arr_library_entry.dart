import 'package:kinos/arr/models/arr_library_item.dart';

/// Film ou série choisi dans la recherche bibliothèque — l'un des deux
/// champs est renseigné, jamais les deux (cf. les constructeurs nommés).
/// Porte aussi les champs d'affichage communs aux deux (jaquette, statut,
/// qualité...), pour que l'écran de recherche n'ait pas à distinguer les
/// deux cas partout.
class ArrLibraryEntry {
  final ArrMovie? movie;
  final ArrSeries? series;

  const ArrLibraryEntry.movie(this.movie) : series = null;

  const ArrLibraryEntry.series(this.series) : movie = null;

  bool get isMovie => movie != null;
  int get id => movie?.id ?? series!.id;
  String get title => movie?.title ?? series!.title;
  int? get year => movie?.year ?? series?.year;
  DateTime? get added => movie?.added ?? series?.added;
  String? get posterUrl => movie?.posterUrl ?? series?.posterUrl;
  bool get monitored => movie?.monitored ?? series?.monitored ?? false;

  Map<String, dynamic> get _raw => movie?.raw ?? series!.raw;

  /// Identifiants de fournisseurs externes, tels que Radarr/Sonarr les
  /// exposent au premier niveau de la ressource brute — appariement
  /// exact avec Jellyfin (`OverviewModel.tmdbId`/`imdbId`/`tvdbId`, cf.
  /// `arr_jellyfin_dedup.dart`), prioritaire sur tout rapprochement de
  /// titre. Radarr porte `tmdbId` (entier) et souvent `imdbId` ; Sonarr
  /// n'a pas d'équivalent TMDB natif (métadonnées TheTVDB) mais porte
  /// `tvdbId` et souvent `imdbId` — les trois canaux sont donc utiles
  /// selon le type d'entrée, jamais tous renseignés à la fois.
  String? get tmdbId =>
      _raw['tmdbId'] is int ? (_raw['tmdbId'] as int).toString() : null;
  String? get imdbId {
    final value = _raw['imdbId'];
    return value is String && value.isNotEmpty ? value : null;
  }

  String? get tvdbId =>
      _raw['tvdbId'] is int ? (_raw['tvdbId'] as int).toString() : null;

  /// Un fichier existe (film) ou au moins un épisode est présent (série) —
  /// sans être forcément complet, cf. [isComplete].
  bool get hasContent =>
      movie?.hasFile ?? ((series?.episodeFileCount ?? 0) > 0);

  /// Le film est présent, ou tous les épisodes surveillés de la série le
  /// sont.
  bool get isComplete {
    if (isMovie) return movie!.hasFile;
    final series = this.series!;
    return series.episodeCount > 0 &&
        series.episodeFileCount >= series.episodeCount;
  }

  /// Qualité du fichier déjà présent — films uniquement, une série n'a pas
  /// de qualité unique (elle varie par épisode).
  String? get qualityName => movie?.qualityName;

  int? get seasonCount => series?.seasonCount;

  /// "Dans la bibliothèque" / "Manquant" / "Non surveillé" — dans cet
  /// ordre de priorité : un item non surveillé reste non surveillé même
  /// s'il a déjà du contenu (téléchargé avant d'être désactivé).
  String get statusLabel {
    if (!monitored) return 'Non surveillé';
    if (isComplete) return 'Dans la bibliothèque';
    if (hasContent) return 'Partiellement présent';
    return 'Manquant';
  }
}
