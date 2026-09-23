import 'package:flutter_test/flutter_test.dart';

import 'package:kinos/recommendations/engine/home_registry.dart';

void main() {
  group('reserveIds', () {
    test('keeps only the first reserve items, in order', () {
      final ids = reserveIds(['a', 'b', 'c', 'd', 'e'], (s) => s, reserve: 3);

      expect(ids, {'a', 'b', 'c'});
    });

    test('reserves at most reserve even if fewer items exist', () {
      final ids = reserveIds(['a', 'b'], (s) => s, reserve: 8);

      expect(ids, {'a', 'b'});
    });
  });

  group('excludeKnown', () {
    test('filters out items whose id is already in the registry', () {
      final result = excludeKnown(['a', 'b', 'c'], (s) => s, {'b'});

      expect(result, ['a', 'c']);
    });

    test('registry empty — nothing excluded', () {
      final result = excludeKnown(['a', 'b'], (s) => s, {});

      expect(result, ['a', 'b']);
    });

    test('preserves original order', () {
      final result = excludeKnown(['z', 'a', 'm'], (s) => s, {'a'});

      expect(result, ['z', 'm']);
    });
  });
}
