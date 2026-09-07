import 'dart:async';

import 'package:flutter/material.dart';

import 'package:fladder/theme/app_theme.dart';

/// Infobulle des motifs de rejet — ne s'appuie PAS sur [Tooltip] : sa
/// cible (l'icône, colonne la plus à gauche du tableau) est trop proche du
/// bord de l'écran, et le positionnement par défaut de [Tooltip] s'y fait
/// tronquer plutôt que se décaler. Ici, la position est recalculée à
/// chaque affichage à partir de la taille réelle de l'écran ([MediaQuery])
/// et de la taille mesurée de la bulle elle-même, puis bornée pour
/// qu'elle ne déborde jamais — décalée à droite/en dessous si nécessaire
/// plutôt que coupée.
class ArrRejectionTooltip extends StatefulWidget {
  final Widget child;
  final List<String> reasons;

  const ArrRejectionTooltip(
      {required this.child, required this.reasons, super.key});

  @override
  State<ArrRejectionTooltip> createState() => _ArrRejectionTooltipState();
}

class _ArrRejectionTooltipState extends State<ArrRejectionTooltip> {
  final _controller = OverlayPortalController();
  Timer? _timer;

  void _show() {
    _timer?.cancel();
    _timer = Timer(const Duration(milliseconds: 300), () {
      if (mounted) _controller.show();
    });
  }

  void _hide() {
    _timer?.cancel();
    if (_controller.isShowing) _controller.hide();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  final _targetKey = GlobalKey();

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => _show(),
      onExit: (_) => _hide(),
      child: OverlayPortal(
        controller: _controller,
        overlayChildBuilder: (context) => _RejectionTooltipOverlay(
          reasons: widget.reasons,
          targetKey: _targetKey,
        ),
        child: KeyedSubtree(key: _targetKey, child: widget.child),
      ),
    );
  }
}

class _RejectionTooltipOverlay extends StatelessWidget {
  final List<String> reasons;
  final GlobalKey targetKey;

  const _RejectionTooltipOverlay(
      {required this.reasons, required this.targetKey});

  @override
  Widget build(BuildContext context) {
    final targetBox =
        targetKey.currentContext?.findRenderObject() as RenderBox?;
    if (targetBox == null || !targetBox.attached) {
      return const SizedBox.shrink();
    }
    final targetPosition = targetBox.localToGlobal(Offset.zero);
    final targetSize = targetBox.size;

    return Positioned.fill(
      child: IgnorePointer(
        child: CustomSingleChildLayout(
          delegate: _RejectionTooltipLayoutDelegate(
            targetGlobalPosition: targetPosition,
            targetSize: targetSize,
          ),
          child: _RejectionTooltipBubble(reasons: reasons),
        ),
      ),
    );
  }
}

class _RejectionTooltipLayoutDelegate extends SingleChildLayoutDelegate {
  final Offset targetGlobalPosition;
  final Size targetSize;

  static const margin = AppSpacing.xs;
  static const verticalOffset = AppSpacing.xs;

  const _RejectionTooltipLayoutDelegate({
    required this.targetGlobalPosition,
    required this.targetSize,
  });

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) =>
      constraints.loosen();

  @override
  Offset getPositionForChild(Size size, Size childSize) {
    // `size` est la taille de l'overlay (l'écran) ; `childSize` celle,
    // déjà mesurée, de la bulle — jamais besoin d'un double passage de
    // layout pour connaître sa taille avant de la positionner.
    var dx = targetGlobalPosition.dx + (targetSize.width - childSize.width) / 2;
    final maxDx = size.width - childSize.width - margin;
    dx = dx.clamp(margin, maxDx < margin ? margin : maxDx);

    // Sous la cible par défaut ; bascule au-dessus si ça ne tient pas.
    var dy = targetGlobalPosition.dy + targetSize.height + verticalOffset;
    if (dy + childSize.height > size.height - margin) {
      final above = targetGlobalPosition.dy - childSize.height - verticalOffset;
      if (above >= margin) dy = above;
    }
    final maxDy = size.height - childSize.height - margin;
    dy = dy.clamp(margin, maxDy < margin ? margin : maxDy);

    return Offset(dx, dy);
  }

  @override
  bool shouldRelayout(covariant _RejectionTooltipLayoutDelegate oldDelegate) =>
      oldDelegate.targetGlobalPosition != targetGlobalPosition ||
      oldDelegate.targetSize != targetSize;
}

class _RejectionTooltipBubble extends StatelessWidget {
  final List<String> reasons;

  const _RejectionTooltipBubble({required this.reasons});

  @override
  Widget build(BuildContext context) {
    final textStyle = Theme.of(context)
        .textTheme
        .bodySmall
        ?.copyWith(color: AppColors.textPrimary);

    return Material(
      color: Colors.transparent,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 300),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: AppColors.surfaceHigh,
            borderRadius: AppRadii.controlBorder,
            border: Border.all(color: AppColors.border),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
            child: reasons.isEmpty
                ? Text('Rejetée', style: textStyle)
                : Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (final reason in reasons)
                        Padding(
                          padding: const EdgeInsets.symmetric(
                              vertical: AppSpacing.xxs),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('•', style: textStyle),
                              const SizedBox(width: AppSpacing.xxs),
                              Expanded(child: Text(reason, style: textStyle)),
                            ],
                          ),
                        ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}
