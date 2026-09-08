import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:kinos/arr/models/arr_service.dart';
import 'package:kinos/arr/providers/arr_providers.dart';
import 'package:kinos/arr/services/arr_api_client.dart';

/// Client Radarr typé, ou `null` tant que le service n'est pas configuré —
/// centralise le seul endroit où [arrApiClientProvider] (typé
/// [ArrApiClient] côté commun) doit être ramené à son type concret.
final radarrClientProvider = Provider<RadarrApiClient?>(
  (ref) =>
      ref.watch(arrApiClientProvider(ArrService.radarr)) as RadarrApiClient?,
);

/// Équivalent Sonarr de [radarrClientProvider].
final sonarrClientProvider = Provider<SonarrApiClient?>(
  (ref) =>
      ref.watch(arrApiClientProvider(ArrService.sonarr)) as SonarrApiClient?,
);
