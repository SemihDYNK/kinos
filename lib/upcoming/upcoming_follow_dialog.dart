import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:kinos/letterboxd/letterboxd_import_controller.dart'
    show letterboxdDiscoveryClient;
import 'package:kinos/models/items/images_models.dart';
import 'package:kinos/providers/user_provider.dart';
import 'package:kinos/theme/app_theme.dart';
import 'package:kinos/util/kinos_image.dart';
import 'package:kinos/widgets/shared/frosted_surface.dart';
import 'package:kinos/widgets/shared/item_actions.dart';

import 'upcoming_logic.dart';
import 'upcoming_models.dart';
import 'upcoming_providers.dart';
import 'upcoming_strings.dart';

/// L'action « Suivre… » d'une fiche, si la page Prochainement est active
/// et que le titre a un identifiant TMDB.
List<ItemAction> upcomingFollowActions(
    BuildContext context, WidgetRef ref, String type, String? tmdbId) {
  final id = int.tryParse(tmdbId ?? '');
  if (id == null || !ref.read(upcomingAvailableProvider)) return const [];
  return [
    ItemActionButton(
      icon: const Icon(Icons.notifications_none_rounded),
      label: const Text(UpcomingStrings.follow),
      action: () => showUpcomingFollowDialog(context, type: type, tmdbId: id),
    ),
  ];
}

Future<void> showUpcomingFollowDialog(BuildContext context,
        {required String type, required int tmdbId}) =>
    showDialog<void>(
        context: context,
        builder: (_) => UpcomingFollowDialog(type: type, tmdbId: tmdbId));

/// Les personnes, la saga, les studios et chaînes d'un titre, à suivre ou
/// ne plus suivre d'un geste.
class UpcomingFollowDialog extends ConsumerStatefulWidget {
  const UpcomingFollowDialog(
      {required this.type, required this.tmdbId, super.key});
  final String type;
  final int tmdbId;

  @override
  ConsumerState<UpcomingFollowDialog> createState() => _State();
}

class _State extends ConsumerState<UpcomingFollowDialog> {
  List<UpcomingFollow>? _candidates;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final client = letterboxdDiscoveryClient(
        ref.read(userProvider)?.seerrCredentials,
        interval: Duration.zero);
    if (client == null) {
      setState(() => _failed = true);
      return;
    }
    try {
      final details = await client.get('${widget.type}/${widget.tmdbId}',
          language: Localizations.localeOf(context).languageCode);
      if (mounted) {
        setState(() => _candidates =
            followCandidates(widget.type, widget.tmdbId, details));
      }
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    } finally {
      client.close();
    }
  }

  static String _kind(UpcomingFollow f) => switch (f.kind) {
        UpcomingFollowKind.person =>
          f.role == UpcomingRole.directing ? 'Réalisation' : 'Interprétation',
        UpcomingFollowKind.company => UpcomingStrings.studio,
        UpcomingFollowKind.network => UpcomingStrings.network,
        UpcomingFollowKind.collection => UpcomingStrings.saga,
        UpcomingFollowKind.tv => UpcomingStrings.thisSeries,
      };

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final state = ref.watch(upcomingProvider);
    final candidates = _candidates;
    return GlassDialog(
      constraints: const BoxConstraints(maxWidth: AppPageLayout.compactWidth),
      child: FocusTraversalGroup(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(UpcomingStrings.followDialogTitle,
                  style: text.headlineSmall),
              const SizedBox(height: AppSpacing.xs),
              Text(UpcomingStrings.followDialogHint,
                  style:
                      text.bodySmall?.copyWith(color: AppColors.textSecondary)),
              const SizedBox(height: AppSpacing.md),
              if (_failed)
                const Text(UpcomingStrings.followDialogFailed)
              else if (candidates == null)
                const Center(child: CircularProgressIndicator())
              else if (candidates.isEmpty)
                const Text(UpcomingStrings.followDialogEmpty)
              else
                Flexible(
                  child: ListView(
                    shrinkWrap: true,
                    children: [
                      for (final (index, follow) in candidates.indexed)
                        _Row(
                          follow: follow,
                          kind: _kind(follow),
                          followed: state.isFollowed(follow.key),
                          autofocus: index == 0,
                          onTap: () => ref
                              .read(upcomingProvider.notifier)
                              .toggleFollow(follow),
                        ),
                    ],
                  ),
                ),
              const SizedBox(height: AppSpacing.md),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Fermer')),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row(
      {required this.follow,
      required this.kind,
      required this.followed,
      required this.onTap,
      this.autofocus = false});
  final UpcomingFollow follow;
  final String kind;
  final bool followed;
  final VoidCallback onTap;
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final logo = follow.kind == UpcomingFollowKind.company ||
        follow.kind == UpcomingFollowKind.network;
    const size = AppDetailLayout.friendAvatarSize;
    return Semantics(
      toggled: followed,
      child: FocusRing(
        autofocus: autofocus,
        borderRadius: AppRadii.controlBorder,
        onActivate: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.xs, vertical: AppSpacing.xxs),
          child: Row(children: [
            SizedBox.square(
              dimension: size,
              child: ClipRRect(
                borderRadius:
                    BorderRadius.circular(logo ? AppRadii.control : size / 2),
                child: ColoredBox(
                  color: logo ? AppColors.textPrimary : AppColors.surfaceHigh,
                  child: follow.image == null
                      ? const SizedBox.shrink()
                      : Padding(
                          padding: EdgeInsets.all(logo ? AppSpacing.xxs : 0),
                          child: KinosImage(
                              image: ImageData(
                                  path: tmdbImage(follow.image!, size: 'w185'),
                                  key: 'follow:${follow.key}'),
                              fit: logo ? BoxFit.contain : BoxFit.cover),
                        ),
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(follow.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: text.bodyMedium),
                    Text(kind,
                        style: text.bodySmall
                            ?.copyWith(color: AppColors.textSecondary)),
                  ]),
            ),
            Icon(
                followed
                    ? Icons.check_circle_rounded
                    : Icons.add_circle_outline_rounded,
                color:
                    followed ? AppColors.textPrimary : AppColors.textSecondary),
          ]),
        ),
      ),
    );
  }
}
