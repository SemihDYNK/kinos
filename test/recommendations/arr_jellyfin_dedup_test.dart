import 'package:flutter_test/flutter_test.dart';

import 'package:kinos/recommendations/engine/arr_jellyfin_dedup.dart';
import 'package:kinos/recommendations/models/candidate_item.dart';

CandidateItem _arrCandidate(String title, {int? year}) => CandidateItem(
      id: 'arr:movie:${title.hashCode}',
      title: title,
      traits: const [],
      source: CandidateSource.arrOnly,
      year: year,
    );

void main() {
  test('excludes an Arr candidate whose title and year match a known Jellyfin work',
      () {
    final result = excludeArrCandidatesKnownToJellyfin(
      [_arrCandidate('Quantum of Solace', year: 2008)],
      [(title: 'Quantum of Solace', year: 2008)],
    );

    expect(result, isEmpty);
  });

  test('is case- and whitespace-insensitive on the title', () {
    final result = excludeArrCandidatesKnownToJellyfin(
      [_arrCandidate('  Quantum Of Solace  ', year: 2008)],
      [(title: 'quantum of solace', year: 2008)],
    );

    expect(result, isEmpty);
  });

  test('keeps a candidate whose title does not match anything known', () {
    final result = excludeArrCandidatesKnownToJellyfin(
      [_arrCandidate('A Totally Different Film', year: 2020)],
      [(title: 'Quantum of Solace', year: 2008)],
    );

    expect(result, hasLength(1));
  });

  test('years more than a year apart are treated as distinct works, not excluded',
      () {
    final result = excludeArrCandidatesKnownToJellyfin(
      [_arrCandidate('Same Title', year: 1975)],
      [(title: 'Same Title', year: 2020)],
    );

    expect(result, hasLength(1),
        reason: 'un remake sous le même titre ne doit pas être escamoté');
  });

  test('a one-year gap still counts as the same work (release vs. digital year drift)',
      () {
    final result = excludeArrCandidatesKnownToJellyfin(
      [_arrCandidate('Same Title', year: 2019)],
      [(title: 'Same Title', year: 2020)],
    );

    expect(result, isEmpty);
  });

  test('matching title but missing year on either side excludes by caution', () {
    final missingOnArrSide = excludeArrCandidatesKnownToJellyfin(
      [_arrCandidate('Mystery Movie', year: null)],
      [(title: 'Mystery Movie', year: 2010)],
    );
    final missingOnJellyfinSide = excludeArrCandidatesKnownToJellyfin(
      [_arrCandidate('Mystery Movie', year: 2010)],
      [(title: 'Mystery Movie', year: null)],
    );

    expect(missingOnArrSide, isEmpty);
    expect(missingOnJellyfinSide, isEmpty);
  });

  test('an empty list of known Jellyfin works excludes nothing', () {
    final result = excludeArrCandidatesKnownToJellyfin(
      [_arrCandidate('Anything', year: 2000)],
      const [],
    );

    expect(result, hasLength(1));
  });

  test('only the matching candidate is removed, others in the list are kept',
      () {
    final result = excludeArrCandidatesKnownToJellyfin(
      [
        _arrCandidate('Quantum of Solace', year: 2008),
        _arrCandidate('Skyfall', year: 2012),
      ],
      [(title: 'Quantum of Solace', year: 2008)],
    );

    expect(result.map((c) => c.title), ['Skyfall']);
  });

  group('findKnownJellyfinMatch', () {
    test('finds the matching catalog item on title and year', () {
      final match = findKnownJellyfinMatch(
        'Quantum of Solace',
        2008,
        ['Casino Royale:2006', 'Quantum of Solace:2008'],
        titleOf: (e) => e.split(':').first,
        yearOf: (e) => int.parse(e.split(':').last),
      );

      expect(match, 'Quantum of Solace:2008');
    });

    test('is case- and whitespace-insensitive, same rule as the bulk exclusion',
        () {
      final match = findKnownJellyfinMatch(
        '  Quantum Of Solace  ',
        2008,
        ['quantum of solace:2008'],
        titleOf: (e) => e.split(':').first,
        yearOf: (e) => int.parse(e.split(':').last),
      );

      expect(match, isNotNull);
    });

    test('returns null when no title matches', () {
      final match = findKnownJellyfinMatch(
        'Spectre',
        2015,
        ['Skyfall:2012'],
        titleOf: (e) => e.split(':').first,
        yearOf: (e) => int.parse(e.split(':').last),
      );

      expect(match, isNull);
    });

    test('years more than a year apart are treated as distinct works', () {
      final match = findKnownJellyfinMatch(
        'Same Title',
        2000,
        ['Same Title:2010'],
        titleOf: (e) => e.split(':').first,
        yearOf: (e) => int.parse(e.split(':').last),
      );

      expect(match, isNull);
    });

    test(
        'an external id match wins even when the title would not have matched '
        'at all — the actual bug reported (Evil Dead II vs. Evil Dead 2, plus a '
        'completely unrelated Jellyfin title)', () {
      final match = findKnownJellyfinMatch(
        'Evil Dead II',
        1987,
        ['Something Else Entirely:tmdb789'],
        titleOf: (e) => e.split(':').first,
        yearOf: (e) => null,
        externalIds: (tmdbId: '789', imdbId: null, tvdbId: null),
        externalIdsOf: (e) => (
          tmdbId: e.split(':').last.replaceFirst('tmdb', ''),
          imdbId: null,
          tvdbId: null,
        ),
      );

      expect(match, 'Something Else Entirely:tmdb789');
    });

    test('external ids are tried before falling back to the title', () {
      var titleWasChecked = false;
      final match = findKnownJellyfinMatch(
        'Evil Dead II',
        1987,
        ['irrelevant'],
        titleOf: (e) {
          titleWasChecked = true;
          return e;
        },
        yearOf: (e) => null,
        externalIds: (tmdbId: '789', imdbId: null, tvdbId: null),
        externalIdsOf: (e) => (tmdbId: '789', imdbId: null, tvdbId: null),
      );

      expect(match, 'irrelevant');
      expect(titleWasChecked, isFalse,
          reason: 'un identifiant trouvé ne devrait jamais nécessiter le repli');
    });

    test('falls back to the title when neither side has an external id', () {
      final match = findKnownJellyfinMatch(
        'Quantum of Solace',
        2008,
        ['Quantum of Solace:2008'],
        titleOf: (e) => e.split(':').first,
        yearOf: (e) => int.parse(e.split(':').last),
        externalIds: (tmdbId: null, imdbId: null, tvdbId: null),
        externalIdsOf: (e) => (tmdbId: null, imdbId: null, tvdbId: null),
      );

      expect(match, isNotNull);
    });

    test('falls back to the original title when the display title differs',
        () {
      final match = findKnownJellyfinMatch(
        'Le Fabuleux Destin d\'Amélie Poulain',
        2001,
        [(title: 'Amelie', original: 'Le Fabuleux Destin d\'Amélie Poulain')],
        titleOf: (e) => e.title,
        yearOf: (e) => 2001,
        originalTitleOf: (e) => e.original,
      );

      expect(match, isNotNull);
    });

    test(
        'a Jellyfin item with no providerIds and an Arr entry with no imdbId '
        'still match on title, without crashing — regression demandée', () {
      final match = findKnownJellyfinMatch(
        'Quantum of Solace',
        2008,
        [(title: 'Quantum of Solace', tmdbId: null, imdbId: null, tvdbId: null)],
        titleOf: (e) => e.title,
        yearOf: (e) => 2008,
        // Cas courant : aucun ProviderIds côté Jellyfin (champ non
        // demandé, ou métadonnées absentes) et pas d'imdbId côté Radarr
        // (souvent absent) — tous les champs sont `null` des deux côtés,
        // pas seulement l'un d'eux.
        externalIds: (tmdbId: null, imdbId: null, tvdbId: null),
        externalIdsOf: (e) =>
            (tmdbId: e.tmdbId, imdbId: e.imdbId, tvdbId: e.tvdbId),
      );

      expect(match, isNotNull);
    });

    test(
        'does not crash on a title with an uppercase accented letter — la '
        'régression réelle (pas les champs d\'identifiant : `_stripDiacritics` '
        'réindexait avec la casse d\'origine au lieu de la minuscule)', () {
      expect(
        () => findKnownJellyfinMatch(
          'À Bout De Souffle',
          1960,
          ['À Bout De Souffle:1960'],
          titleOf: (e) => e.split(':').first,
          yearOf: (e) => int.parse(e.split(':').last),
        ),
        returnsNormally,
      );
    });
  });

  group('normalizeTitleForMatching', () {
    test('strips accents', () {
      expect(normalizeTitleForMatching('Amélie'), normalizeTitleForMatching('Amelie'));
    });

    test(
        'strips an uppercase accented letter without crashing — régression : '
        '`_stripDiacritics` réindexait `_diacriticsMap` avec la casse '
        'd\'origine ("É") au lieu de sa forme minuscule ("é"), la seule '
        'présente dans la table, d\'où un `!` sur `null`', () {
      expect(normalizeTitleForMatching('À Bout De Souffle'),
          normalizeTitleForMatching('a bout de souffle'));
      expect(normalizeTitleForMatching('ÉLITE'), normalizeTitleForMatching('elite'));
    });

    test('strips punctuation without gluing words together', () {
      expect(normalizeTitleForMatching('Spider-Man: Homecoming'),
          isNot(contains('spiderman')));
      expect(normalizeTitleForMatching('Spider-Man: Homecoming'),
          normalizeTitleForMatching('Spider Man Homecoming'));
    });

    test('drops a leading article, French or English', () {
      expect(normalizeTitleForMatching('The Batman'),
          normalizeTitleForMatching('Batman'));
      expect(normalizeTitleForMatching('Le Fabuleux Destin'),
          normalizeTitleForMatching('Fabuleux Destin'));
      expect(normalizeTitleForMatching('L\'Auberge espagnole'),
          normalizeTitleForMatching('Auberge espagnole'));
    });

    test('converts a trailing roman numeral to arabic — the reported bug',
        () {
      expect(normalizeTitleForMatching('Evil Dead II'),
          normalizeTitleForMatching('Evil Dead 2'));
      expect(normalizeTitleForMatching('Rocky IV'),
          normalizeTitleForMatching('Rocky 4'));
    });

    test('does not touch a roman numeral in the middle of a title', () {
      expect(normalizeTitleForMatching('Evil Dead II Rises'),
          isNot(normalizeTitleForMatching('Evil Dead 2 Rises')));
    });

    test('never confuses two genuinely different titles', () {
      expect(normalizeTitleForMatching('Batman'),
          isNot(normalizeTitleForMatching('Batman Returns')));
    });
  });
}
