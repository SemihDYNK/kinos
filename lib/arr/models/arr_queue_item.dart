/// Statut normalisé d'une ligne de file d'attente — dérivé de trois champs
/// bruts distincts de `QueueResource` (`status`, `trackedDownloadStatus`,
/// `trackedDownloadState`) en une seule valeur affichable, avec une
/// priorité claire : une erreur/un avertissement de suivi prime toujours
/// sur le statut brut du téléchargement (un téléchargement "terminé" mais
/// bloqué à l'import est un avertissement, pas un succès).
enum ArrQueueStatus {
  downloading,
  paused,
  queued,
  importing,
  completed,
  warning,
  failed;

  static ArrQueueStatus fromApi({
    required String? status,
    required String? trackedDownloadStatus,
    required String? trackedDownloadState,
  }) {
    final tracked = trackedDownloadStatus?.toLowerCase();
    if (tracked == 'error') return ArrQueueStatus.failed;
    if (tracked == 'warning') return ArrQueueStatus.warning;

    final state = trackedDownloadState?.toLowerCase();
    if (state == 'importing' || state == 'importpending') {
      return ArrQueueStatus.importing;
    }
    if (state == 'imported') return ArrQueueStatus.completed;
    if (state == 'failed' || state == 'failedpending') {
      return ArrQueueStatus.failed;
    }

    return switch (status?.toLowerCase()) {
      'downloading' => ArrQueueStatus.downloading,
      'paused' => ArrQueueStatus.paused,
      'completed' => ArrQueueStatus.completed,
      'failed' => ArrQueueStatus.failed,
      'warning' => ArrQueueStatus.warning,
      _ => ArrQueueStatus.queued,
    };
  }

  String get label => switch (this) {
        ArrQueueStatus.downloading => 'Téléchargement',
        ArrQueueStatus.paused => 'En pause',
        ArrQueueStatus.queued => 'En attente',
        ArrQueueStatus.importing => 'Import en cours',
        ArrQueueStatus.completed => 'Terminé',
        ArrQueueStatus.warning => 'Avertissement',
        ArrQueueStatus.failed => 'Échec',
      };
}

/// Lit un champ en tolérant un type inattendu plutôt que de lever — un
/// `as int?`/`as String?` direct lève une exception si le champ existe
/// mais n'a pas exactement le type attendu (ex. un nombre renvoyé en
/// `double` là où `int` était attendu), ce qu'un simple `??` ne rattrape
/// pas (il ne couvre que l'absence, pas le mauvais type). Utilisé partout
/// dans [ArrQueueItem.fromJson] : les deux services partagent la forme
/// générale de `QueueResource`, mais Radarr porte un `movie` imbriqué là
/// où Sonarr porte `series`/`episode` — assez pour qu'un champ scalaire
/// diffère de forme d'un service à l'autre sans prévenir.
int? _asInt(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return null;
}

String? _asString(dynamic value) => value is String ? value : null;

class ArrQueueItem {
  final int id;
  final String title;
  final int? size;
  final int? sizeLeft;

  /// Chaîne fournie telle quelle par l'API (ex. "00:12:34") — pas de
  /// `Duration` reconstruite : le format exact varie selon la version du
  /// serveur et ne vaut pas la peine d'être reparsé pour un simple
  /// affichage.
  final String? timeLeft;

  final String? indexer;
  final String? qualityName;
  final int customFormatScore;
  final ArrQueueStatus status;
  final List<String> statusMessages;
  final String? errorMessage;
  final String protocol;

  /// Identifiant du téléchargement chez le client (hash du torrent côté
  /// qBittorrent) — partagé par toutes les lignes d'un même paquet de
  /// saison Sonarr (un enregistrement par épisode, même `downloadId`) :
  /// c'est la clé de regroupement (cf. `ArrQueueGroup`) et celle attendue
  /// par l'API du client de téléchargement pour pause/reprise.
  final String? downloadId;

  /// Numéro de saison — Sonarr uniquement, cherché à la fois au niveau
  /// de la ligne et dans l'objet `episode` imbriqué (la forme exacte
  /// n'est pas garantie identique selon la version du serveur). `null`
  /// côté Radarr, ou si introuvable.
  final int? seasonNumber;

  const ArrQueueItem({
    required this.id,
    required this.title,
    required this.size,
    required this.sizeLeft,
    required this.timeLeft,
    required this.indexer,
    required this.qualityName,
    required this.customFormatScore,
    required this.status,
    required this.statusMessages,
    required this.errorMessage,
    required this.protocol,
    required this.downloadId,
    required this.seasonNumber,
  });

  /// Progression 0.0–1.0, `null` si la taille totale est inconnue (ligne
  /// tout juste ajoutée, certains clients de téléchargement ne la
  /// renseignent pas immédiatement).
  double? get progress {
    final total = size;
    if (total == null || total <= 0) return null;
    final left = sizeLeft ?? total;
    return (1 - (left / total)).clamp(0.0, 1.0);
  }

  /// Ne lève jamais — chaque champ se replie sur une valeur par défaut
  /// s'il est absent ou d'un type inattendu (cf. [_asInt]/[_asString]),
  /// pour qu'une ligne mal formée dégrade proprement plutôt que de faire
  /// échouer tout le tableau (cf. [ArrApiClient._parseQueue], qui isole
  /// quand même chaque ligne individuellement en plus de ça).
  factory ArrQueueItem.fromJson(Map<String, dynamic> json) {
    final quality = json['quality'];
    String? qualityName;
    if (quality is Map) {
      final inner = quality['quality'];
      if (inner is Map) qualityName = _asString(inner['name']);
    }

    final rawMessages = json['statusMessages'];
    final messages = <String>[];
    if (rawMessages is List) {
      for (final entry in rawMessages) {
        if (entry is Map && entry['messages'] is List) {
          messages.addAll((entry['messages'] as List).whereType<String>());
        }
      }
    }

    final episode = json['episode'];
    final seasonNumber = _asInt(json['seasonNumber']) ??
        (episode is Map ? _asInt(episode['seasonNumber']) : null);

    return ArrQueueItem(
      id: _asInt(json['id']) ?? 0,
      title: _asString(json['title']) ?? '',
      size: _asInt(json['size']),
      sizeLeft: _asInt(json['sizeleft']),
      timeLeft: _asString(json['timeleft']),
      indexer: _asString(json['indexer']),
      qualityName: qualityName,
      customFormatScore: _asInt(json['customFormatScore']) ?? 0,
      status: ArrQueueStatus.fromApi(
        status: _asString(json['status']),
        trackedDownloadStatus: _asString(json['trackedDownloadStatus']),
        trackedDownloadState: _asString(json['trackedDownloadState']),
      ),
      statusMessages: messages,
      errorMessage: _asString(json['errorMessage']),
      protocol: (_asString(json['protocol']) ?? '').toLowerCase(),
      downloadId: _asString(json['downloadId']),
      seasonNumber: seasonNumber,
    );
  }
}

/// Un téléchargement de la file — une ligne par élément dans la plupart
/// des cas, mais un paquet de saison Sonarr fait tenir plusieurs épisodes
/// (même `downloadId`) dans un seul groupe : cf.
/// [ArrQueueGroup.groupItems]. Taille/progression/temps restant sont
/// portés par le groupe entier (Sonarr les répète, identiques, sur
/// chaque épisode d'un même paquet — les sommer les multiplierait par le
/// nombre d'épisodes au lieu de les lire une fois).
class ArrQueueGroup {
  final String key;
  final List<ArrQueueItem> items;

  const ArrQueueGroup({required this.key, required this.items});

  ArrQueueItem get primary => items.first;
  bool get isGrouped => items.length > 1;
  int get episodeCount => items.length;

  int get id => primary.id;
  String get title => primary.title;
  int? get size => primary.size;
  int? get sizeLeft => primary.sizeLeft;
  String? get timeLeft => primary.timeLeft;
  String? get indexer => primary.indexer;
  String? get qualityName => primary.qualityName;
  int get customFormatScore => primary.customFormatScore;
  ArrQueueStatus get status => primary.status;
  List<String> get statusMessages => primary.statusMessages;
  String? get errorMessage => primary.errorMessage;
  String get protocol => primary.protocol;
  String? get downloadId => primary.downloadId;
  double? get progress => primary.progress;

  /// Étiquette courte pour un paquet groupé — "S03 · 11 épisodes" quand
  /// le numéro de saison est connu, sinon juste "11 épisodes".
  String get groupLabel {
    final season = primary.seasonNumber;
    final episodes = '$episodeCount épisode${episodeCount > 1 ? 's' : ''}';
    return season == null
        ? episodes
        : 'S${season.toString().padLeft(2, '0')} · $episodes';
  }

  /// Regroupe par `downloadId` — chaque ligne sans `downloadId` (ou dont
  /// le `downloadId` n'est partagé par aucune autre ligne) reste un
  /// groupe à elle seule ; l'ordre d'apparition d'origine est préservé
  /// (première occurrence de chaque `downloadId`).
  static List<ArrQueueGroup> groupItems(List<ArrQueueItem> items) {
    final order = <String>[];
    final byKey = <String, List<ArrQueueItem>>{};
    var ungroupedIndex = 0;
    for (final item in items) {
      final key = item.downloadId?.isNotEmpty == true
          ? item.downloadId!
          : '__single_${ungroupedIndex++}';
      if (!byKey.containsKey(key)) order.add(key);
      byKey.putIfAbsent(key, () => []).add(item);
    }
    return order
        .map((key) => ArrQueueGroup(key: key, items: byKey[key]!))
        .toList();
  }
}
