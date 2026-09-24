import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path/path.dart' as path;

import 'package:kinos/bootstrap/startup_trace.dart';

/// Ancien identifiant d'application (`linux/CMakeLists.txt` avant le
/// renommage en Kinos) — sert uniquement à la migration ci-dessous, plus
/// nulle part ailleurs dans le code.
const String legacyApplicationId = 'nl.jknaapen.fladder';

/// Identifiant actuel — cf. `linux/CMakeLists.txt` (`APPLICATION_ID`).
const String applicationId = 'app.kinos';

/// Migre le dossier de données déposé sous l'ancien identifiant vers le
/// nouveau — appelée en tout premier dans `bootstrapApplication()`, avant
/// tout accès à `SharedPreferences` ou à la base Drift. Les deux vivent
/// sous `getApplicationSupportDirectory()` (`path_provider_linux`), qui
/// résout `$XDG_DATA_HOME/<id GTK application-id>` : renommer
/// `APPLICATION_ID` sans rien faire aurait rendu la bibliothèque et
/// l'historique de lecture invisibles à la nouvelle identité. Un seul
/// déplacement de dossier couvre donc Drift ET SharedPreferences à la
/// fois — confirmé en lisant le code des deux plugins, pas supposé.
///
/// Ne fait rien hors Linux, ni si la nouvelle destination existe déjà
/// (migration déjà faite, ou premier lancement propre — jamais de
/// deuxième tentative, jamais d'écrasement).
Future<void> migrateLegacyDataDirectory({
  String? dataHomeOverride,
  Map<String, String>? environment,
}) async {
  if (kIsWeb || !Platform.isLinux) return;
  final dataHome =
      dataHomeOverride ?? _xdgDataHome(environment ?? Platform.environment);
  final oldDir = Directory(path.join(dataHome, legacyApplicationId));
  final newDir = Directory(path.join(dataHome, applicationId));

  if (await newDir.exists() || !await oldDir.exists()) return;

  try {
    await oldDir.rename(newDir.path);
  } catch (_) {
    // `rename()` échoue si les deux chemins ne sont pas sur le même
    // système de fichiers (rare pour $XDG_DATA_HOME, mais pas exclu) —
    // repli sur une copie récursive puis suppression de l'original.
    await _copyDirectoryContents(oldDir, newDir);
    await oldDir.delete(recursive: true);
  }
}

String _xdgDataHome(Map<String, String> environment) {
  final xdg = environment['XDG_DATA_HOME'];
  if (xdg != null && xdg.isNotEmpty) return xdg;
  final home = environment['HOME'] ?? '';
  return path.join(home, '.local', 'share');
}

Future<void> _copyDirectoryContents(
    Directory source, Directory destination) async {
  await destination.create(recursive: true);
  await for (final entity in source.list(recursive: false)) {
    final newPath = path.join(destination.path, path.basename(entity.path));
    if (entity is Directory) {
      await _copyDirectoryContents(entity, Directory(newPath));
    } else if (entity is File) {
      await entity.copy(newPath);
    }
  }
}

/// Attribut libsecret sous lequel `flutter_secure_storage_linux`
/// stockait tous les secrets (identifiants Jellyfin, Arr, qBittorrent)
/// avant le renommage — le plugin natif (code tiers, pas dans ce dépôt)
/// dérive directement ce nom de `APPLICATION_ID`
/// (`"<id>.secureStorage"`), donc changer cet identifiant sans rien
/// faire les aurait rendus invisibles à la nouvelle identité.
const String legacySecureStorageAccount = '$legacyApplicationId.secureStorage';

/// Délai maximal accordé à `secret-tool lookup` avant d'abandonner la
/// migration — une migration best-effort ne doit jamais retarder le
/// démarrage. Constaté en réel (diagnostic écran noir sous Hyprland/
/// Ryoku) : `secret-tool` peut rester bloqué indéfiniment si sa
/// recherche croise une collection libsecret verrouillée dont personne
/// ne répond à la demande de déverrouillage (un `SystemPrompter`
/// enregistré mais qui n'aboutit jamais) — ni une erreur, ni une
/// absence de `secret-tool`, juste un silence permanent, donc rien
/// qu'un simple `try/catch` puisse intercepter.
const _secretToolTimeout = Duration(seconds: 3);

/// Signature de `Process.run`, injectable pour les tests — pas de nouvelle
/// dépendance, juste de quoi remplacer l'appel réel par un faux.
typedef ProcessRunner = Future<ProcessResult> Function(
    String executable, List<String> arguments);

/// Signature de `Process.start`, injectable pour les tests — même
/// principe que [ProcessRunner], mais expose le [Process] en cours pour
/// pouvoir le tuer si [_secretToolTimeout] expire : `Process.run` ne
/// rend la main qu'une fois le processus déjà terminé, donc impossible
/// à interrompre depuis un simple `Future.timeout` sans laisser le
/// processus tourner en arrière-plan. C'est ce qui s'est produit
/// pendant le diagnostic : plusieurs `secret-tool` accumulés,
/// silencieusement bloqués, après plusieurs lancements successifs de
/// l'application — `Future.timeout` seul aurait arrêté d'attendre côté
/// Dart sans jamais arrêter le processus lui-même.
typedef ProcessStarter = Future<Process> Function(
    String executable, List<String> arguments);

/// Lance [executable] et attend sa fin au plus [_secretToolTimeout] —
/// au-delà, tue le processus au lieu de se contenter d'abandonner
/// l'attente (cf. [ProcessStarter]). Utilisée uniquement comme
/// implémentation par défaut de `runProcess` ci-dessous : un
/// `ProcessRunner` de test injecté directement (cf.
/// `legacy_migration_test.dart`) la court-circuite entièrement, aucun
/// changement de surface pour les tests existants.
Future<ProcessResult> _runWithTimeout(
    ProcessStarter start, String executable, List<String> arguments) async {
  final process = await start(executable, arguments);
  final stdoutFuture = process.stdout.transform(utf8.decoder).join();
  final stderrFuture = process.stderr.transform(utf8.decoder).join();

  var timedOut = false;
  final exitCode = await process.exitCode.timeout(_secretToolTimeout,
      onTimeout: () {
    timedOut = true;
    process.kill();
    return -1;
  });

  if (timedOut) {
    // Cas explicitement demandé à rester visible plutôt que silencieux
    // — distinct de "secret-tool a répondu, mais rien trouvé" (code non
    // nul, tracé plus bas comme les autres cas).
    traceStartup('migrateLegacySecureStorage: secret-tool a dépassé '
        '${_secretToolTimeout.inSeconds}s — processus tué, migration '
        'abandonnée sans bloquer le démarrage');
  }

  return ProcessResult(
      process.pid, exitCode, await stdoutFuture, await stderrFuture);
}

/// Best-effort : récupère les secrets stockés sous l'ancien identifiant
/// via `secret-tool` (paquet `libsecret-tools`, généralement présent sur
/// les environnements GNOME/KDE mais pas garanti) et les réécrit via
/// l'API `flutter_secure_storage` normale — qui les stockera désormais
/// sous le nouveau schéma. Si `secret-tool` est absent, si le trousseau
/// est verrouillé, si la réponse est illisible, ou si l'appel dépasse
/// [_secretToolTimeout] : abandon silencieux (hors l'expiration
/// elle-même, tracée, cf. [_runWithTimeout]), l'utilisateur redemande
/// une authentification comme à un premier lancement normal — jamais de
/// plantage, jamais de blocage, jamais de comportement surprenant pour
/// un cas qu'on ne peut pas garantir.
///
/// Ne touche à rien si le nouveau stockage contient déjà des données
/// (migration déjà faite, ou compte déjà réauthentifié) : jamais
/// d'écrasement.
Future<void> migrateLegacySecureStorage({
  FlutterSecureStorage? storage,
  ProcessRunner? runProcess,
  // Injectable séparément de [runProcess] (cf. [ProcessStarter]) : c'est
  // ce paramètre-ci, jamais `runProcess`, qui laisse un test exercer le
  // vrai comportement d'expiration/mise à mort de [_runWithTimeout]
  // plutôt que le contourner avec un `ProcessResult` tout prêt.
  ProcessStarter? processStarter,
}) async {
  if (kIsWeb || !Platform.isLinux) return;
  final secureStorage = storage ?? const FlutterSecureStorage();

  try {
    final existing = await secureStorage.readAll();
    if (existing.isNotEmpty) return;
  } catch (_) {
    return;
  }

  final run = runProcess ??
      (exe, args) =>
          _runWithTimeout(processStarter ?? Process.start, exe, args);
  Map<String, dynamic> data;
  try {
    final result = await run(
        'secret-tool', ['lookup', 'account', legacySecureStorageAccount]);
    if (result.exitCode != 0) return;
    final blob = (result.stdout as String).trim();
    if (blob.isEmpty) return;
    final decoded = jsonDecode(blob);
    if (decoded is! Map) return;
    data = Map<String, dynamic>.from(decoded);
  } catch (_) {
    return;
  }

  for (final entry in data.entries) {
    final value = entry.value;
    if (value is String) {
      await secureStorage.write(key: entry.key, value: value);
    }
  }
}
