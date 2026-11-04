import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  for (final family in ['barlow_condensed', 'inter']) {
    test('$family license is included in the application bundle', () async {
      final license = await rootBundle.loadString('assets/fonts/$family/OFL.txt');
      expect(license, contains('SIL OPEN FONT LICENSE'));
    });
  }
}
