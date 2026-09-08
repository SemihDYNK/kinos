import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:kinos/l10n/generated/app_localizations.dart';
import 'package:kinos/localization_delegates.dart';
import 'package:kinos/models/items/media_streams_model.dart';
import 'package:kinos/util/localization_helper.dart';
import 'package:kinos/widgets/shared/track_label.dart';

void main() {
  group('formatChannelLayout', () {
    test('passes through a plain channel layout unchanged', () {
      expect(formatChannelLayout('5.1'), '5.1');
      expect(formatChannelLayout('7.1'), '7.1');
    });

    test('strips a parenthetical suffix', () {
      expect(formatChannelLayout('5.1(side)'), '5.1');
    });

    test('normalizes mono/stereo to numeric layouts', () {
      expect(formatChannelLayout('stereo'), '2.0');
      expect(formatChannelLayout('mono'), '1.0');
    });

    test('returns null for an empty layout', () {
      expect(formatChannelLayout(''), isNull);
      expect(formatChannelLayout('   '), isNull);
    });
  });

  group('formatCodecName', () {
    test('maps known audio codecs to their display name', () {
      expect(formatCodecName('eac3'), 'E-AC3');
      expect(formatCodecName('AC3'), 'AC3');
      expect(formatCodecName('truehd'), 'TrueHD');
      expect(formatCodecName('dts'), 'DTS');
    });

    test('maps known subtitle containers to their display name', () {
      expect(formatCodecName('subrip'), 'SRT');
      expect(formatCodecName('pgssub'), 'PGS');
      expect(formatCodecName('ass'), 'ASS');
    });

    test('falls back to an uppercased code for an unknown value', () {
      expect(formatCodecName('mystery_codec'), 'MYSTERY_CODEC');
    });

    test('returns null for an empty codec', () {
      expect(formatCodecName(''), isNull);
    });
  });

  group('formatAudioTrackLabel / formatSubtitleTrackLabel', () {
    Future<void> withContext(
        WidgetTester tester, void Function(BuildContext context) body) async {
      await tester.pumpWidget(MaterialApp(
        localizationsDelegates: KinosLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(builder: (context) {
          body(context);
          return const SizedBox.shrink();
        }),
      ));
      await tester.pumpAndSettle();
    }

    testWidgets(
        'audio track: langue, canaux et codec en ligne principale, "Par défaut" en secondaire',
        (tester) async {
      await withContext(tester, (context) {
        final stream = AudioStreamModel(
          displayTitle: 'Fre - AC3 - 5.1 - Default',
          name: '',
          codec: 'eac3',
          isDefault: true,
          isExternal: false,
          index: 1,
          language: 'fre',
          channelLayout: '5.1',
          sampleRate: null,
          channels: 6,
          bitRate: null,
          bitDepth: null,
          profile: null,
          spatialFormat: null,
        );
        final info = formatAudioTrackLabel(context, stream);
        expect(info.primary, 'Français · 5.1 · E-AC3');
        expect(info.secondaryFlags, ['Par défaut']);
      });
    });

    testWidgets('audio track: pas de "Par défaut" quand ce n\'est pas le cas',
        (tester) async {
      await withContext(tester, (context) {
        final stream = AudioStreamModel(
          displayTitle: '',
          name: '',
          codec: 'aac',
          isDefault: false,
          isExternal: false,
          index: 2,
          language: 'eng',
          channelLayout: 'stereo',
          sampleRate: null,
          channels: 2,
          bitRate: null,
          bitDepth: null,
          profile: null,
          spatialFormat: null,
        );
        final info = formatAudioTrackLabel(context, stream);
        expect(info.primary, 'Anglais · 2.0 · AAC');
        expect(info.secondaryFlags, isEmpty);
      });
    });

    testWidgets(
        'subtitle track: seuls les drapeaux qui s\'appliquent apparaissent',
        (tester) async {
      await withContext(tester, (context) {
        final stream = SubStreamModel(
          name: '',
          id: '1',
          title: '',
          displayTitle: '',
          language: 'fre',
          codec: 'subrip',
          isDefault: false,
          isExternal: false,
          index: 3,
          isForced: true,
          isHearingImpaired: false,
        );
        final info = formatSubtitleTrackLabel(context, stream);
        expect(info.primary, 'Français');
        // Forcé et le conteneur s'appliquent ; Par défaut et SDH non.
        expect(info.secondaryFlags, ['Forcé', 'SRT']);
      });
    });

    testWidgets('subtitle track: Forcé, Par défaut et SDH tous ensemble',
        (tester) async {
      await withContext(tester, (context) {
        final stream = SubStreamModel(
          name: '',
          id: '2',
          title: '',
          displayTitle: '',
          language: 'eng',
          codec: 'pgssub',
          isDefault: true,
          isExternal: false,
          index: 4,
          isForced: true,
          isHearingImpaired: true,
        );
        final info = formatSubtitleTrackLabel(context, stream);
        expect(info.primary, 'Anglais');
        expect(info.secondaryFlags, ['Forcé', 'Par défaut', 'SDH', 'PGS']);
      });
    });

    testWidgets('une piste "off" affiche le libellé localisé, sans drapeau',
        (tester) async {
      await withContext(tester, (context) {
        final info = formatSubtitleTrackLabel(context, SubStreamModel.no());
        expect(info.primary, context.localized.off);
        expect(info.secondaryFlags, isEmpty);
      });
    });
  });
}
