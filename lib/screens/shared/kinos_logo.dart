import 'package:flutter/material.dart';
import 'package:kinos/screens/shared/kinos_icon.dart';

class KinosLogo extends StatelessWidget {
  const KinosLogo({super.key});
  @override
  Widget build(BuildContext context) =>
      const Hero(tag: 'Kinos_Logo_Tag', child: KinosWordmark());
}
