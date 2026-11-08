import 'package:flutter_test/flutter_test.dart';
import 'package:kinos/providers/remote_subtitles_provider.dart';

void main() {
  test('accepts Jellyfin empty 204 response for a remote subtitle download',
      () {
    expect(isRemoteSubtitleDownloadStatus(204), isTrue);
  });
}
