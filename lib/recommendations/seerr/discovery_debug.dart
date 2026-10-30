import 'package:flutter/foundation.dart';

/// Debug-only progress. Never pass URLs, headers, identifiers or error messages.
class DiscoveryDebug {
  DiscoveryDebug({void Function(String)? write})
      : _write = write ?? _print;

  final void Function(String) _write;
  final Stopwatch _clock = Stopwatch()..start();
  static int _nextRun = 0;
  final int _run = ++_nextRun;
  String _stage = 'démarrage';

  static void _print(String line) {
    if (kDebugMode) debugPrint(line);
  }

  void step(String stage, {Map<String, int> counts = const {}}) {
    _stage = stage;
    final values = counts.entries.map((e) => '${e.key}=${e.value}').join(' ');
    note('$stage $values');
  }

  void note(String message) {
    _write('[Seerr découverte] calcul=$_run '
        '+${_clock.elapsedMilliseconds}ms $message');
  }

  void failure(Object error, {bool cancelled = false}) {
    note('${cancelled ? 'annulé' : 'échec'} '
        'étape=$_stage type=${error.runtimeType}');
  }
}
