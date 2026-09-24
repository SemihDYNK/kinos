import 'dart:io';

/// Trace de démarrage temporaire (diagnostic écran noir sous Hyprland,
/// pas une fonctionnalité durable) — écrit dans un fichier plutôt que sur
/// la console : sous certains environnements de bureau, la console est
/// noyée ou pas consultée avant que le point de blocage ait déjà eu
/// lieu. Chemin fixe sous `/tmp`, jamais dérivé de
/// `path_provider`/XDG — ce sont justement ces résolutions qui sont
/// suspectées de bloquer, la trace ne doit dépendre d'aucune d'elles
/// pour fonctionner.
///
/// Écriture synchrone et immédiatement vidée sur disque (`flush: true`)
/// : si le programme se bloque juste après un appel à [traceStartup],
/// cette ligne doit malgré tout être déjà sur le disque, pas encore
/// dans un tampon perdu avec le process.
final _traceFile = File('/tmp/kinos_startup_trace.log');

void traceStartup(String message) {
  try {
    final now = DateTime.now().toIso8601String();
    _traceFile.writeAsStringSync('$now  $message\n',
        mode: FileMode.append, flush: true);
  } catch (_) {
    // Best-effort : l'écriture de la trace elle-même ne doit jamais
    // devenir une nouvelle cause de blocage ou de plantage au
    // démarrage.
  }
}
