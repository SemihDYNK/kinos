import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:fladder/theme/app_theme.dart';

/// Voile ancré sur son déclencheur — pour un choix simple qui ne
/// justifie ni une feuille modale ni un panneau plein cadre. Reprend le
/// principe de positionnement de `ArrRejectionTooltip` ([OverlayPortal] +
/// `CustomSingleChildLayout`), mais interactif : fermeture au clic
/// extérieur et à Échap (avec retour du focus au déclencheur), et un
/// contenu dont la largeur suit le sien plutôt qu'un panneau pleine
/// hauteur.
///
/// Le contenu (fourni par [popoverBuilder]) reçoit un callback `close` —
/// à appeler une fois un choix fait, pour fermer sans attendre Échap.
/// Pour une liste de choix, cf. [PopoverOptionList], pensé pour être posé
/// directement dedans.
class AnchoredPopover extends StatefulWidget {
  final Widget child;
  final Widget Function(BuildContext context, VoidCallback close)
      popoverBuilder;
  final AnchoredPopoverController? controller;

  /// Côté préféré — au-dessus par défaut (boutons de barre d'outils en
  /// bas d'écran) ; bascule de l'autre côté tout seul si la place manque.
  final AxisDirection preferredDirection;

  /// Appelé à l'ouverture et à la fermeture — le popover est un
  /// `OverlayPortal` (posé au-dessus de tout, y compris un voile qui
  /// s'estompe) : un appelant dont le déclencheur peut disparaître
  /// (fondu d'inactivité...) doit pouvoir s'en garder informé, plutôt
  /// que de laisser un popover flotter sans plus rien qui l'ancre
  /// visuellement.
  final ValueChanged<bool>? onOpenChanged;

  const AnchoredPopover({
    required this.child,
    required this.popoverBuilder,
    this.controller,
    this.preferredDirection = AxisDirection.up,
    this.onOpenChanged,
    super.key,
  });

  @override
  State<AnchoredPopover> createState() => _AnchoredPopoverState();
}

/// Permet d'ouvrir/fermer un [AnchoredPopover] depuis l'extérieur (ex. un
/// raccourci clavier qui doit ouvrir le même popover que le bouton).
class AnchoredPopoverController {
  _AnchoredPopoverState? _state;

  void show() => _state?._show();
  void hide() => _state?._hide();
  void toggle() =>
      (_state?._overlayController.isShowing ?? false) ? hide() : show();
  bool get isOpen => _state?._overlayController.isShowing ?? false;
}

class _AnchoredPopoverState extends State<AnchoredPopover> {
  final _overlayController = OverlayPortalController();
  final _targetKey = GlobalKey();
  final _scopeNode = FocusScopeNode(debugLabel: 'AnchoredPopoverScope');
  FocusNode? _returnFocus;

  @override
  void initState() {
    super.initState();
    widget.controller?._state = this;
  }

  @override
  void didUpdateWidget(covariant AnchoredPopover oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      if (oldWidget.controller?._state == this) {
        oldWidget.controller?._state = null;
      }
      widget.controller?._state = this;
    }
  }

  @override
  void dispose() {
    if (widget.controller?._state == this) widget.controller?._state = null;
    _scopeNode.dispose();
    super.dispose();
  }

  void _show() {
    if (_overlayController.isShowing) return;
    _returnFocus = FocusManager.instance.primaryFocus;
    _overlayController.show();
    widget.onOpenChanged?.call(true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      // Ne prend le focus que si rien à l'intérieur ne l'a déjà réclamé
      // lui-même (ex. l'auto-focus de PopoverOptionList) — sinon on le
      // lui disputerait au lieu de le lui laisser (bug constaté : les
      // flèches n'atteignaient plus la liste). Nécessaire quand même
      // pour le cas où le déclencheur gardait le focus au clavier avant
      // l'ouverture (autofocus ne vole jamais un focus déjà posé
      // ailleurs) et pour un contenu sans rien de focalisable lui-même.
      if (!_scopeNode.hasFocus) _scopeNode.requestFocus();
    });
  }

  void _hide() {
    if (!_overlayController.isShowing) return;
    _overlayController.hide();
    widget.onOpenChanged?.call(false);
    final returnFocus = _returnFocus;
    _returnFocus = null;
    if (returnFocus != null && returnFocus.canRequestFocus) {
      returnFocus.requestFocus();
    }
  }

  @override
  Widget build(BuildContext context) {
    return OverlayPortal(
      controller: _overlayController,
      overlayChildBuilder: (context) => _PopoverOverlay(
        targetKey: _targetKey,
        preferredDirection: widget.preferredDirection,
        scopeNode: _scopeNode,
        onDismiss: _hide,
        builder: (context) => widget.popoverBuilder(context, _hide),
      ),
      child: KeyedSubtree(key: _targetKey, child: widget.child),
    );
  }
}

class _PopoverOverlay extends StatelessWidget {
  final GlobalKey targetKey;
  final AxisDirection preferredDirection;
  final FocusScopeNode scopeNode;
  final VoidCallback onDismiss;
  final WidgetBuilder builder;

  const _PopoverOverlay({
    required this.targetKey,
    required this.preferredDirection,
    required this.scopeNode,
    required this.onDismiss,
    required this.builder,
  });

  @override
  Widget build(BuildContext context) {
    final targetBox =
        targetKey.currentContext?.findRenderObject() as RenderBox?;
    if (targetBox == null || !targetBox.attached) {
      return const SizedBox.shrink();
    }
    final targetPosition = targetBox.localToGlobal(Offset.zero);
    final targetSize = targetBox.size;

    return Stack(
      children: [
        // Clic extérieur : ferme, ne consomme pas le clic lui-même
        // (l'utilisateur peut agir directement sur ce qu'il visait).
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTap: onDismiss,
          ),
        ),
        CustomSingleChildLayout(
          delegate: _PopoverLayoutDelegate(
            targetGlobalPosition: targetPosition,
            targetSize: targetSize,
            preferredDirection: preferredDirection,
          ),
          // FocusScope, pas Focus : Échap doit être attrapé qu'importe
          // quel descendant détient le focus réel (ex. l'option en
          // surbrillance de PopoverOptionList) — un `Focus` simple ici
          // ne verrait l'évènement que s'il détenait lui-même le focus,
          // ce qui entrerait en conflit avec l'auto-focus du contenu.
          // `node: scopeNode` (stable, pas recréé à chaque frame) plutôt
          // que `autofocus: true` ici : `_show()` ne lui demande le focus
          // que si rien à l'intérieur ne l'a déjà réclamé lui-même (ex.
          // l'auto-focus de PopoverOptionList) — les deux coopèrent au
          // lieu de se le disputer.
          child: FocusScope(
            node: scopeNode,
            onKeyEvent: (node, event) {
              if (event is! KeyDownEvent) return KeyEventResult.ignored;
              if (event.logicalKey == LogicalKeyboardKey.escape) {
                onDismiss();
                return KeyEventResult.handled;
              }
              return KeyEventResult.ignored;
            },
            child: Material(
              color: Colors.transparent,
              child: ConstrainedBox(
                // Largeur dictée par le contenu (bornée pour rester
                // lisible et tenir sur un petit écran) — jamais pleine
                // hauteur : un choix simple, pas un panneau.
                constraints: BoxConstraints(
                  minWidth: 200,
                  maxWidth: 320,
                  maxHeight: MediaQuery.sizeOf(context).height * 0.5,
                ),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: AppColors.surfaceHigh,
                    borderRadius: AppRadii.sheetBorder,
                    border: Border.all(color: AppColors.border),
                  ),
                  child: builder(context),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _PopoverLayoutDelegate extends SingleChildLayoutDelegate {
  final Offset targetGlobalPosition;
  final Size targetSize;
  final AxisDirection preferredDirection;

  static const margin = AppSpacing.xs;
  static const gap = AppSpacing.xxs;

  const _PopoverLayoutDelegate({
    required this.targetGlobalPosition,
    required this.targetSize,
    required this.preferredDirection,
  });

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) =>
      constraints.loosen();

  @override
  Offset getPositionForChild(Size size, Size childSize) {
    // Aligné sur le bord gauche du déclencheur, borné pour ne jamais
    // déborder à droite ni à gauche.
    var dx = targetGlobalPosition.dx;
    final maxDx = size.width - childSize.width - margin;
    dx = dx.clamp(margin, maxDx < margin ? margin : maxDx);

    final above = targetGlobalPosition.dy - childSize.height - gap;
    final below = targetGlobalPosition.dy + targetSize.height + gap;
    final fitsAbove = above >= margin;
    final fitsBelow = below + childSize.height <= size.height - margin;

    // Se replace tout seul s'il sortirait de l'écran du côté préféré.
    var dy = switch (preferredDirection) {
      AxisDirection.up => fitsAbove ? above : (fitsBelow ? below : margin),
      _ => fitsBelow ? below : (fitsAbove ? above : margin),
    };
    final maxDy = size.height - childSize.height - margin;
    dy = dy.clamp(margin, maxDy < margin ? margin : maxDy);

    return Offset(dx, dy);
  }

  @override
  bool shouldRelayout(covariant _PopoverLayoutDelegate oldDelegate) =>
      oldDelegate.targetGlobalPosition != targetGlobalPosition ||
      oldDelegate.targetSize != targetSize ||
      oldDelegate.preferredDirection != preferredDirection;
}

/// Une option d'un [PopoverOptionList].
class PopoverOption {
  final Widget content;
  final bool selected;
  final VoidCallback? onSelect;
  const PopoverOption(
      {required this.content, this.selected = false, this.onSelect});
}

/// Liste de choix pour l'intérieur d'un [AnchoredPopover] — flèches
/// haut/bas pour parcourir, Entrée pour choisir (ferme le popover
/// ensuite via [onSelected]), focus visible sur l'option courante.
class PopoverOptionList extends StatefulWidget {
  final List<PopoverOption> options;

  /// Appelé après qu'une option a été activée (clic ou Entrée) — a
  /// généralement pour effet de fermer le popover englobant.
  final VoidCallback? onSelected;

  const PopoverOptionList({required this.options, this.onSelected, super.key});

  @override
  State<PopoverOptionList> createState() => _PopoverOptionListState();
}

class _PopoverOptionListState extends State<PopoverOptionList> {
  int _index = 0;

  @override
  void didUpdateWidget(covariant PopoverOptionList oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_index >= widget.options.length) {
      _index = widget.options.isEmpty ? 0 : widget.options.length - 1;
    }
  }

  void _activate(int index) {
    widget.options[index].onSelect?.call();
    widget.onSelected?.call();
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final options = widget.options;
    switch (event.logicalKey) {
      case LogicalKeyboardKey.arrowDown:
        if (options.isNotEmpty) {
          setState(() => _index = (_index + 1).clamp(0, options.length - 1));
        }
        return KeyEventResult.handled;
      case LogicalKeyboardKey.arrowUp:
        if (options.isNotEmpty) {
          setState(() => _index = (_index - 1).clamp(0, options.length - 1));
        }
        return KeyEventResult.handled;
      case LogicalKeyboardKey.enter:
      case LogicalKeyboardKey.numpadEnter:
        if (options.isNotEmpty) _activate(_index.clamp(0, options.length - 1));
        return KeyEventResult.handled;
      default:
        return KeyEventResult.ignored;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.options.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(AppSpacing.md),
        child: Text('Rien à choisir ici.',
            style: TextStyle(color: AppColors.textSecondary)),
      );
    }
    return Focus(
      autofocus: true,
      onKeyEvent: _onKey,
      child: ListView.builder(
        shrinkWrap: true,
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
        itemCount: widget.options.length,
        itemBuilder: (context, index) {
          final option = widget.options[index];
          return ColoredBox(
            color:
                index == _index ? AppColors.surfaceHover : Colors.transparent,
            child: InkWell(
              onTap: () => _activate(index),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
                child: Row(
                  children: [
                    Expanded(child: option.content),
                    if (option.selected) ...[
                      const SizedBox(width: AppSpacing.xs),
                      const Icon(Icons.check_rounded,
                          size: 18, color: AppColors.textPrimary),
                    ],
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
