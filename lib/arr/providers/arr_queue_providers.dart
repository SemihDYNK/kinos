import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:fladder/arr/models/arr_queue_item.dart';
import 'package:fladder/arr/models/arr_service.dart';
import 'package:fladder/arr/providers/arr_providers.dart';
import 'package:fladder/arr/providers/qbittorrent_providers.dart';
import 'package:fladder/arr/services/arr_api_client.dart';
import 'package:fladder/arr/services/qbittorrent_api_client.dart';

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

  /// Pas de pause/reprise côté API *Arr (confirmé 405 sur un serveur réel :
  /// `/api/v3/queue/{id}/pause` n'existe pas, seul DELETE est accepté sur ce
  /// chemin) — l'opération appartient au client de téléchargement.
  /// `downloadId` d'une ligne de file *Arr est le hash du torrent attendu
  /// par qBittorrent. L'appelant est responsable de désactiver le contrôle
  /// quand `downloadId` est absent ou qu'aucun client n'est configuré,
  /// plutôt que de laisser cette méthode échouer silencieusement au clic.
  Future<ArrResult<void>> pause(String downloadId) =>
      _qbAction(downloadId, (client) => client.pause(downloadId));

  Future<ArrResult<void>> resume(String downloadId) =>
      _qbAction(downloadId, (client) => client.resume(downloadId));

  Future<ArrResult<void>> _qbAction(
    String downloadId,
    Future<bool> Function(QBittorrentApiClient client) action,
  ) async {
    final client = ref.read(qbittorrentClientProvider);
    if (client == null) {
      return const ArrFailure(
          ArrApiError.unreachable, 'Client de téléchargement non configuré');
    }
    final ok = await action(client);
    if (!ok) {
      return const ArrFailure(ArrApiError.unreachable,
          'Action refusée par le client de téléchargement');
    }
    await refreshNow();
    return const ArrSuccess(null);
  }

  Future<ArrResult<void>> forceImport(int id) =>
      _act((client) => client.forceImportQueueItem(id));

  /// Applique "forcer l'import" à chaque épisode d'un paquet de saison —
  /// l'API *Arr n'a pas d'équivalent groupé, un appel par élément est
  /// nécessaire. Un seul rafraîchissement à la fin plutôt qu'un par
  /// épisode.
  Future<ArrResult<void>> forceImportGroup(List<int> ids) async {
    final client = _client;
    if (client == null) {
      return const ArrFailure(ArrApiError.unreachable, 'Service non configuré');
    }
    ArrResult<void> last = const ArrSuccess(null);
    for (final id in ids) {
      final result = await client.forceImportQueueItem(id);
      if (result is ArrFailure) last = result;
    }
    await refreshNow();
    return last;
  }

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
