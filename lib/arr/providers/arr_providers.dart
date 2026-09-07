import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:fladder/arr/models/arr_credentials.dart';
import 'package:fladder/arr/models/arr_service.dart';
import 'package:fladder/arr/services/arr_api_client.dart';
import 'package:fladder/arr/services/arr_credentials_store.dart';

final arrCredentialsStoreProvider =
    Provider<ArrCredentialsStore>((ref) => const ArrCredentialsStore());

/// Identifiants persistés d'un service *Arr — chargés depuis le coffre
/// sécurisé au premier accès, tenus à jour ensuite via [save]/[clear].
final arrCredentialsProvider = StateNotifierProvider.family<
    ArrCredentialsNotifier, AsyncValue<ArrCredentials>, ArrService>(
  (ref, service) => ArrCredentialsNotifier(ref, service),
);

class ArrCredentialsNotifier extends StateNotifier<AsyncValue<ArrCredentials>> {
  ArrCredentialsNotifier(this.ref, this.service)
      : super(const AsyncValue.loading()) {
    _load();
  }

  final Ref ref;
  final ArrService service;

  Future<void> _load() async {
    final store = ref.read(arrCredentialsStoreProvider);
    try {
      final credentials = await store.read(service) ?? ArrCredentials.empty;
      if (mounted) state = AsyncValue.data(credentials);
    } catch (e, stackTrace) {
      if (mounted) state = AsyncValue.error(e, stackTrace);
    }
  }

  Future<void> save(ArrCredentials credentials) async {
    final store = ref.read(arrCredentialsStoreProvider);
    await store.save(service, credentials);
    if (mounted) state = AsyncValue.data(credentials);
  }

  Future<void> clear() async {
    final store = ref.read(arrCredentialsStoreProvider);
    await store.delete(service);
    if (mounted) state = const AsyncValue.data(ArrCredentials.empty);
  }
}

/// Client prêt à l'emploi pour un service, ou `null` tant qu'il n'est pas
/// configuré — reconstruit automatiquement si les identifiants changent.
final arrApiClientProvider =
    Provider.family<ArrApiClient?, ArrService>((ref, service) {
  final credentials = ref.watch(arrCredentialsProvider(service)).valueOrNull;
  if (credentials == null || !credentials.isConfigured) return null;
  final client = switch (service) {
    ArrService.radarr =>
      RadarrApiClient(baseUrl: credentials.baseUrl, apiKey: credentials.apiKey),
    ArrService.sonarr =>
      SonarrApiClient(baseUrl: credentials.baseUrl, apiKey: credentials.apiKey),
  };
  ref.onDispose(client.close);
  return client;
});
