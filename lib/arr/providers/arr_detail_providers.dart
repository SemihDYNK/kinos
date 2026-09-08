import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:fladder/arr/models/arr_media_detail.dart';
import 'package:fladder/arr/models/arr_service.dart';
import 'package:fladder/arr/providers/arr_search_providers.dart';
import 'package:fladder/arr/services/arr_api_client.dart';

/// Identifie une fiche détail — instance ET identifiant d'œuvre, jamais
/// partagé avec la grille bibliothèque ni la file d'attente (cf.
/// CLAUDE.md § notes Arr, le bug déjà rencontré avec un état partagé
/// entre onglets).
typedef ArrDetailKey = ({ArrService service, int id});

class ArrDetailState {
  final bool loading;
  final ArrApiError? error;
  final String? errorDetail;
  final ArrDetailEntry? entry;

  const ArrDetailState({
    this.loading = true,
    this.error,
    this.errorDetail,
    this.entry,
  });

  ArrDetailState copyWith({
    bool? loading,
    ArrApiError? error,
    bool clearError = false,
    String? errorDetail,
    ArrDetailEntry? entry,
  }) {
    return ArrDetailState(
      loading: loading ?? this.loading,
      error: clearError ? null : (error ?? this.error),
      errorDetail: clearError ? null : (errorDetail ?? this.errorDetail),
      entry: entry ?? this.entry,
    );
  }
}

/// Fiche détail d'une œuvre — `.family<ArrDetailKey>.autoDispose`, même
/// principe que [arrLibraryProvider] : jamais partagé entre deux œuvres,
/// ni avec la grille bibliothèque ou la file d'attente. Pas de
/// `keepAlive` (contrairement à [arrLibraryProvider]) : une fiche détail
/// est feuilletée puis quittée, elle n'a pas vocation à rester en
/// mémoire pour la session.
final arrDetailProvider = StateNotifierProvider.family
    .autoDispose<ArrDetailNotifier, ArrDetailState, ArrDetailKey>(
  (ref, key) => ArrDetailNotifier(ref, key.service, key.id),
);

class ArrDetailNotifier extends StateNotifier<ArrDetailState> {
  ArrDetailNotifier(this.ref, this.service, this.id)
      : super(const ArrDetailState()) {
    _fetch();
  }

  final Ref ref;
  final ArrService service;
  final int id;

  Future<void> _fetch() async {
    final result = switch (service) {
      ArrService.radarr =>
        await ref.read(radarrClientProvider)?.fetchMovieDetail(id),
      ArrService.sonarr =>
        await ref.read(sonarrClientProvider)?.fetchSeriesDetail(id),
    };
    if (!mounted) return;
    if (result == null) {
      state = state.copyWith(
        loading: false,
        error: ArrApiError.unreachable,
        errorDetail: 'Service non configuré',
      );
      return;
    }
    switch (result) {
      case ArrSuccess(:final data):
        final entry = switch (service) {
          ArrService.radarr => ArrDetailEntry.movie(data as ArrMovieDetail),
          ArrService.sonarr => ArrDetailEntry.series(data as ArrSeriesDetail),
        };
        state = state.copyWith(loading: false, entry: entry, clearError: true);
      case ArrFailure(:final error, :final detail):
        state =
            state.copyWith(loading: false, error: error, errorDetail: detail);
    }
  }

  /// Recharge explicitement — appelé automatiquement après une
  /// modification qui change l'état affiché (surveillance, édition),
  /// pour que la fiche reflète toujours ce que le serveur a réellement
  /// enregistré plutôt qu'une mise à jour optimiste locale.
  Future<void> refresh() {
    state = state.copyWith(loading: true);
    return _fetch();
  }

  Future<ArrResult<void>> toggleMonitored() async {
    final entry = state.entry;
    if (entry == null) {
      return const ArrFailure(ArrApiError.unreachable, 'Pas encore chargé');
    }
    return edit(
      monitored: !entry.monitored,
      qualityProfileId: entry.qualityProfileId,
      rootFolderPath: entry.rootFolderPath ?? '',
    );
  }

  Future<ArrResult<void>> edit({
    required bool monitored,
    required int qualityProfileId,
    required String rootFolderPath,
  }) async {
    final entry = state.entry;
    if (entry == null) {
      return const ArrFailure(ArrApiError.unreachable, 'Pas encore chargé');
    }
    final result = switch (service) {
      ArrService.radarr => await ref.read(radarrClientProvider)?.updateMovie(
            entry.movie!,
            monitored: monitored,
            qualityProfileId: qualityProfileId,
            rootFolderPath: rootFolderPath,
          ),
      ArrService.sonarr => await ref.read(sonarrClientProvider)?.updateSeries(
            entry.series!,
            monitored: monitored,
            qualityProfileId: qualityProfileId,
            rootFolderPath: rootFolderPath,
          ),
    };
    if (result == null) {
      return const ArrFailure(ArrApiError.unreachable, 'Service non configuré');
    }
    if (result is ArrSuccess && mounted) await refresh();
    return result;
  }

  /// Recherche automatique (indexeurs déjà configurés) — pas la recherche
  /// interactive, cf. `ArrDetailSearchSection`.
  Future<ArrResult<void>> triggerSearch() => switch (service) {
        ArrService.radarr =>
          ref.read(radarrClientProvider)?.triggerMovieSearch(id) ??
              Future.value(const ArrFailure(
                  ArrApiError.unreachable, 'Service non configuré')),
        ArrService.sonarr =>
          ref.read(sonarrClientProvider)?.triggerSeriesSearch(id) ??
              Future.value(const ArrFailure(
                  ArrApiError.unreachable, 'Service non configuré')),
      };

  Future<ArrResult<void>> remove() => switch (service) {
        ArrService.radarr => ref.read(radarrClientProvider)?.deleteMovie(id) ??
            Future.value(const ArrFailure(
                ArrApiError.unreachable, 'Service non configuré')),
        ArrService.sonarr => ref.read(sonarrClientProvider)?.deleteSeries(id) ??
            Future.value(const ArrFailure(
                ArrApiError.unreachable, 'Service non configuré')),
      };
}

/// Profils de qualité de l'instance — `.family<ArrService>.autoDispose`,
/// avec `keepAlive` une fois chargés (même principe que
/// [arrLibraryProvider]) : cette liste est propre à l'instance, pas à une
/// œuvre — un aller-retour entre deux fiches détail du même service ne
/// doit pas la recharger à chaque fois.
final arrQualityProfilesProvider = FutureProvider.family
    .autoDispose<List<ArrQualityProfile>, ArrService>((ref, service) async {
  final result = switch (service) {
    ArrService.radarr =>
      await ref.read(radarrClientProvider)?.fetchQualityProfiles(),
    ArrService.sonarr =>
      await ref.read(sonarrClientProvider)?.fetchQualityProfiles(),
  };
  final profiles = switch (result) {
    ArrSuccess(:final data) => data,
    ArrFailure() || null => const <ArrQualityProfile>[],
  };
  if (profiles.isNotEmpty) ref.keepAlive();
  return profiles;
});

/// Dossiers racine de l'instance — même principe que
/// [arrQualityProfilesProvider].
final arrRootFoldersProvider = FutureProvider.family
    .autoDispose<List<ArrRootFolder>, ArrService>((ref, service) async {
  final result = switch (service) {
    ArrService.radarr =>
      await ref.read(radarrClientProvider)?.fetchRootFolders(),
    ArrService.sonarr =>
      await ref.read(sonarrClientProvider)?.fetchRootFolders(),
  };
  final folders = switch (result) {
    ArrSuccess(:final data) => data,
    ArrFailure() || null => const <ArrRootFolder>[],
  };
  if (folders.isNotEmpty) ref.keepAlive();
  return folders;
});
