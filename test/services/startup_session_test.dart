import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:kinos/services/startup_session.dart';

void main() {
  final boot = DateTime(2026, 11, 17, 8);
  final now = DateTime(2026, 11, 17, 20);

  Future<SharedPreferences> prefs([DateTime? lastLaunch]) async {
    SharedPreferences.setMockInitialValues({
      if (lastLaunch != null)
        startupLastLaunchKey: lastLaunch.millisecondsSinceEpoch,
    });
    return SharedPreferences.getInstance();
  }

  StartupIntro resolve(SharedPreferences p,
          {DateTime? bootTime, Map<String, String> env = const {}}) =>
      resolveStartupIntro(p,
          now: now, bootTime: bootTime ?? boot, environment: env);

  test('tout premier lancement : version longue', () async {
    expect(resolve(await prefs()), StartupIntro.long);
  });

  test('premier lancement depuis le démarrage de la machine : version longue',
      () async {
    expect(resolve(await prefs(boot.subtract(const Duration(hours: 3)))),
        StartupIntro.long);
  });

  test('déjà lancé depuis le démarrage : version courte', () async {
    expect(resolve(await prefs(boot.add(const Duration(hours: 2)))),
        StartupIntro.short);
  });

  test('chaque lancement est noté : le suivant est court', () async {
    final p = await prefs(boot.subtract(const Duration(days: 1)));
    expect(resolve(p), StartupIntro.long);
    expect(p.getInt(startupLastLaunchKey), now.millisecondsSinceEpoch);
    expect(resolve(p), StartupIntro.short);
  });

  test('KINOS_STARTUP_INTRO force la version, et note quand même le lancement',
      () async {
    final p = await prefs(boot.add(const Duration(hours: 2)));
    expect(resolve(p, env: const {'KINOS_STARTUP_INTRO': 'long'}),
        StartupIntro.long);
    expect(resolve(await prefs(), env: const {'KINOS_STARTUP_INTRO': 'short'}),
        StartupIntro.short);
    expect(p.getInt(startupLastLaunchKey), now.millisecondsSinceEpoch);
  });

  test('le réglage force l\'animation, et le lancement est quand même noté',
      () async {
    Future<StartupIntro> withMode(StartupIntroMode mode,
        {DateTime? lastLaunch}) async {
      SharedPreferences.setMockInitialValues({
        startupIntroModeKey: mode.name,
        if (lastLaunch != null)
          startupLastLaunchKey: lastLaunch.millisecondsSinceEpoch,
      });
      final p = await SharedPreferences.getInstance();
      final intro = resolve(p);
      expect(p.getInt(startupLastLaunchKey), now.millisecondsSinceEpoch);
      return intro;
    }

    final sameSession = boot.add(const Duration(hours: 2));
    expect(await withMode(StartupIntroMode.full, lastLaunch: sameSession),
        StartupIntro.long);
    expect(await withMode(StartupIntroMode.quick), StartupIntro.short,
        reason: 'même au tout premier lancement');
    expect(await withMode(StartupIntroMode.legacy), StartupIntro.legacy);
    expect(await withMode(StartupIntroMode.auto, lastLaunch: sameSession),
        StartupIntro.short);
  });

  test('KINOS_STARTUP_INTRO=legacy force l\'ancienne animation', () async {
    expect(resolve(await prefs(), env: const {'KINOS_STARTUP_INTRO': 'legacy'}),
        StartupIntro.legacy);
  });

  test('l\'heure de démarrage de cette machine se lit', () {
    final boot = systemBootTime();
    expect(boot, isNotNull);
    expect(boot!.isBefore(DateTime.now()), isTrue);
  });
}
