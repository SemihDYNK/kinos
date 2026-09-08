import 'package:flutter/material.dart';

import 'package:fladder/arr/models/arr_service.dart';
import 'package:fladder/theme/app_theme.dart';

/// Onglet "Calendrier" — structure d'accueil seulement pour l'instant, le
/// contenu (sorties à venir/manquantes par jour) suit dans un prochain
/// travail. Les jetons de statut ([AppColors.calendarAnnounced],
/// [AppColors.calendarDownloaded], [AppColors.calendarMissing]) sont déjà
/// posés dans `app_theme.dart`, prêts à être utilisés à ce moment-là.
class ArrCalendarScreen extends StatelessWidget {
  final ArrService service;

  const ArrCalendarScreen({required this.service, super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxl),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.calendar_month_outlined,
                size: 32, color: AppColors.textDisabled),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Calendrier ${service.label}',
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: AppColors.textSecondary),
            ),
            const SizedBox(height: AppSpacing.xxs),
            const Text(
              'Bientôt : sorties à venir et manquantes, jour par jour.',
              style: TextStyle(color: AppColors.textDisabled),
            ),
          ],
        ),
      ),
    );
  }
}
