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

    test('parses a realistic Sonarr record (series/episode, not movie)', () {
      // Forme réelle d'un enregistrement Sonarr : `seriesId`/`episodeId`
      // et des objets `series`/`episode` imbriqués là où Radarr porte
      // `movieId`/`movie` — aucun de ces champs n'est lu par
      // ArrQueueItem.fromJson, mais leur seule présence ne doit ni faire
      // planter le parsing ni être confondue avec les champs communs.
      final item = ArrQueueItem.fromJson({
        'id': 7,
        'seriesId': 12,
        'episodeId': 345,
        'series': {
          'id': 12,
          'title': 'Some Series',
          'seasonCount': 3,
        },
        'episode': {
          'id': 345,
          'seasonNumber': 2,
          'episodeNumber': 5,
          'title': 'Episode Title',
        },
        'title': 'Some.Series.S02E05.1080p.WEB-DL-GROUP',
        'size': 1073741824,
        'sizeleft': 268435456,
        'timeleft': '00:05:00',
        'indexer': 'SomeIndexer',
        'quality': {
          'quality': {'id': 4, 'name': 'WEBDL-1080p'},
        },
        'customFormatScore': 0,
        'status': 'downloading',
        'trackedDownloadStatus': 'ok',
        'trackedDownloadState': 'downloading',
        'protocol': 'usenet',
      });

      expect(item.id, 7);
      expect(item.title, 'Some.Series.S02E05.1080p.WEB-DL-GROUP');
      expect(item.qualityName, 'WEBDL-1080p');
      expect(item.status, ArrQueueStatus.downloading);
      expect(item.protocol, 'usenet');
      expect(item.progress, closeTo(0.75, 0.001));
    });

    test('a field with an unexpected type degrades instead of throwing', () {
      // Ex. un id renvoyé en `double` plutôt qu'`int` (arrive avec
      // certains décodeurs JSON/proxys) : ne doit jamais faire échouer
      // la ligne entière, seulement ce champ précis.
      expect(
        () => ArrQueueItem.fromJson({
          'id': 42.0,
          'title': 123,
          'size': 'unknown',
          'quality': {
            'quality': {'name': 99},
          },
        }),
        returnsNormally,
      );

      final item = ArrQueueItem.fromJson({
        'id': 42.0,
        'title': 123,
        'size': 'unknown',
        'quality': {
          'quality': {'name': 99},
        },
      });
      expect(item.id, 42);
      expect(item.title, ''); // 123 n'est pas une String : repli.
      expect(item.size, isNull); // 'unknown' n'est pas un nombre : repli.
      expect(item.qualityName, isNull); // 99 n'est pas une String : repli.
    });
  });

  group('ArrQueueGroup.groupItems', () {
    Map<String, dynamic> sonarrEpisode({
      required int id,
      required int episodeNumber,
    }) =>
        {
          'id': id,
          'seriesId': 12,
          'episodeId': 1000 + episodeNumber,
          'series': {'id': 12, 'title': 'Some Series'},
          'episode': {
            'id': 1000 + episodeNumber,
            'seasonNumber': 3,
            'episodeNumber': episodeNumber,
            'title': 'Episode $episodeNumber',
          },
          'title': 'Some.Series.S03E${episodeNumber.toString().padLeft(2, '0')}'
              '.1080p.WEB-DL-GROUP',
          // Répétés à l'identique sur chaque épisode par Sonarr — le
          // paquet entier fait 13 Go, pas 13 Go par épisode.
          'downloadId': 'ABCDEF0123456789',
          'size': 13000000000,
          'sizeleft': 0,
          'timeleft': '00:00:00',
          'indexer': 'SomeIndexer',
          'quality': {
            'quality': {'id': 4, 'name': 'WEBDL-1080p'},
          },
          'status': 'completed',
          'trackedDownloadStatus': 'ok',
          'trackedDownloadState': 'imported',
          'protocol': 'torrent',
        };

    test(
        'un paquet de saison de 11 épisodes ne fait qu\'un seul groupe, '
        'sans multiplier la taille', () {
      // Cas rapporté : 11 lignes identiques à 13 Go chacune, soit 143 Go
      // affichés au lieu de 13 Go — reproduit ici avec un vrai payload
      // Sonarr de paquet de saison (même downloadId sur les 11 lignes).
      final items = [
        for (var i = 1; i <= 11; i++)
          ArrQueueItem.fromJson(sonarrEpisode(id: i, episodeNumber: i)),
      ];

      final groups = ArrQueueGroup.groupItems(items);

      expect(groups, hasLength(1));
      final group = groups.single;
      expect(group.isGrouped, isTrue);
      expect(group.episodeCount, 11);
      expect(group.size, 13000000000); // Pas 11 × 13 Go.
      expect(group.groupLabel, 'S03 · 11 épisodes');
      expect(group.downloadId, 'ABCDEF0123456789');
    });

    test('des lignes sans downloadId partagé restent des groupes séparés', () {
      final movie = ArrQueueItem.fromJson({
        'id': 99,
        'title': 'Some.Movie.2024.1080p.BluRay-GROUP',
        'downloadId': 'ZZZZ9999',
        'size': 4000000000,
      });
      final episodes = [
        for (var i = 1; i <= 3; i++)
          ArrQueueItem.fromJson(sonarrEpisode(id: i, episodeNumber: i)),
      ];

      final groups = ArrQueueGroup.groupItems([movie, ...episodes]);

      expect(groups, hasLength(2));
      expect(groups.first.isGrouped, isFalse);
      expect(groups.first.id, 99);
      expect(groups.last.isGrouped, isTrue);
      expect(groups.last.episodeCount, 3);
    });

    test('une ligne sans downloadId reste son propre groupe, jamais fusionnée',
        () {
      final withoutId = ArrQueueItem.fromJson({'id': 1, 'title': 'A'});
      final alsoWithoutId = ArrQueueItem.fromJson({'id': 2, 'title': 'B'});

      final groups = ArrQueueGroup.groupItems([withoutId, alsoWithoutId]);

      expect(groups, hasLength(2));
      expect(groups.every((g) => !g.isGrouped), isTrue);
    });
  });
}
