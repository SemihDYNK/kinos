import 'package:flutter/widgets.dart';

/// Comme [SliverLayoutBuilder], mais ne reconstruit son contenu que si la
/// largeur disponible change.
///
/// [SliverLayoutBuilder] relance son `builder` dès que ses contraintes
/// changent ; or les contraintes d'un sliver portent la position de
/// défilement : chaque image d'un défilement reconstruisait toute la
/// grille (30 à 48 ms par image sur la page Découvrir). Ici, tant que la
/// largeur et le widget parent sont les mêmes, le même contenu est rendu
/// tel quel, et Flutter ne reconstruit rien.
class CrossAxisSliverBuilder extends StatefulWidget {
  const CrossAxisSliverBuilder({required this.builder, super.key});

  /// Reçoit la largeur disponible (`crossAxisExtent`).
  final Widget Function(BuildContext context, double width) builder;

  @override
  State<CrossAxisSliverBuilder> createState() => _CrossAxisSliverBuilderState();
}

class _CrossAxisSliverBuilderState extends State<CrossAxisSliverBuilder> {
  double? _width;
  Widget? _sliver;

  @override
  void didUpdateWidget(covariant CrossAxisSliverBuilder oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Le parent a reconstruit : le contenu peut avoir changé.
    _sliver = null;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sliver = null;
  }

  @override
  Widget build(BuildContext context) {
    // Le contenu dépend du thème et de la fenêtre (densité, taille du
    // texte) : en dépendre ici vide le cache quand ils changent.
    MediaQuery.of(context);
    DefaultTextStyle.of(context);
    return SliverLayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.crossAxisExtent;
        if (_sliver == null || width != _width) {
          _width = width;
          _sliver = widget.builder(context, width);
        }
        return _sliver!;
      },
    );
  }
}
