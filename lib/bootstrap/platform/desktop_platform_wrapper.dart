import 'dart:async';

import 'package:flutter/foundation.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:macos_window_utils/window_manipulator.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:smtc_windows/smtc_windows.dart' if (dart.library.html) 'package:kinos/stubs/web/smtc_web.dart';
import 'package:window_manager/window_manager.dart';

import 'package:kinos/bootstrap/platform/base_app_wrapper.dart';
import 'package:kinos/logic/application_menu.dart';
import 'package:kinos/providers/arguments_provider.dart';
import 'package:kinos/providers/settings/client_settings_provider.dart';
import 'package:kinos/providers/video_player_provider.dart';
import 'package:kinos/screens/video_player/components/seek_preview.dart';
import 'package:kinos/src/application_menu.g.dart';
import 'package:kinos/util/macos_window_helpers.dart';
import 'package:kinos/util/window_helper.dart';

class DesktopAppWrapper extends BaseAppWrapper {
  const DesktopAppWrapper({super.key, required super.builder});

  @override
  ConsumerState<DesktopAppWrapper> createState() => _DesktopAppWrapperState();
}

class _DesktopAppWrapperState extends BaseAppWrapperState<DesktopAppWrapper> with WindowListener {
  @override
  Future<void> platformInit() async {
    if (defaultTargetPlatform == TargetPlatform.windows) {
      await SMTCWindows.initialize();
    }
    if (defaultTargetPlatform == TargetPlatform.macOS) {
      await WindowManipulator.initialize(enableWindowDelegate: true);
    }

    ApplicationMenu.setUp(ApplicationMenuImp());

    await WindowManager.instance.ensureInitialized();
    windowManager.addListener(this);
    // La fermeture passe par [onWindowClose], qui libère les lecteurs avant
    // de détruire la fenêtre.
    await windowManager.setPreventClose(true);

    final packageInfo = await PackageInfo.fromPlatform();
    final clientSettings = ref.read(clientSettingsProvider);
    final startupArguments = ref.read(argumentsStateProvider);
    await windowManager.setupKinosWindowChrome(
      startupArguments,
      clientSettings,
      packageInfo,
    );
    await toggleMacTrafficLights(await windowManager.isFullScreen());
  }

  @override
  void dispose() {
    windowManager.removeListener(this);
    super.dispose();
  }

  @override
  Future<void> onWindowClose() async {
    ref.read(videoPlayerProvider).stop();
    ref.read(clientSettingsProvider.notifier).closeDirectory();
    // Les aperçus de la barre du lecteur (un mpv chacun) d'abord : détruits
    // avec le moteur Flutter, ils faisaient planter Kinos à la fermeture.
    await SeekPreviewEngine.disposeAll().timeout(const Duration(seconds: 2), onTimeout: () => const []);
    super.onWindowClose();
    await windowManager.destroy();
  }

  @override
  void onWindowResize() async {
    final size = await windowManager.getSize();
    ref.read(clientSettingsProvider.notifier).setWindowSize(size);
    super.onWindowResize();
  }

  @override
  void onWindowResized() async {
    final size = await windowManager.getSize();
    ref.read(clientSettingsProvider.notifier).setWindowSize(size);
    super.onWindowResized();
  }

  @override
  void onWindowMove() async {
    final position = await windowManager.getPosition();
    ref.read(clientSettingsProvider.notifier).setWindowPosition(position);
    super.onWindowMove();
  }

  @override
  void onWindowMoved() async {
    final position = await windowManager.getPosition();
    ref.read(clientSettingsProvider.notifier).setWindowPosition(position);
    super.onWindowMoved();
  }

  @override
  void onWindowEnterFullScreen() {
    ref.read(mediaPlaybackProvider.notifier).update((state) => state.copyWith(fullScreen: true));
    unawaited(toggleMacTrafficLights(true));
    super.onWindowEnterFullScreen();
  }

  @override
  void onWindowLeaveFullScreen() {
    unawaited(toggleMacTrafficLights(false));
    ref.read(mediaPlaybackProvider.notifier).update((state) => state.copyWith(fullScreen: false));
    super.onWindowLeaveFullScreen();
  }
}
