import 'dart:io';

import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

import 'package:logging/logging.dart';

final _log = Logger('Frames');

/// Relevé des images lentes, écran par écran, pour la mise au point de la
/// fluidité : `KINOS_FRAME_LOG=1`. Inactif sinon.
///
/// Chaque image dont la construction ou le rendu dépasse 16,7 ms est
/// consignée (WARNING, journal de l'app) avec l'écran affiché ; un bilan
/// par écran suit toutes les 15 s.
abstract final class FrameLog {
  static const _budget = Duration(microseconds: 16700);
  static bool _active = false;
  static String _route = 'démarrage';
  static final _frames = <String, int>{};
  static final _slow = <String, int>{};

  static bool get requested =>
      !Platform.environment.containsKey('FLUTTER_TEST') &&
      Platform.environment['KINOS_FRAME_LOG'] == '1';

  static void startIfRequested() {
    if (_active || !requested) return;
    _active = true;
    SchedulerBinding.instance.addTimingsCallback(_onTimings);
    Stream<void>.periodic(const Duration(seconds: 15)).listen((_) {
      if (_frames.isEmpty) return;
      _log.warning('Bilan (lentes/total) : ${[
        for (final route in _frames.keys)
          '$route ${_slow[route] ?? 0}/${_frames[route]}'
      ].join(', ')}');
      _frames.clear();
      _slow.clear();
    });
  }

  static void _onTimings(List<FrameTiming> timings) {
    for (final timing in timings) {
      _frames[_route] = (_frames[_route] ?? 0) + 1;
      final build = timing.buildDuration, raster = timing.rasterDuration;
      if (build <= _budget && raster <= _budget) continue;
      _slow[_route] = (_slow[_route] ?? 0) + 1;
      _log.warning('Image lente ($_route) : build '
          '${(build.inMicroseconds / 1000).toStringAsFixed(1)} ms, raster '
          '${(raster.inMicroseconds / 1000).toStringAsFixed(1)} ms');
    }
  }
}

/// Suit l'écran affiché pour [FrameLog].
class FrameLogObserver extends NavigatorObserver {
  void _set(Route<dynamic>? route) {
    if (route == null || !FrameLog._active) return;
    FrameLog._route = route.settings.name ??
        (route is PopupRoute ? 'fenêtre' : 'page sans nom');
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      _set(route);

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      _set(previousRoute);

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) =>
      _set(newRoute);
}
