import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:kinos/providers/seerr_service_provider.dart';
import 'package:kinos/seerr/seerr_chopper_service.dart';
import 'package:kinos/seerr/seerr_models.dart';

/// posterFromDiscoverItem / _resolveMediaType (seerr_service_provider.dart)
/// are pure given a SeerrDiscoverItem - they never touch `ref` or `_api` on
/// this path. `ref` and `_api` still need real (never-invoked) instances to
/// satisfy SeerrService's constructor; SeerrChopperService.create() with no
/// client and a throwaway Ref are both inert for this test.
SeerrService _service() {
  final container = ProviderContainer();
  addTearDown(container.dispose);
  final ref = container.read(Provider<Ref>((ref) => ref));
  return SeerrService(ref, SeerrChopperService.create());
}

void main() {
  group('SeerrService.posterFromDiscoverItem — media type resolution', () {
    test('explicit mediaType movie wins, even with tvdbId present in '
        'mediaInfo (explicit field always takes priority over inference)',
        () {
      final poster = _service().posterFromDiscoverItem(SeerrDiscoverItem(
        id: 1,
        mediaType: SeerrMediaType.movie,
        title: 'A Movie',
        mediaInfo: SeerrMediaInfo(tvdbId: 999),
      ));

      expect(poster?.type, SeerrMediaType.movie);
    });

    test('explicit mediaType tvshow wins', () {
      final poster = _service().posterFromDiscoverItem(SeerrDiscoverItem(
        id: 1,
        mediaType: SeerrMediaType.tvshow,
        name: 'A Show',
      ));

      expect(poster?.type, SeerrMediaType.tvshow);
    });

    test('mediaType person: no poster at all (people are not requestable '
        'media, filtered out entirely rather than mapped to a broken '
        'poster)', () {
      final poster = _service().posterFromDiscoverItem(SeerrDiscoverItem(
        id: 1,
        mediaType: SeerrMediaType.person,
        name: 'An Actor',
      ));

      expect(poster, isNull);
    });

    test('mediaType null, mediaInfo.tvdbId present: inferred as tvshow',
        () {
      final poster = _service().posterFromDiscoverItem(SeerrDiscoverItem(
        id: 1,
        name: 'Inferred Show',
        mediaInfo: SeerrMediaInfo(tvdbId: 371572),
      ));

      expect(poster?.type, SeerrMediaType.tvshow);
    });

    test('mediaType null, mediaInfo.tmdbId present (no tvdbId): inferred '
        'as movie', () {
      final poster = _service().posterFromDiscoverItem(SeerrDiscoverItem(
        id: 1,
        title: 'Inferred Movie',
        mediaInfo: SeerrMediaInfo(tmdbId: 603692),
      ));

      expect(poster?.type, SeerrMediaType.movie);
    });

    test('mediaType null, mediaInfo null: ambiguous, no poster (this is '
        'the case a search-results endpoint returning bare discover items '
        'without mediaInfo would hit)', () {
      final poster = _service().posterFromDiscoverItem(SeerrDiscoverItem(
        id: 1,
        title: 'No Info At All',
      ));

      expect(poster, isNull);
    });

    test('mediaType null, mediaInfo present but both tmdbId and tvdbId '
        'null: still ambiguous, no poster', () {
      final poster = _service().posterFromDiscoverItem(SeerrDiscoverItem(
        id: 1,
        title: 'Empty MediaInfo',
        mediaInfo: SeerrMediaInfo(id: 4821),
      ));

      expect(poster, isNull);
    });
  });

  group('SeerrService.posterFromDiscoverItem — title/id/year selection', () {
    test('movie: title falls back title -> originalTitle -> name in that '
        'order', () {
      final poster = _service().posterFromDiscoverItem(SeerrDiscoverItem(
        id: 1,
        mediaType: SeerrMediaType.movie,
        originalTitle: 'Le Titre Original',
        name: 'Should Never Be Used For A Movie',
      ));

      expect(poster?.title, 'Le Titre Original');
    });

    test('tvshow: title falls back name -> originalName -> title in that '
        'order', () {
      final poster = _service().posterFromDiscoverItem(SeerrDiscoverItem(
        id: 1,
        mediaType: SeerrMediaType.tvshow,
        originalName: 'Original Show Name',
        title: 'Should Never Be Used For A TV Show',
      ));

      expect(poster?.title, 'Original Show Name');
    });

    test('tmdbId comes from item.id when present, mediaInfo.tmdbId is a '
        'fallback only used when item.id is absent', () {
      final poster = _service().posterFromDiscoverItem(SeerrDiscoverItem(
        id: 603692,
        mediaType: SeerrMediaType.movie,
        title: 'X',
        mediaInfo: SeerrMediaInfo(tmdbId: 999999),
      ));

      expect(poster?.tmdbId, 603692);
    });

    test('releaseYear is the year slice of releaseDate for a movie', () {
      final poster = _service().posterFromDiscoverItem(SeerrDiscoverItem(
        id: 1,
        mediaType: SeerrMediaType.movie,
        title: 'X',
        releaseDate: '2023-03-24',
      ));

      expect(poster?.releaseYear, '2023');
    });

    test('releaseYear is the year slice of firstAirDate for a tvshow, not '
        'releaseDate', () {
      final poster = _service().posterFromDiscoverItem(SeerrDiscoverItem(
        id: 1,
        mediaType: SeerrMediaType.tvshow,
        name: 'X',
        firstAirDate: '2022-08-21',
        releaseDate: '1999-01-01', // present but must be ignored for a tvshow
      ));

      expect(poster?.releaseYear, '2022');
    });

    test('an empty-string release date does not produce a bogus '
        'releaseYear', () {
      final poster = _service().posterFromDiscoverItem(SeerrDiscoverItem(
        id: 1,
        mediaType: SeerrMediaType.movie,
        title: 'X',
        releaseDate: '',
      ));

      expect(poster?.releaseYear, isNull);
    });
  });
}
