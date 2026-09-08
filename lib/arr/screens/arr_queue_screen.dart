import 'package:flutter/material.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:kinos/arr/models/arr_service.dart';
import 'package:kinos/arr/providers/arr_queue_providers.dart';
import 'package:kinos/arr/providers/qbittorrent_providers.dart';
import 'package:kinos/arr/screens/widgets/arr_queue_table.dart';
import 'package:kinos/arr/services/arr_api_client.dart';
import 'package:kinos/screens/shared/kinos_notification_overlay.dart';
import 'package:kinos/theme/app_theme.dart';

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
      KinosSnack.show(
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

    final downloadClientReady = ref.watch(qbittorrentClientProvider) != null;

    return ArrQueueTable(
      items: state.items,
      instanceLabel: service.label,
      downloadClientReady: downloadClientReady,
      onPause: (group) {
        final downloadId = group.downloadId;
        if (downloadId == null || downloadId.isEmpty) return;
        _runAction(
          context,
          () => notifier.pause(downloadId),
          failureContext: 'Pause',
        );
      },
      onResume: (group) {
        final downloadId = group.downloadId;
        if (downloadId == null || downloadId.isEmpty) return;
        _runAction(
          context,
          () => notifier.resume(downloadId),
          failureContext: 'Reprise',
        );
      },
      // Un appel par épisode : la file entière du groupe est visée,
      // l'API *Arr n'a pas d'équivalent "forcer l'import" groupé.
      onForceImport: (group) => _runAction(
        context,
        () => notifier.forceImportGroup(group.items.map((e) => e.id).toList()),
        failureContext: 'Import forcé',
      ),
      onRemove: (groups, {required removeFromClient, required blocklist}) {
        final ids = groups.expand((g) => g.items.map((e) => e.id)).toList();
        _runAction(
          context,
          () => ids.length == 1
              ? notifier.remove(
                  ids.first,
                  removeFromClient: removeFromClient,
                  blocklist: blocklist,
                )
              : notifier.removeMultiple(
                  ids,
                  removeFromClient: removeFromClient,
                  blocklist: blocklist,
                ),
          failureContext: 'Retrait',
        );
      },
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
