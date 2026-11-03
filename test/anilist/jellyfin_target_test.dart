import 'package:flutter_test/flutter_test.dart';
import 'package:kinos/anilist/jellyfin_target.dart';
import 'package:kinos/anilist/mapping.dart';
import 'package:kinos/jellyfin/jellyfin_open_api.swagger.dart' as dto;
import 'package:kinos/models/items/movie_model.dart';
import 'package:kinos/models/items/season_model.dart';
import 'package:kinos/models/items/series_model.dart';

void main() {
  test('reads existing movie metadata without changing its model', () {
    final movie = MovieModel.fromBaseDto(
        const dto.BaseItemDto(
            id: 'm', name: 'Movie', providerIds: {'Tmdb': '128'}),
        null);
    final target = anilistTargetFromItem(movie);
    expect(target.kind, AnilistTargetKind.movie);
    expect(target.ids.values['tmdb'], '128');
  });
  test('raw season index preserves unknown versus actual specials', () {
    const unknown = dto.BaseItemDto(id: 's', name: 'Season');
    const specials = dto.BaseItemDto(id: 's', name: 'Season', indexNumber: 0);
    final item = SeasonModel.fromBaseDto(unknown, null);
    expect(anilistTargetFromItem(item).season, isNull);
    final a = anilistTargetFromItem(item, source: unknown);
    final b = anilistTargetFromItem(item, source: specials);
    expect(a.season, isNull);
    expect(b.season, 0);
    expect(a.fingerprint, isNot(b.fingerprint));
  });
  test('keeps season metadata separate from parent IDs', () {
    final parent = SeriesModel.fromBaseDto(
        const dto.BaseItemDto(
            id: 'tv', name: 'TV', providerIds: {'Tmdb': '31910'}),
        null);
    final season = SeasonModel.fromBaseDto(
        const dto.BaseItemDto(
            id: 's', name: 'Season 3', seriesId: 'tv', indexNumber: 3),
        null);
    final target = anilistTargetFromItem(season, parent: parent);
    expect(target.ids.values, isEmpty);
    expect(target.parentIds.values['tmdb'], '31910');
    expect(target.season, 3);
    expect(target.seasonSource, isNull);
  });
}
