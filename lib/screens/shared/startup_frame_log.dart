import 'dart:developer' show Timeline;
import 'dart:ui' show FrameTiming, FramePhase;

import 'package:flutter/scheduler.dart';

import 'package:logging/logging.dart';

/// Journal des images lentes du démarrage (niveau WARNING : repris par le
/// journal de l'app, y compris sur les versions publiées).
final startupFrameLogger = Logger('StartupFrames');

/// Phase de l'intro, pour attribuer chaque image lente.
enum StartupPhase {
  assembly('assemblage'),
  aurora('clap/aurore'),
  waiting('attente de l\'accueil'),
  beam('faisceau'),
  reveal('révélation de l\'accueil');

  const StartupPhase(this.label);
  final String label;
}

/// Relève les images lentes pendant le démarrage seulement, jusqu'à la fin
/// de la révélation de l'accueil.
///
/// Les durées d'image arrivent par paquets, après coup : chaque changement
/// de phase est daté sur l'horloge des images (celle de la timeline), et
/// chaque image est rattachée à la phase en cours au début de sa vsync.
abstract final class StartupFrameLog {
  /// Une image au-delà de ce budget (60 Hz) est consignée.
  static const _budget = Duration(microseconds: 16700);

  // Le dernier paquet de durées arrive après la fin de la révélation.
  static const _flush = Duration(milliseconds: 1500);

  static bool _active = false;
  static final _phases = <(int, StartupPhase)>[];
  static final _frames = <StartupPhase, int>{};
  static final _slow = <StartupPhase, int>{};

  static void start() {
    if (_active) return;
    _active = true;
    _phases
      ..clear()
      ..add((Timeline.now, StartupPhase.assembly));
    _frames.clear();
    _slow.clear();
    SchedulerBinding.instance.addTimingsCallback(_onTimings);
  }

  /// Change de phase (sans effet si c'est déjà la phase en cours).
  static void phase(StartupPhase phase) {
    if (!_active || _phases.last.$2 == phase) return;
    _phases.add((Timeline.now, phase));
  }

  /// Fin de la révélation : le relevé s'arrête une fois le dernier paquet
  /// reçu, avec un bilan par phase.
  static void stop() {
    if (!_active) return;
    Future<void>.delayed(_flush, () {
      if (!_active) return;
      _active = false;
      SchedulerBinding.instance.removeTimingsCallback(_onTimings);
      final summary = [
        for (final phase in StartupPhase.values)
          if (_frames[phase] != null)
            '${phase.label} ${_slow[phase] ?? 0}/${_frames[phase]}',
      ].join(', ');
      startupFrameLogger
          .warning('Démarrage : images lentes par phase (lentes/total) : '
              '$summary');
    });
  }

  static StartupPhase _phaseAt(int micros) {
    var current = _phases.first.$2;
    for (final (at, phase) in _phases) {
      if (at > micros) break;
      current = phase;
    }
    return current;
  }

  static void _onTimings(List<FrameTiming> timings) {
    for (final timing in timings) {
      final phase =
          _phaseAt(timing.timestampInMicroseconds(FramePhase.vsyncStart));
      _frames[phase] = (_frames[phase] ?? 0) + 1;
      final build = timing.buildDuration;
      final raster = timing.rasterDuration;
      if (build <= _budget && raster <= _budget) continue;
      _slow[phase] = (_slow[phase] ?? 0) + 1;
      startupFrameLogger.warning('Image lente (${phase.label}) : '
          'build ${_ms(build)} ms, raster ${_ms(raster)} ms, '
          'total ${_ms(timing.totalSpan)} ms');
    }
  }

  static String _ms(Duration duration) =>
      (duration.inMicroseconds / 1000).toStringAsFixed(1);
}
