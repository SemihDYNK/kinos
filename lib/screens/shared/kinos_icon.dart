import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:kinos/theme/app_theme.dart';

/// Kinos Signature: the same vector geometry at every display size.
class KinosIcon extends StatelessWidget {
  const KinosIcon({this.size = 100, super.key});
  final double size;
  @override
  Widget build(BuildContext context) => SvgPicture.asset('icons/kinos_signature_final.svg',
      width: size,
      height: size,
      semanticsLabel: 'Kinos',
      colorFilter:
          const ColorFilter.mode(AppColors.textPrimary, BlendMode.srcIn));
}

class KinosIconOutlined extends StatelessWidget {
  const KinosIconOutlined({this.size = 100, this.color, super.key});
  final double size;
  final Color? color;
  @override
  Widget build(BuildContext context) => SvgPicture.asset(
      'icons/kinos_signature_final.svg',
      width: size,
      height: size,
      semanticsLabel: 'Kinos',
      colorFilter:
          ColorFilter.mode(color ?? AppColors.textPrimary, BlendMode.srcIn));
}

class KinosWordmark extends StatelessWidget {
  const KinosWordmark({this.width = AppBrand.wordmarkWidth, super.key});
  final double width;
  @override
  Widget build(BuildContext context) => SvgPicture.asset(
      'icons/kinos_wordmark_final.svg',
      width: width,
      height: width / AppBrand.wordmarkAspectRatio,
      semanticsLabel: 'Kinos',
      colorFilter:
          const ColorFilter.mode(AppColors.textPrimary, BlendMode.srcIn));
}
