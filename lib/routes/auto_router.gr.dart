// dart format width=80
// GENERATED CODE - DO NOT MODIFY BY HAND

// **************************************************************************
// AutoRouterGenerator
// **************************************************************************

// ignore_for_file: type=lint
// coverage:ignore-file

// ignore_for_file: no_leading_underscores_for_library_prefixes
import 'package:auto_route/auto_route.dart' as _i37;
import 'package:collection/collection.dart' as _i46;
import 'package:flutter/foundation.dart' as _i42;
import 'package:flutter/material.dart' as _i39;
import 'package:kinos/arr/models/arr_service.dart' as _i38;
import 'package:kinos/arr/screens/arr_detail_screen.dart' as _i2;
import 'package:kinos/arr/screens/arr_home_screen.dart' as _i3;
import 'package:kinos/arr/screens/arr_search_screen.dart' as _i4;
import 'package:kinos/arr/screens/arr_settings_screen.dart' as _i5;
import 'package:kinos/arr/screens/arr_title_details_screen.dart' as _i6;
import 'package:kinos/jellyfin/jellyfin_open_api.enums.swagger.dart' as _i45;
import 'package:kinos/models/item_base_model.dart' as _i41;
import 'package:kinos/models/items/images_models.dart' as _i40;
import 'package:kinos/models/items/item_shared_models.dart' as _i44;
import 'package:kinos/models/items/photo_queue_source.dart' as _i48;
import 'package:kinos/models/items/photos_model.dart' as _i47;
import 'package:kinos/models/library_search/library_search_options.dart'
    as _i43;
import 'package:kinos/models/seerr/seerr_dashboard_model.dart' as _i49;
import 'package:kinos/routes/nested_details_screen.dart' as _i18;
import 'package:kinos/screens/control_panel/control_active_tasks_page.dart'
    as _i8;
import 'package:kinos/screens/control_panel/control_dashboard_page.dart' as _i9;
import 'package:kinos/screens/control_panel/control_libraries_page.dart'
    as _i10;
import 'package:kinos/screens/control_panel/control_livetv_page.dart' as _i11;
import 'package:kinos/screens/control_panel/control_panel_screen.dart' as _i12;
import 'package:kinos/screens/control_panel/control_panel_selection_screen.dart'
    as _i13;
import 'package:kinos/screens/control_panel/control_server_page.dart' as _i14;
import 'package:kinos/screens/control_panel/control_user_edit_page.dart'
    as _i15;
import 'package:kinos/screens/control_panel/control_users_page.dart' as _i16;
import 'package:kinos/screens/dashboard/dashboard_screen.dart' as _i17;
import 'package:kinos/screens/favourites/favourites_screen.dart' as _i19;
import 'package:kinos/screens/home_screen.dart' as _i21;
import 'package:kinos/screens/library/library_screen.dart' as _i22;
import 'package:kinos/screens/library_search/library_search_screen.dart'
    as _i23;
import 'package:kinos/screens/live_tv/live_tv_screen.dart' as _i24;
import 'package:kinos/screens/login/lock_screen.dart' as _i25;
import 'package:kinos/screens/login/login_screen.dart' as _i26;
import 'package:kinos/screens/photo_viewer/photo_viewer_screen.dart' as _i27;
import 'package:kinos/screens/seerr/seerr_details_screen.dart' as _i30;
import 'package:kinos/screens/seerr/seerr_screen.dart' as _i31;
import 'package:kinos/screens/seerr/seerr_search_screen.dart' as _i32;
import 'package:kinos/screens/settings/about_settings_page.dart' as _i1;
import 'package:kinos/screens/settings/client_settings_page.dart' as _i7;
import 'package:kinos/screens/settings/home_rows_settings_screen.dart' as _i20;
import 'package:kinos/screens/settings/player_settings_page.dart' as _i28;
import 'package:kinos/screens/settings/profile_settings_page.dart' as _i29;
import 'package:kinos/screens/settings/settings_screen.dart' as _i33;
import 'package:kinos/screens/settings/settings_selection_screen.dart' as _i34;
import 'package:kinos/screens/splash_screen.dart' as _i35;
import 'package:kinos/screens/syncing/synced_screen.dart' as _i36;
import 'package:kinos/seerr/seerr_models.dart' as _i50;
import 'package:kinos/jellyfin/jellyfin_open_api.enums.swagger.dart' as _i51;
import 'package:kinos/letterboxd/home/letterboxd_watchlist_screen.dart'
    as _i52;
import 'package:kinos/models/items/images_models.dart' as _i53;
import 'package:kinos/screens/dashboard/genre_page_screen.dart' as _i54;

/// generated route for
/// [_i1.AboutSettingsPage]
class AboutSettingsRoute extends _i37.PageRouteInfo<void> {
  const AboutSettingsRoute({List<_i37.PageRouteInfo>? children})
      : super(AboutSettingsRoute.name, initialChildren: children);

  static const String name = 'AboutSettingsRoute';

  static _i37.PageInfo page = _i37.PageInfo(
    name,
    builder: (data) {
      return const _i1.AboutSettingsPage();
    },
  );
}

/// generated route for
/// [_i2.ArrDetailScreen]
class ArrDetailRoute extends _i37.PageRouteInfo<ArrDetailRouteArgs> {
  ArrDetailRoute({
    required _i38.ArrService service,
    required int id,
    bool autoExpandSearch = false,
    int? initialSearchEpisodeId,
    _i39.Key? key,
    List<_i37.PageRouteInfo>? children,
  }) : super(
          ArrDetailRoute.name,
          args: ArrDetailRouteArgs(
            service: service,
            id: id,
            autoExpandSearch: autoExpandSearch,
            initialSearchEpisodeId: initialSearchEpisodeId,
            key: key,
          ),
          initialChildren: children,
        );

  static const String name = 'ArrDetailRoute';

  static _i37.PageInfo page = _i37.PageInfo(
    name,
    builder: (data) {
      final args = data.argsAs<ArrDetailRouteArgs>();
      return _i2.ArrDetailScreen(
        service: args.service,
        id: args.id,
        autoExpandSearch: args.autoExpandSearch,
        initialSearchEpisodeId: args.initialSearchEpisodeId,
        key: args.key,
      );
    },
  );
}

class ArrDetailRouteArgs {
  const ArrDetailRouteArgs({
    required this.service,
    required this.id,
    this.autoExpandSearch = false,
    this.initialSearchEpisodeId,
    this.key,
  });

  final _i38.ArrService service;

  final int id;

  final bool autoExpandSearch;

  final int? initialSearchEpisodeId;

  final _i39.Key? key;

  @override
  String toString() {
    return 'ArrDetailRouteArgs{service: $service, id: $id, autoExpandSearch: $autoExpandSearch, initialSearchEpisodeId: $initialSearchEpisodeId, key: $key}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! ArrDetailRouteArgs) return false;
    return service == other.service &&
        id == other.id &&
        autoExpandSearch == other.autoExpandSearch &&
        initialSearchEpisodeId == other.initialSearchEpisodeId &&
        key == other.key;
  }

  @override
  int get hashCode =>
      service.hashCode ^
      id.hashCode ^
      autoExpandSearch.hashCode ^
      initialSearchEpisodeId.hashCode ^
      key.hashCode;
}

/// generated route for
/// [_i3.ArrHomeScreen]
class ArrHomeRoute extends _i37.PageRouteInfo<void> {
  const ArrHomeRoute({List<_i37.PageRouteInfo>? children})
      : super(ArrHomeRoute.name, initialChildren: children);

  static const String name = 'ArrHomeRoute';

  static _i37.PageInfo page = _i37.PageInfo(
    name,
    builder: (data) {
      return const _i3.ArrHomeScreen();
    },
  );
}

/// generated route for
/// [_i4.ArrSearchScreen]
class ArrSearchRoute extends _i37.PageRouteInfo<void> {
  const ArrSearchRoute({List<_i37.PageRouteInfo>? children})
      : super(ArrSearchRoute.name, initialChildren: children);

  static const String name = 'ArrSearchRoute';

  static _i37.PageInfo page = _i37.PageInfo(
    name,
    builder: (data) {
      return const _i4.ArrSearchScreen();
    },
  );
}

/// generated route for
/// [_i5.ArrSettingsScreen]
class ArrSettingsRoute extends _i37.PageRouteInfo<void> {
  const ArrSettingsRoute({List<_i37.PageRouteInfo>? children})
      : super(ArrSettingsRoute.name, initialChildren: children);

  static const String name = 'ArrSettingsRoute';

  static _i37.PageInfo page = _i37.PageInfo(
    name,
    builder: (data) {
      return const _i5.ArrSettingsScreen();
    },
  );
}

/// generated route for
/// [_i6.ArrTitleDetailsScreen]
class ArrTitleDetailsRoute
    extends _i37.PageRouteInfo<ArrTitleDetailsRouteArgs> {
  ArrTitleDetailsRoute({
    required _i38.ArrService service,
    required int id,
    required String title,
    _i40.ImageData? image,
    Object? tag,
    _i39.Key? key,
    List<_i37.PageRouteInfo>? children,
  }) : super(
          ArrTitleDetailsRoute.name,
          args: ArrTitleDetailsRouteArgs(
            service: service,
            id: id,
            title: title,
            image: image,
            tag: tag,
            key: key,
          ),
          initialChildren: children,
        );

  static const String name = 'ArrTitleDetailsRoute';

  static _i37.PageInfo page = _i37.PageInfo(
    name,
    builder: (data) {
      final args = data.argsAs<ArrTitleDetailsRouteArgs>();
      return _i6.ArrTitleDetailsScreen(
        service: args.service,
        id: args.id,
        title: args.title,
        image: args.image,
        tag: args.tag,
        key: args.key,
      );
    },
  );
}

class ArrTitleDetailsRouteArgs {
  const ArrTitleDetailsRouteArgs({
    required this.service,
    required this.id,
    required this.title,
    this.image,
    this.tag,
    this.key,
  });

  final _i38.ArrService service;

  final int id;

  final String title;

  final _i40.ImageData? image;

  final Object? tag;

  final _i39.Key? key;

  @override
  String toString() {
    return 'ArrTitleDetailsRouteArgs{service: $service, id: $id, title: $title, image: $image, tag: $tag, key: $key}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! ArrTitleDetailsRouteArgs) return false;
    return service == other.service &&
        id == other.id &&
        title == other.title &&
        image == other.image &&
        tag == other.tag &&
        key == other.key;
  }

  @override
  int get hashCode =>
      service.hashCode ^
      id.hashCode ^
      title.hashCode ^
      image.hashCode ^
      tag.hashCode ^
      key.hashCode;
}

/// generated route for
/// [_i7.ClientSettingsPage]
class ClientSettingsRoute extends _i37.PageRouteInfo<void> {
  const ClientSettingsRoute({List<_i37.PageRouteInfo>? children})
      : super(ClientSettingsRoute.name, initialChildren: children);

  static const String name = 'ClientSettingsRoute';

  static _i37.PageInfo page = _i37.PageInfo(
    name,
    builder: (data) {
      return const _i7.ClientSettingsPage();
    },
  );
}

/// generated route for
/// [_i8.ControlActiveTasksPage]
class ControlActiveTasksRoute extends _i37.PageRouteInfo<void> {
  const ControlActiveTasksRoute({List<_i37.PageRouteInfo>? children})
      : super(ControlActiveTasksRoute.name, initialChildren: children);

  static const String name = 'ControlActiveTasksRoute';

  static _i37.PageInfo page = _i37.PageInfo(
    name,
    builder: (data) {
      return const _i8.ControlActiveTasksPage();
    },
  );
}

/// generated route for
/// [_i9.ControlDashboardPage]
class ControlDashboardRoute extends _i37.PageRouteInfo<void> {
  const ControlDashboardRoute({List<_i37.PageRouteInfo>? children})
      : super(ControlDashboardRoute.name, initialChildren: children);

  static const String name = 'ControlDashboardRoute';

  static _i37.PageInfo page = _i37.PageInfo(
    name,
    builder: (data) {
      return const _i9.ControlDashboardPage();
    },
  );
}

/// generated route for
/// [_i10.ControlLibrariesPage]
class ControlLibrariesRoute extends _i37.PageRouteInfo<void> {
  const ControlLibrariesRoute({List<_i37.PageRouteInfo>? children})
      : super(ControlLibrariesRoute.name, initialChildren: children);

  static const String name = 'ControlLibrariesRoute';

  static _i37.PageInfo page = _i37.PageInfo(
    name,
    builder: (data) {
      return const _i10.ControlLibrariesPage();
    },
  );
}

/// generated route for
/// [_i11.ControlLiveTvPage]
class ControlLiveTvRoute extends _i37.PageRouteInfo<void> {
  const ControlLiveTvRoute({List<_i37.PageRouteInfo>? children})
      : super(ControlLiveTvRoute.name, initialChildren: children);

  static const String name = 'ControlLiveTvRoute';

  static _i37.PageInfo page = _i37.PageInfo(
    name,
    builder: (data) {
      return const _i11.ControlLiveTvPage();
    },
  );
}

/// generated route for
/// [_i12.ControlPanelScreen]
class ControlPanelRoute extends _i37.PageRouteInfo<void> {
  const ControlPanelRoute({List<_i37.PageRouteInfo>? children})
      : super(ControlPanelRoute.name, initialChildren: children);

  static const String name = 'ControlPanelRoute';

  static _i37.PageInfo page = _i37.PageInfo(
    name,
    builder: (data) {
      return const _i12.ControlPanelScreen();
    },
  );
}

/// generated route for
/// [_i13.ControlPanelSelectionScreen]
class ControlPanelSelectionRoute extends _i37.PageRouteInfo<void> {
  const ControlPanelSelectionRoute({List<_i37.PageRouteInfo>? children})
      : super(ControlPanelSelectionRoute.name, initialChildren: children);

  static const String name = 'ControlPanelSelectionRoute';

  static _i37.PageInfo page = _i37.PageInfo(
    name,
    builder: (data) {
      return const _i13.ControlPanelSelectionScreen();
    },
  );
}

/// generated route for
/// [_i14.ControlServerPage]
class ControlServerRoute extends _i37.PageRouteInfo<void> {
  const ControlServerRoute({List<_i37.PageRouteInfo>? children})
      : super(ControlServerRoute.name, initialChildren: children);

  static const String name = 'ControlServerRoute';

  static _i37.PageInfo page = _i37.PageInfo(
    name,
    builder: (data) {
      return const _i14.ControlServerPage();
    },
  );
}

/// generated route for
/// [_i15.ControlUserEditPage]
class ControlUserEditRoute
    extends _i37.PageRouteInfo<ControlUserEditRouteArgs> {
  ControlUserEditRoute({
    String? userId,
    _i39.Key? key,
    List<_i37.PageRouteInfo>? children,
  }) : super(
          ControlUserEditRoute.name,
          args: ControlUserEditRouteArgs(userId: userId, key: key),
          rawQueryParams: {'userId': userId},
          initialChildren: children,
        );

  static const String name = 'ControlUserEditRoute';

  static _i37.PageInfo page = _i37.PageInfo(
    name,
    builder: (data) {
      final queryParams = data.queryParams;
      final args = data.argsAs<ControlUserEditRouteArgs>(
        orElse: () =>
            ControlUserEditRouteArgs(userId: queryParams.optString('userId')),
      );
      return _i15.ControlUserEditPage(userId: args.userId, key: args.key);
    },
  );
}

class ControlUserEditRouteArgs {
  const ControlUserEditRouteArgs({this.userId, this.key});

  final String? userId;

  final _i39.Key? key;

  @override
  String toString() {
    return 'ControlUserEditRouteArgs{userId: $userId, key: $key}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! ControlUserEditRouteArgs) return false;
    return userId == other.userId && key == other.key;
  }

  @override
  int get hashCode => userId.hashCode ^ key.hashCode;
}

/// generated route for
/// [_i16.ControlUsersPage]
class ControlUsersRoute extends _i37.PageRouteInfo<void> {
  const ControlUsersRoute({List<_i37.PageRouteInfo>? children})
      : super(ControlUsersRoute.name, initialChildren: children);

  static const String name = 'ControlUsersRoute';

  static _i37.PageInfo page = _i37.PageInfo(
    name,
    builder: (data) {
      return const _i16.ControlUsersPage();
    },
  );
}

/// generated route for
/// [_i17.DashboardScreen]
class DashboardRoute extends _i37.PageRouteInfo<void> {
  const DashboardRoute({List<_i37.PageRouteInfo>? children})
      : super(DashboardRoute.name, initialChildren: children);

  static const String name = 'DashboardRoute';

  static _i37.PageInfo page = _i37.PageInfo(
    name,
    builder: (data) {
      return const _i17.DashboardScreen();
    },
  );
}

/// generated route for
/// [_i18.DetailsScreen]
class DetailsRoute extends _i37.PageRouteInfo<DetailsRouteArgs> {
  DetailsRoute({
    String id = '',
    _i41.ItemBaseModel? item,
    Object? tag,
    _i42.Key? key,
    List<_i37.PageRouteInfo>? children,
  }) : super(
          DetailsRoute.name,
          args: DetailsRouteArgs(id: id, item: item, tag: tag, key: key),
          rawQueryParams: {'id': id},
          initialChildren: children,
        );

  static const String name = 'DetailsRoute';

  static _i37.PageInfo page = _i37.PageInfo(
    name,
    builder: (data) {
      final queryParams = data.queryParams;
      final args = data.argsAs<DetailsRouteArgs>(
        orElse: () => DetailsRouteArgs(id: queryParams.getString('id', '')),
      );
      return _i18.DetailsScreen(
        id: args.id,
        item: args.item,
        tag: args.tag,
        key: args.key,
      );
    },
  );
}

class DetailsRouteArgs {
  const DetailsRouteArgs({this.id = '', this.item, this.tag, this.key});

  final String id;

  final _i41.ItemBaseModel? item;

  final Object? tag;

  final _i42.Key? key;

  @override
  String toString() {
    return 'DetailsRouteArgs{id: $id, item: $item, tag: $tag, key: $key}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! DetailsRouteArgs) return false;
    return id == other.id &&
        item == other.item &&
        tag == other.tag &&
        key == other.key;
  }

  @override
  int get hashCode => id.hashCode ^ item.hashCode ^ tag.hashCode ^ key.hashCode;
}

/// generated route for
/// [_i19.FavouritesScreen]
class FavouritesRoute extends _i37.PageRouteInfo<void> {
  const FavouritesRoute({List<_i37.PageRouteInfo>? children})
      : super(FavouritesRoute.name, initialChildren: children);

  static const String name = 'FavouritesRoute';

  static _i37.PageInfo page = _i37.PageInfo(
    name,
    builder: (data) {
      return const _i19.FavouritesScreen();
    },
  );
}

/// generated route for
/// [_i54.GenrePageScreen]
class GenrePageRoute extends _i37.PageRouteInfo<GenrePageRouteArgs> {
  GenrePageRoute({
    required String label,
    required List<String> names,
    _i51.BaseItemKind? kind,
    String? libraryId,
    _i53.ImageData? image,
    _i39.Key? key,
    List<_i37.PageRouteInfo>? children,
  }) : super(
          GenrePageRoute.name,
          args: GenrePageRouteArgs(
            label: label,
            names: names,
            kind: kind,
            libraryId: libraryId,
            image: image,
            key: key,
          ),
          initialChildren: children,
        );

  static const String name = 'GenrePageRoute';

  static _i37.PageInfo page = _i37.PageInfo(
    name,
    builder: (data) {
      final args = data.argsAs<GenrePageRouteArgs>();
      return _i54.GenrePageScreen(
        label: args.label,
        names: args.names,
        kind: args.kind,
        libraryId: args.libraryId,
        image: args.image,
        key: args.key,
      );
    },
  );
}

class GenrePageRouteArgs {
  const GenrePageRouteArgs({
    required this.label,
    required this.names,
    this.kind,
    this.libraryId,
    this.image,
    this.key,
  });

  final String label;

  final List<String> names;

  final _i51.BaseItemKind? kind;

  final String? libraryId;

  final _i53.ImageData? image;

  final _i39.Key? key;

  @override
  String toString() {
    return 'GenrePageRouteArgs{label: $label, names: $names, kind: $kind, libraryId: $libraryId, image: $image, key: $key}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! GenrePageRouteArgs) return false;
    return label == other.label &&
        names == other.names &&
        kind == other.kind &&
        libraryId == other.libraryId &&
        image == other.image &&
        key == other.key;
  }

  @override
  int get hashCode =>
      label.hashCode ^
      names.hashCode ^
      kind.hashCode ^
      libraryId.hashCode ^
      image.hashCode ^
      key.hashCode;
}

/// generated route for
/// [_i20.HomeRowsSettingsScreen]
class HomeRowsSettingsRoute extends _i37.PageRouteInfo<void> {
  const HomeRowsSettingsRoute({List<_i37.PageRouteInfo>? children})
      : super(HomeRowsSettingsRoute.name, initialChildren: children);

  static const String name = 'HomeRowsSettingsRoute';

  static _i37.PageInfo page = _i37.PageInfo(
    name,
    builder: (data) {
      return const _i20.HomeRowsSettingsScreen();
    },
  );
}

/// generated route for
/// [_i21.HomeScreen]
class HomeRoute extends _i37.PageRouteInfo<void> {
  const HomeRoute({List<_i37.PageRouteInfo>? children})
      : super(HomeRoute.name, initialChildren: children);

  static const String name = 'HomeRoute';

  static _i37.PageInfo page = _i37.PageInfo(
    name,
    builder: (data) {
      return const _i21.HomeScreen();
    },
  );
}

/// generated route for
/// [_i52.LetterboxdWatchlistScreen]
class LetterboxdWatchlistRoute extends _i37.PageRouteInfo<void> {
  const LetterboxdWatchlistRoute({List<_i37.PageRouteInfo>? children})
      : super(LetterboxdWatchlistRoute.name, initialChildren: children);

  static const String name = 'LetterboxdWatchlistRoute';

  static _i37.PageInfo page = _i37.PageInfo(
    name,
    builder: (data) {
      return const _i52.LetterboxdWatchlistScreen();
    },
  );
}

/// generated route for
/// [_i22.LibraryScreen]
class LibraryRoute extends _i37.PageRouteInfo<void> {
  const LibraryRoute({List<_i37.PageRouteInfo>? children})
      : super(LibraryRoute.name, initialChildren: children);

  static const String name = 'LibraryRoute';

  static _i37.PageInfo page = _i37.PageInfo(
    name,
    builder: (data) {
      return const _i22.LibraryScreen();
    },
  );
}

/// generated route for
/// [_i23.LibrarySearchScreen]
class LibrarySearchRoute extends _i37.PageRouteInfo<LibrarySearchRouteArgs> {
  LibrarySearchRoute({
    String? query,
    List<String>? parentId,
    bool? favourites,
    _i43.SortingOrder? sortOrder,
    _i43.SortingOptions? sortingOptions,
    Map<_i41.KinosItemType, bool>? types,
    Map<String, bool>? genres,
    Map<_i44.Studio, bool>? studios,
    Map<_i45.ItemFilter, bool>? itemFilters,
    Map<String, bool>? tags,
    Map<int, bool>? years,
    bool? recursive,
    bool? isDefault,
    _i42.Key? key,
    List<_i37.PageRouteInfo>? children,
  }) : super(
          LibrarySearchRoute.name,
          args: LibrarySearchRouteArgs(
            query: query,
            parentId: parentId,
            favourites: favourites,
            sortOrder: sortOrder,
            sortingOptions: sortingOptions,
            types: types,
            genres: genres,
            studios: studios,
            itemFilters: itemFilters,
            tags: tags,
            years: years,
            recursive: recursive,
            isDefault: isDefault,
            key: key,
          ),
          rawQueryParams: {
            'query': query,
            'parentId': parentId,
            'favourites': favourites,
            'sortOrder': sortOrder,
            'sortOptions': sortingOptions,
            'itemTypes': types,
            'genres': genres,
            'studios': studios,
            'itemFilters': itemFilters,
            'tags': tags,
            'years': years,
            'recursive': recursive,
            'isDefault': isDefault,
          },
          initialChildren: children,
        );

  static const String name = 'LibrarySearchRoute';

  static _i37.PageInfo page = _i37.PageInfo(
    name,
    builder: (data) {
      final queryParams = data.queryParams;
      final args = data.argsAs<LibrarySearchRouteArgs>(
        orElse: () => LibrarySearchRouteArgs(
          query: queryParams.optString('query'),
          parentId: queryParams.optList('parentId'),
          favourites: queryParams.optBool('favourites'),
          sortOrder: queryParams.get('sortOrder'),
          sortingOptions: queryParams.get('sortOptions'),
          types: queryParams.get('itemTypes'),
          genres: queryParams.get('genres'),
          studios: queryParams.get('studios'),
          itemFilters: queryParams.get('itemFilters'),
          tags: queryParams.get('tags'),
          years: queryParams.get('years'),
          recursive: queryParams.optBool('recursive'),
          isDefault: queryParams.optBool('isDefault'),
        ),
      );
      return _i23.LibrarySearchScreen(
        query: args.query,
        parentId: args.parentId,
        favourites: args.favourites,
        sortOrder: args.sortOrder,
        sortingOptions: args.sortingOptions,
        types: args.types,
        genres: args.genres,
        studios: args.studios,
        itemFilters: args.itemFilters,
        tags: args.tags,
        years: args.years,
        recursive: args.recursive,
        isDefault: args.isDefault,
        key: args.key,
      );
    },
  );
}

class LibrarySearchRouteArgs {
  const LibrarySearchRouteArgs({
    this.query,
    this.parentId,
    this.favourites,
    this.sortOrder,
    this.sortingOptions,
    this.types,
    this.genres,
    this.studios,
    this.itemFilters,
    this.tags,
    this.years,
    this.recursive,
    this.isDefault,
    this.key,
  });

  final String? query;

  final List<String>? parentId;

  final bool? favourites;

  final _i43.SortingOrder? sortOrder;

  final _i43.SortingOptions? sortingOptions;

  final Map<_i41.KinosItemType, bool>? types;

  final Map<String, bool>? genres;

  final Map<_i44.Studio, bool>? studios;

  final Map<_i45.ItemFilter, bool>? itemFilters;

  final Map<String, bool>? tags;

  final Map<int, bool>? years;

  final bool? recursive;

  final bool? isDefault;

  final _i42.Key? key;

  @override
  String toString() {
    return 'LibrarySearchRouteArgs{query: $query, parentId: $parentId, favourites: $favourites, sortOrder: $sortOrder, sortingOptions: $sortingOptions, types: $types, genres: $genres, studios: $studios, itemFilters: $itemFilters, tags: $tags, years: $years, recursive: $recursive, isDefault: $isDefault, key: $key}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! LibrarySearchRouteArgs) return false;
    return query == other.query &&
        const _i46.ListEquality().equals(parentId, other.parentId) &&
        favourites == other.favourites &&
        sortOrder == other.sortOrder &&
        sortingOptions == other.sortingOptions &&
        const _i46.MapEquality().equals(types, other.types) &&
        const _i46.MapEquality().equals(genres, other.genres) &&
        const _i46.MapEquality().equals(studios, other.studios) &&
        const _i46.MapEquality().equals(itemFilters, other.itemFilters) &&
        const _i46.MapEquality().equals(tags, other.tags) &&
        const _i46.MapEquality().equals(years, other.years) &&
        recursive == other.recursive &&
        isDefault == other.isDefault &&
        key == other.key;
  }

  @override
  int get hashCode =>
      query.hashCode ^
      const _i46.ListEquality().hash(parentId) ^
      favourites.hashCode ^
      sortOrder.hashCode ^
      sortingOptions.hashCode ^
      const _i46.MapEquality().hash(types) ^
      const _i46.MapEquality().hash(genres) ^
      const _i46.MapEquality().hash(studios) ^
      const _i46.MapEquality().hash(itemFilters) ^
      const _i46.MapEquality().hash(tags) ^
      const _i46.MapEquality().hash(years) ^
      recursive.hashCode ^
      isDefault.hashCode ^
      key.hashCode;
}

/// generated route for
/// [_i24.LiveTvScreen]
class LiveTvRoute extends _i37.PageRouteInfo<LiveTvRouteArgs> {
  LiveTvRoute({
    String viewId = "",
    _i39.Key? key,
    List<_i37.PageRouteInfo>? children,
  }) : super(
          LiveTvRoute.name,
          args: LiveTvRouteArgs(viewId: viewId, key: key),
          rawQueryParams: {'viewId': viewId},
          initialChildren: children,
        );

  static const String name = 'LiveTvRoute';

  static _i37.PageInfo page = _i37.PageInfo(
    name,
    builder: (data) {
      final queryParams = data.queryParams;
      final args = data.argsAs<LiveTvRouteArgs>(
        orElse: () =>
            LiveTvRouteArgs(viewId: queryParams.getString('viewId', "")),
      );
      return _i24.LiveTvScreen(viewId: args.viewId, key: args.key);
    },
  );
}

class LiveTvRouteArgs {
  const LiveTvRouteArgs({this.viewId = "", this.key});

  final String viewId;

  final _i39.Key? key;

  @override
  String toString() {
    return 'LiveTvRouteArgs{viewId: $viewId, key: $key}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! LiveTvRouteArgs) return false;
    return viewId == other.viewId && key == other.key;
  }

  @override
  int get hashCode => viewId.hashCode ^ key.hashCode;
}

/// generated route for
/// [_i25.LockScreen]
class LockRoute extends _i37.PageRouteInfo<void> {
  const LockRoute({List<_i37.PageRouteInfo>? children})
      : super(LockRoute.name, initialChildren: children);

  static const String name = 'LockRoute';

  static _i37.PageInfo page = _i37.PageInfo(
    name,
    builder: (data) {
      return const _i25.LockScreen();
    },
  );
}

/// generated route for
/// [_i26.LoginScreen]
class LoginRoute extends _i37.PageRouteInfo<LoginRouteArgs> {
  LoginRoute({
    String? authLink,
    _i39.Key? key,
    List<_i37.PageRouteInfo>? children,
  }) : super(
          LoginRoute.name,
          args: LoginRouteArgs(authLink: authLink, key: key),
          rawQueryParams: {'authLink': authLink},
          initialChildren: children,
        );

  static const String name = 'LoginRoute';

  static _i37.PageInfo page = _i37.PageInfo(
    name,
    builder: (data) {
      final queryParams = data.queryParams;
      final args = data.argsAs<LoginRouteArgs>(
        orElse: () =>
            LoginRouteArgs(authLink: queryParams.optString('authLink')),
      );
      return _i26.LoginScreen(authLink: args.authLink, key: args.key);
    },
  );
}

class LoginRouteArgs {
  const LoginRouteArgs({this.authLink, this.key});

  final String? authLink;

  final _i39.Key? key;

  @override
  String toString() {
    return 'LoginRouteArgs{authLink: $authLink, key: $key}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! LoginRouteArgs) return false;
    return authLink == other.authLink && key == other.key;
  }

  @override
  int get hashCode => authLink.hashCode ^ key.hashCode;
}

/// generated route for
/// [_i27.PhotoViewerScreen]
class PhotoViewerRoute extends _i37.PageRouteInfo<PhotoViewerRouteArgs> {
  PhotoViewerRoute({
    List<_i47.PhotoModel>? items,
    String? selected,
    _i48.PhotoQueueSource? photoQueueSource,
    _i39.Key? key,
    List<_i37.PageRouteInfo>? children,
  }) : super(
          PhotoViewerRoute.name,
          args: PhotoViewerRouteArgs(
            items: items,
            selected: selected,
            photoQueueSource: photoQueueSource,
            key: key,
          ),
          rawQueryParams: {'selectedId': selected},
          initialChildren: children,
        );

  static const String name = 'PhotoViewerRoute';

  static _i37.PageInfo page = _i37.PageInfo(
    name,
    builder: (data) {
      final queryParams = data.queryParams;
      final args = data.argsAs<PhotoViewerRouteArgs>(
        orElse: () =>
            PhotoViewerRouteArgs(selected: queryParams.optString('selectedId')),
      );
      return _i27.PhotoViewerScreen(
        items: args.items,
        selected: args.selected,
        photoQueueSource: args.photoQueueSource,
        key: args.key,
      );
    },
  );
}

class PhotoViewerRouteArgs {
  const PhotoViewerRouteArgs({
    this.items,
    this.selected,
    this.photoQueueSource,
    this.key,
  });

  final List<_i47.PhotoModel>? items;

  final String? selected;

  final _i48.PhotoQueueSource? photoQueueSource;

  final _i39.Key? key;

  @override
  String toString() {
    return 'PhotoViewerRouteArgs{items: $items, selected: $selected, photoQueueSource: $photoQueueSource, key: $key}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! PhotoViewerRouteArgs) return false;
    return const _i46.ListEquality().equals(items, other.items) &&
        selected == other.selected &&
        photoQueueSource == other.photoQueueSource &&
        key == other.key;
  }

  @override
  int get hashCode =>
      const _i46.ListEquality().hash(items) ^
      selected.hashCode ^
      photoQueueSource.hashCode ^
      key.hashCode;
}

/// generated route for
/// [_i28.PlayerSettingsPage]
class PlayerSettingsRoute extends _i37.PageRouteInfo<void> {
  const PlayerSettingsRoute({List<_i37.PageRouteInfo>? children})
      : super(PlayerSettingsRoute.name, initialChildren: children);

  static const String name = 'PlayerSettingsRoute';

  static _i37.PageInfo page = _i37.PageInfo(
    name,
    builder: (data) {
      return const _i28.PlayerSettingsPage();
    },
  );
}

/// generated route for
/// [_i29.ProfileSettingsPage]
class ProfileSettingsRoute extends _i37.PageRouteInfo<void> {
  const ProfileSettingsRoute({List<_i37.PageRouteInfo>? children})
      : super(ProfileSettingsRoute.name, initialChildren: children);

  static const String name = 'ProfileSettingsRoute';

  static _i37.PageInfo page = _i37.PageInfo(
    name,
    builder: (data) {
      return const _i29.ProfileSettingsPage();
    },
  );
}

/// generated route for
/// [_i30.SeerrDetailsScreen]
class SeerrDetailsRoute extends _i37.PageRouteInfo<SeerrDetailsRouteArgs> {
  SeerrDetailsRoute({
    required String mediaType,
    required int tmdbId,
    _i49.SeerrDashboardPosterModel? poster,
    Object? tag,
    _i39.Key? key,
    List<_i37.PageRouteInfo>? children,
  }) : super(
          SeerrDetailsRoute.name,
          args: SeerrDetailsRouteArgs(
            mediaType: mediaType,
            tmdbId: tmdbId,
            poster: poster,
            tag: tag,
            key: key,
          ),
          rawPathParams: {'mediaType': mediaType, 'tmdbId': tmdbId},
          initialChildren: children,
        );

  static const String name = 'SeerrDetailsRoute';

  static _i37.PageInfo page = _i37.PageInfo(
    name,
    builder: (data) {
      final pathParams = data.inheritedPathParams;
      final args = data.argsAs<SeerrDetailsRouteArgs>(
        orElse: () => SeerrDetailsRouteArgs(
          mediaType: pathParams.getString('mediaType'),
          tmdbId: pathParams.getInt('tmdbId'),
        ),
      );
      return _i30.SeerrDetailsScreen(
        mediaType: args.mediaType,
        tmdbId: args.tmdbId,
        poster: args.poster,
        tag: args.tag,
        key: args.key,
      );
    },
  );
}

class SeerrDetailsRouteArgs {
  const SeerrDetailsRouteArgs({
    required this.mediaType,
    required this.tmdbId,
    this.poster,
    this.tag,
    this.key,
  });

  final String mediaType;

  final int tmdbId;

  final _i49.SeerrDashboardPosterModel? poster;

  final Object? tag;

  final _i39.Key? key;

  @override
  String toString() {
    return 'SeerrDetailsRouteArgs{mediaType: $mediaType, tmdbId: $tmdbId, poster: $poster, tag: $tag, key: $key}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! SeerrDetailsRouteArgs) return false;
    return mediaType == other.mediaType &&
        tmdbId == other.tmdbId &&
        poster == other.poster &&
        tag == other.tag &&
        key == other.key;
  }

  @override
  int get hashCode =>
      mediaType.hashCode ^
      tmdbId.hashCode ^
      poster.hashCode ^
      tag.hashCode ^
      key.hashCode;
}

/// generated route for
/// [_i31.SeerrScreen]
class SeerrRoute extends _i37.PageRouteInfo<void> {
  const SeerrRoute({List<_i37.PageRouteInfo>? children})
      : super(SeerrRoute.name, initialChildren: children);

  static const String name = 'SeerrRoute';

  static _i37.PageInfo page = _i37.PageInfo(
    name,
    builder: (data) {
      return const _i31.SeerrScreen();
    },
  );
}

/// generated route for
/// [_i32.SeerrSearchScreen]
class SeerrSearchRoute extends _i37.PageRouteInfo<SeerrSearchRouteArgs> {
  SeerrSearchRoute({
    _i50.SeerrSearchMode? mode,
    int? yearGte,
    _i39.Key? key,
    List<_i37.PageRouteInfo>? children,
  }) : super(
          SeerrSearchRoute.name,
          args: SeerrSearchRouteArgs(mode: mode, yearGte: yearGte, key: key),
          rawQueryParams: {'mode': mode, 'yearGte': yearGte},
          initialChildren: children,
        );

  static const String name = 'SeerrSearchRoute';

  static _i37.PageInfo page = _i37.PageInfo(
    name,
    builder: (data) {
      final queryParams = data.queryParams;
      final args = data.argsAs<SeerrSearchRouteArgs>(
        orElse: () => SeerrSearchRouteArgs(
          mode: queryParams.get('mode'),
          yearGte: queryParams.optInt('yearGte'),
        ),
      );
      return _i32.SeerrSearchScreen(
        mode: args.mode,
        yearGte: args.yearGte,
        key: args.key,
      );
    },
  );
}

class SeerrSearchRouteArgs {
  const SeerrSearchRouteArgs({this.mode, this.yearGte, this.key});

  final _i50.SeerrSearchMode? mode;

  final int? yearGte;

  final _i39.Key? key;

  @override
  String toString() {
    return 'SeerrSearchRouteArgs{mode: $mode, yearGte: $yearGte, key: $key}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! SeerrSearchRouteArgs) return false;
    return mode == other.mode && yearGte == other.yearGte && key == other.key;
  }

  @override
  int get hashCode => mode.hashCode ^ yearGte.hashCode ^ key.hashCode;
}

/// generated route for
/// [_i33.SettingsScreen]
class SettingsRoute extends _i37.PageRouteInfo<void> {
  const SettingsRoute({List<_i37.PageRouteInfo>? children})
      : super(SettingsRoute.name, initialChildren: children);

  static const String name = 'SettingsRoute';

  static _i37.PageInfo page = _i37.PageInfo(
    name,
    builder: (data) {
      return const _i33.SettingsScreen();
    },
  );
}

/// generated route for
/// [_i34.SettingsSelectionScreen]
class SettingsSelectionRoute extends _i37.PageRouteInfo<void> {
  const SettingsSelectionRoute({List<_i37.PageRouteInfo>? children})
      : super(SettingsSelectionRoute.name, initialChildren: children);

  static const String name = 'SettingsSelectionRoute';

  static _i37.PageInfo page = _i37.PageInfo(
    name,
    builder: (data) {
      return const _i34.SettingsSelectionScreen();
    },
  );
}

/// generated route for
/// [_i35.SplashScreen]
class SplashRoute extends _i37.PageRouteInfo<SplashRouteArgs> {
  SplashRoute({
    dynamic Function(bool)? loggedIn,
    _i39.Key? key,
    List<_i37.PageRouteInfo>? children,
  }) : super(
          SplashRoute.name,
          args: SplashRouteArgs(loggedIn: loggedIn, key: key),
          initialChildren: children,
        );

  static const String name = 'SplashRoute';

  static _i37.PageInfo page = _i37.PageInfo(
    name,
    builder: (data) {
      final args = data.argsAs<SplashRouteArgs>(
        orElse: () => const SplashRouteArgs(),
      );
      return _i35.SplashScreen(loggedIn: args.loggedIn, key: args.key);
    },
  );
}

class SplashRouteArgs {
  const SplashRouteArgs({this.loggedIn, this.key});

  final dynamic Function(bool)? loggedIn;

  final _i39.Key? key;

  @override
  String toString() {
    return 'SplashRouteArgs{loggedIn: $loggedIn, key: $key}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! SplashRouteArgs) return false;
    return key == other.key;
  }

  @override
  int get hashCode => key.hashCode;
}

/// generated route for
/// [_i36.SyncedScreen]
class SyncedRoute extends _i37.PageRouteInfo<void> {
  const SyncedRoute({List<_i37.PageRouteInfo>? children})
      : super(SyncedRoute.name, initialChildren: children);

  static const String name = 'SyncedRoute';

  static _i37.PageInfo page = _i37.PageInfo(
    name,
    builder: (data) {
      return const _i36.SyncedScreen();
    },
  );
}
