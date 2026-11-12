import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kinos/models/items/episode_model.dart';
import 'package:kinos/models/items/item_shared_models.dart';
import 'package:kinos/models/items/media_streams_model.dart';
import 'package:kinos/models/items/overview_model.dart';
import 'package:kinos/models/syncing/database_item.dart';
import 'package:kinos/playback/series_track_preferences.dart';
import 'package:kinos/providers/database_provider.dart';
import 'package:kinos/providers/user_provider.dart';

import '../widgets/seerr_discovery_section_test.dart' show TestUser;

AudioStreamModel audio(int index, String language,
        {String title = '', bool isDefault = false}) =>
    AudioStreamModel(
        displayTitle: title,
        name: title,
        codec: 'aac',
        isDefault: isDefault,
        isExternal: false,
        index: index,
        language: language,
        channelLayout: 'stereo',
        sampleRate: null,
        channels: 2,
        bitRate: null,
        bitDepth: null,
        profile: null,
        spatialFormat: null);

SubStreamModel sub(int index, String language,
        {bool forced = false, bool hearingImpaired = false}) =>
    SubStreamModel(
        name: language,
        id: '$index',
        title: language,
        displayTitle: language,
        language: language,
        codec: 'srt',
        isDefault: false,
        isExternal: false,
        index: index,
        isForced: forced,
        isHearingImpaired: hearingImpaired);

/// Épisode typique d'un anime : VF par défaut, VO japonaise, sous-titres
/// français complets et forcés.
MediaStreamsModel streams({int? audioIndex = 1, int? subIndex = -1}) =>
    MediaStreamsModel(
      versionStreamIndex: 0,
      defaultAudioStreamIndex: audioIndex,
      defaultSubStreamIndex: subIndex,
      versionStreams: [
        VersionStreamModel(
          name: 'v',
          index: 0,
          defaultAudioStreamIndex: 1,
          defaultSubStreamIndex: -1,
          videoStreams: const [],
          audioStreams: [
            audio(1, 'fre', isDefault: true),
            audio(2, 'jpn', title: 'Commentaire'),
            audio(3, 'jpn'),
          ],
          subStreams: [
            sub(4, 'fre', forced: true),
            sub(5, 'fra'),
            sub(6, 'eng'),
          ],
        )
      ],
    );

EpisodeModel episode(String seriesId, MediaStreamsModel streams) =>
    EpisodeModel(
      seriesName: 'Série',
      season: 1,
      episode: 1,
      episodeEnd: null,
      name: 'Épisode',
      id: 'ep',
      overview: const OverviewModel(),
      parentId: seriesId,
      playlistId: null,
      images: null,
      childCount: null,
      primaryRatio: null,
      userData: const UserData(),
      parentImages: null,
      mediaStreams: streams,
    );

void main() {
  group('choosing tracks', () {
    test('audio prefers the main track of the language over a commentary', () {
      expect(
          preferredAudioIndex(const SeriesTrackPreference(audioLanguage: 'jpn'),
              streams().audioStreams),
          3);
    });

    test('language codes match across their forms', () {
      expect(
          preferredAudioIndex(const SeriesTrackPreference(audioLanguage: 'fra'),
              streams().audioStreams),
          1);
      expect(
          preferredSubIndex(
              const SeriesTrackPreference(subtitleLanguage: 'fre'),
              streams().subStreams),
          5);
    });

    test('subtitles keep their forced kind, or stay off', () {
      expect(
          preferredSubIndex(
              const SeriesTrackPreference(
                  subtitleLanguage: 'fre', subtitleForced: true),
              streams().subStreams),
          4);
      expect(
          preferredSubIndex(const SeriesTrackPreference(subtitlesOff: true),
              streams().subStreams),
          -1);
    });

    test('a language the episode lacks leaves its defaults alone', () {
      final result = applySeriesTracks(
          streams(), const SeriesTrackPreference(audioLanguage: 'kor'));
      expect(result.defaultAudioStreamIndex, 1);
      expect(result.defaultSubStreamIndex, -1);
    });
  });

  group('remembering tracks', () {
    test('current tracks become the series preference', () {
      final pref =
          preferenceFromStreams(streams(audioIndex: 3, subIndex: 5), null);
      expect(
          pref,
          const SeriesTrackPreference(
              audioLanguage: 'jpn', subtitleLanguage: 'fra'));
    });

    test('a track without language keeps the previous choice', () {
      final unknown = MediaStreamsModel(
          versionStreamIndex: 0,
          defaultAudioStreamIndex: 7,
          defaultSubStreamIndex: -1,
          versionStreams: [
            VersionStreamModel(
                name: 'v',
                index: 0,
                defaultAudioStreamIndex: 7,
                defaultSubStreamIndex: -1,
                videoStreams: const [],
                audioStreams: [audio(7, 'und')],
                subStreams: const [])
          ]);
      final pref = preferenceFromStreams(
          unknown, const SeriesTrackPreference(audioLanguage: 'jpn'));
      expect(pref.audioLanguage, 'jpn');
      expect(pref.subtitlesOff, isTrue);
    });

    test('stored per series and profile, then forgotten', () async {
      final container = ProviderContainer(overrides: [
        userProvider.overrideWith(TestUser.new),
        appDatabaseProvider
            .overrideWith((ref) => AppDatabase(ref, NativeDatabase.memory())),
      ]);
      addTearDown(container.dispose);
      final tracks = container.read(seriesTracksProvider);

      await tracks.remember(episode('dbz', streams(audioIndex: 3, subIndex: 5)),
          streams(audioIndex: 3, subIndex: 5));
      expect((await tracks.read('dbz'))?.audioLanguage, 'jpn');
      expect(await tracks.read('slow-horses'), isNull);

      final defaults =
          await tracks.defaultsFor(episode('dbz', streams()), streams());
      expect(defaults, (audio: 3, sub: 5));

      (container.read(userProvider.notifier) as TestUser).change('b');
      expect(await tracks.read('dbz'), isNull);
      (container.read(userProvider.notifier) as TestUser).change('a');

      await tracks.forget('dbz');
      expect(await tracks.read('dbz'), isNull);
      expect(await tracks.defaultsFor(episode('dbz', streams()), streams()),
          isNull);
    });
  });
}
