import 'package:flutter_test/flutter_test.dart';

import 'package:kinos/arr/providers/arr_library_providers.dart';

void main() {
  group('ArrLibraryViewNotifier', () {
    test('defaults to "added", descending — most recent first', () {
      final notifier = ArrLibraryViewNotifier();
      expect(notifier.state.sort, ArrLibrarySort.added);
      expect(notifier.state.ascending, isFalse);
    });

    test('switching criterion falls back to that criterion\'s own default', () {
      final notifier = ArrLibraryViewNotifier();

      notifier.setSort(ArrLibrarySort.title);
      // Un titre part alphabétique (croissant) par défaut, jamais le sens
      // hérité du critère précédent (date, décroissant par défaut).
      expect(notifier.state.ascending, isTrue);

      notifier.setSort(ArrLibrarySort.year);
      expect(notifier.state.ascending, isFalse);
    });

    test(
        'the direction chosen for one criterion is remembered independently '
        'of the others', () {
      final notifier = ArrLibraryViewNotifier();

      // Date d'ajout : décroissant par défaut — on le bascule en croissant.
      notifier.toggleDirection();
      expect(notifier.state.ascending, isTrue);

      // Titre : reste sur son propre défaut (croissant), pas affecté par
      // la bascule sur "Date d'ajout" plus haut.
      notifier.setSort(ArrLibrarySort.title);
      expect(notifier.state.ascending, isTrue);
      notifier.toggleDirection();
      expect(notifier.state.ascending, isFalse);

      // Revenir à "Date d'ajout" retrouve le sens qu'on lui avait donné
      // (croissant), pas son défaut d'origine (décroissant) ni celui que
      // "Titre" vient de prendre.
      notifier.setSort(ArrLibrarySort.added);
      expect(notifier.state.ascending, isTrue);
    });

    test('setFilter changes the filter without touching sort state', () {
      final notifier = ArrLibraryViewNotifier();
      notifier.setSort(ArrLibrarySort.title);
      notifier.toggleDirection();

      notifier.setFilter(ArrLibraryFilter.monitored);

      expect(notifier.state.filter, ArrLibraryFilter.monitored);
      expect(notifier.state.sort, ArrLibrarySort.title);
      expect(notifier.state.ascending, isFalse);
    });
  });
}
