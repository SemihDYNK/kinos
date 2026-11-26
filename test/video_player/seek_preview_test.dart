import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:kinos/screens/video_player/components/seek_preview.dart';

void main() {
  test('the preview height follows the picture, always even', () {
    expect(previewHeight(1920, 1080), 180);
    expect(previewHeight(1920, 800), 134);
    expect(previewHeight(720, 576), 256);
  });

  test('padded mpv rows are packed tight and made opaque', () {
    // 2×2 pixels, lignes de 12 octets (4 de bourrage).
    final bytes = Uint8List.fromList([
      1, 2, 3, 0, 4, 5, 6, 0, 9, 9, 9, 9, //
      7, 8, 9, 0, 10, 11, 12, 0, 9, 9, 9, 9,
    ]);
    expect(packFrame(bytes, 2, 2), [
      1, 2, 3, 255, 4, 5, 6, 255, //
      7, 8, 9, 255, 10, 11, 12, 255,
    ]);
  });

  test('a frame of the wrong size is refused', () {
    expect(packFrame(Uint8List(10), 2, 2), isNull);
  });
}
