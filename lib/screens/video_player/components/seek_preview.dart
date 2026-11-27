import 'dart:async';
import 'dart:collection';
import 'dart:developer';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';

import 'package:media_kit/media_kit.dart' as mpv;

import 'package:kinos/models/playback/direct_playback_model.dart';
import 'package:kinos/models/playback/offline_playback_model.dart';
import 'package:kinos/models/playback/playback_model.dart';

/// L'image du film à une position donnée, pour l'aperçu au survol de la
/// barre quand le serveur n'a pas généré de trickplay.
///
/// Un second mpv, invisible et muet, ouvre le même fichier et, à chaque
/// demande, saute à l'image clé la plus proche et en tire une vignette de
/// [width] pixels de large. Seulement en lecture directe ou hors ligne :
/// sur un flux transcodé, il lancerait un second transcodage sur le
/// serveur.
class SeekPreviewEngine {
  SeekPreviewEngine._(this._player) {
    _live.add(this);
  }

  final mpv.Player _player;

  /// Les aperçus ouverts : à fermer avant la fenêtre, sans quoi leur mpv,
  /// détruit avec le moteur Flutter, fait planter Kinos (SIGSEGV).
  static final _live = <SeekPreviewEngine>{};

  static Future<void> disposeAll() =>
      Future.wait([for (final engine in _live.toList()) engine.dispose()]);

  /// Largeur des vignettes.
  static const width = 320;

  /// Vignettes gardées : la grille du film entier, plus les instants
  /// survolés précisément.
  static const maxFrames = 120;
  static const _maxExact = 40;

  /// Écart minimal de la grille.
  static const _minStep = Duration(seconds: 10);

  /// Assez proche d'une vignette en cache : pas de nouvelle capture.
  static const _closeEnough = Duration(seconds: 2);

  /// La vignette montrée, avec l'instant réel de son image.
  final frame = ValueNotifier<({Duration at, ui.Image image})?>(null);

  /// Les vignettes tirées, par instant réel (ms).
  final _cache = SplayTreeMap<int, ui.Image>();
  final _exact = Queue<int>();

  /// La grille à précapturer, du plus grossier au plus fin.
  final _prefetch = Queue<int>();
  bool _planned = false;

  int? _height;
  Duration? _wanted;
  Duration? _hovered;
  bool _busy = false;
  bool _disposed = false;

  /// L'adresse que l'aperçu peut ouvrir pour [model], ou null.
  static String? sourceOf(PlaybackModel? model) => switch (model) {
        DirectPlaybackModel(:final media?) when media.url.isNotEmpty =>
          media.url,
        OfflinePlaybackModel(:final media?) when media.url.isNotEmpty =>
          media.url,
        _ => null,
      };

  static Future<SeekPreviewEngine?> open(String url) async {
    try {
      final player = mpv.Player(
          configuration: const mpv.PlayerConfiguration(
              vo: 'null',
              muted: true,
              title: 'Kinos aperçu',
              logLevel: mpv.MPVLogLevel.error));
      final native = player.platform as dynamic;
      for (final (name, value) in const [
        // media_kit coupe la vidéo tant qu'aucun affichage n'est attaché.
        ('vid', 'auto'),
        ('aid', 'no'),
        ('sid', 'no'),
        ('sub-auto', 'no'),
        ('hr-seek', 'no'),
        ('hwdec', 'no'),
        ('vd-lavc-skiploopfilter', 'all'),
        ('vd-lavc-fast', 'yes'),
        ('demuxer-max-bytes', '4MiB'),
        ('demuxer-readahead-secs', '0'),
        ('load-scripts', 'no'),
        ('ytdl', 'no'),
      ]) {
        await native.setProperty(name, value);
      }
      await player.open(mpv.Media(url), play: false);
      return SeekPreviewEngine._(player);
    } catch (error) {
      log('Aperçu de la barre indisponible : $error');
      return null;
    }
  }

  /// Montre aussitôt la vignette en cache la plus proche de [at], puis
  /// capture l'instant exact s'il n'y en a pas d'assez proche. Seule la
  /// dernière demande compte : un survol rapide ne fait pas la queue.
  void request(Duration at) {
    if (_disposed) return;
    _hovered = at;
    _show(at);
    final near = _nearest(at);
    if (near == null ||
        (near - at.inMilliseconds).abs() > _closeEnough.inMilliseconds) {
      _wanted = at;
    }
    if (!_busy) unawaited(_pump());
  }

  int? _nearest(Duration at) {
    final ms = at.inMilliseconds;
    final before = _cache.lastKeyBefore(ms + 1);
    final after = _cache.firstKeyAfter(ms);
    if (before == null) return after;
    if (after == null) return before;
    return ms - before <= after - ms ? before : after;
  }

  void _show(Duration at) {
    final key = _nearest(at);
    if (key == null) return;
    final image = _cache[key]!;
    if (frame.value?.image == image) return;
    frame.value = (at: Duration(milliseconds: key), image: image);
  }

  /// Les demandes d'abord, puis la grille du film en arrière-plan.
  Future<void> _pump() async {
    _busy = true;
    try {
      while (!_disposed) {
        final wanted = _wanted;
        _wanted = null;
        final int target;
        if (wanted != null) {
          target = wanted.inMilliseconds;
        } else {
          if (!_planned) await _plan();
          if (_prefetch.isEmpty) break;
          target = _prefetch.removeFirst();
          final near = _nearest(Duration(milliseconds: target));
          if (near != null &&
              (near - target).abs() < _closeEnough.inMilliseconds) {
            continue;
          }
        }
        final grabbed = await _grab(Duration(milliseconds: target));
        if (grabbed == null) continue;
        if (_disposed) {
          grabbed.image.dispose();
          return;
        }
        _store(grabbed.at, grabbed.image, exact: wanted != null);
        if (_hovered case final hovered?) _show(hovered);
      }
    } catch (error) {
      log('Aperçu de la barre : $error');
    } finally {
      _busy = false;
    }
  }

  void _store(int at, ui.Image image, {required bool exact}) {
    final old = _cache[at];
    if (old != null && old != image) {
      if (frame.value?.image == old) {
        image.dispose();
        return;
      }
      old.dispose();
    }
    _cache[at] = image;
    if (!exact) return;
    _exact.addLast(at);
    // Les instants survolés ne s'accumulent pas : les plus anciens partent,
    // sauf celui qui est affiché.
    while (_exact.length > _maxExact) {
      final key = _exact.removeFirst();
      final evicted = _cache[key];
      if (evicted == null || frame.value?.image == evicted) continue;
      _cache.remove(key)?.dispose();
    }
  }

  /// La grille : [maxFrames] instants au plus, tous les [_minStep] au
  /// moins, dans un ordre qui couvre vite tout le film (d'abord un sur
  /// huit, puis un sur quatre…).
  Future<void> _plan() async {
    _planned = true;
    var duration = _player.state.duration;
    if (duration <= Duration.zero) {
      final native = _player.platform as dynamic;
      final seconds =
          double.tryParse(await native.getProperty('duration') as String);
      if (seconds == null) return;
      duration = Duration(milliseconds: (seconds * 1000).round());
    }
    _prefetch.addAll(previewGrid(duration));
  }

  Future<({int at, ui.Image image})?> _grab(Duration at) async {
    final native = _player.platform as dynamic;
    await _player.seek(at);
    for (var i = 0; i < 40; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 15));
      if (_disposed) return null;
      if (await native.getProperty('seeking') != 'yes') break;
    }
    final height = _height ??= await _scaleHeight(native);
    if (height == null) return null;
    final bytes = await _player.screenshot(format: null);
    if (bytes == null || bytes.isEmpty) return null;
    final pixels = packFrame(bytes, width, height);
    if (pixels == null) return null;
    // L'image clé atteinte peut précéder l'instant demandé de quelques
    // secondes : la vignette est rangée à son instant réel.
    final position =
        double.tryParse(await native.getProperty('time-pos') as String);
    final completer = Completer<ui.Image>();
    ui.decodeImageFromPixels(
        pixels, width, height, ui.PixelFormat.bgra8888, completer.complete);
    return (
      at: position == null ? at.inMilliseconds : (position * 1000).round(),
      image: await completer.future,
    );
  }

  /// La hauteur des vignettes d'après l'image du film (son rapport
  /// d'affichage), puis le filtre qui les réduit à [width] de large.
  Future<int?> _scaleHeight(dynamic native) async {
    final w = double.tryParse(await native.getProperty('video-params/dw'));
    final h = double.tryParse(await native.getProperty('video-params/dh'));
    if (w == null || h == null || w <= 0 || h <= 0) return null;
    final height = previewHeight(w, h);
    await native.setProperty('vf', 'scale=$width:$height');
    // Le filtre s'applique aux images suivantes : on reprend celle-ci.
    await _player.seek(_player.state.position);
    return height;
  }

  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    _live.remove(this);
    // Le notificateur n'est pas libéré : la vignette affichée peut encore
    // l'écouter le temps d'une image ; il part avec le moteur.
    frame.value = null;
    for (final image in _cache.values) {
      image.dispose();
    }
    _cache.clear();
    _prefetch.clear();
    await _player.dispose();
  }
}

/// Les instants à précapturer pour un film de [duration] : une grille de
/// [SeekPreviewEngine.maxFrames] points au plus, tous les 10 s au moins,
/// rangée du plus grossier au plus fin.
List<int> previewGrid(Duration duration) {
  final total = duration.inMilliseconds;
  if (total <= 0) return const [];
  final step = (total / SeekPreviewEngine.maxFrames)
      .ceil()
      .clamp(SeekPreviewEngine._minStep.inMilliseconds, total);
  final count = total ~/ step + 1;
  final order = <int>[];
  final seen = <int>{};
  for (final stride in const [8, 4, 2, 1]) {
    for (var i = 0; i < count; i += stride) {
      if (seen.add(i)) order.add(i * step);
    }
  }
  return order;
}

/// Hauteur paire d'une vignette de [SeekPreviewEngine.width] de large pour
/// une image de [w]×[h].
int previewHeight(double w, double h) {
  final height = (SeekPreviewEngine.width * h / w).round();
  return height.isEven ? height : height + 1;
}

/// Les pixels `bgr0` de mpv, lignes éventuellement allongées (stride), en
/// BGRA serré et opaque pour [ui.decodeImageFromPixels]. Null si la taille
/// ne correspond pas.
Uint8List? packFrame(Uint8List bytes, int width, int height) {
  final row = width * 4;
  if (height <= 0 || bytes.length < row * height) return null;
  final stride = bytes.length ~/ height;
  if (stride < row) return null;
  final out = Uint8List(row * height);
  for (var y = 0; y < height; y++) {
    out.setRange(y * row, y * row + row, bytes, y * stride);
  }
  for (var i = 3; i < out.length; i += 4) {
    out[i] = 255;
  }
  return out;
}
