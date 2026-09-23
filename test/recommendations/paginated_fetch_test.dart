import 'package:flutter_test/flutter_test.dart';

import 'package:kinos/recommendations/engine/paginated_fetch.dart';

void main() {
  group('fetchAllPagesConcurrently', () {
    test('fetches a single page when the total fits in one page', () async {
      var callCount = 0;
      Future<PageResult<int>> fetchPage(
          {required int startIndex, required int limit}) async {
        callCount++;
        return (items: List.generate(50, (i) => i), totalRecordCount: 50);
      }

      final result = await fetchAllPagesConcurrently<int>(fetchPage);

      expect(result.items, hasLength(50));
      expect(result.pageCount, 1);
      expect(callCount, 1);
    });

    test('splits into pages of pageSize and fetches the rest', () async {
      const total = 450; // 3 pages of 200 (last one partial)
      Future<PageResult<int>> fetchPage(
          {required int startIndex, required int limit}) async {
        final items = List.generate(limit, (i) => startIndex + i)
            .where((i) => i < total)
            .toList();
        return (items: items, totalRecordCount: total);
      }

      final result = await fetchAllPagesConcurrently<int>(fetchPage,
          pageSize: 200, concurrency: 4);

      expect(result.items, List.generate(total, (i) => i));
      expect(result.pageCount, 3);
    });

    test('calls onFirstPage as soon as the first page resolves, once only',
        () async {
      const total = 600; // 3 pages
      final firstPageCalls = <List<int>>[];
      Future<PageResult<int>> fetchPage(
          {required int startIndex, required int limit}) async {
        // Les pages suivantes répondent plus lentement que la première —
        // vérifie que le rappel arrive bien avant la fin de la fusion
        // complète, pas seulement avant le retour de la fonction.
        await Future.delayed(Duration(milliseconds: startIndex == 0 ? 1 : 20));
        final items = List.generate(limit, (i) => startIndex + i)
            .where((i) => i < total)
            .toList();
        return (items: items, totalRecordCount: total);
      }

      final result = await fetchAllPagesConcurrently<int>(
        fetchPage,
        pageSize: 200,
        concurrency: 4,
        onFirstPage: firstPageCalls.add,
      );

      expect(firstPageCalls, hasLength(1));
      expect(firstPageCalls.single, List.generate(200, (i) => i));
      expect(result.items, hasLength(total));
    });

    test('merges pages in startIndex order regardless of completion order',
        () async {
      const total = 600; // 3 pages
      Future<PageResult<int>> fetchPage(
          {required int startIndex, required int limit}) async {
        // La page 200 répond plus vite que la page 400 — vérifie que la
        // fusion respecte l'ordre des pages, pas l'ordre d'arrivée.
        await Future.delayed(
            Duration(milliseconds: startIndex == 200 ? 5 : 30));
        final items = List.generate(limit, (i) => startIndex + i)
            .where((i) => i < total)
            .toList();
        return (items: items, totalRecordCount: total);
      }

      final result = await fetchAllPagesConcurrently<int>(fetchPage,
          pageSize: 200, concurrency: 4);

      expect(result.items, List.generate(total, (i) => i));
    });

    test('never exceeds the configured concurrency', () async {
      const total = 1000; // 5 pages of 200
      var inFlight = 0;
      var maxInFlight = 0;
      Future<PageResult<int>> fetchPage(
          {required int startIndex, required int limit}) async {
        inFlight++;
        maxInFlight = maxInFlight < inFlight ? inFlight : maxInFlight;
        await Future.delayed(const Duration(milliseconds: 15));
        inFlight--;
        final items = List.generate(limit, (i) => startIndex + i)
            .where((i) => i < total)
            .toList();
        return (items: items, totalRecordCount: total);
      }

      await fetchAllPagesConcurrently<int>(fetchPage,
          pageSize: 200, concurrency: 2);

      expect(maxInFlight, lessThanOrEqualTo(2));
    });

    test('retries a failing page once, succeeds on retry', () async {
      var attemptsAtStart200 = 0;
      Future<PageResult<int>> fetchPage(
          {required int startIndex, required int limit}) async {
        if (startIndex == 200) {
          attemptsAtStart200++;
          if (attemptsAtStart200 == 1) throw Exception('network blip');
        }
        final items = List.generate(limit, (i) => startIndex + i)
            .where((i) => i < 400)
            .toList();
        return (items: items, totalRecordCount: 400);
      }

      final result = await fetchAllPagesConcurrently<int>(fetchPage,
          pageSize: 200, concurrency: 4);

      expect(result.items, hasLength(400));
      expect(attemptsAtStart200, 2);
      expect(
        result.pageTimings.singleWhere((p) => p.startIndex == 200).retried,
        isTrue,
      );
    });

    test('throws PaginatedFetchException when a page fails twice in a row',
        () async {
      Future<PageResult<int>> fetchPage(
          {required int startIndex, required int limit}) async {
        if (startIndex == 200) throw Exception('server down');
        return (
          items: List.generate(limit, (i) => startIndex + i),
          totalRecordCount: 400
        );
      }

      expect(
        () => fetchAllPagesConcurrently<int>(fetchPage,
            pageSize: 200, concurrency: 4),
        throwsA(isA<PaginatedFetchException>()),
      );
    });

    test('reports the slowest page duration', () async {
      Future<PageResult<int>> fetchPage(
          {required int startIndex, required int limit}) async {
        await Future.delayed(Duration(milliseconds: startIndex == 0 ? 40 : 5));
        final items = List.generate(limit, (i) => startIndex + i)
            .where((i) => i < 400)
            .toList();
        return (items: items, totalRecordCount: 400);
      }

      final result = await fetchAllPagesConcurrently<int>(fetchPage,
          pageSize: 200, concurrency: 4);

      expect(
          result.slowestPageElapsed.inMilliseconds, greaterThanOrEqualTo(35));
    });
  });
}
