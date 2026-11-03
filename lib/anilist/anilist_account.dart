import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:kinos/services/platform_secure_storage.dart';
import 'mapping.dart';

Uri anilistAuthorizationUri() =>
    Uri.https('anilist.co', '/api/v2/oauth/authorize', {
      'client_id': const String.fromEnvironment('ANILIST_CLIENT_ID',
          defaultValue: '55890'),
      'response_type': 'token',
    });

class AnilistConnection {
  final int id;
  final String name, token;
  final bool enabled;
  const AnilistConnection(
      {required this.id,
      required this.name,
      required this.token,
      required this.enabled});
  AnilistConnection withEnabled(bool value) =>
      AnilistConnection(id: id, name: name, token: token, enabled: value);
}

class AnilistAccountStore {
  final FlutterSecureStorage storage;
  const AnilistAccountStore({this.storage = platformSecureStorage});
  String _key(String profile) => 'kinos:anilist:account:v1:$profile';
  Future<AnilistConnection?> read(String profile) async {
    final raw = await storage.read(key: _key(profile));
    if (raw == null) return null;
    try {
      final j = jsonDecode(raw);
      if (j is! Map ||
          positiveId(j['id']) == null ||
          j['name'] is! String ||
          j['token'] is! String ||
          (j['token'] as String).isEmpty ||
          j['enabled'] is! bool) {
        return null;
      }
      return AnilistConnection(
          id: positiveId(j['id'])!,
          name: j['name'] as String,
          token: j['token'] as String,
          enabled: j['enabled'] as bool);
    } on FormatException {
      return null;
    }
  }

  Future<void> save(String profile, AnilistConnection value) => storage.write(
      key: _key(profile),
      value: jsonEncode({
        'id': value.id,
        'name': value.name,
        'token': value.token,
        'enabled': value.enabled
      }));
  Future<void> delete(String profile) => storage.delete(key: _key(profile));
}
