/// URL et clé API d'une instance Radarr ou Sonarr — sérialisé tel quel
/// dans `flutter_secure_storage` (cf. ArrCredentialsStore), jamais dans
/// SharedPreferences (même politique que les identifiants Jellyfin).
class ArrCredentials {
  final String baseUrl;
  final String apiKey;

  const ArrCredentials({required this.baseUrl, required this.apiKey});

  static const empty = ArrCredentials(baseUrl: '', apiKey: '');

  bool get isConfigured =>
      baseUrl.trim().isNotEmpty && apiKey.trim().isNotEmpty;

  ArrCredentials copyWith({String? baseUrl, String? apiKey}) => ArrCredentials(
        baseUrl: baseUrl ?? this.baseUrl,
        apiKey: apiKey ?? this.apiKey,
      );

  Map<String, dynamic> toJson() => {'baseUrl': baseUrl, 'apiKey': apiKey};

  factory ArrCredentials.fromJson(Map<String, dynamic> json) => ArrCredentials(
        baseUrl: json['baseUrl'] as String? ?? '',
        apiKey: json['apiKey'] as String? ?? '',
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ArrCredentials &&
          other.baseUrl == baseUrl &&
          other.apiKey == apiKey);

  @override
  int get hashCode => Object.hash(baseUrl, apiKey);
}
