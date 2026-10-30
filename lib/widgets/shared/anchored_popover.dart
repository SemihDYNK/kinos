import 'package:kinos/widgets/shared/animated_media_icon.dart';
import 'package:kinos/widgets/shared/frosted_surface.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:kinos/theme/app_theme.dart';

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
  void toggle() => (_state?._open ?? false) ? hide() : show();
  bool get isOpen => _state?._open ?? false;
}

class _AnchoredPopoverState extends State<AnchoredPopover>
    with SingleTickerProviderStateMixin {
  final _overlayController = OverlayPortalController();
  final _targetKey = GlobalKey();
  final _panelKey = GlobalKey();
  bool _open = false;
  AnimationController? _revealController;
  AnimationController get _reveal => _revealController ??= AnimationController(
      vsync: this,
      duration: AppDurations.popover,
      reverseDuration: AppDurations.hover)
    ..addStatusListener((status) {
      if (status == AnimationStatus.dismissed) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && !_open && _reveal.isDismissed) {
            _overlayController.hide();
          }
        });
      }
    });
  final _scopeNode = FocusScopeNode(debugLabel: 'AnchoredPopoverScope');
  FocusNode? _returnFocus;

  @override
  void initState() {
    super.initState();
    widget.controller?._state = this;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!AppMotion.enabled(context) && _reveal.isAnimating) {
      _reveal.value = _open ? 1 : 0;
    }
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
    _revealController?.dispose();
    _scopeNode.dispose();
    super.dispose();
  }

  void _show() {
    if (_open) return;
    _returnFocus = FocusManager.instance.primaryFocus;
    setState(() => _open = true);
    _overlayController.show();
    if (AppMotion.enabled(context)) {
      _reveal.animateTo(1, curve: AppMotion.easeOut);
    } else {
      _reveal.value = 1;
    }
    widget.onOpenChanged?.call(true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_open) return;
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
    if (!_open) return;
    setState(() => _open = false);
    if (AppMotion.enabled(context) && _reveal.value > 0) {
      _reveal.animateBack(0, curve: AppMotion.easeOut);
    } else {
      _reveal.value = 0;
      _overlayController.hide();
    }
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
      overlayChildBuilder: (context) => IgnorePointer(
          ignoring: !_open,
          child: ExcludeFocus(
              excluding: !_open,
              child: _PopoverOverlay(
                targetKey: _targetKey,
                panelKey: _panelKey,
                reveal: _reveal,
                preferredDirection: widget.preferredDirection,
                scopeNode: _scopeNode,
                onDismiss: _hide,
                builder: (context) => widget.popoverBuilder(context, _hide),
              ))),
      child: KeyedSubtree(key: _targetKey, child: widget.child),
    );
  }
}

class _PopoverOverlay extends StatelessWidget {
  final GlobalKey targetKey;
  final GlobalKey panelKey;
  final Animation<double> reveal;
  final AxisDirection preferredDirection;
  final FocusScopeNode scopeNode;
  final VoidCallback onDismiss;
  final WidgetBuilder builder;

  const _PopoverOverlay({
    required this.targetKey,
    required this.panelKey,
    required this.reveal,
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
                key: panelKey,
                // Largeur dictée par le contenu (bornée pour rester
                // lisible et tenir sur un petit écran) — jamais pleine
                // hauteur : un choix simple, pas un panneau.
                constraints: BoxConstraints(
                  minWidth: AppDetailLayout.popoverMinWidth,
                  maxWidth: AppDetailLayout.popoverMaxWidth,
                  maxHeight: MediaQuery.sizeOf(context).height * 0.5,
                ),
                child: FadeTransition(
                  opacity: reveal,
                  child: AnimatedBuilder(
                    animation: reveal,
                    child: FrostedSurface(child: builder(context)),
                    builder: (context, child) {
                      final panel = panelKey.currentContext?.findRenderObject()
                          as RenderBox?;
                      var pivot = Offset.zero;
                      if (panel != null && panel.hasSize) {
                        final origin = panel.globalToLocal(
                            targetPosition + targetSize.center(Offset.zero));
                        pivot = Offset(origin.dx.clamp(0, panel.size.width),
                            origin.dy.clamp(0, panel.size.height));
                      }
                      return Transform.translate(
                          offset: Offset(0, AppSpacing.xs * (1 - reveal.value)),
                          child: Transform.scale(
                            alignment: Alignment.topLeft,
                            origin: pivot,
                            scale: AppMotion.menuScale +
                                (1 - AppMotion.menuScale) * reveal.value,
                            child: child,
                          ));
                    },
                  ),
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
  void initState() {
    super.initState();
    final selected = widget.options.indexWhere((option) => option.selected);
    if (selected >= 0) _index = selected;
  }

  @override
  void didUpdateWidget(covariant PopoverOptionList oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_index >= widget.options.length) {
      _index = widget.options.isEmpty ? 0 : widget.options.length - 1;
    }
  }

  void _activate(int index) {
    setState(() => _index = index);
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
        padding: const EdgeInsets.all(AppSpacing.xs),
        itemCount: widget.options.length,
        itemBuilder: (context, index) {
          final option = widget.options[index];
          return AnimatedContainer(
            duration:
                AppMotion.enabled(context) ? AppDurations.hover : Duration.zero,
            curve: AppMotion.easeOut,
            decoration: BoxDecoration(
              borderRadius: AppRadii.controlBorder,
              color: index == _index
                  ? AppDetailLayout.popoverHighlight
                  : Colors.transparent,
              border: Border.all(
                  color: index == _index
                      ? AppColors.borderStrong
                      : Colors.transparent),
            ),
            child: InkWell(
              borderRadius: AppRadii.controlBorder,
              onTap: () => _activate(index),
              onHover: (hovering) {
                if (hovering && _index != index) setState(() => _index = index);
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm, vertical: AppSpacing.sm),
                child: Row(
                  children: [
                    Expanded(child: option.content),
                    const SizedBox(width: AppSpacing.xs),
                    AnimatedWatchedIcon(
                      selected: option.selected,
                      circled: false,
                      size: AppDetailLayout.popoverCheckSize,
                      color: AppColors.textPrimary,
                    ),
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
