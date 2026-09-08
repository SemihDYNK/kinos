import 'package:flutter_test/flutter_test.dart';

import 'package:fladder/arr/models/arr_queue_item.dart';

void main() {
  group('ArrQueueStatus.fromApi', () {
    test('trackedDownloadStatus error always wins, regardless of status', () {
      expect(
        ArrQueueStatus.fromApi(
          status: 'completed',
          trackedDownloadStatus: 'error',
          trackedDownloadState: 'imported',
        ),
        ArrQueueStatus.failed,
      );
    });

    test('trackedDownloadStatus warning wins over a "completed" status', () {
      // Le cas signalé par l'utilisateur : un téléchargement "terminé"
      // mais bloqué à l'import est un avertissement, pas un succès.
      expect(
        ArrQueueStatus.fromApi(
          status: 'completed',
          trackedDownloadStatus: 'warning',
          trackedDownloadState: 'importPending',
        ),
        ArrQueueStatus.warning,
      );
    });

    test('trackedDownloadState imported maps to completed', () {
      expect(
        ArrQueueStatus.fromApi(
          status: 'downloading',
          trackedDownloadStatus: 'ok',
          trackedDownloadState: 'imported',
        ),
        ArrQueueStatus.completed,
      );
    });

    test('trackedDownloadState importPending maps to importing', () {
      expect(
        ArrQueueStatus.fromApi(
          status: 'completed',
          trackedDownloadStatus: 'ok',
          trackedDownloadState: 'importPending',
        ),
        ArrQueueStatus.importing,
      );
    });

    test('falls back to the raw status when tracking fields are absent', () {
      expect(
        ArrQueueStatus.fromApi(
            status: 'downloading',
            trackedDownloadStatus: null,
            trackedDownloadState: null),
        ArrQueueStatus.downloading,
      );
      expect(
        ArrQueueStatus.fromApi(
            status: 'paused',
            trackedDownloadStatus: null,
            trackedDownloadState: null),
        ArrQueueStatus.paused,
      );
    });

    test('unknown/missing status defaults to queued rather than throwing', () {
      expect(
        ArrQueueStatus.fromApi(
            status: null,
            trackedDownloadStatus: null,
            trackedDownloadState: null),
        ArrQueueStatus.queued,
      );
    });
  });

  group('ArrQueueItem.fromJson', () {
    test('parses a typical downloading item', () {
      final item = ArrQueueItem.fromJson({
        'id': 42,
        'title': 'Movie.Title.2024.1080p.BluRay-GROUP',
        'size': 4294967296,
        'sizeleft': 1073741824,
        'timeleft': '00:12:34',
        'indexer': 'SomeIndexer',
        'quality': {
          'quality': {'id': 7, 'name': 'Bluray-1080p'},
        },
        'customFormatScore': 50,
        'status': 'downloading',
        'trackedDownloadStatus': 'ok',
        'trackedDownloadState': 'downloading',
        'protocol': 'torrent',
      });

      expect(item.id, 42);
      expect(item.title, 'Movie.Title.2024.1080p.BluRay-GROUP');
      expect(item.size, 4294967296);
      expect(item.sizeLeft, 1073741824);
      expect(item.timeLeft, '00:12:34');
      expect(item.indexer, 'SomeIndexer');
      expect(item.qualityName, 'Bluray-1080p');
      expect(item.customFormatScore, 50);
      expect(item.status, ArrQueueStatus.downloading);
      expect(item.protocol, 'torrent');
      // (4294967296 - 1073741824) / 4294967296 = 0.75
      expect(item.progress, closeTo(0.75, 0.001));
    });

    test('progress is null when the total size is unknown', () {
      final item = ArrQueueItem.fromJson({
        'id': 1,
        'title': 'X',
        'status': 'queued',
      });

      expect(item.size, isNull);
      expect(item.progress, isNull);
    });

    test('progress clamps to 1.0 rather than exceeding it', () {
      // sizeleft > size ne devrait jamais arriver, mais un serveur
      // incohérent ne doit pas produire une progression négative ou
      // supérieure à 100%.
      final item = ArrQueueItem.fromJson({
        'id': 1,
        'title': 'X',
        'size': 100,
        'sizeleft': 150,
      });

      expect(item.progress, 0.0);
    });

    test('collects statusMessages from every group', () {
      final item = ArrQueueItem.fromJson({
        'id': 1,
        'title': 'X',
        'statusMessages': [
          {
            'title': 'Movie.Title',
            'messages': ['Not a preferred word', 'Sample'],
          },
          {
            'title': 'Other',
            'messages': ['Second group message'],
          },
        ],
      });

      expect(item.statusMessages,
          ['Not a preferred word', 'Sample', 'Second group message']);
    });

    test('tolerates missing optional fields without throwing', () {
      final item = ArrQueueItem.fromJson(const {});

      expect(item.id, 0);
      expect(item.title, '');
      expect(item.size, isNull);
      expect(item.qualityName, isNull);
      expect(item.status, ArrQueueStatus.queued);
      expect(item.statusMessages, isEmpty);
      expect(item.errorMessage, isNull);
      expect(item.protocol, '');
    });
  });
}
