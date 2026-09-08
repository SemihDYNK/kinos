import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:kinos/arr/models/arr_service.dart';
import 'package:kinos/arr/providers/arr_library_providers.dart';
import 'package:kinos/screens/shared/chips/filter_button.dart';
import 'package:kinos/theme/app_theme.dart';

/// Reproduit la Row complète de la barre d'outils de ArrLibraryScreen
/// (texte de raccourcis + 4 FilterButton + menu de tri + bouton de sens)
/// à des largeurs de fenêtre réalistes pour une app bureau — pour
/// vérifier qu'aucun débordement de Row ne fait atterrir le geste de tap
/// ailleurs que sur le bouton visé. Avant correction : le texte de
/// raccourcis (une phrase longue) et un `Spacer()` sans aucun élément
/// borné en largeur pouvaient déborder de plusieurs centaines de pixels
/// même à une largeur confortable — c'était la cause du bouton
/// croissant/décroissant "cliquable mais sans effet" rapporté : la
/// cible visuelle et la cible de geste réelle ne coïncidaient plus.
class _ToolbarHarness extends ConsumerWidget {
  final double width;
  const _ToolbarHarness({required this.width});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final view = ref.watch(arrLibraryViewProvider(ArrService.radarr));
    final viewNotifier =
        ref.read(arrLibraryViewProvider(ArrService.radarr).notifier);
    return MaterialApp(
      home: Scaffold(
        body: SizedBox(
          width: width,
          child: Row(
            children: [
              Expanded(
                child: Text(
                  '↑↓←→ naviguer · Entrée détail · clic droit ou touche Menu : actions',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: AppColors.textDisabled),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Row(
                spacing: AppSpacing.xxs,
                children: [
                  FilterButton(
                    isSelected: view.filter == ArrLibraryFilter.all,
                    label: const Text('Tout'),
                    onPressed: () =>
                        viewNotifier.setFilter(ArrLibraryFilter.all),
                  ),
                  FilterButton(
                    isSelected: view.filter == ArrLibraryFilter.monitored,
                    label: const Text('Surveillé'),
                    onPressed: () =>
                        viewNotifier.setFilter(ArrLibraryFilter.monitored),
                  ),
                  FilterButton(
                    isSelected: view.filter == ArrLibraryFilter.unmonitored,
                    label: const Text('Non surveillé'),
                    onPressed: () =>
                        viewNotifier.setFilter(ArrLibraryFilter.unmonitored),
                  ),
                  FilterButton(
                    isSelected: view.filter == ArrLibraryFilter.missing,
                    label: const Text('Manquant'),
                    onPressed: () =>
                        viewNotifier.setFilter(ArrLibraryFilter.missing),
                  ),
                ],
              ),
              const SizedBox(width: AppSpacing.sm),
              FocusRing(
                borderRadius: AppRadii.controlBorder,
                child: ExcludeFocus(
                  child: PopupMenuButton<ArrLibrarySort>(
                    tooltip: 'Trier',
                    color: AppColors.surfaceHigh,
                    shape: const RoundedRectangleBorder(
                        borderRadius: AppRadii.sheetBorder),
                    icon: const Icon(Icons.sort_rounded,
                        color: AppColors.textSecondary),
                    onSelected: viewNotifier.setSort,
                    itemBuilder: (context) => const [
                      PopupMenuItem(
                          value: ArrLibrarySort.added,
                          child: Text('Date d\'ajout')),
                      PopupMenuItem(
                          value: ArrLibrarySort.title, child: Text('Titre')),
                      PopupMenuItem(
                          value: ArrLibrarySort.year, child: Text('Année')),
                      PopupMenuItem(
                          value: ArrLibrarySort.status,
                          child: Text('Statut')),
                    ],
                  ),
                ),
              ),
              FocusRing(
                borderRadius: AppRadii.controlBorder,
                onActivate: viewNotifier.toggleDirection,
                child: ExcludeFocus(
                  child: Tooltip(
                    message: view.ascending ? 'Croissant' : 'Décroissant',
                    child: IconButton(
                      key: const Key('direction-toggle'),
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
            ],
          ),
        ),
      ),
    );
  }
}

void main() {
  // 900px et plus : plage réaliste pour une fenêtre Fladder (bureau
  // uniquement, cf. CLAUDE.md) — en-deçà, un toolbar aussi dense que
  // celui-ci déborderait dans n'importe quelle app, ce n'est pas ce que
  // ce test cherche à couvrir.
  for (final width in [900.0, 1200.0, 1600.0]) {
    testWidgets(
        'tapping the direction button at width=$width flips ascending '
        'without an overflow eating the gesture', (tester) async {
      await tester.pumpWidget(
        ProviderScope(child: _ToolbarHarness(width: width)),
      );
      await tester.pumpAndSettle();

      // Un débordement de RenderFlex, s'il y en a un, se signale ici —
      // sans quoi il resterait silencieux dans ce test.
      expect(tester.takeException(), isNull);

      expect(find.byIcon(Icons.arrow_downward_rounded), findsOneWidget);

      await tester.tap(find.byKey(const Key('direction-toggle')));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byIcon(Icons.arrow_upward_rounded), findsOneWidget,
          reason: 'le tap sur le bouton de sens devrait avoir basculé '
              'ascending à width=$width');
    });
  }
}
