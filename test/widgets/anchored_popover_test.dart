import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:kinos/widgets/shared/anchored_popover.dart';

Widget _harness({
  required Widget Function(BuildContext, VoidCallback close) popoverBuilder,
  AnchoredPopoverController? controller,
  FocusNode? triggerFocusNode,
  ValueChanged<bool>? onOpenChanged,
}) {
  return MaterialApp(
    home: Scaffold(
      body: Column(
        children: [
          AnchoredPopover(
            controller: controller,
            popoverBuilder: popoverBuilder,
            onOpenChanged: onOpenChanged,
            child: TextButton(
              key: const Key('trigger'),
              focusNode: triggerFocusNode,
              onPressed: controller == null ? () {} : controller.toggle,
              child: const Text('Ouvrir'),
            ),
          ),
          const TextButton(
            onPressed: null,
            child: Text('Ailleurs dans la page'),
          ),
        ],
      ),
    ),
  );
}

void main() {
  group('AnchoredPopover', () {
    testWidgets('shows content on demand and closes on outside tap',
        (tester) async {
      final controller = AnchoredPopoverController();
      await tester.pumpWidget(_harness(
        controller: controller,
        popoverBuilder: (context, close) => const Text('Contenu popover'),
      ));

      expect(find.text('Contenu popover'), findsNothing);

      controller.show();
      await tester.pumpAndSettle();
      expect(find.text('Contenu popover'), findsOneWidget);

      // Un clic ailleurs dans la page ferme le popover.
      await tester.tapAt(const Offset(5, 5));
      await tester.pumpAndSettle();
      expect(find.text('Contenu popover'), findsNothing);
    });

    testWidgets('Escape closes the popover and returns focus to the trigger',
        (tester) async {
      final controller = AnchoredPopoverController();
      final triggerFocusNode = FocusNode(debugLabel: 'trigger');
      addTearDown(triggerFocusNode.dispose);
      await tester.pumpWidget(_harness(
        controller: controller,
        triggerFocusNode: triggerFocusNode,
        popoverBuilder: (context, close) => const Text('Contenu popover'),
      ));

      triggerFocusNode.requestFocus();
      await tester.pumpAndSettle();
      expect(triggerFocusNode.hasFocus, isTrue);

      controller.show();
      await tester.pumpAndSettle();
      expect(find.text('Contenu popover'), findsOneWidget);
      expect(triggerFocusNode.hasFocus, isFalse);

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();

      expect(find.text('Contenu popover'), findsNothing);
      expect(triggerFocusNode.hasFocus, isTrue);
    });

    testWidgets('onOpenChanged fires true on open and false on close',
        (tester) async {
      final controller = AnchoredPopoverController();
      final events = <bool>[];
      await tester.pumpWidget(_harness(
        controller: controller,
        onOpenChanged: events.add,
        popoverBuilder: (context, close) => const Text('Contenu popover'),
      ));

      expect(events, isEmpty);
      controller.show();
      await tester.pumpAndSettle();
      expect(events, [true]);

      controller.hide();
      await tester.pumpAndSettle();
      expect(events, [true, false]);
    });

    testWidgets('close() passed to the builder closes the popover',
        (tester) async {
      final controller = AnchoredPopoverController();
      await tester.pumpWidget(_harness(
        controller: controller,
        popoverBuilder: (context, close) => TextButton(
          onPressed: close,
          child: const Text('Fermer depuis le contenu'),
        ),
      ));

      controller.show();
      await tester.pumpAndSettle();
      expect(find.text('Fermer depuis le contenu'), findsOneWidget);

      await tester.tap(find.text('Fermer depuis le contenu'));
      await tester.pumpAndSettle();
      expect(find.text('Fermer depuis le contenu'), findsNothing);
    });
  });

  group('PopoverOptionList', () {
    testWidgets('arrow keys move the highlighted option, Enter selects it',
        (tester) async {
      final selections = <String>[];
      final controller = AnchoredPopoverController();
      await tester.pumpWidget(_harness(
        controller: controller,
        popoverBuilder: (context, close) => PopoverOptionList(
          onSelected: close,
          options: [
            PopoverOption(
                content: const Text('Un'),
                onSelect: () => selections.add('Un')),
            PopoverOption(
                content: const Text('Deux'),
                onSelect: () => selections.add('Deux')),
            PopoverOption(
                content: const Text('Trois'),
                onSelect: () => selections.add('Trois')),
          ],
        ),
      ));

      controller.show();
      await tester.pumpAndSettle();

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();

      expect(selections, ['Trois']);
      // La sélection ferme le popover (onSelected == close).
      expect(find.text('Un'), findsNothing);
    });

    testWidgets('clicking an option selects it directly', (tester) async {
      final selections = <String>[];
      final controller = AnchoredPopoverController();
      await tester.pumpWidget(_harness(
        controller: controller,
        popoverBuilder: (context, close) => PopoverOptionList(
          onSelected: close,
          options: [
            PopoverOption(
                content: const Text('Un'),
                onSelect: () => selections.add('Un')),
            PopoverOption(
                content: const Text('Deux'),
                onSelect: () => selections.add('Deux')),
          ],
        ),
      ));

      controller.show();
      await tester.pumpAndSettle();

      await tester.tap(find.text('Deux'));
      await tester.pumpAndSettle();

      expect(selections, ['Deux']);
    });

    testWidgets('a selected option shows a check mark', (tester) async {
      final controller = AnchoredPopoverController();
      await tester.pumpWidget(_harness(
        controller: controller,
        popoverBuilder: (context, close) => const PopoverOptionList(
          options: [
            PopoverOption(content: Text('Un'), selected: false),
            PopoverOption(content: Text('Deux'), selected: true),
          ],
        ),
      ));

      controller.show();
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.check_rounded), findsOneWidget);
    });
  });
}
