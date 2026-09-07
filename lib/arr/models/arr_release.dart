/// Protocole de la release — détermine si "seeders/leechers" ou un simple
/// libellé protocole s'affiche dans le tableau de résultats.
enum ArrReleaseProtocol {
  torrent,
  usenet,
  unknown;

  static ArrReleaseProtocol fromApi(String? value) =>
      switch (value?.toLowerCase()) {
        'torrent' => ArrReleaseProtocol.torrent,
        'usenet' => ArrReleaseProtocol.usenet,
        _ => ArrReleaseProtocol.unknown,
      };

  String get label => switch (this) {
        ArrReleaseProtocol.torrent => 'Torrent',
        ArrReleaseProtocol.usenet => 'Usenet',
        ArrReleaseProtocol.unknown => '—',
      };
}

/// Une ligne du tableau de résultats de recherche interactive — la forme
/// (largement commune à Radarr et Sonarr) de `ReleaseResource`, l'objet
/// renvoyé par `GET /api/v3/release`.
class ArrRelease {
  /// Identifiant de la release chez l'indexeur — avec [indexerId], ce
  /// qu'il faut renvoyer à `POST /api/v3/release` pour lancer le
  /// téléchargement.
  final String guid;
  final int indexerId;
  final String indexer;
  final String title;

  /// Taille en octets — `null` si absente de la réponse (rare, mais pas
  /// garanti par l'API).
  final int? size;

  /// Âge en jours (fractionnaire), toujours dérivé de `publishDate`
  /// (l'horodatage de PUBLICATION DE CETTE RELEASE chez l'indexeur — pas
  /// une date liée au film/à la série lui-même) recalculé à la volée par
  /// rapport à l'heure courante. Les champs `age`/`ageHours` renvoyés par
  /// l'API sont un instantané figé au moment où le serveur *Arr a
  /// construit sa réponse (potentiellement mis en cache) : ne servent que
  /// de repli si `publishDate` est absente ou illisible.
  final double? ageDays;

  final int? seeders;
  final int? leechers;
  final ArrReleaseProtocol protocol;
  final String? qualityName;
  final List<String> languages;

  /// Score des formats personnalisés — peut être négatif (pénalité).
  final int customFormatScore;

  final bool rejected;
  final List<String> rejections;

  const ArrRelease({
    required this.guid,
    required this.indexerId,
    required this.indexer,
    required this.title,
    required this.size,
    required this.ageDays,
    required this.seeders,
    required this.leechers,
    required this.protocol,
    required this.qualityName,
    required this.languages,
    required this.customFormatScore,
    required this.rejected,
    required this.rejections,
  });

  factory ArrRelease.fromJson(Map<String, dynamic> json) {
    final publishDate = DateTime.tryParse(json['publishDate'] as String? ?? '');
    final ageField = json['age'];
    final ageHoursField = json['ageHours'];
    final ageDays = publishDate != null
        ? DateTime.now().toUtc().difference(publishDate.toUtc()).inMinutes /
            (60 * 24)
        : ageField is num
            ? ageField.toDouble()
            : ageHoursField is num
                ? ageHoursField.toDouble() / 24
                : null;

    final rawLanguages = json['languages'];
    final languages = rawLanguages is List
        ? rawLanguages
            .whereType<Map>()
            .map((entry) => entry['name'] as String?)
            .whereType<String>()
            .toList()
        : <String>[
            if (json['language'] is Map &&
                (json['language'] as Map)['name'] is String)
              (json['language'] as Map)['name'] as String,
          ];

    final rawRejections = json['rejections'];
    final rejections = rawRejections is List
        ? rawRejections.whereType<String>().toList()
        : const <String>[];

    final quality = json['quality'];
    String? qualityName;
    if (quality is Map) {
      final inner = quality['quality'];
      if (inner is Map) qualityName = inner['name'] as String?;
    }

    return ArrRelease(
      guid: json['guid'] as String? ?? '',
      indexerId: json['indexerId'] as int? ?? 0,
      indexer: json['indexer'] as String? ?? '',
      title: json['title'] as String? ?? '',
      size: json['size'] as int?,
      ageDays: ageDays,
      seeders: json['seeders'] as int?,
      leechers: json['leechers'] as int?,
      protocol: ArrReleaseProtocol.fromApi(json['protocol'] as String?),
      qualityName: qualityName,
      languages: languages,
      customFormatScore: json['customFormatScore'] as int? ?? 0,
      rejected: json['rejected'] as bool? ?? false,
      rejections: rejections,
    );
  }
}
