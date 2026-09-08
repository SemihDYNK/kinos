import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'package:flutter_svg/flutter_svg.dart';

import 'package:kinos/util/theme_extensions.dart';

class KinosIcon extends StatelessWidget {
  final double size;
  const KinosIcon({this.size = 100, super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        ShaderMask(
          shaderCallback: (Rect bounds) {
            return ui.Gradient.linear(
              const Offset(30, 30),
              const Offset(80, 80),
              [
                Theme.of(context).colorScheme.primary,
                Theme.of(context).colorScheme.secondary,
              ],
            );
          },
          child: SvgPicture.asset(
            "icons/kinos_icon.svg",
            width: size,
            colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn),
          ),
        ),
      ],
    );
  }
}

class KinosIconOutlined extends StatelessWidget {
  final double size;
  final Color? color;
  const KinosIconOutlined({this.size = 100, this.color, super.key});

  @override
  Widget build(BuildContext context) {
    return SvgPicture.asset(
      "icons/kinos_icon_outline.svg",
      width: size,
      colorFilter: ColorFilter.mode(color ?? context.colors.onSurfaceVariant, BlendMode.srcATop),
    );
  }
}
