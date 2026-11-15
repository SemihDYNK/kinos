import 'package:logging/logging.dart';

/// Journal des moteurs de lecture. Les niveaux WARNING et SEVERE sont repris
/// par le journal de l'app (À propos → journal), y compris sur les versions
/// publiées.
final playerLogger = Logger('Player');

final _secretQuery = RegExp(
  r'([?&](?:api_key|apikey|ApiKey|X-Emby-Token|X-MediaBrowser-Token|token|PlaySessionId)=)[^&\s"]+',
  caseSensitive: false,
);

/// Masque les jetons d'accès qu'une URL de flux Jellyfin porte en paramètre.
String redactPlayerLog(String text) =>
    text.replaceAllMapped(_secretQuery, (m) => '${m[1]}***');
