import 'package:auto_route/auto_route.dart';
import 'package:chopper/chopper.dart' as chopper;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:kinos/jellyfin/jellyfin_open_api.swagger.dart' show BaseItemDto;
import 'package:kinos/models/item_base_model.dart';
import 'package:kinos/models/items/episode_model.dart';
import 'package:kinos/models/items/item_shared_models.dart';
import 'package:kinos/models/items/movie_model.dart';
import 'package:kinos/models/items/series_model.dart';
import 'package:kinos/providers/items/episode_details_provider.dart';
import 'package:kinos/providers/items/movies_details_provider.dart';
import 'package:kinos/providers/items/series_details_provider.dart';
import 'package:kinos/providers/user_provider.dart';
import 'package:kinos/routes/nested_details_screen.dart';
import 'package:kinos/screens/shared/media_detail_scaffold.dart';
import 'package:kinos/widgets/shared/animated_media_icon.dart';
import 'seerr_discovery_section_test.dart'
    show shell, TestUser, PendingDetailsRouter;

class _User extends TestUser {
  final favourites = <bool>[];
  final played = <bool>[];
  var data = const UserData();
  @override
  Future<chopper.Response<UserData>?> setAsFavorite(
      bool value, String id) async {
    favourites.add(value);
    data = data.copyWith(isFavourite: value);
    return chopper.Response(http.Response('', 200), data);
  }

  @override
  Future<chopper.Response<UserData>?> markAsPlayed(
      bool value, String id) async {
    played.add(value);
    data = data.copyWith(played: value);
    return chopper.Response(http.Response('', 200), data);
  }
}

class _Movie extends MovieDetails {
  _Movie(this.item);
  final MovieModel item;
  @override
  MovieModel? build(String arg) => item;
  @override
  Future<chopper.Response?> fetchDetails(ItemBaseModel item) async => null;
}

class _Series extends SeriesDetailViewNotifier {
  _Series(super.ref, SeriesModel item) {
    state = item;
  }
  @override
  Future<chopper.Response?> fetchDetails(ItemBaseModel item) async => null;
}

class _Episode extends EpisodeDetailsProvider {
  _Episode(super.ref, EpisodeModel item) {
    updateEpisode(item);
  }
  @override
  Future<chopper.Response?> fetchDetails(ItemBaseModel item) async => null;
}

void main() {
  setUpAll(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
            const MethodChannel('window_manager'), (_) async => null);
  });
  for (final kind in ['movie', 'series', 'episode']) {
    testWidgets(
        '$kind favourite and watched immediately reflect confirmed data and toggle back',
        (tester) async {
      tester.view.physicalSize = const Size(1800, 1200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final router = PendingDetailsRouter();
      addTearDown(router.dispose);
      final user = _User();
      const dto = BaseItemDto(
          id: 'item', name: 'Titre', seriesId: 'series', parentId: 'series');
      final movie = MovieModel.fromBaseDto(dto, null);
      final series = SeriesModel.fromBaseDto(dto, null);
      final episode = EpisodeModel.fromBaseDto(dto, null);
      await tester.pumpWidget(ProviderScope(
          overrides: [
            userProvider.overrideWith(() => user),
            movieDetailsProvider('item').overrideWith(() => _Movie(movie)),
            seriesDetailsProvider('item')
                .overrideWith((ref) => _Series(ref, series)),
            episodeDetailsProvider('item')
                .overrideWith((ref) => _Episode(ref, episode)),
          ],
          child: StackRouterScope(
              controller: router,
              stateHash: 0,
              child: shell(SliverToBoxAdapter(
                  child: SizedBox(
                      height: 1200,
                      child: DetailsScreen(
                          item: switch (kind) {
                        'movie' => movie,
                        'series' => series,
                        _ => episode,
                      })))))));
      expect(find.byType(MediaDetailScaffold), findsOneWidget);
      expect(find.byKey(const Key("progress-indicator")), findsNothing);
      await tester.pumpAndSettle();
      for (final value in [true, false]) {
        await tester.tap(find.ancestor(
            of: find.byType(AnimatedFavouriteIcon),
            matching: find.byType(IconButton)));
        await tester.pumpAndSettle();
        expect(
            tester
                .widget<AnimatedFavouriteIcon>(
                    find.byType(AnimatedFavouriteIcon))
                .selected,
            value);
      }
      expect(user.favourites, [true, false]);
      for (final value in [true, false]) {
        await tester.tap(find.ancestor(
            of: find.byType(AnimatedWatchedIcon).first,
            matching: find.byType(IconButton)));
        await tester.pumpAndSettle();
        expect(
            tester
                .widget<AnimatedWatchedIcon>(
                    find.byType(AnimatedWatchedIcon).first)
                .selected,
            value);
      }
      expect(user.played, [true, false]);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    });
  }
}
