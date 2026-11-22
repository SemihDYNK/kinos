import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kinos/widgets/shared/kinos_error_view.dart';

void main() {
  testWidgets('a crashed page explains itself instead of a grey screen',
      (tester) async {
    await tester.pumpWidget(KinosErrorView(
        FlutterErrorDetails(exception: StateError('Bad state: No element'))));
    expect(find.text('Cette page n\'a pas pu s\'afficher.'), findsOneWidget);
    expect(find.textContaining('No element'), findsOneWidget);
    // Sans routeur (au-dessus de l'app), pas de bouton qui ne mène nulle part.
    expect(find.text('Accueil'), findsNothing);
  });
}
