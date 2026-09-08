import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:fladder/arr/models/arr_library_entry.dart';
import 'package:fladder/arr/models/arr_library_item.dart';
import 'package:fladder/arr/models/arr_service.dart';
import 'package:fladder/arr/providers/arr_search_providers.dart';
import 'package:fladder/arr/services/arr_api_client.dart';

/// État de la bibliothèque d'un service — `error` ne s'affiche que
/// lorsque [entries] est vide, même logique que [ArrQueueState].
class ArrLibraryState {
  final bool loading;
  final ArrApiError? error;
  final String? errorDetail;
  final List<ArrLibraryEntry> entries;

  const ArrLibraryState({
    this.loading = true,
    this.error,
    this.errorDetail,
    this.entries = const [],
  });

  ArrLibraryState copyWith({
    bool? loading,
    ArrApiError? error,
    bool clearError = false,
    String? errorDetail,
    List<ArrLibraryEntry>? entries,
  }) {
    return ArrLibraryState(
      loading: loading ?? this.loading,
      error: clearError ? null : (error ?? this.error),
      errorDetail: clearError ? null : (errorDetail ?? this.errorDetail),
      entries: entries ?? this.entries,
    );
  }
}

/// Bibliothèque d'un service — `.family<ArrService>.autoDispose`, mêmes
/// principes que [arrQueueProvider] : jamais d'état partagé entre
/// Radarr et Sonarr, jamais avec l'onglet File d'attente ni les écrans
/// Recherche/Films/Séries.
///
/// Contrairement à la file d'attente, pas de polling : un seul appel
/// (`GET /api/v3/movie` ou `/series`, toute la bibliothèque en une
/// fois), et le résultat reste en mémoire pour la session — `ref
/// .keepAlive()` après un chargement réussi annule l'auto-dispose
/// habituel de ce provider, pour qu'un aller-retour entre les onglets de
/// [ArrHomeScreen] ne redéclenche pas l'appel (cf. `_ArrHomeContent`,
/// qui démonte l'onglet inactif). Un échec, lui, reste rejouable au
/// prochain passage sur l'onglet (pas de keepAlive tant que ça n'a pas
/// marché).
final arrLibraryProvider = StateNotifierProvider.family
    .autoDispose<ArrLibraryNotifier, ArrLibraryState, ArrService>(
  (ref, service) => ArrLibraryNotifier(ref, service),
);

class ArrLibraryNotifier extends StateNotifier<ArrLibraryState> {
  ArrLibraryNotifier(this.ref, this.service) : super(const ArrLibraryState()) {
    _fetch();
  }

  final Ref ref;
  final ArrService service;

  Future<void> _fetch() async {
    final result = switch (service) {
      ArrService.radarr =>
        await ref.read(radarrClientProvider)?.searchMovies(''),
      ArrService.sonarr =>
        await ref.read(sonarrClientProvider)?.searchSeries(''),
    };
    if (!mounted) return;
    if (result == null) {
      state = state.copyWith(
        loading: false,
        entries: const [],
        error: ArrApiError.unreachable,
        errorDetail: 'Service non configuré',
      );
      return;
    }
    switch (result) {
      case ArrSuccess(:final data):
        final entries = switch (service) {
          ArrService.radarr =>
            (data as List<ArrMovie>).map(ArrLibraryEntry.movie).toList(),
          ArrService.sonarr =>
            (data as List<ArrSeries>).map(ArrLibraryEntry.series).toList(),
        };
        state =
            state.copyWith(loading: false, entries: entries, clearError: true);
        // Chargement réussi : garde ce provider en vie même une fois que
        // plus rien ne l'observe (onglet Bibliothèque quitté), pour ne
        // jamais refaire cet appel deux fois dans la même session.
        ref.keepAlive();
      case ArrFailure(:final error, :final detail):
        state =
            state.copyWith(loading: false, error: error, errorDetail: detail);
    }
  }

  /// Recharge explicitement — jamais appelé automatiquement (ni au
  /// changement d'onglet, ni en tâche de fond) : seulement si
  /// l'utilisateur le demande depuis la barre d'outils.
  Future<void> refresh() {
    state = state.copyWith(loading: true);
    return _fetch();
  }

  ArrLibraryEntry _updated(ArrLibraryEntry entry, bool monitored) {
    if (entry.isMovie) {
      final movie = entry.movie!;
      return ArrLibraryEntry.movie(ArrMovie(
        id: movie.id,
        title: movie.title,
        year: movie.year,
        posterUrl: movie.posterUrl,
        monitored: monitored,
        hasFile: movie.hasFile,
        qualityName: movie.qualityName,
        raw: {...movie.raw, 'monitored': monitored},
      ));
    }
    final series = entry.series!;
    return ArrLibraryEntry.series(ArrSeries(
      id: series.id,
      title: series.title,
      year: series.year,
      posterUrl: series.posterUrl,
      monitored: monitored,
      seasonCount: series.seasonCount,
      episodeCount: series.episodeCount,
      episodeFileCount: series.episodeFileCount,
      raw: {...series.raw, 'monitored': monitored},
    ));
  }

  Future<ArrResult<void>> toggleMonitored(ArrLibraryEntry entry) async {
    final newMonitored = !entry.monitored;
    final result = switch (service) {
      ArrService.radarr => await ref
          .read(radarrClientProvider)
          ?.setMovieMonitored(entry.movie!, newMonitored),
      ArrService.sonarr => await ref
          .read(sonarrClientProvider)
          ?.setSeriesMonitored(entry.series!, newMonitored),
    };
    if (result == null) {
      return const ArrFailure(ArrApiError.unreachable, 'Service non configuré');
    }
    if (result is ArrSuccess && mounted) {
      final updated = _updated(entry, newMonitored);
      state = state.copyWith(
        entries: [
          for (final e in state.entries)
            if (e.id == entry.id) updated else e,
        ],
      );
    }
    return result;
  }

  Future<ArrResult<void>> remove(ArrLibraryEntry entry) async {
    final result = switch (service) {
      ArrService.radarr =>
        await ref.read(radarrClientProvider)?.deleteMovie(entry.id),
      ArrService.sonarr =>
        await ref.read(sonarrClientProvider)?.deleteSeries(entry.id),
    };
    if (result == null) {
      return const ArrFailure(ArrApiError.unreachable, 'Service non configuré');
    }
    if (result is ArrSuccess && mounted) {
      state = state.copyWith(
        entries: [
          for (final e in state.entries)
            if (e.id != entry.id) e
        ],
      );
    }
    return result;
  }

  /// Recherche automatique — ne modifie pas [entries] : le résultat
  /// n'apparaît que dans la file d'attente, pas ici.
  Future<ArrResult<void>> search(ArrLibraryEntry entry) => switch (service) {
        ArrService.radarr =>
          ref.read(radarrClientProvider)?.triggerMovieSearch(entry.id) ??
              Future.value(const ArrFailure(
                  ArrApiError.unreachable, 'Service non configuré')),
        ArrService.sonarr =>
          ref.read(sonarrClientProvider)?.triggerSeriesSearch(entry.id) ??
              Future.value(const ArrFailure(
                  ArrApiError.unreachable, 'Service non configuré')),
      };
}
