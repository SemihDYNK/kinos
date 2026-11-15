import 'package:flutter_test/flutter_test.dart';

import 'package:kinos/theme/app_theme.dart';

/// Laisse passer le rebond d'une tuile cliquée (cf. PressBounce) : son
/// action part au sommet du rebond, pas au relâchement. Les étapes du
/// rebond démarrent chacune à l'image suivante, d'où les petits pas.
Future<void> pumpPressBounce(WidgetTester tester) async {
  final total = AppDurations.pressIn + AppDurations.pressRelease;
  const step = Duration(milliseconds: 16);
  for (var elapsed = Duration.zero;
      elapsed <= total + step * 4;
      elapsed += step) {
    await tester.pump(step);
  }
}
