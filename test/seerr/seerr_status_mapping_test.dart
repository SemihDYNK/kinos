import 'package:flutter_test/flutter_test.dart';

import 'package:kinos/models/seerr/seerr_dashboard_model.dart';

void main() {
  group('SeerrRequestStatus.fromRaw', () {
    const cases = {
      1: SeerrRequestStatus.pending,
      2: SeerrRequestStatus.approved,
      3: SeerrRequestStatus.declined,
      4: SeerrRequestStatus.failed,
      5: SeerrRequestStatus.completed,
    };

    for (final entry in cases.entries) {
      test('maps raw ${entry.key} to ${entry.value}', () {
        expect(SeerrRequestStatus.fromRaw(entry.key), entry.value);
      });
    }

    test('null maps to unknown', () {
      expect(SeerrRequestStatus.fromRaw(null), SeerrRequestStatus.unknown);
    });

    test('0 (never a real Jellyseerr/Overseerr value) maps to unknown', () {
      expect(SeerrRequestStatus.fromRaw(0), SeerrRequestStatus.unknown);
    });

    test('an out-of-range value (future API addition) maps to unknown, '
        'not a crash', () {
      expect(SeerrRequestStatus.fromRaw(99), SeerrRequestStatus.unknown);
    });

    test('isKnown is false only for unknown', () {
      expect(SeerrRequestStatus.unknown.isKnown, isFalse);
      for (final status in cases.values) {
        expect(status.isKnown, isTrue, reason: '$status should be known');
      }
    });
  });

  group('SeerrMediaStatus.fromRaw', () {
    const cases = {
      1: SeerrMediaStatus.unknown,
      2: SeerrMediaStatus.pending,
      3: SeerrMediaStatus.processing,
      4: SeerrMediaStatus.partiallyAvailable,
      5: SeerrMediaStatus.available,
      6: SeerrMediaStatus.blacklisted,
      7: SeerrMediaStatus.deleted,
    };

    for (final entry in cases.entries) {
      test('maps raw ${entry.key} to ${entry.value}', () {
        expect(SeerrMediaStatus.fromRaw(entry.key), entry.value);
      });
    }

    test('null maps to unknown', () {
      expect(SeerrMediaStatus.fromRaw(null), SeerrMediaStatus.unknown);
    });

    test('0 maps to unknown', () {
      expect(SeerrMediaStatus.fromRaw(0), SeerrMediaStatus.unknown);
    });

    test('an out-of-range value maps to unknown, not a crash', () {
      expect(SeerrMediaStatus.fromRaw(42), SeerrMediaStatus.unknown);
    });

    test('isKnown is false for both raw 1 and a missing value - both decode '
        'to SeerrMediaStatus.unknown, so isKnown cannot tell "explicitly '
        'unknown from the server" apart from "absent/malformed" (documents '
        'current behavior, not a bug: Jellyseerr/Overseerr\'s raw value 1 IS '
        'literally named UNKNOWN server-side too)', () {
      expect(SeerrMediaStatus.fromRaw(1).isKnown, isFalse);
      expect(SeerrMediaStatus.fromRaw(null).isKnown, isFalse);
    });
  });
}
