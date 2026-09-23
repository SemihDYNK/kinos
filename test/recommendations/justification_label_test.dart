import 'package:flutter_test/flutter_test.dart';

import 'package:kinos/recommendations/adapters/justification_label.dart';
import 'package:kinos/recommendations/models/trait.dart';

void main() {
  test('null trait produces null label — never a placeholder', () {
    expect(justificationLabel(null), isNull);
  });

  test('director/actor use "Parce que vous avez regardé X", title-cased', () {
    expect(
      justificationLabel(trait(TraitKind.director, 'Denis Villeneuve')),
      'Parce que vous avez regardé Denis Villeneuve',
    );
    expect(
      justificationLabel(trait(TraitKind.actor, 'Timothée Chalamet')),
      'Parce que vous avez regardé Timothée Chalamet',
    );
  });

  test('studio uses "Produit par X"', () {
    expect(
      justificationLabel(trait(TraitKind.studio, 'A24')),
      'Produit par A24',
    );
  });

  test('decade reads "Des années XXXX"', () {
    expect(
      justificationLabel(trait(TraitKind.decade, '1990')),
      'Des années 1990',
    );
  });

  test('genre is shown title-cased, with no framing phrase', () {
    expect(
      justificationLabel(trait(TraitKind.genre, 'science fiction')),
      'Science Fiction',
    );
  });

  test('a known keyword is translated to a natural French phrase', () {
    expect(
      justificationLabel(trait(TraitKind.keyword, 'neo-noir')),
      'Thriller néo-noir',
    );
    expect(
      justificationLabel(trait(TraitKind.keyword, 'space opera')),
      'Space opera',
    );
  });

  test(
      'an unknown keyword produces no justification — never a raw English label',
      () {
    expect(
      justificationLabel(trait(TraitKind.keyword, 'a made up keyword')),
      isNull,
    );
  });

  test('a custom translation map overrides the defaults', () {
    expect(
      justificationLabel(
        trait(TraitKind.keyword, 'heist'),
        keywordTranslations: const {'heist': 'Braquage'},
      ),
      'Braquage',
    );
  });
}
