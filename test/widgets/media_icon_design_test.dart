import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kinos/providers/user_provider.dart';
import 'package:kinos/screens/shared/media/components/poster_image.dart';
import 'package:kinos/theme/app_icons.dart';
import 'package:kinos/util/focus_provider.dart';
import 'package:kinos/theme/app_theme.dart';
import 'package:kinos/widgets/shared/frosted_surface.dart';
import 'package:kinos/widgets/shared/status_card.dart';
import 'seerr_discovery_section_test.dart' show shell, TestUser;
import 'support/home_visual_fixture.dart' show fixtureMovies;

void main() {
  testWidgets(
      'watched badges stay compact and use an opaque high contrast fallback',
      (tester) async {
    for (final highContrast in [false, true]) {
      await tester.pumpWidget(MaterialApp(
          theme: buildAppTheme(),
          home: MediaQuery(
              data: MediaQueryData(highContrast: highContrast),
              child: const Scaffold(
                  body: Align(
                      alignment: Alignment.topLeft,
                      child: StatusCard(child: Icon(AppIcons.watched)))))));
      await tester.pumpAndSettle();
      final surface = tester.getSize(find.byType(FrostedSurface));
      expect(surface, const Size.square(AppMediaIcons.badgeSize));
      expect(find.byType(BackdropFilter),
          highContrast ? findsNothing : findsOneWidget);
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('poster play uses a glass circle and remains keyboard operable',
      (tester) async {
    var played = false;
    final movie = fixtureMovies().first;
    await tester.pumpWidget(ProviderScope(
        overrides: [userProvider.overrideWith(TestUser.new)],
        child: shell(SliverToBoxAdapter(
            child: Align(
                alignment: Alignment.topLeft,
                child: SizedBox(
                    width: 180,
                    height: 270,
                    child: PosterImage(
                        poster: movie,
                        playVideo: (_) => played = true,
                        onPressed: (_, __) {})))))));
    await tester.pumpAndSettle();
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: Offset.zero);
    await mouse.moveTo(tester.getCenter(find.byType(PosterImage)));
    await tester.pumpAndSettle();
    expect(
        tester.widget<FocusButton>(find.byType(FocusButton).first).posterMotion,
        isTrue);
    final play = find.widgetWithIcon(IconButton, AppIcons.play);
    expect(play, findsOneWidget);
    expect(
        tester.getSize(play), const Size.square(AppMediaIcons.playTargetSize));
    expect(find.ancestor(of: play, matching: find.byType(FrostedSurface)),
        findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pumpAndSettle();
    expect(
        tester
            .widget<IconButton>(play)
            .style
            ?.side
            ?.resolve({WidgetState.focused})?.color,
        AppColors.focus);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(played, isTrue);
    expect(tester.takeException(), isNull);
    await mouse.removePointer();
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });
}
