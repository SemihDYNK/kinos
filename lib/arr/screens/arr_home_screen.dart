import 'package:kinos/widgets/shared/frosted_surface.dart';
import 'package:flutter/material.dart';

import 'package:auto_route/auto_route.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:kinos/arr/models/arr_service.dart';
import 'package:kinos/arr/providers/arr_providers.dart';
import 'package:kinos/arr/screens/arr_calendar_screen.dart';
import 'package:kinos/arr/screens/arr_library_screen.dart';
import 'package:kinos/arr/screens/arr_queue_screen.dart';
import 'package:kinos/arr/widgets/arr_desktop_scope.dart';
import 'package:kinos/routes/auto_router.gr.dart';
import 'package:kinos/screens/shared/chips/filter_button.dart';
import 'package:kinos/theme/app_theme.dart';
import 'package:kinos/widgets/shared/app_page_header.dart';
import 'package:kinos/util/adaptive_layout/adaptive_layout.dart';

enum _ArrTab { library, queue, calendar }

/// Accueil du module *Arr — toujours atteignable depuis "Arr" dans la
/// barre latérale, même sans aucun service configuré (sans quoi la
/// configuration elle-même serait inatteignable) : invite alors à la
/// configurer. Dès qu'au moins un service l'est, affiche le sélecteur
/// d'instance puis, en dessous, les onglets Bibliothèque/File
/// d'attente/Calendrier — recherche interactive et réglages restent
/// atteignables via les raccourcis en haut à droite.
@RoutePage()
class ArrHomeScreen extends ConsumerStatefulWidget {
  const ArrHomeScreen({super.key});

  @override
  ConsumerState<ArrHomeScreen> createState() => _ArrHomeScreenState();
}

class _ArrHomeScreenState extends ConsumerState<ArrHomeScreen> {
  ArrService? _selected;
  _ArrTab _tab = _ArrTab.library;

  @override
  Widget build(BuildContext context) {
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
    final available = [
      if (radarrConfigured) ArrService.radarr,
      if (sonarrConfigured) ArrService.sonarr,
    ];

    // Repli sur le premier service configuré si rien n'est sélectionné,
    // ou si la sélection courante a été désactivée entre-temps (réglages
    // modifiés pendant que cet écran était déjà ouvert).
    if (_selected == null || !available.contains(_selected)) {
      _selected = available.isEmpty ? null : available.first;
    }

    return ArrDesktopScope(
      child: ColoredBox(
        color: AppColors.background,
        child: Padding(
          padding: EdgeInsets.zero,
          child: available.isEmpty
              ? const _ArrInvite()
              : _ArrHomeContent(
                  selectedService: _selected!,
                  availableServices: available,
                  onSelectService: (service) =>
                      setState(() => _selected = service),
                  tab: _tab,
                  onSelectTab: (tab) => setState(() => _tab = tab),
                ),
        ),
      ),
    );
  }
}

class _ArrHomeContent extends StatelessWidget {
  final ArrService selectedService;
  final List<ArrService> availableServices;
  final ValueChanged<ArrService> onSelectService;
  final _ArrTab tab;
  final ValueChanged<_ArrTab> onSelectTab;

  const _ArrHomeContent({
    required this.selectedService,
    required this.availableServices,
    required this.onSelectService,
    required this.tab,
    required this.onSelectTab,
  });

  @override
  Widget build(BuildContext context) {
    final padding = EdgeInsets.fromLTRB(
        AdaptiveLayout.of(context).sideBarWidth + AppSpacing.screenPadding,
        AdaptiveLayout.of(context).topBarHeight + AppSpacing.lg,
        AppSpacing.screenPadding,
        AppSpacing.lg);
    final header = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text('Arr', style: AppTypography.sectionTitle),
            const SizedBox(width: AppSpacing.lg),
            if (availableServices.length > 1)
              FrostedSurface(
                  borderRadius: AppRadii.controlBorder,
                  child: Padding(
                      padding: const EdgeInsets.all(AppSpacing.xxs),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        for (final service in availableServices)
                          FilterButton(
                              isSelected: service == selectedService,
                              label: Text(service.label),
                              onPressed: () => onSelectService(service))
                      ]))),
            const Spacer(),
            FocusRing(
              borderRadius: AppRadii.controlBorder,
              onActivate: () => context.router.push(const ArrSearchRoute()),
              child: ExcludeFocus(
                child: Tooltip(
                  message: 'Recherche interactive',
                  child: IconButton(
                    onPressed: () =>
                        context.router.push(const ArrSearchRoute()),
                    icon: const Icon(Icons.search_rounded),
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ),
            FocusRing(
              borderRadius: AppRadii.controlBorder,
              onActivate: () => context.router.push(const ArrSettingsRoute()),
              child: ExcludeFocus(
                child: Tooltip(
                  message: 'Réglages Radarr / Sonarr',
                  child: IconButton(
                    onPressed: () =>
                        context.router.push(const ArrSettingsRoute()),
                    icon: const Icon(Icons.settings_outlined),
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        _ArrTabStrip(tab: tab, onSelectTab: onSelectTab),
        const SizedBox(height: AppSpacing.md),
      ],
    );
    return switch (tab) {
      _ArrTab.library => ArrLibraryScreen(
          key: ValueKey(selectedService),
          service: selectedService,
          header: header,
          contentPadding: padding),
      _ArrTab.queue => SingleChildScrollView(
          padding: padding,
          child: Column(children: [
            header,
            ArrQueueScreen(
                key: ValueKey(selectedService), service: selectedService)
          ])),
      _ArrTab.calendar => SingleChildScrollView(
          padding: padding,
          child: Column(children: [
            header,
            ArrCalendarScreen(
                key: ValueKey(selectedService), service: selectedService)
          ])),
    };
  }
}

/// Barre d'onglets sobre — texte + soulignement fin sous l'onglet actif,
/// jamais l'indicateur/pastille glissant du TabBar Material par défaut
/// (langage M3, hors direction du projet). Aucun `TabBar`/`TabController`
/// nulle part ailleurs dans l'app : ni motif ni composant à reprendre, ce
/// module en introduit un, volontairement minimal.
class _ArrTabStrip extends StatelessWidget {
  final _ArrTab tab;
  final ValueChanged<_ArrTab> onSelectTab;

  const _ArrTabStrip({required this.tab, required this.onSelectTab});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: AppColors.border))),
      child: Wrap(
        spacing: AppSpacing.xxs,
        runSpacing: AppSpacing.xxs,
        children: [
          _ArrTabButton(
            label: 'Bibliothèque',
            selected: tab == _ArrTab.library,
            onTap: () => onSelectTab(_ArrTab.library),
          ),
          _ArrTabButton(
            label: 'File d\'attente',
            selected: tab == _ArrTab.queue,
            onTap: () => onSelectTab(_ArrTab.queue),
          ),
          _ArrTabButton(
            label: 'Calendrier',
            selected: tab == _ArrTab.calendar,
            onTap: () => onSelectTab(_ArrTab.calendar),
          ),
        ],
      ),
    );
  }
}

class _ArrTabButton extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _ArrTabButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppColors.textPrimary : AppColors.textSecondary;
    return FocusRing(
      borderRadius: AppRadii.controlBorder,
      onActivate: onTap,
      child: ExcludeFocus(
        child: InkWell(
          onTap: onTap,
          borderRadius: AppRadii.controlBorder,
          child: Container(
            padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.sm, vertical: AppSpacing.sm),
            decoration: BoxDecoration(
              border: Border(
                  bottom: BorderSide(
                      color:
                          selected ? AppColors.textPrimary : Colors.transparent,
                      width: AppTopNavigation.indicatorHeight)),
            ),
            child: Text(
              label,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: color, fontWeight: FontWeight.w600),
            ),
          ),
        ),
      ),
    );
  }
}

class _ArrInvite extends StatelessWidget {
  const _ArrInvite();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          const Expanded(child: AppPageHeader(title: 'Arr')),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Configurez Radarr et/ou Sonarr pour activer la file d\'attente, '
            'le calendrier et la recherche interactive.',
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
            onActivate: () => context.router.push(const ArrSettingsRoute()),
            child: ExcludeFocus(
              child: FilledButton(
                onPressed: () => context.router.push(const ArrSettingsRoute()),
                child: const Text('Configurer Radarr / Sonarr'),
              ),
            ),
          ),
        ],
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
