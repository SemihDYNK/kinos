import 'package:media_kit/media_kit.dart' as mpv;

/// Les lecteurs mpv d'appoint (musique du Wrapped, sons de l'intro), hors
/// lecteur vidéo. Fermés avant la fenêtre : détruits avec le moteur Dart,
/// leurs rappels arrivaient après son arrêt et faisaient avorter Kinos
/// (« GetFfiCallbackMetadata called after shutdown »).
final _players = <mpv.Player>{};

mpv.Player openBackgroundPlayer(mpv.PlayerConfiguration configuration) {
  final player = mpv.Player(configuration: configuration);
  _players.add(player);
  return player;
}

/// [player] n'a pas encore été libéré : la fermeture de la fenêtre libère
/// tous les lecteurs d'un coup, sans prévenir leurs propriétaires, dont les
/// fondus en cours doivent alors s'arrêter.
bool backgroundPlayerOpen(mpv.Player player) => _players.contains(player);

/// Libère [player], une seule fois même si la fermeture de la fenêtre l'a
/// déjà fait.
Future<void> disposeBackgroundPlayer(mpv.Player player) async {
  if (!_players.remove(player)) return;
  await player.dispose();
}

Future<void> disposeBackgroundPlayers() => Future.wait(
    [for (final player in _players.toList()) disposeBackgroundPlayer(player)]);
