import 'package:flutter_test/flutter_test.dart';

import 'package:kinos/wrappers/players/player_log.dart';

void main() {
  test('les jetons d\'accès des URL de flux sont masqués', () {
    const url = 'https://srv.example/jellyfin/Videos/abc/stream?static=true'
        '&api_key=SECRET123&PlaySessionId=XYZ&MediaSourceId=abc';
    final redacted = redactPlayerLog('Failed to open $url.');
    expect(redacted, isNot(contains('SECRET123')));
    expect(redacted, isNot(contains('XYZ')));
    expect(redacted, contains('api_key=***'));
    expect(redacted, contains('MediaSourceId=abc'));
  });
}
