import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:kinos/util/adaptive_layout/adaptive_layout.dart';
import 'package:kinos/util/adaptive_layout/adaptive_layout_model.dart';
import 'package:kinos/util/poster_defaults.dart';
import 'package:kinos/widgets/shared/anchored_popover.dart';
import 'package:kinos/widgets/shared/modal_side_sheet.dart';

// `showModalSideSheet` lit `AdaptiveLayout.of(context)` — un modèle minimal
// suffit ici, la modale de demande Seerr (vrai appelant) en fournit un réel
// via l'arbre de widgets normal de l'app.
const _testAdaptiveLayout = AdaptiveLayoutModel(
  viewSize: ViewSize.desktop,
  layoutMode: LayoutMode.single,
  inputDevice: InputDevice.pointer,
  platform: TargetPlatform.linux,
  isDesktop: true,
  posterDefaults: PosterDefaults(size: 150, ratio: 1.5),
  controller: {},
  sideBarWidth: 0,
  topBarHeight: 0,
  statusBarHeight: 0,
);

// AnchoredPopover est déjà couvert isolément par anchored_popover_test.dart.
// Ce fichier vérifie spécifiquement son comportement quand le déclencheur
// vit *dans* une modale (showModalSideSheet) — le cas de la modale de
// demande Seerr : empilement au-dessus de la modale, repositionnement,
// Échap qui ne ferme que le popover (la modale reste ouverte, un second
// Échap la ferme), et retour du focus au déclencheur dans la modale plutôt
// qu'au contenu du fond.
void main() {
  Future<void> openModal(WidgetTester tester,
      AnchoredPopoverController controller, List<String> selections,
      {FocusNode? triggerFocusNode}) async {
    await tester.pumpWidget(AdaptiveLayout(
      data: _testAdaptiveLayout,
      child: MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => Center(
              child: TextButton(
                key: const Key('open-modal'),
                onPressed: () => showModalSideSheet(
                  context,
                  header: const Text('Modale'),
                  content: Column(
                    children: [
                      const Text('Contenu modale', key: Key('modal-marker')),
                      AnchoredPopover(
                        controller: controller,
                        popoverBuilder: (context, close) => PopoverOptionList(
                          onSelected: close,
                          options: [
                            PopoverOption(
                              content: const Text('Option A'),
                              onSelect: () => selections.add('Option A'),
                            ),
                          ],
                        ),
                        child: TextButton(
                          key: const Key('trigger'),
                          focusNode: triggerFocusNode,
                          onPressed: controller.toggle,
                          child: const Text('Ouvrir popover'),
                        ),
                      ),
                    ],
                  ),
                ),
                child: const Text('Ouvrir modale'),
              ),
            ),
          ),
        ),
      ),
    ));

    await tester.tap(find.byKey(const Key('open-modal')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('modal-marker')), findsOneWidget);
  }

  testWidgets(
      'the popover stacks above the modal — a tap on an option reaches it, not the barrier below',
      (tester) async {
    final controller = AnchoredPopoverController();
    final selections = <String>[];
    await openModal(tester, controller, selections);

    await tester.tap(find.byKey(const Key('trigger')));
    await tester.pumpAndSettle();
    expect(find.text('Option A'), findsOneWidget);

    await tester.tap(find.text('Option A'));
    await tester.pumpAndSettle();

    // Si le popover était rendu sous la modale (mauvaise couche
    // d'Overlay), ce tap n'atteindrait jamais l'option — soit il ne
    // ferait rien, soit il retomberait sur le barrage de la modale.
    expect(selections, ['Option A']);
    expect(find.text('Option A'), findsNothing);
    expect(find.byKey(const Key('modal-marker')), findsOneWidget,
        reason: 'sélectionner une option ne doit pas fermer la modale');
  });

  testWidgets(
      'Escape closes only the popover — the modal stays open; a second Escape closes the modal',
      (tester) async {
    final controller = AnchoredPopoverController();
    final selections = <String>[];
    final triggerFocusNode = FocusNode(debugLabel: 'seerr-trigger');
    addTearDown(triggerFocusNode.dispose);
    await openModal(tester, controller, selections,
        triggerFocusNode: triggerFocusNode);

    // Le déclencheur doit détenir le focus avant l'ouverture — comme un
    // vrai clic ou une navigation clavier le ferait — pour que ce test
    // vérifie un retour de focus réel, pas un cas où rien n'était focalisé
    // avant.
    triggerFocusNode.requestFocus();
    await tester.pumpAndSettle();
    controller.show();
    await tester.pumpAndSettle();
    expect(find.text('Option A'), findsOneWidget);

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();

    expect(find.text('Option A'), findsNothing,
        reason: 'le premier Échap ferme le popover');
    expect(find.byKey(const Key('modal-marker')), findsOneWidget,
        reason: 'le premier Échap ne doit pas fermer la modale');
    expect(triggerFocusNode.hasFocus, isTrue,
        reason: 'le focus revient au déclencheur dans la modale, pas au fond');

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('modal-marker')), findsNothing,
        reason: 'le second Échap ferme la modale');
  });

  testWidgets('the popover repositions itself to stay inside the window',
      (tester) async {
    // Fenêtre de test étroite : un popover ancré près du bord droit doit
    // se replacer plutôt que déborder.
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final controller = AnchoredPopoverController();
    final selections = <String>[];
    await openModal(tester, controller, selections);

    controller.show();
    await tester.pumpAndSettle();

    final popoverBox = tester.renderObject<RenderBox>(find.text('Option A'));
    final topLeft = popoverBox.localToGlobal(Offset.zero);
    final windowSize = tester.view.physicalSize / tester.view.devicePixelRatio;

    expect(topLeft.dx, greaterThanOrEqualTo(0));
    expect(topLeft.dy, greaterThanOrEqualTo(0));
    expect(topLeft.dx, lessThanOrEqualTo(windowSize.width));
    expect(topLeft.dy, lessThanOrEqualTo(windowSize.height));
  });
}
