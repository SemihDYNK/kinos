import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:kinos/routes/auto_router.gr.dart';
import 'package:kinos/theme/app_theme.dart';

/// Remplace l'écran gris de Flutter quand un écran plante pendant sa
/// construction : ce qui s'est passé, et de quoi repartir (accueil,
/// paramètres). Le détail part dans le journal des erreurs comme avant.
///
/// Peut s'afficher n'importe où dans l'arbre, même hors de l'app : il ne
/// suppose ni thème, ni routeur, ni raccourcis.
class KinosErrorView extends StatelessWidget {
  const KinosErrorView(this.details, {super.key});
  final FlutterErrorDetails details;

  void _go(BuildContext context, PageRouteInfo route) {
    try {
      AutoRouter.of(context).navigate(route);
    } catch (_) {
      // Hors du routeur : rien de mieux à proposer.
    }
  }

  @override
  Widget build(BuildContext context) {
    final summary = details.exceptionAsString().split('\n').first;
    final hasRouter = StackRouterScope.of(context) != null;
    return Directionality(
      textDirection: TextDirection.ltr,
      child: ColoredBox(
        color: AppColors.background,
        child: DefaultTextStyle(
          style: AppTypography.body.copyWith(color: AppColors.textPrimary),
          child: Center(
            child: ConstrainedBox(
              constraints:
                  const BoxConstraints(maxWidth: AppPageLayout.compactWidth),
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.xl),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Cette page n\'a pas pu s\'afficher.',
                          style: AppTypography.displaySmall
                              .copyWith(color: AppColors.textPrimary)),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                          'Le détail est dans le journal des erreurs '
                          '(Paramètres → À propos).',
                          style: AppTypography.body
                              .copyWith(color: AppColors.textSecondary)),
                      const SizedBox(height: AppSpacing.xs),
                      Text(summary,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.meta
                              .copyWith(color: AppColors.textSecondary)),
                      if (hasRouter) ...[
                        const SizedBox(height: AppSpacing.lg),
                        Wrap(spacing: AppSpacing.sm, children: [
                          _ErrorButton(
                              label: 'Accueil',
                              autofocus: true,
                              onActivate: () =>
                                  _go(context, const DashboardRoute())),
                          _ErrorButton(
                              label: 'Paramètres',
                              onActivate: () =>
                                  _go(context, const SettingsRoute())),
                        ]),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ErrorButton extends StatefulWidget {
  const _ErrorButton(
      {required this.label, required this.onActivate, this.autofocus = false});
  final String label;
  final VoidCallback onActivate;
  final bool autofocus;

  @override
  State<_ErrorButton> createState() => _ErrorButtonState();
}

class _ErrorButtonState extends State<_ErrorButton> {
  bool _focused = false;
  bool _hovered = false;

  @override
  Widget build(BuildContext context) => Focus(
        autofocus: widget.autofocus,
        onFocusChange: (value) => setState(() => _focused = value),
        onKeyEvent: (_, event) {
          if (event is KeyDownEvent &&
              (event.logicalKey == LogicalKeyboardKey.enter ||
                  event.logicalKey == LogicalKeyboardKey.space)) {
            widget.onActivate();
            return KeyEventResult.handled;
          }
          return KeyEventResult.ignored;
        },
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          onEnter: (_) => setState(() => _hovered = true),
          onExit: (_) => setState(() => _hovered = false),
          child: GestureDetector(
            onTap: widget.onActivate,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: _hovered ? AppColors.surfaceHover : AppColors.surface,
                border: Border.all(
                    color: _focused ? AppColors.focus : AppColors.borderStrong,
                    width: _focused ? 2 : 1),
                borderRadius: AppRadii.controlBorder,
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md, vertical: AppSpacing.xs),
                child: Text(widget.label),
              ),
            ),
          ),
        ),
      );
}
