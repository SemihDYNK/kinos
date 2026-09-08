import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:fladder/arr/models/qbittorrent_credentials.dart';
import 'package:fladder/arr/services/qbittorrent_api_client.dart';
import 'package:fladder/arr/services/qbittorrent_credentials_store.dart';

final qbittorrentCredentialsStoreProvider =
    Provider<QBittorrentCredentialsStore>(
        (ref) => const QBittorrentCredentialsStore());

/// Identifiants qBittorrent persistés — une seule instance (pas de
/// `.family` par service *Arr : Radarr et Sonarr partagent généralement
/// le même client de téléchargement). Mêmes principes que
/// `ArrCredentialsNotifier`.
final qbittorrentCredentialsProvider = StateNotifierProvider<
    QBittorrentCredentialsNotifier, AsyncValue<QBittorrentCredentials>>(
  (ref) => QBittorrentCredentialsNotifier(ref),
);

class QBittorrentCredentialsNotifier
    extends StateNotifier<AsyncValue<QBittorrentCredentials>> {
  QBittorrentCredentialsNotifier(this.ref) : super(const AsyncValue.loading()) {
    _load();
  }

  final Ref ref;

  Future<void> _load() async {
    final store = ref.read(qbittorrentCredentialsStoreProvider);
    try {
      final credentials = await store.read() ?? QBittorrentCredentials.empty;
      if (mounted) state = AsyncValue.data(credentials);
    } catch (e, stackTrace) {
      if (mounted) state = AsyncValue.error(e, stackTrace);
    }
  }

  Future<void> save(QBittorrentCredentials credentials) async {
    final store = ref.read(qbittorrentCredentialsStoreProvider);
    await store.save(credentials);
    if (mounted) state = AsyncValue.data(credentials);
  }

  Future<void> clear() async {
    final store = ref.read(qbittorrentCredentialsStoreProvider);
    await store.delete();
    if (mounted) state = const AsyncValue.data(QBittorrentCredentials.empty);
  }
}

/// Client prêt à l'emploi, ou `null` tant que rien n'est configuré —
/// reconstruit automatiquement si les identifiants changent (nouvelle
/// session à la prochaine action, cf. QBittorrentApiClient).
final qbittorrentClientProvider = Provider<QBittorrentApiClient?>((ref) {
  final credentials = ref.watch(qbittorrentCredentialsProvider).valueOrNull;
  if (credentials == null || !credentials.isConfigured) return null;
  final client = QBittorrentApiClient(
    baseUrl: credentials.baseUrl,
    username: credentials.username,
    password: credentials.password,
  );
  ref.onDispose(client.close);
  return client;
});
