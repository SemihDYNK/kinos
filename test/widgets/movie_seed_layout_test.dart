import 'package:chopper/chopper.dart' as chopper;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kinos/models/item_base_model.dart';
import 'package:kinos/models/items/movie_model.dart';
import 'package:kinos/providers/items/movies_details_provider.dart';
import 'package:kinos/providers/user_provider.dart';
import 'package:kinos/screens/details_screens/movie_detail_screen.dart';
import 'package:kinos/screens/shared/media_hero_title.dart';
import 'package:kinos/screens/shared/media_detail_scaffold.dart';
import 'package:auto_route/auto_route.dart';
import 'seerr_discovery_section_test.dart'
    show shell, TestUser, PendingDetailsRouter;
import 'support/home_visual_fixture.dart' show fixtureMovies;

class _LoadingMovie extends MovieDetails {
  @override
  MovieModel? build(String arg) => null;
  @override
  Future<chopper.Response?> fetchDetails(ItemBaseModel item) async => null;
  void complete(MovieModel item) => state = item;
}

void main() {
  testWidgets(
      'movie logo keeps its position when the initial details become available',
      (tester) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
            const MethodChannel('window_manager'), (_) async => null);
    final movie = fixtureMovies().first;
    final container = ProviderContainer(overrides: [
      userProvider.overrideWith(TestUser.new),
      movieDetailsProvider(movie.id).overrideWith(_LoadingMovie.new),
    ]);
    addTearDown(container.dispose);
    final router = PendingDetailsRouter();
    addTearDown(router.dispose);
    await tester.pumpWidget(UncontrolledProviderScope(
        container: container,
        child: StackRouterScope(
            controller: router,
            stateHash: 0,
            child: shell(SliverToBoxAdapter(
                child: SizedBox(
                    height: 900, child: MovieDetailScreen(item: movie)))))));
    await tester.pumpAndSettle();
    final initial = tester.getRect(find.byType(MediaHeroTitle));
    final initialScaffold =
        tester.widget<MediaDetailScaffold>(find.byType(MediaDetailScaffold));
    (container.read(movieDetailsProvider(movie.id).notifier) as _LoadingMovie)
        .complete(movie.copyWith(originalTitle: movie.title));
    await tester.pumpAndSettle();
    expect(tester.getRect(find.byType(MediaHeroTitle)), initial);
    expect(initialScaffold.heroContent, isNotNull);
    expect(initialScaffold.onPlay, isNotNull);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
