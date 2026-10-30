import 'package:flutter_test/flutter_test.dart';
import 'package:kinos/models/items/chapters_model.dart';
import 'package:kinos/models/items/media_segments_model.dart';
import 'package:kinos/screens/video_player/components/active_skip_segment.dart';

Chapter chapter(String name, int seconds) => Chapter(
    name: name, imageUrl: '', startPosition: Duration(seconds: seconds));

void main() {
  final chapters = [
    chapter('Intro', 0),
    chapter('Episode', 90),
    chapter('Credits', 1260)
  ];
  MediaSegment? at(int seconds,
          {MediaSegmentsModel? server,
          List<Chapter>? source,
          int duration = 1370}) =>
      activeSkipSegment(
          serverSegments: server,
          chapters: source ?? chapters,
          position: Duration(seconds: seconds),
          duration: Duration(seconds: duration));

  test('Intro and Credits use chapter boundaries; Episode remains untouched',
      () {
    expect(at(30)?.type, MediaSegmentType.intro);
    expect(at(30)?.end, const Duration(seconds: 90));
    expect(at(90), isNull);
    expect(at(900), isNull);
    expect(at(1300)?.type, MediaSegmentType.outro);
    expect(at(1300)?.end, const Duration(seconds: 1370));
    expect(at(1370), isNull);
    expect(at(-1), isNull);
  });

  test('native timing takes priority, including outside its interval', () {
    final intro = MediaSegment(
        type: MediaSegmentType.intro,
        start: const Duration(seconds: 10),
        end: const Duration(seconds: 75));
    final server = MediaSegmentsModel(segments: [intro]);
    expect(at(30, server: server), same(intro));
    expect(at(5, server: server), isNull);
    expect(at(75, server: server), isNull);
    expect(at(80, server: server), isNull);
    expect(at(1300, server: server)?.type, MediaSegmentType.outro);
  });

  test('a native recap wins over an overlapping Intro chapter', () {
    final recap = MediaSegment(
        type: MediaSegmentType.recap,
        start: const Duration(seconds: 20),
        end: const Duration(seconds: 40));
    expect(at(30, server: MediaSegmentsModel(segments: [recap])), same(recap));
  });

  test('ordinary and ambiguous chapter names never skip episode content', () {
    for (final name in [
      'Chapter 1',
      'Episode',
      'Opening scene',
      'Credits scene',
      'Optional',
      'Chapter 01'
    ]) {
      expect(at(30, source: [chapter(name, 0), chapter('Episode', 90)]), isNull,
          reason: name);
    }
    expect(
        at(30, source: [chapter('Intro', 0), chapter('Episode', 0)]), isNull);
  });

  test('last chapter needs a known duration and cannot seek beyond the runtime',
      () {
    expect(at(1300, duration: 0), isNull);
    expect(at(30, source: [chapter('Intro', 0)], duration: 0), isNull);
    expect(at(30, duration: 0)?.end, const Duration(seconds: 90));
    expect(
        at(30,
                source: [chapter('Intro', 0), chapter('Episode', 200)],
                duration: 100)
            ?.end,
        const Duration(seconds: 100));
  });

  test('sorting metadata does not mutate the source chapter list', () {
    final source = [chapter('Episode', 90), chapter('Intro', 0)];
    expect(at(30, source: source)?.end, const Duration(seconds: 90));
    expect(source.first.name, 'Episode');
  });

  test('explicit international labels and whitespace are recognized', () {
    for (final name in [' INTRO ', 'Opening', 'OP', 'Générique de début']) {
      expect(at(30, source: [chapter(name, 0), chapter('Episode', 90)])?.type,
          MediaSegmentType.intro,
          reason: name);
    }
    for (final name in [
      'Credits',
      'Credit',
      'Crédits',
      'Crédit',
      'Outro',
      'Ending',
      'ED',
      'End credits',
      'Générique de fin'
    ]) {
      expect(at(30, source: [chapter(name, 0)])?.type, MediaSegmentType.outro,
          reason: name);
    }
  });
}
