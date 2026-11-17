import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:kinos/providers/shared_provider.dart';

import 'package:kinos/services/startup_uptime/windows_uptime_stub.dart'
    if (dart.library.ffi) 'package:kinos/services/startup_uptime/windows_uptime_io.dart';

/// Animation de démarrage à jouer.
enum StartupIntro {
  /// Premier lancement depuis le démarrage de la machine : la version
  /// longue (gros plan, pièces venues des bords, clap).
  long,

  /// Kinos a déjà été ouvert depuis : la même intro, sans le mot.
  short,

  /// L'ancienne animation : l'assemblage court et l'ouverture en iris, sans
  /// projecteur ni sons.
  legacy,
}

/// Réglage « Animation de démarrage ».
enum StartupIntroMode {
  /// Complète au premier lancement depuis le démarrage de la machine, puis
  /// rapide (par défaut).
  auto,

  /// Toujours complète (avec « KINOS »).
  full,

  /// Toujours rapide (sans « KINOS »).
  quick,

  /// L'ancienne animation.
  legacy,
}

const startupIntroModeKey = 'startupIntroMode';

StartupIntroMode startupIntroMode(SharedPreferences preferences) =>
    StartupIntroMode.values
        .asNameMap()[preferences.getString(startupIntroModeKey)] ??
    StartupIntroMode.auto;

/// Le réglage, pour l'écran des réglages.
final startupIntroModeProvider = StateProvider<StartupIntroMode>(
    (ref) => startupIntroMode(ref.watch(sharedPreferencesProvider)));

void setStartupIntroMode(WidgetRef ref, StartupIntroMode mode) {
  ref.read(startupIntroModeProvider.notifier).state = mode;
  ref.read(sharedPreferencesProvider).setString(startupIntroModeKey, mode.name);
}

/// Dernier lancement de Kinos, en millisecondes depuis l'époque Unix.
const startupLastLaunchKey = 'startupLastLaunch';

/// Choisit l'animation de démarrage et note ce lancement.
///
/// Le réglage [StartupIntroMode] décide ; en automatique, la version longue
/// se joue au premier lancement depuis le démarrage de
/// la machine (le dernier lancement noté est plus ancien que le démarrage),
/// et au tout premier lancement. Si l'heure de démarrage est inconnue, la
/// version courte : mieux vaut la rater que la rejouer à chaque fois.
///
/// `KINOS_STARTUP_INTRO=long`, `short` ou `legacy` force l'une ou l'autre
/// (mise au point), avant le réglage. Le lancement est noté dans tous les
/// cas : revenu en automatique, le choix repart d'une base juste.
StartupIntro resolveStartupIntro(
  SharedPreferences preferences, {
  DateTime? now,
  DateTime? bootTime,
  Map<String, String>? environment,
}) {
  final forced = (environment ?? _environment())['KINOS_STARTUP_INTRO'];
  final last = preferences.getInt(startupLastLaunchKey);
  final current = now ?? DateTime.now();
  // Sans attendre : la décision ne dépend que de la valeur précédente.
  preferences.setInt(startupLastLaunchKey, current.millisecondsSinceEpoch);
  if (forced == 'long') return StartupIntro.long;
  if (forced == 'short') return StartupIntro.short;
  if (forced == 'legacy') return StartupIntro.legacy;
  switch (startupIntroMode(preferences)) {
    case StartupIntroMode.full:
      return StartupIntro.long;
    case StartupIntroMode.quick:
      return StartupIntro.short;
    case StartupIntroMode.legacy:
      return StartupIntro.legacy;
    case StartupIntroMode.auto:
      break;
  }
  if (last == null) return StartupIntro.long;
  final boot = bootTime ?? systemBootTime();
  if (boot == null) return StartupIntro.short;
  return last < boot.millisecondsSinceEpoch
      ? StartupIntro.long
      : StartupIntro.short;
}

Map<String, String> _environment() => kIsWeb ? const {} : Platform.environment;

/// Heure de démarrage de la machine, ou `null` si elle est inconnue.
DateTime? systemBootTime() {
  if (kIsWeb) return null;
  try {
    final uptime = switch (defaultTargetPlatform) {
      TargetPlatform.linux || TargetPlatform.android => _linuxUptime(),
      TargetPlatform.macOS => null,
      TargetPlatform.windows => windowsUptime(),
      _ => null,
    };
    if (uptime != null) return DateTime.now().subtract(uptime);
    if (defaultTargetPlatform == TargetPlatform.macOS) return _macBootTime();
  } catch (_) {
    // Heure de démarrage illisible : la version courte.
  }
  return null;
}

/// `/proc/uptime` : secondes depuis le démarrage, puis temps d'inactivité.
Duration? _linuxUptime() {
  final seconds =
      double.tryParse(File('/proc/uptime').readAsStringSync().split(' ').first);
  return seconds == null
      ? null
      : Duration(microseconds: (seconds * 1e6).round());
}

/// `sysctl -n kern.boottime` : `{ sec = 1731822222, usec = 123 } …`.
DateTime? _macBootTime() {
  final result = Process.runSync('sysctl', ['-n', 'kern.boottime']);
  final seconds =
      RegExp(r'sec = (\d+)').firstMatch(result.stdout.toString())?.group(1);
  return seconds == null
      ? null
      : DateTime.fromMillisecondsSinceEpoch(int.parse(seconds) * 1000);
}
