import 'package:kinos/models/items/movie_model.dart';
import 'anilist_account_dialog.dart';
import 'anilist_ranges_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kinos/models/item_base_model.dart';
import 'package:kinos/providers/user_provider.dart';
import 'package:kinos/screens/shared/media/external_urls.dart' as external_urls;
import 'package:kinos/theme/app_theme.dart';
import 'package:kinos/util/localization_helper.dart';
import 'package:kinos/widgets/shared/frosted_surface.dart';
import 'package:kinos/widgets/shared/item_actions.dart';
import 'anilist_providers.dart';
import 'mapping.dart';

ItemActionButton anilistMappingAction(
        BuildContext context, ItemBaseModel item) =>
    ItemActionButton(
        icon: const Icon(Icons.link_rounded),
        label: Text(context.localized.anilistTitle),
        action: () => showAnilistMappingDialog(context, item));

Future<void> showAnilistMappingDialog(
        BuildContext context, ItemBaseModel item) =>
    showDialog<void>(
        context: context, builder: (_) => _MappingDialog(item: item));

class _MappingDialog extends ConsumerStatefulWidget {
  final ItemBaseModel item;
  const _MappingDialog({required this.item});
  @override
  ConsumerState<_MappingDialog> createState() => _MappingDialogState();
}

class _MappingDialogState extends ConsumerState<_MappingDialog> {
  final search = TextEditingController();
  bool searched = false;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ref.read(anilistMappingProvider(widget.item).notifier).resolve();
      }
    });
  }

  @override
  void dispose() {
    search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(
        userProvider.select(
            (u) => (u?.id, u?.credentials.serverId, u?.credentials.url)),
        (previous, next) {
      if (previous != next && mounted) Navigator.of(context).pop();
    });
    final state = ref.watch(anilistMappingProvider(widget.item));
    final controller = ref.read(anilistMappingProvider(widget.item).notifier);
    final l = context.localized;
    final theme = Theme.of(context);
    final candidates = searched
        ? [
            for (final m in state.searchResults)
              AnilistCandidate(m.id, const {}, media: m)
          ]
        : state.match.candidates;
    final reason = switch (state.match.reason) {
      AnilistMatchReason.conflictingIds => l.anilistConflict,
      AnilistMatchReason.splitSeason => l.anilistSplit,
      AnilistMatchReason.changedIds => l.anilistChanged,
      AnilistMatchReason.invalidSource => l.anilistInvalid,
      _ => null,
    };
    Future<void> submit() async {
      if (search.text.trim().isEmpty) return;
      await controller.search(search.text);
      if (mounted && !ref.read(anilistMappingProvider(widget.item)).failed) {
        setState(() => searched = true);
      }
    }

    return GlassDialog(
      constraints: BoxConstraints(
          maxWidth: AppPageLayout.compactWidth,
          maxHeight: MediaQuery.sizeOf(context).height - AppSpacing.xxl * 2),
      child: FocusTraversalGroup(
          child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(l.anilistTitle, style: theme.textTheme.headlineSmall),
              const SizedBox(height: AppSpacing.xs),
              Text(state.target.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleMedium),
              const SizedBox(height: AppSpacing.md),
              Flexible(
                  child: SingleChildScrollView(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                    Text(
                        state.busy
                            ? l.loading
                            : state.failed
                                ? l.anilistUnconfirmed
                                : state.savedId != null
                                    ? l.anilistSaved
                                    : switch (state.match.status) {
                                        AnilistMatchStatus.exact =>
                                          l.anilistExact,
                                        AnilistMatchStatus.needsConfirmation =>
                                          l.anilistUnconfirmed,
                                        _ => l.anilistMissing,
                                      },
                        style: theme.textTheme.titleSmall),
                    if (reason != null)
                      Padding(
                          padding: const EdgeInsets.only(top: AppSpacing.xs),
                          child: Text(reason)),
                    if (state.target.kind == AnilistTargetKind.season)
                      Padding(
                          padding: const EdgeInsets.only(top: AppSpacing.xs),
                          child: Text(l.anilistSeasonWarning)),
                    Padding(
                        padding:
                            const EdgeInsets.symmetric(vertical: AppSpacing.md),
                        child: Text(l.anilistNoSync,
                            style: theme.textTheme.bodySmall)),
                    Text(l.anilistAutomaticInfo),
                    Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton(
                            onPressed: () => showAnilistAccountDialog(context),
                            child: Text(l.anilistAccount))),
                    if (widget.item is! MovieModel)
                      Align(
                          alignment: Alignment.centerLeft,
                          child: OutlinedButton(
                              onPressed: state.busy
                                  ? null
                                  : () => showAnilistRangesDialog(
                                      context, widget.item,
                                      mediaId: state.selectedId),
                              child: Text(l.anilistRanges))),
                    if (state.failed) ...[
                      Text(l.anilistUnavailable),
                      if (state.retryAt case final DateTime retry)
                        Text(l.anilistRetryAt(MaterialLocalizations.of(context)
                            .formatTimeOfDay(
                                TimeOfDay.fromDateTime(retry.toLocal())))),
                      Align(
                          alignment: Alignment.centerLeft,
                          child: TextButton(
                              onPressed: state.busy
                                  ? null
                                  : () {
                                      setState(() => searched = false);
                                      controller.resolve();
                                    },
                              child: Text(l.anilistRetry))),
                    ],
                    TextField(
                        controller: search,
                        onSubmitted: state.busy ? null : (_) => submit(),
                        decoration:
                            InputDecoration(labelText: l.anilistSearchHint)),
                    Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton.icon(
                            onPressed: state.busy ? null : submit,
                            icon: const Icon(Icons.search),
                            label: Text(l.anilistSearch))),
                    if (state.busy) const LinearProgressIndicator(),
                    if (searched &&
                        !state.busy &&
                        !state.failed &&
                        candidates.isEmpty)
                      Text(l.anilistNoResults),
                    for (final candidate in candidates) ...[
                      ListTile(
                        title: Text(candidate.media?.title ??
                            'AniList #${candidate.id}'),
                        subtitle: Text([
                          if (candidate.media?.year case final int year)
                            '$year',
                          if (candidate.media?.format case final String format)
                            format,
                          'AniList #${candidate.id}',
                          ...candidate.sources,
                        ].join(' · ')),
                        selected: state.selectedId == candidate.id,
                        shape: const RoundedRectangleBorder(
                            borderRadius: AppRadii.cardBorder),
                        focusColor: AppColors.focus.withValues(alpha: 0.12),
                        trailing: state.selectedId == candidate.id
                            ? const Icon(Icons.check)
                            : null,
                        onTap: state.busy || candidate.media == null
                            ? null
                            : () => controller.select(candidate.id),
                      ),
                      for (final mapping in candidate.episodeMappings)
                        Padding(
                            padding: const EdgeInsets.only(
                                left: AppSpacing.md, bottom: AppSpacing.xs),
                            child: Text(
                                [
                                  if (mapping.season case final int season)
                                    l.anilistSeasonSource(
                                        mapping.source.toUpperCase(), season),
                                  if (mapping.offset case final int offset)
                                    l.anilistOffset(offset),
                                ].join(' · '),
                                style: theme.textTheme.bodySmall)),
                    ],
                  ]))),
              const SizedBox(height: AppSpacing.md),
              Wrap(
                  alignment: WrapAlignment.end,
                  spacing: AppSpacing.xs,
                  runSpacing: AppSpacing.xs,
                  children: [
                    if (state.savedId != null)
                      TextButton(
                          onPressed: state.busy
                              ? null
                              : () {
                                  setState(() => searched = false);
                                  controller.remove();
                                },
                          child: Text(l.anilistRemove)),
                    if (state.selectedId case final int id)
                      TextButton(
                          onPressed: state.busy
                              ? null
                              : () async {
                                  try {
                                    await external_urls.launchUrl(context,
                                        'https://anilist.co/anime/$id');
                                  } on Exception {
                                    if (context.mounted) {
                                      ScaffoldMessenger.maybeOf(context)
                                          ?.showSnackBar(SnackBar(
                                              content:
                                                  Text(l.anilistUnavailable)));
                                    }
                                  }
                                },
                          child: Text(l.anilistOpen)),
                    TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: Text(l.close)),
                    FilledButton(
                        onPressed: state.busy || state.selectedId == null
                            ? null
                            : () => controller.confirm(state.selectedId!),
                        child: Text(l.anilistConfirm)),
                  ]),
            ]),
      )),
    );
  }
}
