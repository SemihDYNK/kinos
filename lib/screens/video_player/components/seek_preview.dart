import 'dart:async';
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

  /// La dernière vignette tirée, avec sa position.
  final frame = ValueNotifier<({Duration at, ui.Image image})?>(null);

  int? _height;
  Duration? _wanted;
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

  /// Demande la vignette à [at]. Seule la dernière demande compte : un
  /// survol rapide ne fait pas la queue.
  void request(Duration at) {
    if (_disposed) return;
    _wanted = at;
    if (!_busy) unawaited(_pump());
  }

  Future<void> _pump() async {
    _busy = true;
    try {
      while (_wanted != null && !_disposed) {
        final at = _wanted!;
        _wanted = null;
        final image = await _grab(at);
        if (image == null) continue;
        if (_disposed) {
          image.dispose();
          return;
        }
        final previous = frame.value;
        frame.value = (at: at, image: image);
        previous?.image.dispose();
      }
    } catch (error) {
      log('Aperçu de la barre : $error');
    } finally {
      _busy = false;
    }
  }

  Future<ui.Image?> _grab(Duration at) async {
    final native = _player.platform as dynamic;
    await _player.seek(at);
    for (var i = 0; i < 40; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 25));
      if (_disposed) return null;
      if (await native.getProperty('seeking') != 'yes') break;
    }
    final height = _height ??= await _scaleHeight(native);
    if (height == null) return null;
    final bytes = await _player.screenshot(format: null);
    if (bytes == null || bytes.isEmpty) return null;
    final pixels = packFrame(bytes, width, height);
    if (pixels == null) return null;
    final completer = Completer<ui.Image>();
    ui.decodeImageFromPixels(
        pixels, width, height, ui.PixelFormat.bgra8888, completer.complete);
    return completer.future;
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
    final last = frame.value;
    // Le notificateur n'est pas libéré : la vignette affichée peut encore
    // l'écouter le temps d'une image ; il part avec le moteur.
    frame.value = null;
    last?.image.dispose();
    await _player.dispose();
  }
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
