import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:kinos/arr/models/arr_calendar_entry.dart';
import 'package:kinos/arr/models/arr_service.dart';
import 'package:kinos/arr/providers/arr_search_providers.dart';
import 'package:kinos/arr/services/arr_api_client.dart';

/// Identifie une plage de calendrier — instance ET période, jamais
/// partagé entre deux semaines/mois ni entre Radarr et Sonarr (même
/// principe que [ArrDetailKey]). [start]/[end] doivent être normalisés
/// (minuit local) par l'appelant, pour qu'une même période revisitée
/// retombe sur la même clé plutôt que de recharger à chaque fois à
/// cause d'un écart de quelques millisecondes.
typedef ArrCalendarKey = ({ArrService service, DateTime start, DateTime end});

/// État du calendrier d'une période — même logique que
/// [ArrLibraryState] : `error` ne s'affiche que si [entries] est vide.
class ArrCalendarState {
  final bool loading;
  final ArrApiError? error;
  final String? errorDetail;
  final List<ArrCalendarEntry> entries;

  const ArrCalendarState({
    this.loading = true,
    this.error,
    this.errorDetail,
    this.entries = const [],
  });

  ArrCalendarState copyWith({
    bool? loading,
    ArrApiError? error,
    bool clearError = false,
    String? errorDetail,
    List<ArrCalendarEntry>? entries,
  }) {
    return ArrCalendarState(
      loading: loading ?? this.loading,
      error: clearError ? null : (error ?? this.error),
      errorDetail: clearError ? null : (errorDetail ?? this.errorDetail),
      entries: entries ?? this.entries,
    );
  }
}

/// Calendrier d'une période — `.family<ArrCalendarKey>.autoDispose`,
/// pas de table Drift (données volatiles) : `ref.keepAlive()` après un
/// chargement réussi garde le résultat en mémoire pour la session (même
/// principe que [arrLibraryProvider]) sans jamais le persister — changer
/// de semaine crée une nouvelle instance de ce provider (nouvelle clé),
/// l'ancienne reste en vie tant qu'elle a réussi au moins une fois,
/// libérée seulement en quittant le module Arr.
final arrCalendarProvider = StateNotifierProvider.family
    .autoDispose<ArrCalendarNotifier, ArrCalendarState, ArrCalendarKey>(
  (ref, key) => ArrCalendarNotifier(ref, key),
);

class ArrCalendarNotifier extends StateNotifier<ArrCalendarState> {
  ArrCalendarNotifier(this.ref, this.key) : super(const ArrCalendarState()) {
    _fetch();
  }

  final Ref ref;
  final ArrCalendarKey key;

  Future<void> _fetch() async {
    final result = switch (key.service) {
      ArrService.radarr => await ref
          .read(radarrClientProvider)
          ?.fetchCalendar(key.start, key.end),
      ArrService.sonarr => await ref
          .read(sonarrClientProvider)
          ?.fetchCalendar(key.start, key.end),
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
        state =
            state.copyWith(loading: false, entries: data, clearError: true);
        // Chargement réussi : garde cette période en mémoire pour la
        // session, même principe que arrLibraryProvider.
        ref.keepAlive();
      case ArrFailure(:final error, :final detail):
        state =
            state.copyWith(loading: false, error: error, errorDetail: detail);
    }
  }

  /// Recharge explicitement — après une action utilisateur (recherche,
  /// surveillance) qui peut avoir changé l'état affiché.
  Future<void> refreshNow() => _fetch();

  /// Recherche automatique scopée à l'entrée affichée — un épisode
  /// précis côté Sonarr (pas toute la série : l'entrée de calendrier
  /// représente une diffusion, pas la série entière), le film entier
  /// côté Radarr.
  Future<ArrResult<void>> search(ArrCalendarEntry entry) async {
    final result = switch (entry.service) {
      ArrService.radarr => await ref
          .read(radarrClientProvider)
          ?.triggerMovieSearch(entry.detailId),
      ArrService.sonarr => entry.episodeId == null
          ? null
          : await ref
              .read(sonarrClientProvider)
              ?.triggerEpisodeSearch(entry.episodeId!),
    };
    return result ??
        const ArrFailure(ArrApiError.unreachable, 'Service non configuré');
  }

  Future<ArrResult<void>> toggleMonitored(ArrCalendarEntry entry) async {
    final newMonitored = !entry.monitored;
    final result = switch (entry.service) {
      ArrService.radarr => await ref
          .read(radarrClientProvider)
          ?.setMovieMonitoredById(entry.detailId, newMonitored),
      ArrService.sonarr => await ref
          .read(sonarrClientProvider)
          ?.setSeriesMonitoredById(entry.detailId, newMonitored),
    };
    if (result == null) {
      return const ArrFailure(ArrApiError.unreachable, 'Service non configuré');
    }
    // Le calendrier n'affiche pas la surveillance elle-même, mais un
    // rafraîchissement garde `entries` cohérent avec le serveur pour un
    // prochain "basculer" sans repartir d'une valeur périmée.
    if (result is ArrSuccess && mounted) await refreshNow();
    return result;
  }
}
