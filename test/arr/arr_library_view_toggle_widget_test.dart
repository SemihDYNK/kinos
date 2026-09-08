import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:kinos/arr/models/arr_service.dart';
import 'package:kinos/arr/providers/arr_library_providers.dart';
import 'package:kinos/theme/app_theme.dart';

/// Reproduit exactement la composition du bouton croissant/décroissant de
/// ArrLibraryScreen (FocusRing > ExcludeFocus > Tooltip > IconButton,
/// onPressed = viewNotifier.toggleDirection) contre le vrai
/// arrLibraryViewProvider — sans le reste de l'écran (identifiants,
/// requête réseau...), pour isoler : le geste atteint-il bien le
/// notifier ?
class _ToggleHarness extends ConsumerWidget {
  const _ToggleHarness();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final view = ref.watch(arrLibraryViewProvider(ArrService.radarr));
    final viewNotifier =
        ref.read(arrLibraryViewProvider(ArrService.radarr).notifier);
    return MaterialApp(
      home: Scaffold(
        body: FocusRing(
          borderRadius: AppRadii.controlBorder,
          onActivate: viewNotifier.toggleDirection,
          child: ExcludeFocus(
            child: Tooltip(
              message: view.ascending ? 'Croissant' : 'Décroissant',
              child: IconButton(
                onPressed: viewNotifier.toggleDirection,
                icon: Icon(
                  view.ascending
                      ? Icons.arrow_upward_rounded
                      : Icons.arrow_downward_rounded,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

void main() {
  testWidgets(
      'tapping the direction IconButton flips arrLibraryViewProvider.ascending',
      (tester) async {
    await tester.pumpWidget(
      const ProviderScope(child: _ToggleHarness()),
    );
    await tester.pumpAndSettle();

    // Défaut : tri "added", décroissant -> flèche vers le bas.
    expect(find.byIcon(Icons.arrow_downward_rounded), findsOneWidget);
    expect(find.byIcon(Icons.arrow_upward_rounded), findsNothing);

    await tester.tap(find.byType(IconButton));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.arrow_upward_rounded), findsOneWidget);
    expect(find.byIcon(Icons.arrow_downward_rounded), findsNothing);
  });
}
