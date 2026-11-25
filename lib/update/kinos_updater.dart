import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';

import 'package:archive/archive_io.dart';
import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;

import 'package:kinos/util/update_checker.dart';

/// Les étapes d'une mise à jour, pour la barre de progression.
enum UpdateStage { downloading, verifying, extracting, installing }

/// Une mise à jour impossible, avec sa raison en clair.
class UpdateFailure implements Exception {
  const UpdateFailure(this.message);
  final String message;

  @override
  String toString() => message;
}

/// L'archive publiée pour ce système, ou null : Windows (portable) et macOS
/// seulement, les seuls publiés.
String? updateAssetKey({TargetPlatform? platform}) =>
    switch (platform ?? defaultTargetPlatform) {
      TargetPlatform.windows => 'windows_portable',
      TargetPlatform.macOS => 'macos',
      _ => null,
    };

/// Kinos peut se mettre à jour seul sur ce système.
bool get kinosCanSelfUpdate => !kIsWeb && updateAssetKey() != null;

/// L'empreinte attendue de [fileName] dans un `SHA256SUMS.txt`.
String? expectedSha256(String sums, String fileName) {
  for (final line in sums.split('\n')) {
    final parts = line.trim().split(RegExp(r'\s+'));
    if (parts.length < 2) continue;
    // `sha256sum` marque les fichiers binaires d'une étoile.
    final name = parts.last.replaceFirst(RegExp(r'^\*'), '');
    if (name == fileName) return parts.first.toLowerCase();
  }
  return null;
}

/// Le dossier d'une app macOS (`…/Kinos.app`) d'après son exécutable
/// (`…/Kinos.app/Contents/MacOS/Kinos`), ou null hors d'un paquet `.app`.
String? macAppBundle(String executable) {
  final bundle = p.dirname(p.dirname(p.dirname(executable)));
  return bundle.endsWith('.app') ? bundle : null;
}

/// Le premier dossier `.app` sous [root] (l'archive macOS contient
/// `Kinos/Kinos.app`).
Directory? findAppBundle(Directory root) {
  final queue = [root];
  for (var depth = 0; depth < 3 && queue.isNotEmpty; depth++) {
    final next = <Directory>[];
    for (final dir in queue) {
      for (final entity in dir.listSync(followLinks: false)) {
        if (entity is! Directory) continue;
        if (entity.path.endsWith('.app')) return entity;
        next.add(entity);
      }
    }
    queue
      ..clear()
      ..addAll(next);
  }
  return null;
}

/// Le dossier sous [root] qui contient [exeName] (l'archive Windows a les
/// fichiers de l'app à sa racine).
Directory? findWindowsBundle(Directory root, String exeName) {
  final queue = [root];
  for (var depth = 0; depth < 3 && queue.isNotEmpty; depth++) {
    final next = <Directory>[];
    for (final dir in queue) {
      if (File(p.join(dir.path, exeName)).existsSync()) return dir;
      next.addAll(dir.listSync(followLinks: false).whereType<Directory>());
    }
    queue
      ..clear()
      ..addAll(next);
  }
  return null;
}

/// Le journal du dernier remplacement : chaque étape des scripts y est
/// notée, pour comprendre une mise à jour qui n'a pas pris.
String get updateLogPath =>
    p.join(Directory.systemTemp.path, 'kinos-update.log');

/// Le script qui, une fois Kinos fermé, remplace l'app macOS et la relance.
/// Arguments : PID, app installée, nouvelle app, journal. Un Kinos qui ne
/// se termine pas au bout de 20 s est arrêté ; en cas d'échec, l'ancienne
/// app est remise en place. Kinos est relancé dans tous les cas.
const macUpdateScript = r'''#!/bin/sh
PID="$1"; APP="$2"; NEW="$3"; LOG="$4"
exec >>"$LOG" 2>&1
echo "$(date) Remplacement de $APP par $NEW"
i=0
while kill -0 "$PID" 2>/dev/null; do
  sleep 0.2
  i=$((i+1))
  if [ "$i" -eq 100 ]; then
    echo "Kinos ($PID) ne se termine pas : arrêt forcé"
    kill -9 "$PID"
  fi
done
echo "Kinos fermé"
OLD="$APP.kinos-old"
rm -rf "$OLD"
if mv "$APP" "$OLD"; then
  if mv "$NEW" "$APP"; then
    rm -rf "$OLD"
    echo "Nouvelle version en place"
  else
    echo "Échec : la nouvelle app n'a pas pu être déplacée, ancienne remise"
    mv "$OLD" "$APP"
  fi
else
  echo "Échec : l'app installée n'a pas pu être déplacée"
fi
xattr -dr com.apple.quarantine "$APP"
open "$APP" && echo "Kinos relancé"
''';

/// Le script qui, une fois Kinos fermé, copie la nouvelle version par-dessus
/// l'ancienne et la relance. Un Kinos qui ne se termine pas au bout de
/// 20 s est arrêté ; robocopy réessaie les fichiers encore verrouillés.
/// Kinos est relancé dans tous les cas.
const windowsUpdateScript = r'''param(
  [int]$ProcessId,
  [string]$Source,
  [string]$Target,
  [string]$Exe,
  [string]$Log
)
function Note([string]$Message) {
  Add-Content -LiteralPath $Log -Value ("{0} {1}" -f (Get-Date -Format o), $Message)
}
Note "Remplacement de $Target par $Source"
try { Wait-Process -Id $ProcessId -Timeout 20 -ErrorAction Stop } catch {}
if (Get-Process -Id $ProcessId -ErrorAction SilentlyContinue) {
  Note "Kinos ($ProcessId) ne se termine pas : arret force"
  Stop-Process -Id $ProcessId -Force -ErrorAction SilentlyContinue
  Start-Sleep -Seconds 1
}
Note "Kinos ferme"
& robocopy.exe $Source $Target /E /R:20 /W:1 /NP /NFL /NDL /NJH /NJS | Out-Null
$code = $LASTEXITCODE
if ($code -ge 8) { Note "Echec de la copie (robocopy $code)" } else { Note "Nouvelle version en place (robocopy $code)" }
Start-Process -FilePath (Join-Path $Target $Exe) -WorkingDirectory $Target
Note "Kinos relance"
''';

/// Télécharge la version [release] pour ce système, vérifie son empreinte,
/// la prépare, puis ferme Kinos : un petit script remplace l'app et la
/// relance. Réglages, identifiants et cache, rangés hors du dossier de
/// l'app, sont conservés.
class KinosUpdater {
  KinosUpdater({http.Client? client}) : _client = client ?? http.Client();
  final http.Client _client;

  Future<Never> install(
    ReleaseInfo release, {
    void Function(UpdateStage stage, double? progress)? onProgress,
  }) async {
    final key = updateAssetKey();
    final url = key == null ? null : release.downloads[key];
    if (url == null) {
      throw const UpdateFailure(
          'Cette version n\'a pas d\'archive pour ce système.');
    }
    final checksums = release.checksumsUrl;
    if (checksums == null) {
      throw const UpdateFailure(
          'Cette version ne publie pas d\'empreintes : mise à jour refusée.');
    }

    final executable = Platform.resolvedExecutable;
    final installed =
        Platform.isMacOS ? macAppBundle(executable) : p.dirname(executable);
    if (installed == null) {
      throw const UpdateFailure(
          'Kinos ne tourne pas depuis une app installée.');
    }
    await _checkWritable(p.dirname(installed));

    final work = await Directory.systemTemp.createTemp('kinos-update-');
    final fileName = Uri.parse(url).pathSegments.last;
    final archive = File(p.join(work.path, fileName));

    // 1. Téléchargement.
    onProgress?.call(UpdateStage.downloading, 0);
    final response = await _client.send(http.Request('GET', Uri.parse(url)));
    if (response.statusCode != 200) {
      throw UpdateFailure(
          'Téléchargement refusé par GitHub (${response.statusCode}).');
    }
    final total = response.contentLength;
    var received = 0;
    final sink = archive.openWrite();
    await for (final chunk in response.stream) {
      sink.add(chunk);
      received += chunk.length;
      if (total != null && total > 0) {
        onProgress?.call(UpdateStage.downloading, received / total);
      }
    }
    await sink.close();

    // 2. Empreinte : l'archive doit être celle de la release, octet pour
    // octet.
    onProgress?.call(UpdateStage.verifying, null);
    final sums = await _client.get(Uri.parse(checksums));
    final expected =
        sums.statusCode == 200 ? expectedSha256(sums.body, fileName) : null;
    if (expected == null) {
      throw const UpdateFailure('Empreinte de l\'archive introuvable.');
    }
    final actual = (await sha256.bind(archive.openRead()).first).toString();
    if (actual != expected) {
      throw const UpdateFailure(
          'L\'archive téléchargée ne correspond pas à son empreinte.');
    }

    // 3. Extraction. Sur macOS, `ditto` garde les liens symboliques et les
    // droits des frameworks, sans lesquels la signature ne tient plus.
    onProgress?.call(UpdateStage.extracting, null);
    final extracted = Directory(p.join(work.path, 'extracted'));
    await extracted.create();
    if (Platform.isMacOS) {
      final result = await Process.run(
          'ditto', ['-x', '-k', archive.path, extracted.path]);
      if (result.exitCode != 0) {
        throw const UpdateFailure('Impossible d\'extraire l\'archive.');
      }
    } else {
      await extractFileToDisk(archive.path, extracted.path);
    }

    // 4. Le script de remplacement, puis la fermeture de Kinos.
    onProgress?.call(UpdateStage.installing, null);
    final log = File(updateLogPath);
    await log.writeAsString(
        '${DateTime.now().toIso8601String()} Kinos ${release.version} '
        'extrait dans ${extracted.path}\n');
    if (Platform.isMacOS) {
      final app = findAppBundle(extracted);
      if (app == null) {
        throw const UpdateFailure('L\'archive ne contient pas Kinos.app.');
      }
      final script = File(p.join(work.path, 'update.sh'));
      await script.writeAsString(macUpdateScript);
      await Process.start(
          '/bin/sh', [script.path, '$pid', installed, app.path, log.path],
          mode: ProcessStartMode.detached);
    } else {
      final exeName = p.basename(executable);
      final bundle = findWindowsBundle(extracted, exeName);
      if (bundle == null) {
        throw UpdateFailure('L\'archive ne contient pas $exeName.');
      }
      final script = File(p.join(work.path, 'update.ps1'));
      await script.writeAsString(windowsUpdateScript);
      await Process.start(
          'powershell.exe',
          [
            '-NoProfile',
            '-ExecutionPolicy',
            'Bypass',
            '-WindowStyle',
            'Hidden',
            '-File',
            script.path,
            '-ProcessId',
            '$pid',
            '-Source',
            bundle.path,
            '-Target',
            installed,
            '-Exe',
            exeName,
            '-Log',
            log.path,
          ],
          mode: ProcessStartMode.detached);
    }
    // Le script note son départ : sans lui, Kinos se fermait pour rien.
    if (!await _started(log)) {
      throw UpdateFailure('Le script de mise à jour n\'a pas démarré '
          '(journal : ${log.path}).');
    }
    exit(0);
  }

  /// Le script a écrit sa première ligne dans [log] (au plus 10 s).
  static Future<bool> _started(File log) async {
    for (var i = 0; i < 50; i++) {
      final text = await log.readAsString().catchError((_) => '');
      if (text.contains('Remplacement')) return true;
      await Future<void>.delayed(const Duration(milliseconds: 200));
    }
    return false;
  }

  /// Kinos doit pouvoir écrire là où il est installé ; sinon, la mise à
  /// jour reste manuelle.
  static Future<void> _checkWritable(String dir) async {
    try {
      final probe = File(p.join(dir, '.kinos-update-check'));
      await probe.writeAsString('');
      await probe.delete();
    } catch (_) {
      throw UpdateFailure('Kinos ne peut pas écrire dans $dir : '
          'téléchargez la nouvelle version depuis GitHub.');
    }
  }
}
