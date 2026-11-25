import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'package:kinos/update/kinos_updater.dart';

void main() {
  test('the macOS script replaces the app, stops a lingering Kinos, relaunches',
      () async {
    final root = await Directory.systemTemp.createTemp('kinos-script-');
    addTearDown(() => root.delete(recursive: true));
    final app = Directory(p.join(root.path, 'Kinos.app'))..createSync();
    File(p.join(app.path, 'version')).writeAsStringSync('old');
    final fresh = Directory(p.join(root.path, 'new', 'Kinos.app'))
      ..createSync(recursive: true);
    File(p.join(fresh.path, 'version')).writeAsStringSync('new');
    // `xattr` et `open` de macOS, remplacés par des témoins.
    final bin = Directory(p.join(root.path, 'bin'))..createSync();
    final opened = p.join(root.path, 'opened');
    for (final (name, body) in [
      ('xattr', 'exit 0'),
      ('open', 'echo "\$1" > "$opened"'),
    ]) {
      final tool = File(p.join(bin.path, name))
        ..writeAsStringSync('#!/bin/sh\n$body\n');
      await Process.run('chmod', ['+x', tool.path]);
    }
    final script = File(p.join(root.path, 'update.sh'))
      ..writeAsStringSync(macUpdateScript);
    final log = File(p.join(root.path, 'update.log'))..writeAsStringSync('');
    // Un Kinos qui ne se termine pas de lui-même.
    final lingering = await Process.start('sleep', ['60']);

    final result = await Process.run('/bin/sh',
        [script.path, '${lingering.pid}', app.path, fresh.path, log.path],
        environment: {'PATH': '${bin.path}:${Platform.environment['PATH']}'});

    expect(result.exitCode, 0);
    expect(File(p.join(app.path, 'version')).readAsStringSync(), 'new');
    expect(Directory('${app.path}.kinos-old').existsSync(), isFalse);
    expect(File(opened).readAsStringSync().trim(), app.path);
    final text = log.readAsStringSync();
    expect(text, contains('Remplacement'));
    expect(text, contains('arrêt forcé'));
    expect(text, contains('Nouvelle version en place'));
  }, skip: Platform.isWindows, timeout: const Timeout(Duration(seconds: 60)));

  test('the Windows script copies the app, stops a lingering Kinos, relaunches',
      () async {
    final root = await Directory.systemTemp.createTemp('kinos-script-');
    addTearDown(() => root.delete(recursive: true));
    final target = Directory(p.join(root.path, 'Kinos'))..createSync();
    Directory(p.join(target.path, 'data')).createSync();
    File(p.join(target.path, 'data', 'app.so')).writeAsStringSync('old');
    final source = Directory(p.join(root.path, 'extracted'))..createSync();
    Directory(p.join(source.path, 'data')).createSync();
    File(p.join(source.path, 'data', 'app.so')).writeAsStringSync('new');
    final marker = p.join(root.path, 'relaunched');
    // Le « kinos.exe » relancé : un témoin qui laisse une trace.
    File(p.join(source.path, 'relaunch.cmd'))
        .writeAsStringSync('@echo off\r\necho ok > "$marker"\r\n');
    final script = File(p.join(root.path, 'update.ps1'))
      ..writeAsStringSync(windowsUpdateScript);
    final log = File(p.join(root.path, 'update.log'))..writeAsStringSync('');
    // Un Kinos qui ne se termine pas de lui-même.
    final lingering = await Process.start('ping', ['-n', '120', '127.0.0.1']);

    final result = await Process.run('powershell.exe', [
      '-NoProfile',
      '-ExecutionPolicy',
      'Bypass',
      '-File',
      script.path,
      '-ProcessId',
      '${lingering.pid}',
      '-Source',
      source.path,
      '-Target',
      target.path,
      '-Exe',
      'relaunch.cmd',
      '-Log',
      log.path,
    ]);

    expect(result.exitCode, 0, reason: '${result.stdout}${result.stderr}');
    expect(
        File(p.join(target.path, 'data', 'app.so')).readAsStringSync(), 'new');
    for (var i = 0; i < 50 && !File(marker).existsSync(); i++) {
      await Future<void>.delayed(const Duration(milliseconds: 200));
    }
    expect(File(marker).existsSync(), isTrue);
    final text = log.readAsStringSync();
    expect(text, contains('Remplacement'));
    expect(text, contains('arret force'));
    expect(text, contains('Nouvelle version en place'));
  }, skip: !Platform.isWindows, timeout: const Timeout(Duration(seconds: 90)));
}
