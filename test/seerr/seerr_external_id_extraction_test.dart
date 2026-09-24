import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:kinos/seerr/seerr_models.dart';

/// tmdbId/tvdbId live on SeerrMediaInfo, imdbId (+ social ids, unused here)
/// on the separate SeerrExternalIds - there's no single "extraction"
/// function to unit test, so these decode fixtures directly through each
/// model's fromJson, the same as the converter does internally. This is
/// the ground truth the future AniList ID-mapping work (see CLAUDE.md
/// roadmap) will read from, so partial/absent/ambiguous shapes matter here
/// specifically, not just "does it decode".
Map<String, dynamic> _json(String raw) => jsonDecode(raw) as Map<String, dynamic>;

void main() {
  group('SeerrMediaInfo — tmdbId/tvdbId extraction', () {
    test('both present', () {
      final info = SeerrMediaInfo.fromJson(_json('{"tmdbId": 603692, "tvdbId": 371572}'));
      expect(info.tmdbId, 603692);
      expect(info.tvdbId, 371572);
    });

    test('only tmdbId present (movie): tvdbId is null, not 0 or missing-'
        'crash', () {
      final info = SeerrMediaInfo.fromJson(_json('{"tmdbId": 603692}'));
      expect(info.tmdbId, 603692);
      expect(info.tvdbId, isNull);
    });

    test('only tvdbId present (tv): tmdbId is null', () {
      final info = SeerrMediaInfo.fromJson(_json('{"tvdbId": 371572}'));
      expect(info.tmdbId, isNull);
      expect(info.tvdbId, 371572);
    });

    test('neither present: both null, not a crash', () {
      final info = SeerrMediaInfo.fromJson(_json('{"id": 1}'));
      expect(info.tmdbId, isNull);
      expect(info.tvdbId, isNull);
    });

    test('tmdbId given as a numeric string (ambiguous type, e.g. a proxy '
        'or an API version that stringifies ids): currently throws rather '
        'than coercing - same class of unsafe-cast issue as the converter '
        'bug (no `checked: true` in build.yaml), but at the raw fromJson '
        'level rather than through SeerrJsonConverter', () {
      expect(
        () => SeerrMediaInfo.fromJson(_json('{"tmdbId": "603692"}')),
        throwsA(isA<TypeError>()),
      );
    });

    test('tvdbId given as a double (e.g. 371572.0 from a JS-originated '
        'payload): decodes and coerces cleanly to an int - unlike a '
        'wrong-type field elsewhere, generated int? fields are read as '
        '`(json[key] as num?)?.toInt()` (seerr_models.g.dart), not `as '
        'int?`, so num/double/int are all accepted interchangeably here',
        () {
      final info = SeerrMediaInfo.fromJson(_json('{"tvdbId": 371572.0}'));
      expect(info.tvdbId, 371572);
    });
  });

  group('SeerrExternalIds — imdbId extraction', () {
    test('all four ids present', () {
      final ids = SeerrExternalIds.fromJson(_json(
        '{"imdbId": "tt10366206", "facebookId": "fb1", "instagramId": "ig1", "twitterId": "tw1"}',
      ));
      expect(ids.imdbId, 'tt10366206');
      expect(ids.facebookId, 'fb1');
    });

    test('only imdbId present, the rest null (the common case - Jellyseerr '
        'only reliably populates imdbId)', () {
      final ids = SeerrExternalIds.fromJson(_json('{"imdbId": "tt10366206"}'));
      expect(ids.imdbId, 'tt10366206');
      expect(ids.facebookId, isNull);
      expect(ids.instagramId, isNull);
      expect(ids.twitterId, isNull);
    });

    test('imdbId explicitly null in the payload (Jellyseerr sends this for '
        'media TMDB has no IMDb mapping for): null, not the string "null"',
        () {
      final ids = SeerrExternalIds.fromJson(_json('{"imdbId": null}'));
      expect(ids.imdbId, isNull);
    });

    test('completely empty object: all four null, not a crash', () {
      final ids = SeerrExternalIds.fromJson(_json('{}'));
      expect(ids.imdbId, isNull);
    });

    test('imdbId given as a number instead of a string (ambiguous type): '
        'currently throws', () {
      expect(
        () => SeerrExternalIds.fromJson(_json('{"imdbId": 10366206}')),
        throwsA(isA<TypeError>()),
      );
    });
  });

  group('SeerrMovieDetails/SeerrTvDetails — externalIds is nested and '
      'optional', () {
    test('movie details with externalIds present: imdbId reachable via '
        'body.externalIds?.imdbId', () {
      final details = SeerrMovieDetails.fromJson(_json(
        '{"id": 603692, "title": "X", "externalIds": {"imdbId": "tt10366206"}}',
      ));
      expect(details.externalIds?.imdbId, 'tt10366206');
    });

    test('movie details with no externalIds key at all: externalIds is '
        'null, not a crash reading .imdbId off it (must use ?.)', () {
      final details = SeerrMovieDetails.fromJson(_json('{"id": 603692, "title": "X"}'));
      expect(details.externalIds, isNull);
      expect(details.externalIds?.imdbId, isNull);
    });
  });
}
