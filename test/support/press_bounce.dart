import 'package:flutter_test/flutter_test.dart';

import 'package:kinos/theme/app_theme.dart';

/// Laisse passer l'enfoncement d'une tuile cliquée (cf. PressBounce) : un
/// clic bref termine d'enfoncer la tuile avant de lancer l'action. Les
/// animations démarrent à l'image suivante, d'où les petits pas.
Future<void> pumpPressBounce(WidgetTester tester) async {
  final total = AppDurations.pressIn + AppDurations.pressSettle;
  const step = Duration(milliseconds: 16);
  for (var elapsed = Duration.zero;
      elapsed <= total + step * 4;
      elapsed += step) {
    await tester.pump(step);
  }
}
