import 'dart:async';

import 'package:flutter/material.dart';

import 'package:kinos/theme/app_theme.dart';
import 'package:kinos/util/localization_helper.dart';
import 'package:kinos/widgets/shared/frosted_surface.dart';

import 'letterboxd_model.dart';

/// Le choix fait dans la fenêtre : un film, ou aucun (« ne pas utiliser »).
typedef LetterboxdIdentification = ({LetterboxdWork? work});

/// Identifier à la main un film de l'import Letterboxd : ses candidats
/// connus, puis une recherche libre (bibliothèque, puis TMDB). Rend null si
/// la fenêtre est fermée sans choix.
Future<LetterboxdIdentification?> showLetterboxdIdentifyDialog(
  BuildContext context, {
  required LetterboxdRecord record,
  required Future<List<LetterboxdWork>> Function(String query) search,
}) =>
    showDialog<LetterboxdIdentification>(
      context: context,
      builder: (_) => _IdentifyDialog(record: record, search: search),
    );

class _IdentifyDialog extends StatefulWidget {
  const _IdentifyDialog({required this.record, required this.search});
  final LetterboxdRecord record;
  final Future<List<LetterboxdWork>> Function(String query) search;

  @override
  State<_IdentifyDialog> createState() => _IdentifyDialogState();
}

class _IdentifyDialogState extends State<_IdentifyDialog> {
  late final _query = TextEditingController(text: widget.record.film.title);
  Timer? _debounce;
  List<LetterboxdWork>? _results;
  bool _searching = false;
  bool _failed = false;
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    _run();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _query.dispose();
    super.dispose();
  }

  void _onChanged(String _) {
    _debounce?.cancel();
    _debounce = Timer(AppDurations.searchDebounce, _run);
  }

  Future<void> _run() async {
    final generation = ++_generation;
    setState(() {
      _searching = true;
      _failed = false;
    });
    try {
      final results = await widget.search(_query.text);
      if (!mounted || generation != _generation) return;
      setState(() {
        _results = results;
        _searching = false;
      });
    } catch (_) {
      if (!mounted || generation != _generation) return;
      setState(() {
        _failed = true;
        _searching = false;
      });
    }
  }

  void _pick(LetterboxdWork? work) =>
      Navigator.of(context).pop<LetterboxdIdentification>((work: work));

  @override
  Widget build(BuildContext context) {
    final film = widget.record.film;
    final text = Theme.of(context).textTheme;
    final current = widget.record.work;
    final known = widget.record.choices;
    final results = [
      for (final work in _results ?? const <LetterboxdWork>[])
        if (!known.any((k) => k.identity == work.identity)) work
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
              Text('Identifier', style: text.headlineSmall),
              const SizedBox(height: AppSpacing.xs),
              Text(
                  'Sur Letterboxd : ${film.title}'
                  '${film.year == null ? '' : ' (${film.year})'}',
                  style: text.bodyMedium
                      ?.copyWith(color: AppColors.textSecondary)),
              const SizedBox(height: AppSpacing.md),
              TextField(
                controller: _query,
                autofocus: true,
                onChanged: _onChanged,
                onSubmitted: (_) {
                  _debounce?.cancel();
                  _run();
                },
                decoration: const InputDecoration(
                  hintText: 'Titre du film (original ou traduit)',
                  prefixIcon: Icon(Icons.search),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              if (_searching) const LinearProgressIndicator(),
              if (_failed)
                Text('La recherche TMDB a échoué ; réessayez.',
                    style: text.bodyMedium?.copyWith(color: AppColors.error)),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    if (known.isNotEmpty) ...[
                      const _Header('Candidats trouvés à l\'import'),
                      for (final work in known)
                        _WorkTile(
                            work: work,
                            selected: work.identity == current?.identity,
                            onTap: () => _pick(work)),
                    ],
                    if (results.isNotEmpty) ...[
                      const _Header('Résultats'),
                      for (final work in results)
                        _WorkTile(
                            work: work,
                            selected: work.identity == current?.identity,
                            onTap: () => _pick(work)),
                    ] else if (!_searching && _results != null)
                      Padding(
                        padding:
                            const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                        child: Text(
                            'Aucun résultat. Essayez le titre original, ou '
                            'sans l\'article.',
                            style: text.bodyMedium
                                ?.copyWith(color: AppColors.textSecondary)),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Wrap(
                alignment: WrapAlignment.end,
                spacing: AppSpacing.sm,
                children: [
                  TextButton(
                      onPressed: () => _pick(null),
                      child: Text(context.localized.letterboxdNotUsed)),
                  TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: Text(context.localized.cancel)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header(this.label);
  final String label;

  @override
  Widget build(BuildContext context) => Padding(
        padding:
            const EdgeInsets.only(top: AppSpacing.sm, bottom: AppSpacing.xxs),
        child: Text(label.toUpperCase(),
            style: AppTypography.overline
                .copyWith(color: AppColors.textSecondary)),
      );
}

class _WorkTile extends StatelessWidget {
  const _WorkTile(
      {required this.work, required this.selected, required this.onTap});
  final LetterboxdWork work;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final original =
        work.aliases.where((a) => a.isNotEmpty && a != work.title).firstOrNull;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      onTap: onTap,
      title: Text('${work.title}${work.year == null ? '' : ' (${work.year})'}',
          maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text([
        if (original != null) original,
        if (work.isSeries) 'Série',
        work.jellyfinId != null ? 'Dans la bibliothèque' : 'TMDB',
      ].join(' · ')),
      trailing: selected ? const Icon(Icons.check) : null,
    );
  }
}
