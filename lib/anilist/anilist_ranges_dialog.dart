import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kinos/models/item_base_model.dart';
import 'package:kinos/providers/user_provider.dart';
import 'package:kinos/theme/app_theme.dart';
import 'package:kinos/util/localization_helper.dart';
import 'package:kinos/widgets/shared/frosted_surface.dart';
import 'anilist_ui_service.dart';
import 'episode_mapping.dart';
import 'mapping.dart';

Future<void> showAnilistRangesDialog(BuildContext context, ItemBaseModel item,
        {int? mediaId}) =>
    showDialog<void>(
        context: context,
        builder: (_) => _RangesDialog(item: item, mediaId: mediaId));

class _RangesDialog extends ConsumerStatefulWidget {
  final ItemBaseModel item;
  final int? mediaId;
  const _RangesDialog({required this.item, this.mediaId});
  @override
  ConsumerState<_RangesDialog> createState() => _RangesDialogState();
}

class _RangesDialogState extends ConsumerState<_RangesDialog> {
  final fields = List.generate(5, (_) => TextEditingController());
  AnilistTarget? target;
  List<EpisodeRange> ranges = [];
  bool busy = true, changed = false;
  String? error;
  @override
  void initState() {
    super.initState();
    fields[0].text = '1';
    fields[1].text = '1';
    fields[4].text = '1';
    fields[3].text = widget.mediaId?.toString() ?? '';
    WidgetsBinding.instance.addPostFrameCallback((_) => load());
  }

  @override
  void dispose() {
    for (final f in fields) {
      f.dispose();
    }
    super.dispose();
  }

  Future<void> load() async {
    try {
      final value =
          await ref.read(anilistUiServiceProvider).ranges(widget.item);
      if (mounted) {
        setState(() {
          target = value.target;
          changed = value.changed;
          ranges = value.ranges.toList();
          busy = false;
          error = null;
        });
      }
    } on Exception {
      if (mounted) {
        setState(() {
          busy = false;
          error = 'network';
        });
      }
    }
  }

  void add() {
    try {
      final n = fields.map((f) => int.tryParse(f.text)).toList();
      if (n.any((v) => v == null)) throw ArgumentError();
      final value = EpisodeRange(
          season: n[0]!,
          first: n[1]!,
          last: n[2]!,
          mediaId: n[3]!,
          anilistFirst: n[4]!);
      EpisodePlan.manual([...ranges, value]);
      setState(() {
        ranges = [...ranges, value];
        error = null;
      });
    } on ArgumentError {
      setState(() => error = 'range');
    }
  }

  Future<void> save() async {
    if (target == null || busy) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await ref.read(anilistUiServiceProvider).saveRanges(target!, ranges);
      if (mounted) Navigator.of(context).pop();
    } on ArgumentError {
      if (mounted) setState(() => error = 'range');
    } on Exception {
      if (mounted) setState(() => error = 'network');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(anilistUiServiceProvider);
    ref.listen(
        userProvider.select(
            (u) => (u?.id, u?.credentials.serverId, u?.credentials.url)),
        (a, b) {
      if (a != b && mounted) Navigator.of(context).pop();
    });
    final l = context.localized;
    final labels = [
      l.anilistSeasonNumber,
      l.anilistFirstEpisode,
      l.anilistLastEpisode,
      l.anilistMediaId,
      l.anilistFirstRemoteEpisode
    ];
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
                      Text(l.anilistRanges,
                          style: Theme.of(context).textTheme.headlineSmall),
                      const SizedBox(height: AppSpacing.sm),
                      Text(target?.title ?? widget.item.name,
                          maxLines: 2, overflow: TextOverflow.ellipsis),
                      const SizedBox(height: AppSpacing.md),
                      Flexible(
                          child: SingleChildScrollView(
                              child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                            Text(l.anilistRangeHelp),
                            if (changed) Text(l.anilistChanged),
                            const SizedBox(height: AppSpacing.md),
                            for (final range in ranges)
                              ListTile(
                                  contentPadding: EdgeInsets.zero,
                                  title: Text(l.anilistRangeLine(
                                      range.season,
                                      range.first,
                                      range.last,
                                      range.mediaId,
                                      range.anilistFirst,
                                      range.anilistLast)),
                                  trailing: IconButton(
                                      tooltip: l.anilistDeleteRange,
                                      onPressed: busy
                                          ? null
                                          : () => setState(
                                              () => ranges.remove(range)),
                                      icon: const Icon(Icons.delete_outline))),
                            for (var i = 0; i < fields.length; i++)
                              Padding(
                                  padding: const EdgeInsets.only(
                                      bottom: AppSpacing.sm),
                                  child: TextField(
                                      controller: fields[i],
                                      enabled: !busy && target != null,
                                      keyboardType: TextInputType.number,
                                      inputFormatters: [
                                        FilteringTextInputFormatter.digitsOnly
                                      ],
                                      decoration:
                                          InputDecoration(labelText: labels[i]),
                                      onSubmitted: !busy && target != null
                                          ? (_) => add()
                                          : null)),
                            Align(
                                alignment: Alignment.centerLeft,
                                child: OutlinedButton(
                                    onPressed:
                                        busy || target == null ? null : add,
                                    child: Text(l.anilistAddRange))),
                            if (error != null)
                              Text(error == 'range'
                                  ? l.anilistRangeInvalid
                                  : l.anilistUnavailable),
                            if (target == null && !busy)
                              TextButton(
                                  onPressed: load, child: Text(l.anilistRetry)),
                            if (busy) const LinearProgressIndicator(),
                          ]))),
                      const SizedBox(height: AppSpacing.md),
                      Wrap(
                          alignment: WrapAlignment.end,
                          spacing: AppSpacing.xs,
                          runSpacing: AppSpacing.xs,
                          children: [
                            TextButton(
                                onPressed: () => Navigator.of(context).pop(),
                                child: Text(l.cancel)),
                            FilledButton(
                                onPressed: busy || target == null ? null : save,
                                child: Text(l.anilistSaveRanges)),
                          ]),
                    ]))));
  }
}
