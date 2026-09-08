import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:fladder/arr/models/arr_queue_item.dart';
import 'package:fladder/arr/models/arr_service.dart';
import 'package:fladder/arr/providers/arr_providers.dart';
import 'package:fladder/arr/services/arr_api_client.dart';

/// État de la file d'attente d'un service — `error` ne s'affiche que
/// lorsque [items] est vide : un échec de rafraîchissement ponctuel (ex.
/// un timeout isolé sur un des polls de 5s) ne doit pas faire disparaître
/// une file déjà affichée à l'écran.
class ArrQueueState {
  final bool loading;
  final ArrApiError? error;
  final String? errorDetail;
  final List<ArrQueueItem> items;

  const ArrQueueState({
    this.loading = true,
    this.error,
    this.errorDetail,
    this.items = const [],
  });

  ArrQueueState copyWith({
    bool? loading,
    ArrApiError? error,
    bool clearError = false,
    String? errorDetail,
    List<ArrQueueItem>? items,
  }) {
    return ArrQueueState(
      loading: loading ?? this.loading,
      error: clearError ? null : (error ?? this.error),
      errorDetail: clearError ? null : (errorDetail ?? this.errorDetail),
      items: items ?? this.items,
    );
  }
}

/// File d'attente d'un service — `autoDispose` : volatile, jamais
/// persistée, et le polling s'arrête dès que plus personne ne regarde cet
/// onglet (pas de rafraîchissement en tâche de fond une fois qu'on a
/// quitté le module Arr). `.family<ArrService>` : chaque service a sa
/// propre instance, jamais partagée — mêmes principes que
/// [arrApiClientProvider], en gardant bien à l'esprit le bug d'état
/// partagé déjà rencontré côté bibliothèque (cf. CLAUDE.md / historique du
/// projet) : aucun état ici ne doit être accessible autrement que par ce
/// paramètre de famille.
final arrQueueProvider = StateNotifierProvider.family
    .autoDispose<ArrQueueNotifier, ArrQueueState, ArrService>(
  (ref, service) => ArrQueueNotifier(ref, service),
);

const _pollInterval = Duration(seconds: 5);

class ArrQueueNotifier extends StateNotifier<ArrQueueState> {
  ArrQueueNotifier(this.ref, this.service) : super(const ArrQueueState()) {
    _fetch();
    _timer = Timer.periodic(_pollInterval, (_) => _fetch());
  }

  final Ref ref;
  final ArrService service;
  Timer? _timer;

  ArrApiClient? get _client => ref.read(arrApiClientProvider(service));

  Future<void> _fetch() async {
    final client = _client;
    if (client == null) {
      state = state.copyWith(
        loading: false,
        items: const [],
        error: ArrApiError.unreachable,
        errorDetail: 'Service non configuré',
      );
      return;
    }
    final result = await client.fetchQueue();
    if (!mounted) return;
    switch (result) {
      case ArrSuccess(:final data):
        state = state.copyWith(loading: false, items: data, clearError: true);
      case ArrFailure(:final error, :final detail):
        state = state.copyWith(
          loading: false,
          error: error,
          errorDetail: detail,
          // Garde les lignes déjà affichées : un poll isolé qui échoue ne
          // doit pas vider un tableau que l'utilisateur est en train de
          // regarder.
          items: state.items,
        );
    }
  }

  /// Rafraîchit immédiatement, sans attendre le prochain tic du
  /// polling — après une action utilisateur (pause, retrait...).
  Future<void> refreshNow() => _fetch();

  Future<ArrResult<void>> pause(int id) =>
      _act((client) => client.pauseQueueItem(id));

  Future<ArrResult<void>> resume(int id) =>
      _act((client) => client.resumeQueueItem(id));

  Future<ArrResult<void>> forceImport(int id) =>
      _act((client) => client.forceImportQueueItem(id));

  Future<ArrResult<void>> remove(
    int id, {
    required bool removeFromClient,
    required bool blocklist,
  }) =>
      _act((client) => client.removeQueueItem(
            id,
            removeFromClient: removeFromClient,
            blocklist: blocklist,
          ));

  Future<ArrResult<void>> removeMultiple(
    List<int> ids, {
    required bool removeFromClient,
    required bool blocklist,
  }) =>
      _act((client) => client.removeQueueItems(
            ids,
            removeFromClient: removeFromClient,
            blocklist: blocklist,
          ));

  Future<ArrResult<void>> _act(
      Future<ArrResult<void>> Function(ArrApiClient client) action) async {
    final client = _client;
    if (client == null) {
      return const ArrFailure(ArrApiError.unreachable, 'Service non configuré');
    }
    final result = await action(client);
    if (result is ArrSuccess) await refreshNow();
    return result;
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
