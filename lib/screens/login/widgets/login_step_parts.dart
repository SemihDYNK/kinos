import 'package:flutter/material.dart';

import 'package:iconsax_plus/iconsax_plus.dart';

import 'package:kinos/theme/app_theme.dart';
import 'package:kinos/util/localization_helper.dart';

/// En-tête commun aux deux étapes de connexion : compteur, titre éditorial
/// et phrase de contexte. Le titre reste le seul grand registre de l'écran.
class LoginStepHeader extends StatelessWidget {
  const LoginStepHeader({
    required this.step,
    required this.total,
    required this.title,
    required this.description,
    super.key,
  });

  final int step;
  final int total;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.localized.loginStepCounter(step, total),
          style: textTheme.labelMedium,
        ),
        const SizedBox(height: AppSpacing.xs),
        Semantics(
          header: true,
          child: Text(title, style: textTheme.displayMedium),
        ),
        const SizedBox(height: AppSpacing.sm),
        ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: AppLoginLayout.descriptionWidth,
          ),
          child: Text(
            description,
            style: textTheme.bodyMedium?.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ),
      ],
    );
  }
}

/// Intitulé de section : capitales espacées, ton secondaire.
class LoginSectionLabel extends StatelessWidget {
  const LoginSectionLabel(this.label, {super.key});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(label, style: Theme.of(context).textTheme.labelMedium);
  }
}

/// Erreur d'action, rendue dans le flux plutôt qu'en notification fugace :
/// l'utilisateur doit pouvoir la relire et corriger son adresse.
class LoginInlineError extends StatelessWidget {
  const LoginInlineError(this.message, {super.key});

  final String message;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Semantics(
      container: true,
      liveRegion: true,
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.sm),
        decoration: BoxDecoration(
          color: AppColors.error
              .withValues(alpha: AppLoginLayout.errorSurfaceOpacity),
          borderRadius: AppRadii.controlBorder,
          border: Border.all(
            color: AppColors.error,
            width: AppLoginLayout.statusBorder,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(
              IconsaxPlusLinear.warning_2,
              size: AppLoginLayout.statusIcon,
              color: AppColors.error,
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(message, style: textTheme.bodyMedium),
            ),
          ],
        ),
      ),
    );
  }
}

/// État explicite de la découverte : recherche, absence de serveur, refus
/// d'accès ou échec réseau. Le bloc porte son propre message et, si utile,
/// une action focalisable ; rien n'est relégué à une notification.
class LoginStatusBlock extends StatelessWidget {
  const LoginStatusBlock({
    required this.title,
    this.description,
    this.icon,
    this.action,
    this.showProgress = false,
    super.key,
  });

  final String title;
  final String? description;
  final IconData? icon;
  final Widget? action;
  final bool showProgress;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Semantics(
      container: true,
      liveRegion: true,
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: AppRadii.controlBorder,
          border: Border.all(
            color: AppColors.border,
            width: AppLoginLayout.statusBorder,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (showProgress)
              const SizedBox.square(
                dimension: AppLoginLayout.statusIcon,
                child: CircularProgressIndicator(
                  strokeWidth: AppLoginLayout.progressStroke,
                  strokeCap: StrokeCap.round,
                ),
              )
            else if (icon != null)
              Icon(
                icon,
                size: AppLoginLayout.statusIcon,
                color: AppColors.textSecondary,
              ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: textTheme.titleSmall),
                  if (description != null) ...[
                    const SizedBox(height: AppSpacing.xxs),
                    Text(
                      description!,
                      style: textTheme.bodyMedium?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                  if (action != null) ...[
                    const SizedBox(height: AppSpacing.sm),
                    action!,
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
