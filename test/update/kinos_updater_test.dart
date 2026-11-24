import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'package:kinos/update/kinos_updater.dart';

void main() {
  test('the checksum of an archive comes from SHA256SUMS.txt', () {
    const sums = 'abc123  kinos-windows-x64-portable.zip\n'
        'DEF456 *kinos-macos-universal.zip\n';
    expect(expectedSha256(sums, 'kinos-windows-x64-portable.zip'), 'abc123');
    expect(expectedSha256(sums, 'kinos-macos-universal.zip'), 'def456');
    expect(expectedSha256(sums, 'kinos-linux.tar.gz'), isNull);
  });

  test('only Windows and macOS update themselves', () {
    expect(
        updateAssetKey(platform: TargetPlatform.windows), 'windows_portable');
    expect(updateAssetKey(platform: TargetPlatform.macOS), 'macos');
    expect(updateAssetKey(platform: TargetPlatform.linux), isNull);
  });

  test('the installed macOS app is found from its executable', () {
    expect(macAppBundle('/Applications/Kinos.app/Contents/MacOS/Kinos'),
        '/Applications/Kinos.app');
    expect(macAppBundle('/usr/local/bin/kinos'), isNull);
  });

  test('the new app is found inside the extracted archive', () async {
    final root = await Directory.systemTemp.createTemp('kinos-update-test');
    addTearDown(() => root.delete(recursive: true));
    // macOS : Kinos/Kinos.app/Contents/…
    await Directory(p.join(root.path, 'mac', 'Kinos', 'Kinos.app', 'Contents'))
        .create(recursive: true);
    expect(findAppBundle(Directory(p.join(root.path, 'mac')))?.path,
        p.join(root.path, 'mac', 'Kinos', 'Kinos.app'));
    // Windows : les fichiers de l'app à la racine.
    final win = Directory(p.join(root.path, 'win'));
    await Directory(p.join(win.path, 'data')).create(recursive: true);
    await File(p.join(win.path, 'kinos.exe')).writeAsString('');
    expect(findWindowsBundle(win, 'kinos.exe')?.path, win.path);
    expect(findWindowsBundle(win, 'other.exe'), isNull);
  });
}
