import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kinos/theme/app_theme.dart';
import 'package:kinos/util/localization_helper.dart';
import 'package:kinos/widgets/shared/frosted_surface.dart';
import 'letterboxd_identify_dialog.dart';
import 'letterboxd_import_controller.dart';
import 'letterboxd_model.dart';
import 'letterboxd_providers.dart';

Future<void> showLetterboxdImportDialog(BuildContext context) =>
    showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (_) => const LetterboxdImportDialog());

class LetterboxdImportDialog extends ConsumerStatefulWidget {
  const LetterboxdImportDialog({super.key});
  @override
  ConsumerState<LetterboxdImportDialog> createState() => _ImportDialogState();
}

class _ImportDialogState extends ConsumerState<LetterboxdImportDialog> {
  bool picking = false;

  /// La liste ne montre que les titres non reconnus.
  bool _unmatchedOnly = false;

  Future<void> _identify(LetterboxdRecord record) async {
    final choice = await showLetterboxdIdentifyDialog(context,
        record: record, search: _controller.searchWorks);
    if (choice == null || !mounted) return;
    final ok = await _controller.identify(record.film.uri, choice.work);
    if (!ok && mounted) {
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(const SnackBar(
          content: Text('Impossible de récupérer ce film sur TMDB.')));
    }
  }
  late final LetterboxdImportController _controller =
      ref.read(letterboxdImportProvider.notifier);

  @override
  void initState() {
    super.initState();
    _controller.attachView();
  }

  /// Cocher demande confirmation : beaucoup de films changent d'état d'un
  /// coup (on peut toujours les démarquer dans Jellyfin).
  Future<void> _setMarkPlayed(bool value, int count) async {
    if (value) {
      final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => GlassAlertDialog(
                  title: const Text('Marquer comme vus dans Jellyfin ?'),
                  content: Text(count > 0
                      ? '$count films de votre bibliothèque seront marqués vus, à la date de leur dernier visionnage sur Letterboxd. Ceux déjà vus ne changent pas.'
                      : 'Les films de votre bibliothèque vus sur Letterboxd seront marqués vus, à la date de leur dernier visionnage. Ceux déjà vus ne changent pas.'),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: Text(context.localized.cancel)),
                    FilledButton(
                        onPressed: () => Navigator.pop(context, true),
                        child: const Text('Marquer')),
                  ]));
      if (confirmed != true) return;
    }
    if (mounted) setState(() => _controller.markPlayedInJellyfin = value);
  }

  @override
  void dispose() {
    _controller.detachView();
    super.dispose();
  }

  Future<void> pick() async {
    final scope = ref.read(letterboxdScopeProvider);
    setState(() => picking = true);
    try {
      final bytes = await ref.read(letterboxdPickExportProvider)();
      if (!mounted || ref.read(letterboxdScopeProvider) != scope) return;
      if (bytes != null) {
        await ref.read(letterboxdImportProvider.notifier).prepare(bytes);
      }
    } catch (_) {
      if (mounted && ref.read(letterboxdScopeProvider) == scope) {
        ref.read(letterboxdImportProvider.notifier).fileError();
      }
    } finally {
      if (mounted) setState(() => picking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(letterboxdScopeProvider, (a, b) {
      if (a != b && mounted) Navigator.of(context).pop();
    });
    final state = ref.watch(letterboxdImportProvider);
    final snapshot = ref.watch(letterboxdSnapshotProvider);
    final controller = ref.read(letterboxdImportProvider.notifier);
    final l = context.localized;
    final saved = snapshot.asData?.value;
    final busy = picking || state.busy;
    final records = state.ready ? state.records : saved?.records;
    final matched =
        records?.where((r) => r.work?.traits.isNotEmpty == true).length ?? 0;
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
                      Text(l.letterboxdTitle,
                          style: Theme.of(context).textTheme.headlineSmall),
                      const SizedBox(height: AppSpacing.md),
                      Text(l.letterboxdExplanation),
                      const SizedBox(height: AppSpacing.md),
                      // Le filtre des non reconnus partage la ligne du
                      // bouton : la fenêtre garde sa hauteur pour la liste.
                      Row(children: [
                        OutlinedButton(
                            onPressed: busy ? null : pick,
                            child: Text(l.letterboxdChoose)),
                        const SizedBox(width: AppSpacing.sm),
                        if (records != null && matched < records.length)
                          Expanded(
                              child: Align(
                                  alignment: Alignment.centerRight,
                                  child: TextButton.icon(
                                      onPressed: () => setState(() =>
                                          _unmatchedOnly = !_unmatchedOnly),
                                      icon: Icon(_unmatchedOnly
                                          ? Icons.check_box
                                          : Icons.check_box_outline_blank),
                                      label: Text(
                                          'Non reconnus seulement (${records.length - matched})',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis)))),
                      ]),
                      if (state.saved) Text(l.letterboxdSaved),
                      if (snapshot.hasError || state.error == 'storage')
                        Text(l.letterboxdStorageError),
                      if (state.error == 'file') Text(l.letterboxdFileError),
                      if (state.networkWarning ||
                          state.error == 'network' ||
                          (records != null && matched < records.length))
                        Text(l.letterboxdNetworkWarning),
                      // Option : les films de la bibliothèque vus sur
                      // Letterboxd deviennent vus dans Jellyfin (à la date
                      // de leur dernier visionnage), après confirmation.
                      CheckboxListTile(
                          contentPadding: EdgeInsets.zero,
                          dense: true,
                          visualDensity: VisualDensity.compact,
                          controlAffinity: ListTileControlAffinity.leading,
                          value: controller.markPlayedInJellyfin,
                          onChanged: state.saved
                              ? null
                              : (value) => _setMarkPlayed(value ?? false,
                                  LetterboxdImportController.playable(
                                          state.records)
                                      .length),
                          title: Text(state.ready
                              ? 'Marquer aussi comme vus dans Jellyfin '
                                  '(${LetterboxdImportController.playable(state.records).length} films)'
                              : 'Marquer aussi comme vus dans Jellyfin')),
                      if (busy) ...[
                        Text(picking
                            ? l.letterboxdRead
                            : switch (state.phase) {
                                'match' =>
                                  '${l.letterboxdMatch} ${state.done}/${state.total}',
                                'save' => l.letterboxdSave,
                                _ => l.letterboxdRead
                              }),
                        const LinearProgressIndicator(),
                      ],
                      if (records != null) ...[
                        const SizedBox(height: AppSpacing.md),
                        Text(l.letterboxdSummary(
                            records.length, matched, records.length - matched)),
                        Flexible(
                            child: Builder(builder: (context) {
                          final shown = _unmatchedOnly
                              ? [
                                  for (final r in records)
                                    if (r.work?.traits.isNotEmpty != true) r
                                ]
                              : records;
                          return ListView.builder(
                                shrinkWrap: true,
                                itemCount: shown.length,
                                itemBuilder: (context, index) {
                                  final record = shown[index];
                                  return ListTile(
                                      contentPadding: EdgeInsets.zero,
                                      title: Text(
                                          '${record.film.title}${record.film.year == null ? '' : ' (${record.film.year})'}',
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis),
                                      subtitle: Text(
                                          '${record.film.rating == null ? '' : '★ ${record.film.rating} · '}${record.work?.traits.isNotEmpty == true ? record.work!.title : l.letterboxdUnmatched}'),
                                      // Identifier à la main, pendant
                                      // l'aperçu comme après l'import.
                                      trailing: TextButton(
                                          onPressed: busy
                                              ? null
                                              : () => _identify(record),
                                          child: Text(record.work?.traits
                                                      .isNotEmpty ==
                                                  true
                                              ? 'Changer'
                                              : 'Identifier')));
                                });
                        })),
                      ],
                      const SizedBox(height: AppSpacing.md),
                      Wrap(
                          spacing: AppSpacing.sm,
                          runSpacing: AppSpacing.xs,
                          alignment: WrapAlignment.end,
                          children: [
                            if (saved?.records.isNotEmpty == true &&
                                !state.ready)
                              TextButton(
                                  onPressed:
                                      busy ? null : controller.retrySaved,
                                  child: Text(l.letterboxdRetry)),
                            if (saved?.records.isNotEmpty == true)
                              TextButton(
                                  onPressed: busy
                                      ? null
                                      : () async {
                                          final remove = await showDialog<bool>(
                                              context: context,
                                              builder: (context) =>
                                                  GlassAlertDialog(
                                                      title: Text(
                                                          l.letterboxdRemove),
                                                      content: Text(l
                                                          .letterboxdRemoveQuestion),
                                                      actions: [
                                                        TextButton(
                                                            onPressed: () =>
                                                                Navigator.pop(
                                                                    context,
                                                                    false),
                                                            child:
                                                                Text(l.cancel)),
                                                        TextButton(
                                                            onPressed: () =>
                                                                Navigator.pop(
                                                                    context,
                                                                    true),
                                                            child: Text(l
                                                                .letterboxdRemove)),
                                                      ]));
                                          if (remove == true && mounted) {
                                            await ref
                                                .read(letterboxdImportProvider
                                                    .notifier)
                                                .clear();
                                          }
                                        },
                                  child: Text(l.letterboxdRemove)),
                            if (state.ready)
                              FilledButton(
                                  onPressed: busy ? null : controller.commit,
                                  child: Text(l.letterboxdConfirm)),
                            if (state.busy) ...[
                              // L'analyse continue sans la fenêtre, et
                              // l'import s'enregistre seul à la fin.
                              TextButton(
                                  onPressed: () {
                                    controller.cancel();
                                    Navigator.of(context).pop();
                                  },
                                  child: Text(l.cancel)),
                              FilledButton(
                                  onPressed: () => Navigator.of(context).pop(),
                                  child: const Text(
                                      'Continuer en arrière-plan')),
                            ] else
                              TextButton(
                                  onPressed: () {
                                    if (picking) controller.cancel();
                                    Navigator.of(context).pop();
                                  },
                                  child: Text(picking ? l.cancel : l.close)),
                          ]),
                    ]))));
  }
}
