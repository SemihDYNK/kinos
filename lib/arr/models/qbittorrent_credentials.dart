/// URL et identifiants d'une instance qBittorrent — même politique de
/// stockage que [ArrCredentials] (coffre sécurisé, jamais
/// SharedPreferences), mais un couple utilisateur/mot de passe plutôt
/// qu'une clé API : c'est ce que l'API WebUI de qBittorrent attend pour
/// `POST /api/v2/auth/login`.
class QBittorrentCredentials {
  final String baseUrl;
  final String username;
  final String password;

  const QBittorrentCredentials({
    required this.baseUrl,
    required this.username,
    required this.password,
  });

  static const empty =
      QBittorrentCredentials(baseUrl: '', username: '', password: '');

  bool get isConfigured => baseUrl.trim().isNotEmpty;

  QBittorrentCredentials copyWith({
    String? baseUrl,
    String? username,
    String? password,
  }) =>
      QBittorrentCredentials(
        baseUrl: baseUrl ?? this.baseUrl,
        username: username ?? this.username,
        password: password ?? this.password,
      );

  Map<String, dynamic> toJson() => {
        'baseUrl': baseUrl,
        'username': username,
        'password': password,
      };

  factory QBittorrentCredentials.fromJson(Map<String, dynamic> json) =>
      QBittorrentCredentials(
        baseUrl: json['baseUrl'] as String? ?? '',
        username: json['username'] as String? ?? '',
        password: json['password'] as String? ?? '',
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is QBittorrentCredentials &&
          other.baseUrl == baseUrl &&
          other.username == username &&
          other.password == password);

  @override
  int get hashCode => Object.hash(baseUrl, username, password);
}
