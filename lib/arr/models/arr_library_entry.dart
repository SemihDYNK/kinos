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
