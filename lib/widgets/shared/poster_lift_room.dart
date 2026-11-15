import 'package:flutter/widgets.dart';

import 'package:kinos/theme/app_theme.dart';

/// Laisse de la place autour d'un défilement horizontal de jaquettes.
///
/// Un défilement découpe tout ce qui sort de sa boîte : la jaquette survolée
/// ou focalisée, qui se soulève et grossit (cf. [PosterHoverMotion]), y
/// perdait le haut de son contour. La boîte du défilement déborde donc de
/// [AppMotion.posterLiftRoom] de chaque côté, et [builder] reçoit le
/// padding à donner au défilement pour que les jaquettes restent à leur
/// place. La rangée garde sa taille dans la mise en page.
///
/// Le défilement voit une zone visible plus large de
/// `2 * AppMotion.posterLiftRoom` : à soustraire de `viewportDimension`
/// pour paginer à la largeur de la rangée.
class PosterLiftRoom extends StatelessWidget {
  const PosterLiftRoom(
      {required this.height, required this.builder, super.key});

  /// Hauteur des jaquettes, sans la marge.
  final double height;
  final Widget Function(BuildContext context, EdgeInsets padding) builder;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (context, constraints) {
          const room = AppMotion.posterLiftRoom;
          final width = constraints.maxWidth;
          return SizedBox(
            width: width,
            height: height,
            child: OverflowBox(
              minWidth: width + 2 * room,
              maxWidth: width + 2 * room,
              minHeight: height + 2 * room,
              maxHeight: height + 2 * room,
              child: builder(context, const EdgeInsets.all(room)),
            ),
          );
        },
      );
}
