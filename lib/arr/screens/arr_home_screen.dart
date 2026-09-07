import 'package:flutter/material.dart';

import 'package:auto_route/auto_route.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:fladder/arr/models/arr_service.dart';
import 'package:fladder/arr/providers/arr_providers.dart';
import 'package:fladder/arr/widgets/arr_desktop_scope.dart';
import 'package:fladder/routes/auto_router.gr.dart';
import 'package:fladder/theme/app_theme.dart';
import 'package:fladder/util/adaptive_layout/adaptive_layout.dart';

/// Accueil du module *Arr — toujours atteignable depuis "Gestion", même
/// sans aucun service configuré (sans quoi la configuration elle-même
/// serait inatteignable). Pour l'instant un simple état des lieux des
/// deux services, avec un lien direct vers leur configuration (Partie 1 :
/// fondations) — la recherche interactive (Partie 2) prendra la place de
/// cet écran une fois au moins un service configuré.
@RoutePage()
class ArrHomeScreen extends ConsumerWidget {
  const ArrHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sideBarInset = AdaptiveLayout.of(context).sideBarWidth;
    final radarrConfigured = ref
            .watch(arrCredentialsProvider(ArrService.radarr))
            .valueOrNull
            ?.isConfigured ??
        false;
    final sonarrConfigured = ref
            .watch(arrCredentialsProvider(ArrService.sonarr))
            .valueOrNull
            ?.isConfigured ??
        false;
    final noneConfigured = !radarrConfigured && !sonarrConfigured;

    return ArrDesktopScope(
      child: ColoredBox(
        color: AppColors.background,
        child: Padding(
          padding: EdgeInsetsDirectional.only(start: sideBarInset),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Gestion',
                    style: Theme.of(context).textTheme.displaySmall),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  noneConfigured
                      ? 'Configurez Radarr et/ou Sonarr pour activer la recherche interactive.'
                      : 'Recherche interactive Radarr et Sonarr — bientôt disponible ici.',
                  style: Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.copyWith(color: AppColors.textSecondary),
                ),
                const SizedBox(height: AppSpacing.xl),
                const _ArrServiceStatusRow(service: ArrService.radarr),
                const SizedBox(height: AppSpacing.sm),
                const _ArrServiceStatusRow(service: ArrService.sonarr),
                const SizedBox(height: AppSpacing.lg),
                FocusRing(
                  borderRadius: AppRadii.controlBorder,
                  onActivate: () =>
                      context.router.push(const ArrSettingsRoute()),
                  child: ExcludeFocus(
                    child: noneConfigured
                        ? FilledButton(
                            onPressed: () =>
                                context.router.push(const ArrSettingsRoute()),
                            child: const Text('Configurer Radarr / Sonarr'),
                          )
                        : OutlinedButton(
                            onPressed: () =>
                                context.router.push(const ArrSettingsRoute()),
                            child: const Text('Réglages Radarr / Sonarr'),
                          ),
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

class _ArrServiceStatusRow extends ConsumerWidget {
  final ArrService service;

  const _ArrServiceStatusRow({required this.service});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final credentials = ref.watch(arrCredentialsProvider(service)).valueOrNull;
    final configured = credentials?.isConfigured ?? false;

    return Row(
      children: [
        Icon(
          configured ? Icons.check_circle_rounded : Icons.circle_outlined,
          size: 18,
          color: configured ? AppColors.success : AppColors.textDisabled,
        ),
        const SizedBox(width: AppSpacing.xs),
        Text(service.label, style: Theme.of(context).textTheme.bodyMedium),
        const SizedBox(width: AppSpacing.xs),
        Text(
          configured ? 'configuré' : 'non configuré',
          style: Theme.of(context)
              .textTheme
              .bodySmall
              ?.copyWith(color: AppColors.textSecondary),
        ),
      ],
    );
  }
}
