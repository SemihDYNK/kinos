import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kinos/l10n/generated/app_localizations.dart';
import 'package:kinos/models/items/media_streams_model.dart';
import 'package:kinos/screens/details_screens/components/media_stream_selectors.dart';

void main() {
  testWidgets('exposes subtitle search from the movie track controls',
      (tester) async {
    var openedSearch = false;
    final streams = MediaStreamsModel(
      defaultSubStreamIndex: 0,
      versionStreams: [
        VersionStreamModel(
          name: 'Version',
          index: 0,
          defaultAudioStreamIndex: null,
          defaultSubStreamIndex: 0,
          videoStreams: const [],
          audioStreams: const [],
          subStreams: [
            SubStreamModel(
              name: 'Français',
              id: 'subtitle-1',
              title: 'Français',
              displayTitle: 'Français',
              language: 'French',
              codec: 'srt',
              isDefault: true,
              isExternal: false,
              index: 0,
            ),
          ],
        ),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: MediaStreamSelectors(
            mediaStream: streams,
            onChanged: (_) {},
            onSearchSubtitles: () => openedSearch = true,
          ),
        ),
      ),
    );

    await tester.tap(find.byIcon(Icons.search_rounded));

    expect(openedSearch, isTrue);
  });

  testWidgets('exposes subtitle search when the movie has no subtitles',
      (tester) async {
    var openedSearch = false;
    final streams = MediaStreamsModel(
      defaultSubStreamIndex: -1,
      versionStreams: [
        VersionStreamModel(
          name: 'Version',
          index: 0,
          defaultAudioStreamIndex: null,
          defaultSubStreamIndex: -1,
          videoStreams: const [],
          audioStreams: const [],
          subStreams: const [],
        ),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: MediaStreamSelectors(
            mediaStream: streams,
            onChanged: (_) {},
            onSearchSubtitles: () => openedSearch = true,
          ),
        ),
      ),
    );

    await tester.tap(find.byIcon(Icons.search_rounded));

    expect(openedSearch, isTrue);
  });
}
