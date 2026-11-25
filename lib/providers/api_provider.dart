import 'dart:async';
import 'dart:convert';
import 'dart:developer';
import 'dart:io';

import 'package:chopper/chopper.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:punycoder/punycoder.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:kinos/jellyfin/jellyfin_open_api.swagger.dart';
import 'package:kinos/providers/auth_provider.dart';
import 'package:kinos/providers/connectivity_provider.dart';
import 'package:kinos/providers/service_provider.dart';
import 'package:kinos/providers/user_provider.dart';
part 'api_provider.g.dart';

final serverUrlProvider = StateProvider<String?>((ref) {
  final localUrlAvailable = ref.watch(localConnectionAvailableProvider);
  final userCredentials = ref.watch(userProvider.select((value) => value?.credentials));
  final tempUrl = ref.watch(authProvider.select((value) => value.serverLoginModel?.tempCredentials.url));
  String? newUrl;

  if (localUrlAvailable && userCredentials?.localUrl?.isNotEmpty == true) {
    newUrl = userCredentials?.localUrl;
  } else if (userCredentials?.url.isNotEmpty == true) {
    newUrl = userCredentials?.url;
  } else if (tempUrl?.isNotEmpty == true) {
    newUrl = tempUrl;
  } else {
    newUrl = null;
  }

  return normalizeUrl(newUrl ?? "");
});

@riverpod
class JellyApi extends _$JellyApi {
  @override
  JellyService build() => JellyService(
        ref,
        JellyfinOpenApi.create(
          interceptors: [
            JellyRequest(ref),
            JellyResponse(ref),
            HttpLoggingInterceptor(level: Level.basic),
          ],
        ),
      );
}

JellyfinOpenApi createJellyfinApiForAccount(Ref ref, String baseUrl, Map<String, String> headers) {
  return JellyfinOpenApi.create(
    interceptors: [
      _TempJellyRequest(baseUrl: baseUrl, headers: headers),
      JellyResponse(ref),
      HttpLoggingInterceptor(level: Level.basic),
    ],
  );
}

class _TempJellyRequest implements Interceptor {
  _TempJellyRequest({required this.baseUrl, required this.headers});

  final String baseUrl;
  final Map<String, String> headers;

  @override
  FutureOr<Response<BodyType>> intercept<BodyType>(Chain<BodyType> chain) async {
    if (baseUrl.isEmpty) throw const HttpException('No server URL provided for temp request');

    final request = applyHeaders(chain.request.copyWith(baseUri: Uri.parse(baseUrl)), headers);
    return chain.proceed(request);
  }
}

final int _maxRetries = 3;

/// Au-delà, une requête sans réponse est abandonnée : sans délai, une
/// connexion à demi morte laissait un chargement tourner indéfiniment.
const _requestTimeout = Duration(seconds: 30);

bool _isConnectionError(Object e) {
  return e is IOException || e is TimeoutException;
}

class JellyRequest implements Interceptor {
  JellyRequest(this.ref);

  final Ref ref;

  @override
  FutureOr<Response<BodyType>> intercept<BodyType>(Chain<BodyType> chain) async {
    final connectivityNotifier = ref.read(connectivityStatusProvider.notifier);
    await connectivityNotifier.waitForProbe();
    final serverUrl = ref.read(serverUrlProvider);

    if (serverUrl == null || serverUrl.isEmpty) {
      throw const HttpException('No server URL provided');
    }

    // Use current logged in user otherwise use the authProvider
    final loginModel = ref.read(userProvider)?.credentials ?? ref.read(authProvider).serverLoginModel?.tempCredentials;
    if (loginModel == null) {
      throw UnimplementedError();
    }

    final headers = loginModel.header(ref);

    for (var attempt = 0; attempt <= _maxRetries; attempt++) {
      try {
        final response = await Future.value(chain.proceed(
              applyHeaders(
                chain.request.copyWith(baseUri: Uri.parse(serverUrl)),
                headers,
              ),
            )).timeout(_requestTimeout);
        // Une réponse prouve que le serveur répond : la sonde ne sert qu'à
        // sortir du mode hors ligne. Relancée après chaque requête, une
        // seule sonde lente (serveur distant chargé) faisait passer l'app
        // hors ligne alors que tout fonctionnait.
        if (ref.read(connectivityStatusProvider) == ConnectionState.offline) {
          unawaited(connectivityNotifier.checkConnectivity(immediate: true));
        }
        return response;
      } catch (e) {
        // Seules les lectures sont rejouées : un POST (rapport de lecture,
        // marquer vu) pourrait avoir été reçu avant la coupure.
        if (!_isConnectionError(e) || attempt == _maxRetries || chain.request.method != 'GET') {
          unawaited(connectivityNotifier.checkConnectivity(immediate: true));
          rethrow;
        }

        final delay = Duration(milliseconds: 200 * (attempt + 1));
        log('Connection failed (attempt ${attempt + 1}/$_maxRetries), retrying in ${delay.inMilliseconds}ms: $e');
        await Future.delayed(delay);
      }
    }
    throw StateError('Unexpected state in JellyRequest.intercept');
  }
}

/// Whether [url] already carries an http or https scheme.
/// Uses toLowerCase() because users may type mixed-case schemes (e.g. Https://, HTTP://).
bool hasHttpScheme(String url) {
  final lower = url.toLowerCase();
  return lower.startsWith('http://') || lower.startsWith('https://');
}

String normalizeUrl(String url) {
  final trimmed = url.trim();
  if (trimmed.isEmpty) return '';

  final withScheme = hasHttpScheme(trimmed) ? trimmed : 'http://$trimmed';
  final parsed = Uri.parse(withScheme);

  // Only punycode non-ASCII hostnames. IP addresses are always ASCII, so no special handling needed.
  final host = parsed.host;
  final hasNonAscii = host.runes.any((c) => c > 0x7F);

  if (!hasNonAscii) return parsed.toString();

  try {
    final encodedHost = const PunycodeCodec().encode(host);
    return parsed.replace(host: encodedHost).toString();
  } catch (_) {
    return parsed.toString();
  }
}

Future<String?> _probeUrl(String baseUrl, String endpoint) async {
  try {
    await http.head(Uri.parse('$baseUrl$endpoint')).timeout(const Duration(seconds: 5));
    // Any HTTP response (including 4xx/5xx) means the server is reachable at this URL.
    // This only acts as scheme detection, not as health check.
    return baseUrl;
  } catch (e) {
    log('Probe failed for $baseUrl$endpoint: $e');
  }
  return null;
}

/// Probes a Seerr server URL by hitting /api/v1/status.
Future<String?> probeSeerrUrl(String baseUrl) => _probeUrl(baseUrl, '/api/v1/status');

/// La racine d'un serveur Seerr : une adresse copiée depuis une page de
/// Seerr (`…/users`, `…/movie/123`) n'est pas celle de l'API. Si [url] a un
/// chemin et n'expose pas `/api/v1/status`, mais que l'origine le fait,
/// l'origine est retenue ; sinon [url] reste telle quelle.
Future<String> seerrRootUrl(String url) async {
  final uri = Uri.tryParse(url);
  if (uri == null || !uri.hasScheme || uri.path.isEmpty || uri.path == '/') {
    return url;
  }
  Future<bool> isSeerr(String base) async {
    try {
      final response = await http
          .get(Uri.parse('${base.endsWith('/') ? base.substring(0, base.length - 1) : base}/api/v1/status'))
          .timeout(const Duration(seconds: 5));
      if (response.statusCode != 200) return false;
      final body = jsonDecode(response.body);
      return body is Map && body.containsKey('version');
    } catch (_) {
      return false;
    }
  }

  if (await isSeerr(url)) return url;
  return await isSeerr(uri.origin) ? uri.origin : url;
}

/// Probes a Jellyfin server URL by hitting /System/Info/Public.
Future<String?> probeJellyfinUrl(String baseUrl) => _probeUrl(baseUrl, '/System/Info/Public');

/// Result of [probeAndNormalizeUrl]: the resolved URL and whether a probe succeeded.
typedef ProbeResult = ({String url, bool probed});

/// Tries https and http in parallel using [probeFn] if no scheme is provided.
/// Always returns a usable URL (falls back to https when both probes fail).
/// If a scheme is already present, returns the normalized URL without probing.
Future<ProbeResult> probeAndNormalizeUrl(String url, Future<String?> Function(String) probeFn) async {
  if (!hasHttpScheme(url)) {
    final httpsUrl = normalizeUrl('https://$url');
    final httpUrl = normalizeUrl('http://$url');
    final httpFuture = probeFn(httpUrl);
    final httpsResult = await probeFn(httpsUrl);
    if (httpsResult != null) return (url: httpsResult, probed: true);
    final httpResult = await httpFuture;
    return (url: httpResult ?? httpsUrl, probed: httpResult != null);
  }
  return (url: normalizeUrl(url), probed: true);
}

Uri? tryParseServerBaseUri(String? url) {
  if (url == null) return null;
  final trimmed = url.trim();
  if (trimmed.isEmpty) return null;

  final parsed = Uri.tryParse(trimmed);
  if (parsed == null || parsed.scheme.isEmpty || parsed.host.isEmpty) return null;
  return parsed;
}

Uri? serverBaseUri(Ref ref) => tryParseServerBaseUri(ref.read(serverUrlProvider));

Uri? buildServerUriFromBase(
  String baseUrl, {
  List<String> pathSegments = const [],
  String? relativeUrl,
  Map<String, String?>? queryParameters,
}) {
  final base = tryParseServerBaseUri(baseUrl);
  if (base == null) return null;

  Uri? relative;
  if (relativeUrl != null && relativeUrl.trim().isNotEmpty) {
    relative = Uri.tryParse(relativeUrl.trim());
  }

  if (relative?.hasScheme == true && relative?.host.isNotEmpty == true) {
    return relative;
  }

  final baseSegments = base.pathSegments.where((s) => s.isNotEmpty).toList(growable: false);
  final relSegments = (relative?.pathSegments ?? const <String>[]).where((s) => s.isNotEmpty).toList(growable: false);
  final extraSegments = pathSegments.where((s) => s.isNotEmpty).toList(growable: false);

  final mergedSegments = <String>[...baseSegments, ...relSegments, ...extraSegments];

  final mergedQuery = <String, String>{...?(relative?.queryParameters)};
  if (queryParameters != null) {
    for (final entry in queryParameters.entries) {
      final value = entry.value;
      if (value == null) continue;
      mergedQuery[entry.key] = value;
    }
  }

  return Uri(
    scheme: base.scheme,
    userInfo: base.userInfo,
    host: base.host,
    port: base.hasPort ? base.port : null,
    pathSegments: mergedSegments,
    queryParameters: mergedQuery.isNotEmpty ? mergedQuery : null,
    fragment: relative?.hasFragment == true ? relative!.fragment : null,
  );
}

Uri? buildServerUri(
  Ref ref, {
  List<String> pathSegments = const [],
  String? relativeUrl,
  Map<String, String?>? queryParameters,
}) {
  final baseUrl = ref.read(serverUrlProvider);
  if (baseUrl == null || baseUrl.isEmpty) return null;
  return buildServerUriFromBase(
    baseUrl,
    pathSegments: pathSegments,
    relativeUrl: relativeUrl,
    queryParameters: queryParameters,
  );
}

String buildServerUrl(
  Ref ref, {
  List<String> pathSegments = const [],
  String? relativeUrl,
  Map<String, String?>? queryParameters,
}) {
  return buildServerUri(
        ref,
        pathSegments: pathSegments,
        relativeUrl: relativeUrl,
        queryParameters: queryParameters,
      )?.toString() ??
      '';
}

class JellyResponse implements Interceptor {
  JellyResponse(this.ref);

  final Ref ref;

  @override
  FutureOr<Response<BodyType>> intercept<BodyType>(Chain<BodyType> chain) async {
    final Response<BodyType> response = await chain.proceed(chain.request);

    if (!response.isSuccessful) {
      log('x- ${response.base.statusCode} - ${response.base.reasonPhrase} - ${response.error} - ${response.base.request?.method} ${response.base.request?.url.toString()}');
    }
    if (response.statusCode == 404) {
      // Le chemin seul : la requête peut porter un jeton.
      final request = response.base.request;
      chopperLogger.severe('404 NOT FOUND : ${request?.method} ${request?.url.path}');
    }

    return response;
  }
}
