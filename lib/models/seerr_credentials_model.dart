// ignore_for_file: invalid_annotation_target

import 'package:freezed_annotation/freezed_annotation.dart';

part 'seerr_credentials_model.freezed.dart';
part 'seerr_credentials_model.g.dart';

@Freezed(copyWith: true)
abstract class SeerrCredentialsModel with _$SeerrCredentialsModel {
  const SeerrCredentialsModel._();

  const factory SeerrCredentialsModel({
    @Default("") String serverUrl,
    @Default("") String apiKey,
    @Default("") String sessionCookie,
    @Default({}) Map<String, String> customHeaders,
  }) = _SeerrCredentialsModel;

  bool get isConfigured {
    return serverUrl.isNotEmpty && (apiKey.isNotEmpty || sessionCookie.isNotEmpty);
  }

  factory SeerrCredentialsModel.fromJson(Map<String, dynamic> json) => _$SeerrCredentialsModelFromJson(json);

  /// Overrides the generated toString (which would print [apiKey],
  /// [sessionCookie] and [customHeaders] in clear) — declaring it directly
  /// on this class, rather than the generated `_$SeerrCredentialsModel`
  /// mixin, makes Dart's normal method resolution prefer this one. Presence
  /// only, never the value: this is what ends up in logs, uncaught-error
  /// reports and the Flutter DevTools widget inspector.
  @override
  String toString() {
    String redacted(String value) => value.isEmpty ? '' : '<redacted>';
    return 'SeerrCredentialsModel(serverUrl: $serverUrl, '
        'apiKey: ${redacted(apiKey)}, sessionCookie: ${redacted(sessionCookie)}, '
        'customHeaders: ${customHeaders.isEmpty ? '{}' : '<redacted>'})';
  }
}
