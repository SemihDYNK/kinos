import 'package:kinos/jellyfin/jellyfin_open_api.swagger.dart' as dto;
import 'package:kinos/models/item_base_model.dart';
import 'package:kinos/models/items/movie_model.dart';
import 'package:kinos/models/items/series_model.dart';
import 'package:kinos/models/items/season_model.dart';
import 'mapping.dart';

AnilistTarget anilistTargetFromItem(ItemBaseModel item,
    {SeriesModel? parent,
    dto.BaseItemDto? source,
    dto.BaseItemDto? parentSource}) {
  final ids = <String, Object?>{
    ...?item.overview.providerIds,
    if (item is MovieModel) ...?item.providerIds,
    if (item is SeriesModel) ...?item.providerIds,
  };
  return AnilistTarget(
      itemId: item.id,
      title:
          item is SeasonModel ? '${item.seriesName} · ${item.name}' : item.name,
      kind: switch (item) {
        MovieModel _ => AnilistTargetKind.movie,
        SeasonModel _ => AnilistTargetKind.season,
        _ => AnilistTargetKind.series
      },
      ids: source != null ? source.providerIds : ids,
      parentIds: parentSource != null
          ? parentSource.providerIds
          : parent == null
              ? null
              : {...?parent.overview.providerIds, ...?parent.providerIds},
      // The upstream model folds missing indices into 0; only the raw DTO can prove specials.
      season: item is SeasonModel
          ? source != null
              ? source.indexNumber
              : item.season > 0
                  ? item.season
                  : null
          : null);
}
