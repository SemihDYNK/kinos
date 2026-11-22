import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import 'package:kinos/theme/app_theme.dart';

import 'wrapped_motion.dart';

/// Un format d'export : la story (9:16) ou l'écran (16:9), en pixels.
enum WrappedFormat {
  story(Size(1080, 1920), 'story'),
  screen(Size(1920, 1080), 'ecran');

  const WrappedFormat(this.size, this.suffix);
  final Size size;
  final String suffix;
}

/// Une page à exporter : son nom de fichier (sans extension ni format) et
/// son contenu, posé dans son état final.
class WrappedPage {
  const WrappedPage(
      {required this.file, required this.seconds, required this.builder});
  final String file;
  final double seconds;
  final WidgetBuilder builder;
}

/// Le dossier des exports : les images de l'utilisateur (Images, Pictures),
/// puis `Kinos/Wrapped <année>`.
Future<Directory> wrappedExportDirectory(int year) async {
  String? pictures;
  if (Platform.isLinux) {
    try {
      final result = await Process.run('xdg-user-dir', ['PICTURES']);
      final dir = (result.stdout as String).trim();
      if (result.exitCode == 0 && dir.isNotEmpty) pictures = dir;
    } catch (_) {}
  }
  final home = Platform.environment['HOME'] ??
      Platform.environment['USERPROFILE'] ??
      Directory.systemTemp.path;
  pictures ??= p.join(home, 'Pictures');
  final dir = Directory(p.join(pictures, 'Kinos', 'Wrapped $year'));
  await dir.create(recursive: true);
  return dir;
}

/// Ouvre [dir] dans le gestionnaire de fichiers du système.
Future<void> openWrappedDirectory(Directory dir) async {
  try {
    if (Platform.isLinux) {
      await Process.start('xdg-open', [dir.path]);
    } else if (Platform.isMacOS) {
      await Process.start('open', [dir.path]);
    } else if (Platform.isWindows) {
      await Process.start('explorer', [dir.path]);
    }
  } catch (_) {}
}

/// Le temps laissé aux images pour arriver, et à leur fondu pour finir.
const _settleTimeout = Duration(seconds: 10);
const _settleAfterImages = Duration(milliseconds: 900);

/// Rend [child] hors écran, à la taille [size] (pixels logiques = pixels de
/// l'image), et rend l'image. L'arbre reçoit le conteneur Riverpod, le
/// thème et la langue de l'application ; les images doivent déjà être en
/// cache (cf. [precacheImage]) pour figurer sur la première image.
Future<ui.Image> renderOffscreen(
    BuildContext context, Widget child, Size size) async {
  final container = ProviderScope.containerOf(context);
  final theme = Theme.of(context);
  final locale = Localizations.localeOf(context);
  final boundary = RenderRepaintBoundary();
  final renderView = RenderView(
    view: View.of(context),
    child: RenderPositionedBox(child: boundary),
    configuration: ViewConfiguration(
        logicalConstraints: BoxConstraints.tight(size), devicePixelRatio: 1),
  );
  final pipeline = PipelineOwner()..rootNode = renderView;
  renderView.prepareInitialFrame();
  final build = BuildOwner(focusManager: FocusManager());
  final root = RenderObjectToWidgetAdapter<RenderBox>(
    container: boundary,
    child: UncontrolledProviderScope(
      container: container,
      child: MediaQuery(
        data: MediaQueryData(size: size, disableAnimations: true),
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: Localizations(
            locale: locale,
            delegates: const [
              DefaultMaterialLocalizations.delegate,
              DefaultWidgetsLocalizations.delegate,
            ],
            child: Theme(
              data: theme,
              child: SizedBox.fromSize(size: size, child: child),
            ),
          ),
        ),
      ),
    ),
  ).attachToRenderTree(build);

  // On reconstruit jusqu'à ce que toutes les images soient arrivées et
  // aient fini leur fondu d'apparition (au plus [_settleTimeout]).
  void pass() {
    build.buildScope(root);
    build.finalizeTree();
    pipeline.flushLayout();
    pipeline.flushCompositingBits();
    pipeline.flushPaint();
  }

  final cache = PaintingBinding.instance.imageCache;
  final started = DateTime.now();
  DateTime? idleSince;
  while (DateTime.now().difference(started) < _settleTimeout) {
    pass();
    await Future<void>.delayed(const Duration(milliseconds: 50));
    if (cache.pendingImageCount > 0) {
      idleSince = null;
    } else if ((idleSince ??= DateTime.now())
        .isBefore(DateTime.now().subtract(_settleAfterImages))) {
      break;
    }
  }
  pass();
  final image = await boundary.toImage();
  // On démonte l'arbre : ses fournisseurs et ses écouteurs d'images.
  RenderObjectToWidgetAdapter<RenderBox>(container: boundary)
      .attachToRenderTree(build, root);
  build.buildScope(root);
  build.finalizeTree();
  return image;
}

/// Une page posée dans son état final : horloge arrêtée à la fin, sans
/// mouvement.
Widget wrappedStill(WrappedPage page) => ColoredBox(
      color: AppColors.scrim,
      child: WrappedClock(
        duration: page.seconds,
        motion: false,
        progress: const AlwaysStoppedAnimation(1),
        child: Builder(builder: page.builder),
      ),
    );

/// Exporte [pages] dans [formats] vers [dir] : un PNG par page et par
/// format. [onProgress] reçoit (faites, total).
Future<List<File>> exportWrapped(
  BuildContext context, {
  required Directory dir,
  required List<WrappedPage> pages,
  required Set<WrappedFormat> formats,
  List<ImageProvider> warm = const [],
  void Function(int done, int total)? onProgress,
}) async {
  // Les images chargées d'avance : la première page n'est jamais capturée
  // avant que ses affiches soient décodées.
  for (final image in warm) {
    if (!context.mounted) return const [];
    await precacheImage(image, context, onError: (_, __) {});
  }
  final files = <File>[];
  final total = pages.length * formats.length;
  var done = 0;
  for (final page in pages) {
    for (final format in WrappedFormat.values.where(formats.contains)) {
      if (!context.mounted) return files;
      final image =
          await renderOffscreen(context, wrappedStill(page), format.size);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      if (bytes == null) continue;
      final suffix = formats.length > 1 ? '-${format.suffix}' : '';
      final file = File(p.join(dir.path, '${page.file}$suffix.png'));
      await file.writeAsBytes(bytes.buffer.asUint8List(), flush: true);
      files.add(file);
      onProgress?.call(++done, total);
    }
  }
  return files;
}
