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

/// Une ligne de `GET /api/v3/queue` — commune à Radarr et Sonarr (mêmes
/// champs pour l'essentiel ; `seriesId`/`episodeId` restent `null` côté
/// Radarr, `movieId` côté Sonarr).
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

  factory ArrQueueItem.fromJson(Map<String, dynamic> json) {
    final quality = json['quality'];
    String? qualityName;
    if (quality is Map) {
      final inner = quality['quality'];
      if (inner is Map) qualityName = inner['name'] as String?;
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

    return ArrQueueItem(
      id: json['id'] as int? ?? 0,
      title: json['title'] as String? ?? '',
      size: json['size'] as int?,
      sizeLeft: json['sizeleft'] as int?,
      timeLeft: json['timeleft'] as String?,
      indexer: json['indexer'] as String?,
      qualityName: qualityName,
      customFormatScore: json['customFormatScore'] as int? ?? 0,
      status: ArrQueueStatus.fromApi(
        status: json['status'] as String?,
        trackedDownloadStatus: json['trackedDownloadStatus'] as String?,
        trackedDownloadState: json['trackedDownloadState'] as String?,
      ),
      statusMessages: messages,
      errorMessage: json['errorMessage'] as String?,
      protocol: (json['protocol'] as String? ?? '').toLowerCase(),
    );
  }
}
