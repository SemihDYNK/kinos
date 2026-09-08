// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'library_filter_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_LibraryFilterModel _$LibraryFilterModelFromJson(Map<String, dynamic> json) =>
    _LibraryFilterModel(
      searchQuery: json['searchQuery'] as String? ?? "",
      genres: (json['genres'] as Map<String, dynamic>?)?.map(
            (k, e) => MapEntry(k, e as bool),
          ) ??
          const {},
      itemFilters: (json['itemFilters'] as Map<String, dynamic>?)?.map(
            (k, e) => MapEntry($enumDecode(_$ItemFilterEnumMap, k), e as bool),
          ) ??
          const {
            ItemFilter.isplayed: false,
            ItemFilter.isunplayed: false,
            ItemFilter.isresumable: false
          },
      studios: json['studios'] == null
          ? const {}
          : const StudioEncoder().fromJson(json['studios'] as String),
      tags: (json['tags'] as Map<String, dynamic>?)?.map(
            (k, e) => MapEntry(k, e as bool),
          ) ??
          const {},
      years: (json['years'] as Map<String, dynamic>?)?.map(
            (k, e) => MapEntry(int.parse(k), e as bool),
          ) ??
          const {},
      officialRatings: (json['officialRatings'] as Map<String, dynamic>?)?.map(
            (k, e) => MapEntry(k, e as bool),
          ) ??
          const {},
      types: (json['types'] as Map<String, dynamic>?)?.map(
            (k, e) =>
                MapEntry($enumDecode(_$FladderItemTypeEnumMap, k), e as bool),
          ) ??
          const {
            KinosItemType.audio: false,
            KinosItemType.boxset: false,
            KinosItemType.book: false,
            KinosItemType.collectionFolder: false,
            KinosItemType.episode: false,
            KinosItemType.folder: false,
            KinosItemType.movie: false,
            KinosItemType.musicAlbum: false,
            KinosItemType.musicVideo: false,
            KinosItemType.photo: false,
            KinosItemType.person: false,
            KinosItemType.photoAlbum: false,
            KinosItemType.series: false,
            KinosItemType.video: false
          },
      sortingOption:
          $enumDecodeNullable(_$SortingOptionsEnumMap, json['sortingOption']) ??
              SortingOptions.sortName,
      sortOrder:
          $enumDecodeNullable(_$SortingOrderEnumMap, json['sortOrder']) ??
              SortingOrder.ascending,
      favourites: json['favourites'] as bool?,
      hideEmptyShows: json['hideEmptyShows'] as bool? ?? true,
      recursive: json['recursive'] as bool? ?? false,
      groupBy: $enumDecodeNullable(_$GroupByEnumMap, json['groupBy']) ??
          GroupBy.none,
      isDefault: json['isDefault'] as bool? ?? false,
    );

Map<String, dynamic> _$LibraryFilterModelToJson(_LibraryFilterModel instance) =>
    <String, dynamic>{
      'searchQuery': instance.searchQuery,
      'genres': instance.genres,
      'itemFilters': instance.itemFilters
          .map((k, e) => MapEntry(_$ItemFilterEnumMap[k], e)),
      'studios': const StudioEncoder().toJson(instance.studios),
      'tags': instance.tags,
      'years': instance.years.map((k, e) => MapEntry(k.toString(), e)),
      'officialRatings': instance.officialRatings,
      'types': instance.types
          .map((k, e) => MapEntry(_$FladderItemTypeEnumMap[k]!, e)),
      'sortingOption': _$SortingOptionsEnumMap[instance.sortingOption]!,
      'sortOrder': _$SortingOrderEnumMap[instance.sortOrder]!,
      'favourites': instance.favourites,
      'hideEmptyShows': instance.hideEmptyShows,
      'recursive': instance.recursive,
      'groupBy': _$GroupByEnumMap[instance.groupBy]!,
      'isDefault': instance.isDefault,
    };

const _$ItemFilterEnumMap = {
  ItemFilter.swaggerGeneratedUnknown: null,
  ItemFilter.isfolder: 'IsFolder',
  ItemFilter.isnotfolder: 'IsNotFolder',
  ItemFilter.isunplayed: 'IsUnplayed',
  ItemFilter.isplayed: 'IsPlayed',
  ItemFilter.isfavorite: 'IsFavorite',
  ItemFilter.isresumable: 'IsResumable',
  ItemFilter.likes: 'Likes',
  ItemFilter.dislikes: 'Dislikes',
  ItemFilter.isfavoriteorlikes: 'IsFavoriteOrLikes',
};

const _$FladderItemTypeEnumMap = {
  KinosItemType.baseType: 'baseType',
  KinosItemType.audio: 'audio',
  KinosItemType.musicAlbum: 'musicAlbum',
  KinosItemType.musicArtist: 'musicArtist',
  KinosItemType.musicVideo: 'musicVideo',
  KinosItemType.collectionFolder: 'collectionFolder',
  KinosItemType.video: 'video',
  KinosItemType.movie: 'movie',
  KinosItemType.series: 'series',
  KinosItemType.season: 'season',
  KinosItemType.episode: 'episode',
  KinosItemType.photo: 'photo',
  KinosItemType.person: 'person',
  KinosItemType.photoAlbum: 'photoAlbum',
  KinosItemType.folder: 'folder',
  KinosItemType.boxset: 'boxset',
  KinosItemType.playlist: 'playlist',
  KinosItemType.book: 'book',
  KinosItemType.tvchannel: 'tvchannel',
};

const _$SortingOptionsEnumMap = {
  SortingOptions.sortName: 'sortName',
  SortingOptions.communityRating: 'communityRating',
  SortingOptions.parentalRating: 'parentalRating',
  SortingOptions.dateAdded: 'dateAdded',
  SortingOptions.dateLastContentAdded: 'dateLastContentAdded',
  SortingOptions.favorite: 'favorite',
  SortingOptions.datePlayed: 'datePlayed',
  SortingOptions.folders: 'folders',
  SortingOptions.playCount: 'playCount',
  SortingOptions.releaseDate: 'releaseDate',
  SortingOptions.runTime: 'runTime',
  SortingOptions.random: 'random',
};

const _$SortingOrderEnumMap = {
  SortingOrder.ascending: 'ascending',
  SortingOrder.descending: 'descending',
};

const _$GroupByEnumMap = {
  GroupBy.none: 'none',
  GroupBy.name: 'name',
  GroupBy.genres: 'genres',
  GroupBy.dateAdded: 'dateAdded',
  GroupBy.tags: 'tags',
  GroupBy.releaseDate: 'releaseDate',
  GroupBy.rating: 'rating',
  GroupBy.type: 'type',
};
