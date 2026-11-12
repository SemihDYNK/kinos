import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:kinos/theme/app_theme.dart';
import 'package:kinos/widgets/shared/frosted_surface.dart';

import 'letterboxd_friends_parser.dart';
import 'letterboxd_friends_providers.dart';
import 'letterboxd_friends_store.dart';

Future<void> showLetterboxdFriendsDialog(BuildContext context) =>
    showDialog<void>(
        context: context, builder: (_) => const LetterboxdFriendsDialog());

/// Relie un pseudo Letterboxd public au profil pour afficher les notes des
/// comptes suivis sur les fiches des films.
class LetterboxdFriendsDialog extends ConsumerStatefulWidget {
  const LetterboxdFriendsDialog({super.key});
  @override
  ConsumerState<LetterboxdFriendsDialog> createState() => _State();
}

class _State extends ConsumerState<LetterboxdFriendsDialog> {
  final _username = TextEditingController();
  bool _invalid = false;

  @override
  void dispose() {
    _username.dispose();
    super.dispose();
  }

  Future<void> _link() async {
    final valid = normalizeLetterboxdUsername(_username.text) != null;
    setState(() => _invalid = !valid);
    if (!valid) return;
    await ref.read(letterboxdFriendsSyncProvider.notifier).link(_username.text);
  }

  static String _ago(DateTime at) {
    final elapsed = DateTime.now().difference(at);
    if (elapsed.inMinutes < 1) return "à l'instant";
    if (elapsed.inHours < 1) return 'il y a ${elapsed.inMinutes} min';
    if (elapsed.inDays < 1) return 'il y a ${elapsed.inHours} h';
    return 'il y a ${elapsed.inDays} j';
  }

  String _status(
      LetterboxdFriendsAccount account, LetterboxdFriendsSyncState sync) {
    if (sync.running) {
      return sync.total == 0
          ? 'Lecture des comptes suivis…'
          : 'Synchronisation · ${sync.done} / ${sync.total} amis';
    }
    return switch (sync.error) {
      'profile' => 'Profil @${account.username} introuvable ou privé.',
      'network' => 'Letterboxd ne répond pas. Nouvel essai plus tard.',
      _ => account.syncedAt == null
          ? 'Jamais synchronisé.'
          : '${account.friendCount} amis · synchronisé ${_ago(account.syncedAt!)}',
    };
  }

  @override
  Widget build(BuildContext context) {
    final account = ref.watch(letterboxdFriendsAccountProvider).valueOrNull;
    final sync = ref.watch(letterboxdFriendsSyncProvider);
    final controller = ref.read(letterboxdFriendsSyncProvider.notifier);
    final text = Theme.of(context).textTheme;
    return GlassDialog(
      constraints: const BoxConstraints(maxWidth: AppPageLayout.compactWidth),
      child: FocusTraversalGroup(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Amis Letterboxd', style: text.headlineSmall),
              const SizedBox(height: AppSpacing.md),
              const Text(
                  'Kinos lit les profils publics des comptes que vous suivez '
                  'sur Letterboxd pour afficher leurs notes sur les fiches des '
                  'films. Seul votre pseudo est nécessaire, jamais votre mot '
                  'de passe. Les comptes privés restent invisibles.'),
              const SizedBox(height: AppSpacing.md),
              if (account == null) ...[
                TextField(
                  controller: _username,
                  autofocus: true,
                  onSubmitted: (_) => _link(),
                  decoration: InputDecoration(
                    labelText: 'Pseudo ou adresse du profil',
                    hintText: 'ex. davidehrlich',
                    errorText: _invalid ? 'Pseudo invalide' : null,
                  ),
                ),
              ] else ...[
                Text('Relié à @${account.username}', style: text.titleMedium),
                const SizedBox(height: AppSpacing.xxs),
                Text(_status(account, sync),
                    style: text.bodySmall
                        ?.copyWith(color: AppColors.textSecondary)),
                if (sync.running) ...[
                  const SizedBox(height: AppSpacing.sm),
                  LinearProgressIndicator(
                      value: sync.total == 0 ? null : sync.done / sync.total),
                ],
              ],
              const SizedBox(height: AppSpacing.lg),
              Wrap(
                alignment: WrapAlignment.end,
                spacing: AppSpacing.xs,
                runSpacing: AppSpacing.xs,
                children: [
                  if (account != null) ...[
                    TextButton(
                        onPressed: controller.unlink,
                        child: const Text('Délier')),
                    OutlinedButton(
                        onPressed: sync.running
                            ? null
                            : () => controller.sync(force: true),
                        child: const Text('Synchroniser maintenant')),
                  ] else
                    FilledButton(onPressed: _link, child: const Text('Relier')),
                  TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Fermer')),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
