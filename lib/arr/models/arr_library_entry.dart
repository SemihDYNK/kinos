import 'package:fladder/arr/models/arr_library_item.dart';

/// Film ou série choisi dans la recherche bibliothèque — l'un des deux
/// champs est renseigné, jamais les deux (cf. les constructeurs nommés).
class ArrLibraryEntry {
  final ArrMovie? movie;
  final ArrSeries? series;

  const ArrLibraryEntry.movie(this.movie) : series = null;

  const ArrLibraryEntry.series(this.series) : movie = null;

  bool get isMovie => movie != null;
  String get title => movie?.title ?? series!.title;
  int? get year => movie?.year ?? series?.year;
}
