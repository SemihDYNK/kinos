import 'package:flutter_test/flutter_test.dart';
import 'package:kinos/recommendations/seerr/discovery_debug.dart';

void main() {
  test('debug trace reports progress without exposing exception contents', () {
    final lines = <String>[];
    final trace = DiscoveryDebug(write: lines.add);
    trace.step('graines', counts: {'nombre': 10});
    trace.note('provider libéré');
    trace.failure(StateError('https://secret.example/?apiKey=private-cookie'));

    expect(lines.first, contains('[Seerr découverte]'));
    expect(lines.first, contains('graines'));
    expect(lines.first, contains('nombre=10'));
    expect(lines.last, contains('StateError'));
    expect(lines.last, contains('graines'));
    expect(lines.join(), isNot(contains('secret.example')));
    expect(lines.join(), isNot(contains('private-cookie')));
  });

  test('cancelled runs retain their active stage and differ from failures', () {
    final lines = <String>[];
    final trace = DiscoveryDebug(write: lines.add);
    trace.step('page Jellyfin', counts: {'début': 0});
    trace.note('provider libéré');
    trace.failure(StateError('secret'), cancelled: true);
    expect(lines.last, contains('annulé étape=page Jellyfin'));
    expect(lines.last, isNot(contains('échec')));
    expect(lines.last, contains('calcul='));
  });
}
