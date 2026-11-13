import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';

/// Client Seerr borné : un serveur injoignable ou muet échoue en quelques
/// secondes au lieu de laisser la page charger indéfiniment.
http.Client createSeerrHttpClient() => _TimeoutClient(IOClient(HttpClient()
  ..connectionTimeout = const Duration(seconds: 15)
  ..idleTimeout = const Duration(seconds: 30)));

class _TimeoutClient extends http.BaseClient {
  _TimeoutClient(this._inner);
  final http.Client _inner;
  static const _timeout = Duration(seconds: 30);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) =>
      _inner.send(request).timeout(_timeout);

  @override
  void close() => _inner.close();
}
