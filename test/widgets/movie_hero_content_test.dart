import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kinos/jellyfin/jellyfin_open_api.swagger.dart' as dto;
import 'package:kinos/models/items/media_streams_model.dart';
import 'package:kinos/screens/details_screens/components/movie_hero_content.dart';
import 'package:kinos/widgets/shared/frosted_surface.dart';
import 'seerr_discovery_section_test.dart' show shell;

void main() {
  testWidgets('movie glass track bar keeps keyboard selection and callback',
      (tester) async {
    final streams =
        MediaStreamsModel(defaultAudioStreamIndex: 0, versionStreams: [
      VersionStreamModel(
          name: 'HD',
          index: 0,
          defaultAudioStreamIndex: 0,
          defaultSubStreamIndex: null,
          videoStreams: [],
          subStreams: [],
          audioStreams: [
            AudioStreamModel.fromMediaStream(const dto.MediaStream(
                index: 0, language: 'fra', codec: 'aac', channels: 2)),
            AudioStreamModel.fromMediaStream(const dto.MediaStream(
                index: 1, language: 'eng', codec: 'aac', channels: 2)),
          ]),
    ]);
    MediaStreamsModel? changed;
    await tester.pumpWidget(ProviderScope(
        child: shell(SliverToBoxAdapter(
            child: MovieHeroContent(
      summary: 'Le synopsis reste dans le bandeau.',
      streams: streams,
      onStreamsChanged: (value) => changed = value,
    )))));
    await tester.pumpAndSettle();
    expect(find.byType(FrostedSurface), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(changed?.defaultAudioStreamIndex, 1);
    expect(streams.defaultAudioStreamIndex, 0);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });
}
