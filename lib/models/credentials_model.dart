import 'dart:convert';

import 'package:flutter/foundation.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:xid/xid.dart';

import 'package:kinos/providers/arguments_provider.dart';
import 'package:kinos/util/application_info.dart';
import 'package:kinos/util/string_extensions.dart';

part 'credentials_model.freezed.dart';
part 'credentials_model.g.dart';

@Freezed(copyWith: true)
abstract class CredentialsModel with _$CredentialsModel, DiagnosticableTreeMixin {
  const CredentialsModel._();

  factory CredentialsModel.internal({
    @Default("") String token,
    @Default("") String url,
    String? localUrl,
    @Default("") String serverName,
    @Default("") String serverId,
    @Default("") String deviceId,
  }) = _CredentialsModel;

  factory CredentialsModel.createNewCredentials() => CredentialsModel.internal(deviceId: Xid().toString());

  Map<String, String> header(Ref ref) {
    final application = ref.read(applicationInfoProvider);
    final leanbackMode = ref.read(argumentsStateProvider).leanBackMode;
    final os = switch (application.platform) {
      TargetPlatform.android => kIsWeb
          ? "${application.platform.name.capitalize()} Web"
          : (leanbackMode ? "${application.platform.name.capitalize()} TV" : application.platform.name.capitalize()),
      _ => !kIsWeb ? application.platform.name.capitalize() : "${application.platform.name.capitalize()} Web",
    };
    final headers = {
      'authorization':
          'MediaBrowser Token="$token", Client="${application.name}", Device="$os", DeviceId="$deviceId", Version="${application.version}"'
    };
    return headers;
  }

  factory CredentialsModel.fromJson(Map<String, dynamic> json) => _$CredentialsModelFromJson(json);

  factory CredentialsModel.fromJsonString(String source) => CredentialsModel.fromMap(json.decode(source));

  factory CredentialsModel.fromMap(Map<String, dynamic> map) {
    return CredentialsModel.internal(
      token: map['token'] ?? '',
      url: map['server'] ?? '',
      serverName: map['serverName'] ?? '',
      serverId: map['serverId'] ?? '',
      deviceId: map['deviceId'] ?? '',
    );
  }

  /// Overrides the generated [DiagnosticableTreeMixin] members (which would
  /// print [token] in clear — the Jellyfin session token, the one secret on
  /// this model) — same technique and same reasoning as
  /// `SeerrCredentialsModel.toString`: declared directly on this class
  /// rather than the generated `_$CredentialsModel` mixin, so Dart's normal
  /// method resolution prefers these. Presence only, never the value: this
  /// is what ends up in logs, uncaught-error reports and the Flutter
  /// DevTools widget inspector — [debugFillProperties] specifically is what
  /// DevTools reads to build its tree view, so overriding only [toString]
  /// would leave the token visible there.
  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    properties
      ..add(DiagnosticsProperty('type', 'CredentialsModel'))
      ..add(DiagnosticsProperty('token', token.isEmpty ? '' : '<redacted>'))
      ..add(DiagnosticsProperty('url', url))
      ..add(DiagnosticsProperty('localUrl', localUrl))
      ..add(DiagnosticsProperty('serverName', serverName))
      ..add(DiagnosticsProperty('serverId', serverId))
      ..add(DiagnosticsProperty('deviceId', deviceId));
  }

  @override
  String toString({DiagnosticLevel minLevel = DiagnosticLevel.info}) {
    return 'CredentialsModel(token: ${token.isEmpty ? '' : '<redacted>'}, url: $url, '
        'localUrl: $localUrl, serverName: $serverName, serverId: $serverId, deviceId: $deviceId)';
  }
}
