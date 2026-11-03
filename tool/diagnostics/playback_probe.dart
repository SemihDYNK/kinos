// Native playback regression probe; requires a local video path as argument.
import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:kinos/screens/shared/kinos_icon.dart';
import 'package:kinos/theme/app_theme.dart';
import 'package:kinos/widgets/shared/frosted_surface.dart';
import 'package:kinos/widgets/shared/ambient_blur.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

void main(List<String> arguments) {
  WidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();
  final player = Player();
  final controller = VideoController(player);
  runApp(MaterialApp(
    theme: buildAppTheme(),
    home: Scaffold(
        body: Stack(children: [
      Positioned.fill(
          child: AmbientBlur(
              captureFrame: () => player.screenshot(format: "image/png"))),
      Positioned.fill(
          child: Video(controller: controller, controls: NoVideoControls)),
      const Positioned(
          top: AppSpacing.xl,
          left: AppSpacing.xl,
          child: FrostedSurface(
              child: Padding(
                  padding: EdgeInsets.all(AppSpacing.md),
                  child: KinosWordmark()))),
      const Positioned(
          top: 180,
          bottom: 180,
          left: AppNavigation.inset,
          child: FrostedSurface(
              child: SizedBox(
                  width: AppNavigation.collapsedWidth,
                  child: Center(child: KinosIcon(size: AppBrand.markSize))))),
      const Positioned(
          bottom: AppSpacing.xl,
          right: AppSpacing.xl,
          child: FrostedSurface(
              child: Padding(
                  padding: EdgeInsets.all(AppSpacing.md),
                  child: Text('VIDEO + GLASS')))),
    ])),
  ));
  WidgetsBinding.instance.addPostFrameCallback((_) async {
    await player.open(Media(arguments.single));
    Timer(const Duration(seconds: 8), () async {
      final position = player.state.position;
      await player.dispose();
      if (position < const Duration(seconds: 1)) exit(1);
      stdout.writeln('PLAYBACK_OK');
      exit(0);
    });
  });
}
