import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kinos/theme/app_theme.dart';
import 'package:kinos/util/motion_input.dart';

void main() {
  testWidgets('typing does not switch the app to keyboard motion mode',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: MotionInputBoundary(
          child: Builder(
            builder: (context) => Column(children: [
              Text(
                  AppMotion.enabled(context) ? 'motion enabled' : 'motion off'),
              const TextField(autofocus: true),
            ]),
          ),
        ),
      ),
    ));
    await tester.pump();

    expect(find.text('motion enabled'), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyA);
    await tester.pump();

    expect(find.text('motion enabled'), findsOneWidget);
    expect(tester.testTextInput.hasAnyClients, isTrue);
  });
}
