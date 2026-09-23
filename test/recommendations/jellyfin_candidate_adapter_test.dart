import 'package:flutter_test/flutter_test.dart';

import 'package:kinos/models/item_base_model.dart';
import 'package:kinos/models/items/item_shared_models.dart';
import 'package:kinos/models/items/overview_model.dart';
import 'package:kinos/recommendations/adapters/jellyfin_candidate_adapter.dart';
import 'package:kinos/recommendations/models/candidate_item.dart';
import 'package:kinos/recommendations/models/trait.dart';

ItemBaseModel _item(String id, String name,
    {List<String> genres = const ['Drama'], int? yearAired}) {
  return ItemBaseModel(
    name: name,
    id: id,
    overview: OverviewModel(genres: genres, yearAired: yearAired),
    parentId: null,
    playlistId: null,
    images: null,
    childCount: null,
    primaryRatio: null,
    userData: const UserData(),
    canDownload: null,
    canDelete: null,
    jellyType: null,
  );
}

void main() {
  test('builds a candidate per item, tagged jellyfinLibrary', () {
    final candidates = buildJellyfinCandidates([_item('1', 'Movie A')]);

    expect(candidates, hasLength(1));
    expect(candidates.single.id, '1');
    expect(candidates.single.title, 'Movie A');
    expect(candidates.single.source, CandidateSource.jellyfinLibrary);
    expect(candidates.single.traits, contains(trait(TraitKind.genre, 'Drama')));
  });

  test('skips items with no extractable traits', () {
    final candidates =
        buildJellyfinCandidates([_item('1', 'No traits', genres: const [])]);

    expect(candidates, isEmpty);
  });

  test(
      'reads the year from overview.yearAired — the field actually '
      'populated for a server-loaded item (used by the Arr/Jellyfin '
      'dedup safety net)', () {
    final candidates =
        buildJellyfinCandidates([_item('1', 'Movie A', yearAired: 1987)]);

    expect(candidates.single.year, 1987);
  });
}
