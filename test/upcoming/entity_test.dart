import 'package:flutter_test/flutter_test.dart';
import 'package:kinos/models/seerr/seerr_dashboard_model.dart';
import 'package:kinos/upcoming/entity/entity_models.dart';
import 'package:kinos/upcoming/entity/entity_providers.dart';

void main() {
  test('a Seerr credit becomes a title, with its library status', () {
    final title = EntityTitle.fromJson({
      'id': 438631,
      'mediaType': 'movie',
      'title': 'Dune',
      'releaseDate': '2021-09-15',
      'posterPath': '/d.jpg',
      'character': 'Paul Atreides',
      'popularity': 80.5,
      'mediaInfo': {'status': 5, 'jellyfinMediaId': 'abc'},
    })!;
    expect(title.identity, 'tmdb:movie:438631');
    expect(title.date, DateTime(2021, 9, 15));
    expect(title.inLibrary, isTrue);
    expect(title.status, SeerrMediaStatus.available);
    expect(title.upcoming(DateTime(2026, 11, 18)), isFalse);
    expect(EntityTitle.fromJson({'id': 1, 'mediaType': 'person'}), isNull);
    final tv = EntityTitle.fromJson({'id': 2, 'name': 'Signal'}, type: 'tv')!;
    expect(tv.upcoming(DateTime(2026, 11, 18)), isTrue);
  });

  test('appearances: self, voice, uncredited, a few episodes', () {
    EntityTitle t(String? character, {String type = 'movie', int? episodes}) =>
        EntityTitle(
            type: type,
            id: 1,
            title: 'T',
            character: character,
            episodes: episodes);
    expect(isAppearance(t('Himself')), isTrue);
    expect(isAppearance(t('Narrator (voice)')), isTrue);
    expect(isAppearance(t('Guest (uncredited)')), isTrue);
    expect(isAppearance(t('Paul Atreides')), isFalse);
    expect(isAppearance(t('Lead', type: 'tv', episodes: 2)), isTrue);
    expect(isAppearance(t('Lead', type: 'tv', episodes: 24)), isFalse);
  });

  test('a film role is main once its credits say so; a series by episodes', () {
    const film = EntityTitle(type: 'movie', id: 1, title: 'A', character: 'X');
    const series = EntityTitle(
        type: 'tv', id: 2, title: 'B', character: 'Y', episodes: 30);
    const state = EntityState(main: {'tmdb:movie:1': false});
    expect(state.isMain(film), isFalse);
    expect(const EntityState().isMain(film), isTrue);
    expect(
        const EntityState(main: {'tmdb:movie:1': true}).isMain(film), isTrue);
    expect(state.isMain(series), isTrue);
  });
}
