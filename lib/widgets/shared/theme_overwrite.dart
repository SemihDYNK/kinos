import 'package:flutter/material.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:kinos/providers/settings/client_settings_provider.dart';
import 'package:kinos/screens/shared/detail_scaffold.dart';
import 'package:kinos/theme.dart';

class ThemeOverwrite extends ConsumerStatefulWidget {
  const ThemeOverwrite({
    super.key,
    this.image,
    this.color,
    required this.child,
  });

  final ImageProvider? image;
  final Color? color;
  final Widget Function(BuildContext) child;

  @override
  ConsumerState<ThemeOverwrite> createState() => _ThemeOverwriteState();
}

class _ThemeOverwriteState extends ConsumerState<ThemeOverwrite> {
  Color? _dominantColor;

  @override
  void initState() {
    super.initState();
    if (widget.image != null) _fetchColor(widget.image!);
  }

  @override
  void didUpdateWidget(ThemeOverwrite old) {
    super.didUpdateWidget(old);
    if (widget.image != old.image) {
      _dominantColor = null;
      if (widget.image != null) _fetchColor(widget.image!);
    }
  }

  Future<void> _fetchColor(ImageProvider image) async {
    final color = await getDominantColor(image);
    if (!mounted || widget.image != image) return;
    setState(() => _dominantColor = color);
  }

  @override
  Widget build(BuildContext context) {
    // `deriveColorsFromItem` a disparu avec le passage du detail_scaffold à
    // PaletteService (cf. lib/screens/shared/detail_scaffold.dart). Ce widget
    // ne sert plus qu'aux écrans musique, hors périmètre du projet — laissé
    // tel quel jusqu'à leur retrait.
    final schemeVariant = ref.watch(clientSettingsProvider.select((value) => value.schemeVariant));
    final amoledBlack = ref.watch(clientSettingsProvider.select((value) => value.amoledBlack));
    final isDarkTheme = Theme.brightnessOf(context) == Brightness.dark;
    final effectiveColor = widget.image != null ? _dominantColor : widget.color;
    final amoledOverwrite = amoledBlack && isDarkTheme ? Colors.black : null;

    final newColorScheme = effectiveColor != null
        ? ColorScheme.fromSeed(
            seedColor: effectiveColor,
            brightness: Theme.brightnessOf(context),
            dynamicSchemeVariant: schemeVariant,
          )
        : null;

    final themeData = newColorScheme != null
        ? KinosTheme.theme(newColorScheme, schemeVariant).copyWith(
            scaffoldBackgroundColor: amoledOverwrite,
            cardColor: amoledOverwrite,
            canvasColor: amoledOverwrite,
            colorScheme: newColorScheme.copyWith(
              surface: amoledOverwrite,
              surfaceContainerHighest: amoledOverwrite,
              surfaceContainerLow: amoledOverwrite,
            ),
          )
        : Theme.of(context).copyWith(
            scaffoldBackgroundColor: amoledOverwrite,
            cardColor: amoledOverwrite,
            canvasColor: amoledOverwrite,
          );

    return Theme(
      data: themeData,
      child: Builder(builder: (context) => widget.child(context)),
    );
  }
}
