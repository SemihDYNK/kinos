import 'dart:developer';

import 'package:chopper/chopper.dart';
import 'package:logging/logging.dart' as logging;
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:kinos/jellyfin/jellyfin_open_api.swagger.dart';
import 'package:kinos/models/item_base_model.dart';
import 'package:kinos/models/items/item_shared_models.dart';
import 'package:kinos/models/items/media_streams_model.dart';
import 'package:kinos/models/items/movie_model.dart';
import 'package:kinos/models/items/special_feature_model.dart';
import 'package:kinos/models/seerr/seerr_dashboard_model.dart';
import 'package:kinos/providers/api_provider.dart';
import 'package:kinos/providers/related_provider.dart';
import 'package:kinos/providers/seerr_api_provider.dart';
import 'package:kinos/providers/service_provider.dart';
import 'package:kinos/providers/user_provider.dart';
import 'package:kinos/seerr/seerr_models.dart';
import 'package:kinos/util/item_base_model/item_base_model_extensions.dart';

part 'movies_details_provider.g.dart';

@riverpod
class MovieDetails extends _$MovieDetails {
  late final JellyService api = ref.read(jellyApiProvider);

  @override
  MovieModel? build(String arg) => null;

  Future<Response?> fetchDetails(ItemBaseModel item) async {
    try {
      if (item is MovieModel) {
        state = state ?? item;
      }
      MovieModel? newState;
      final response = await api.usersUserIdItemsItemIdGet(itemId: item.id);
      if (response.body == null) return null;
      newState = (response.bodyOrThrow as MovieModel).copyWith(
        related: state?.related ?? const [],
        seerrRelated: state?.seerrRelated ?? const [],
        seerrRecommended: state?.seerrRecommended ?? const [],
      );

      state = newState;

      List<BaseItemDto> specialFeatures;
      try {
        specialFeatures =
            (await api.itemsItemIdSpecialFeaturesGet(itemId: item.id)).body ??
                [];
      } on Exception catch (e, s) {
        specialFeatures = [];
        log("Failed to get special features for movie id ${item.id} due to $e",
            level: logging.Level.WARNING.value, error: e, stackTrace: s);
      }

      final related =
          await ref.read(relatedUtilityProvider).relatedContent(item.id);
      final List<SpecialFeatureModel> specialFeatureModel =
          SpecialFeatureModel.specialFeaturesFromDto(specialFeatures, ref)
              .toList();

      List<SeerrDashboardPosterModel> seerrRelated = const [];
      List<SeerrDashboardPosterModel> seerrRecommended = const [];

      String? seerrUrl;

      final seerrCreds = ref.read(userProvider)?.seerrCredentials;
      if (seerrCreds?.isConfigured == true) {
        final tmdbId = newState.tmdbId;
        if (tmdbId != null) {
          final seerr = ref.read(seerrApiProvider);
          seerrRelated = await seerr.discoverRelatedMovies(tmdbId: tmdbId);
          seerrRecommended =
              await seerr.discoverRecommendedMovies(tmdbId: tmdbId);
          final seerrPoster = await seerr.fetchDashboardPosterFromIds(
            tmdbId: tmdbId,
            mediaType: SeerrMediaType.movie,
          );
          final status = seerrPoster?.mediaInfo?.mediaStatus;
          if (status != SeerrMediaStatus.unknown) {
            final seerrServerUrl = ref.read(userProvider
                .select((value) => value?.seerrCredentials?.serverUrl));
            seerrUrl = '${seerrServerUrl}movie/$tmdbId';
          }
        }
      }

      state = newState.copyWith(
          related: related.body,
          seerrRelated: seerrRelated,
          seerrRecommended: seerrRecommended,
          overview: state?.overview.copyWith(
            seerrUrl: seerrUrl,
          ),
          specialFeatures: specialFeatureModel);
      return null;
    } catch (e, s) {
      // Repli silencieux avant, sans trace — un échec ici (réseau,
      // décodage...) laissait `state` à null indéfiniment, sans le moindre
      // indice en console. Même traitement que series_details_provider.dart.
      log("Error fetching movie details: $e",
          level: logging.Level.WARNING.value, error: e, stackTrace: s);
      return null;
    }
  }

  void updateUserData(ItemBaseModel item, UserData userData) {
    final current = state ?? item;
    if (current is MovieModel) {
      state = current.copyWith(userData: userData);
    }
  }

  void setMediaStreamHelper(MediaStreamsModel changed) {
    state = state?.copyWith(mediaStreams: changed);
  }
}
