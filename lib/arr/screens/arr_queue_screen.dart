import 'package:flutter/material.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:fladder/arr/models/arr_service.dart';
import 'package:fladder/arr/providers/arr_queue_providers.dart';
import 'package:fladder/arr/screens/widgets/arr_queue_table.dart';
import 'package:fladder/arr/services/arr_api_client.dart';
import 'package:fladder/screens/shared/fladder_notification_overlay.dart';
import 'package:fladder/theme/app_theme.dart';

/// Onglet "File d'attente" — relie [arrQueueProvider] (polling 5s,
/// `.family.autoDispose` par service) à [ArrQueueTable]. Cet écran est le
/// seul point de contact avec le provider : aucun appel réseau direct
/// depuis la table elle-même (cf. CLAUDE.md).
class ArrQueueScreen extends ConsumerWidget {
  final ArrService service;

  const ArrQueueScreen({required this.service, super.key});

  Future<void> _runAction(
    BuildContext context,
    Future<ArrResult<void>> Function() action, {
    String? failureContext,
  }) async {
    final result = await action();
    if (!context.mounted) return;
    if (result case ArrFailure(:final detail)) {
      final parts = [failureContext, detail].nonNulls.toList();
      FladderSnack.show(
        parts.isEmpty ? 'Échec de l\'action.' : parts.join(' — '),
        context: context,
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(arrQueueProvider(service));
    final notifier = ref.read(arrQueueProvider(service).notifier);

    if (state.loading && state.items.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: AppSpacing.xl),
        child: Row(
          children: [
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            SizedBox(width: AppSpacing.sm),
            Text('Chargement de la file…',
                style: TextStyle(color: AppColors.textSecondary)),
          ],
        ),
      );
    }

    if (state.error != null && state.items.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl),
        child: Row(
          children: [
            const Icon(Icons.error_outline_rounded,
                size: 18, color: AppColors.error),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                _errorMessage(state.error!, state.errorDetail),
                style: const TextStyle(color: AppColors.error),
              ),
            ),
          ],
        ),
      );
    }

    return ArrQueueTable(
      items: state.items,
      instanceLabel: service.label,
      onPause: (item) => _runAction(
        context,
        () => notifier.pause(item.id),
        failureContext: 'Pause',
      ),
      onResume: (item) => _runAction(
        context,
        () => notifier.resume(item.id),
        failureContext: 'Reprise',
      ),
      onForceImport: (item) => _runAction(
        context,
        () => notifier.forceImport(item.id),
        failureContext: 'Import forcé',
      ),
      onRemove: (items, {required removeFromClient, required blocklist}) =>
          _runAction(
        context,
        () => items.length == 1
            ? notifier.remove(
                items.first.id,
                removeFromClient: removeFromClient,
                blocklist: blocklist,
              )
            : notifier.removeMultiple(
                items.map((e) => e.id).toList(),
                removeFromClient: removeFromClient,
                blocklist: blocklist,
              ),
        failureContext: 'Retrait',
      ),
    );
  }

  String _errorMessage(ArrApiError error, String? detail) {
    final base = switch (error) {
      ArrApiError.unreachable => 'Serveur injoignable.',
      ArrApiError.unauthorized => 'Clé API invalide.',
      ArrApiError.notFound => 'Route introuvable.',
      ArrApiError.serverError => 'Erreur serveur.',
      ArrApiError.invalidResponse => 'Réponse inattendue.',
    };
    return detail == null ? base : '$base $detail';
  }
}
