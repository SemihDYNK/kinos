import 'package:flutter_test/flutter_test.dart';

import 'package:kinos/screens/video_player/components/video_quality_badge.dart';
import 'package:kinos/util/video_properties.dart';

void main() {
  group('playerHdrBadgeLabel', () {
    test('Dolby Vision variants all read "DoVi → SDR"', () {
      for (final profile in [
        DisplayProfile.dolbyVision,
        DisplayProfile.dolbyVisionHdr10,
        DisplayProfile.dolbyVisionHdr10Plus,
        DisplayProfile.dolbyVisionHlg,
      ]) {
        expect(playerHdrBadgeLabel(profile, null), 'DoVi → SDR');
      }
    });

    test('HDR variants all read "HDR10 → SDR"', () {
      for (final profile in [
        DisplayProfile.hdr,
        DisplayProfile.hdr10,
        DisplayProfile.hdr10Plus,
        DisplayProfile.hlg,
      ]) {
        expect(playerHdrBadgeLabel(profile, null), 'HDR10 → SDR');
      }
    });

    test('SDR reads "SDR", not a tonemap arrow', () {
      expect(playerHdrBadgeLabel(DisplayProfile.sdr, null), 'SDR');
    });

    test('appends the resolution when known, separated by "·"', () {
      expect(
        playerHdrBadgeLabel(DisplayProfile.dolbyVisionHdr10, Resolution.udh),
        'DoVi → SDR · 4K',
      );
      expect(
        playerHdrBadgeLabel(DisplayProfile.sdr, Resolution.hd),
        'SDR · HD',
      );
    });

    test('a null profile with a known resolution shows only the resolution',
        () {
      expect(playerHdrBadgeLabel(null, Resolution.udh), '4K');
    });

    test('both null yields an empty string, not a stray separator', () {
      expect(playerHdrBadgeLabel(null, null), '');
    });
  });
}
