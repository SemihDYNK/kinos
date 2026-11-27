import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart' as mpv;

import 'package:kinos/providers/api_provider.dart';
import 'package:kinos/providers/shared_provider.dart';
import 'package:kinos/providers/user_provider.dart';

import 'wrapped_data.dart';

/// Réglage « Son du Wrapped » (activé par défaut), retenu d'une fois sur
/// l'autre.
const wrappedSoundKey = 'wrappedSound';

final wrappedSoundProvider = StateProvider<bool>((ref) =>
    ref.watch(sharedPreferencesProvider).getBool(wrappedSoundKey) ?? true);

void setWrappedSound(WidgetRef ref, bool enabled) {
  ref.read(wrappedSoundProvider.notifier).state = enabled;
  ref.read(sharedPreferencesProvider).setBool(wrappedSoundKey, enabled);
}

/// L'ambiance de chaque humeur, dans les sons de l'application.
String wrappedMoodAsset(WrappedMood mood) =>
    'asset:///assets/sounds/wrapped_${mood.name}.ogg';

/// L'adresse du thème Jellyfin d'un film (sa musique de générique), s'il en
/// a un sur le serveur.
final wrappedThemeSongProvider =
    FutureProvider.autoDispose.family<String?, String>((ref, itemId) async {
  try {
    final response = await ref
        .read(jellyApiProvider)
        .api
        .itemsItemIdThemeSongsGet(itemId: itemId, inheritFromParent: true);
    final song = response.body?.items?.firstOrNull?.id;
    if (song == null) return null;
    return buildServerUrl(ref, pathSegments: [
      'Audio',
      song,
      'stream'
    ], queryParameters: {
      'static': 'true',
      'api_key': ref.read(userProvider)?.credentials.token,
    });
  } catch (_) {
    return null;
  }
});

/// La musique du Wrapped : une ambiance par acte, en boucle, qui passe à
/// la suivante par un fondu enchaîné ; le thème du film de l'année pour la
/// clôture quand il existe. Deux lecteurs mpv sans image se relaient pour
/// les fondus. Un son absent ou illisible ne fait que se taire.
class WrappedAudio {
  WrappedAudio._(this._players);

  final List<mpv.Player> _players;
  int _active = 0;
  String? _current;
  bool _muted = false;
  bool _disposed = false;
  final _fades = <Timer>[];

  /// Volume mpv (0–100) : un fond, nettement sous la lecture vidéo.
  static const volume = 32.0;
  static const _fade = Duration(milliseconds: 2400);
  static const _fadeStep = Duration(milliseconds: 40);

  static WrappedAudio? create() {
    // Pas de son sur le web, ni dans les tests (sans bibliothèque mpv).
    if (kIsWeb || Platform.environment.containsKey('FLUTTER_TEST')) {
      return null;
    }
    try {
      mpv.MediaKit.ensureInitialized();
      mpv.Player player() => mpv.Player(
          configuration: const mpv.PlayerConfiguration(
              vo: 'null', title: 'Kinos', logLevel: mpv.MPVLogLevel.error));
      return WrappedAudio._([player(), player()]);
    } catch (_) {
      return null;
    }
  }

  /// Joue [source] (une ambiance ou le thème d'un film) ; rien si c'est
  /// déjà elle. La précédente s'efface pendant que celle-ci monte.
  Future<void> play(String? source) async {
    if (_disposed || source == _current) return;
    _current = source;
    final outgoing = _players[_active];
    _active = 1 - _active;
    final incoming = _players[_active];
    _ramp(outgoing, from: _muted ? 0 : volume, to: 0, then: outgoing.pause);
    if (source == null) return;
    try {
      await incoming.setVolume(0);
      await incoming.setPlaylistMode(mpv.PlaylistMode.single);
      await incoming.open(mpv.Media(source));
      if (!_muted) _ramp(incoming, from: 0, to: volume);
    } catch (_) {}
  }

  /// Coupe ou rend le son, sans perdre la place dans la musique.
  void mute(bool muted) {
    if (_disposed || muted == _muted) return;
    _muted = muted;
    final player = _players[_active];
    _ramp(player, from: muted ? volume : 0, to: muted ? 0 : volume, fast: true);
  }

  void _ramp(mpv.Player player,
      {required double from,
      required double to,
      bool fast = false,
      FutureOr<void> Function()? then}) {
    final length = fast ? _fade ~/ 4 : _fade;
    final start = DateTime.now();
    late final Timer timer;
    timer = Timer.periodic(_fadeStep, (_) {
      if (_disposed) return timer.cancel();
      final t = (DateTime.now().difference(start).inMicroseconds /
              length.inMicroseconds)
          .clamp(0.0, 1.0);
      unawaited(player.setVolume(from + (to - from) * t));
      if (t >= 1) {
        timer.cancel();
        _fades.remove(timer);
        if (then != null) unawaited(Future(then));
      }
    });
    _fades.add(timer);
  }

  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    for (final timer in _fades) {
      timer.cancel();
    }
    for (final player in _players) {
      await player.dispose();
    }
  }
}

/// L'acte d'une diapo (0 : le temps, 1 : les goûts, 2 : les séries,
/// 3 : vous), d'après son identifiant.
int wrappedActOf(String slideId) => switch (slideId) {
      'opening' || 'act1' || 'time' || 'when' || 'rhythm' => 0,
      'act2' ||
      'genre' ||
      'director' ||
      'actor' ||
      'ratings' ||
      'friends' ||
      'public-loves' ||
      'you-love' ||
      'agreement' ||
      'voyage' ||
      'elsewhere' =>
        1,
      'act3' ||
      'series' ||
      'marathon' ||
      'pace' ||
      'finished' ||
      'series-of-year' =>
        2,
      _ => 3,
    };
