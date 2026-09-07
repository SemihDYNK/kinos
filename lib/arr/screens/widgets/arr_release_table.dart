import 'package:flutter/material.dart';

import 'package:fladder/arr/models/arr_grab_status.dart';
import 'package:fladder/arr/models/arr_release.dart';
import 'package:fladder/arr/screens/widgets/arr_rejection_tooltip.dart';
import 'package:fladder/screens/details_screens/components/media_info_formatters.dart';
import 'package:fladder/theme/app_theme.dart';

enum _ArrReleaseColumn {
  rejected,
  age,
  title,
  indexer,
  size,
  seeds,
  quality,
  languages,
  score,
}

/// Tableau des résultats de recherche interactive — sobre : texte aligné,
/// pas de pastilles ni de badges arrondis. Une ligne = une release ; le
/// téléchargement se déclenche uniquement via le bouton dédié en fin de
/// ligne (cf. [onGrab]), jamais par un clic sur la ligne elle-même.
///
/// Largeurs de colonnes fixes (hors Titre, extensible mais avec un
/// plancher, [_minTitleWidth]) : une table de données n'a pas d'échelle
/// d'espacement à suivre comme un padding ou un rayon, ces valeurs sont
/// documentées ici plutôt que reprises d'un jeton [AppSpacing]. En
/// dessous de la largeur totale minimale ([_minTableWidth]), le tableau
/// défile horizontalement plutôt que de comprimer/chevaucher ses
/// colonnes — cf. [_buildTable].
class ArrReleaseTable extends StatefulWidget {
  final List<ArrRelease> releases;
  final Map<String, ArrGrabStatus> grabStatuses;
  final ValueChanged<ArrRelease> onGrab;

  const ArrReleaseTable({
    required this.releases,
    required this.grabStatuses,
    required this.onGrab,
    super.key,
  });

  @override
  State<ArrReleaseTable> createState() => _ArrReleaseTableState();
}

class _ArrReleaseTableState extends State<ArrReleaseTable> {
  _ArrReleaseColumn _sortColumn = _ArrReleaseColumn.score;
  bool _ascending = false;

  bool _hideRejected = false;
  int _minSeeders = 0;

  static const _rejectedWidth = 28.0;
  static const _ageWidth = 56.0;
  static const _minTitleWidth = 220.0;
  static const _indexerWidth = 128.0;
  static const _sizeWidth = 84.0;
  // Assez large pour "999 / 999" (le pire cas plausible de seeders/peers)
  // sans jamais frôler la colonne suivante.
  static const _seedsWidth = 108.0;
  static const _qualityWidth = 116.0;
  static const _languagesWidth = 116.0;
  static const _scoreWidth = 64.0;
  static const _actionWidth = 40.0;

  /// Espace entre deux colonnes — fixe, pas [AppSpacing.xs] réutilisé par
  /// coïncidence : c'est un espacement de tableau, pas un padding d'écran.
  static const _columnGap = AppSpacing.xs;

  /// Largeur totale minimale du tableau (toutes colonnes + espacements),
  /// hors barre de filtres : en dessous, le tableau défile
  /// horizontalement plutôt que de laisser deux colonnes se chevaucher
  /// (cf. CLAUDE.md — pas de mode salon pour ce module, mais une fenêtre
  /// desktop peut tout de même être redimensionnée très étroite).
  static const _minTableWidth = _rejectedWidth +
      _columnGap +
      _ageWidth +
      _columnGap +
      _minTitleWidth +
      _columnGap +
      _indexerWidth +
      _columnGap +
      _sizeWidth +
      _columnGap +
      _seedsWidth +
      _columnGap +
      _qualityWidth +
      _columnGap +
      _languagesWidth +
      _columnGap +
      _scoreWidth +
      _columnGap +
      _actionWidth;

  int _compareNum(num? a, num? b) {
    if (a == null && b == null) return 0;
    if (a == null) return 1;
    if (b == null) return -1;
    return a.compareTo(b);
  }

  int _compareStr(String? a, String? b) {
    final left = a?.toLowerCase() ?? '';
    final right = b?.toLowerCase() ?? '';
    return left.compareTo(right);
  }

  List<ArrRelease> get _visible {
    final filtered = widget.releases.where((release) {
      if (_hideRejected && release.rejected) return false;
      if (_minSeeders > 0) {
        // Une release usenet n'a pas de seeders : le seuil ne s'applique
        // qu'au torrent, on ne masque pas les résultats usenet.
        if (release.protocol == ArrReleaseProtocol.torrent &&
            (release.seeders ?? 0) < _minSeeders) {
          return false;
        }
      }
      return true;
    }).toList();

    filtered.sort((a, b) {
      final result = switch (_sortColumn) {
        _ArrReleaseColumn.rejected =>
          (a.rejected ? 1 : 0).compareTo(b.rejected ? 1 : 0),
        _ArrReleaseColumn.age => _compareNum(a.ageDays, b.ageDays),
        _ArrReleaseColumn.title => _compareStr(a.title, b.title),
        _ArrReleaseColumn.indexer => _compareStr(a.indexer, b.indexer),
        _ArrReleaseColumn.size => _compareNum(a.size, b.size),
        _ArrReleaseColumn.seeds => _compareNum(a.seeders, b.seeders),
        _ArrReleaseColumn.quality => _compareStr(a.qualityName, b.qualityName),
        _ArrReleaseColumn.languages =>
          _compareStr(a.languages.join(), b.languages.join()),
        _ArrReleaseColumn.score =>
          _compareNum(a.customFormatScore, b.customFormatScore),
      };
      return _ascending ? result : -result;
    });
    return filtered;
  }

  void _onHeaderTap(_ArrReleaseColumn column) {
    setState(() {
      if (_sortColumn == column) {
        _ascending = !_ascending;
      } else {
        _sortColumn = column;
        _ascending = true;
      }
    });
  }

  Future<void> _handleGrab(ArrRelease release) async {
    if (release.rejected) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Release rejetée'),
          content: Text(
            release.rejections.isEmpty
                ? 'Cette release a été rejetée par les critères de qualité. '
                    'L\'envoyer au téléchargement quand même ?'
                : 'Cette release a été rejetée pour :\n'
                    '${release.rejections.map((r) => '• $r').join('\n')}\n\n'
                    'L\'envoyer au téléchargement quand même ?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Annuler'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Envoyer quand même'),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
    }
    widget.onGrab(release);
  }

  Widget _buildTable(BuildContext context, List<ArrRelease> releases) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _ArrReleaseHeaderRow(
          sortColumn: _sortColumn,
          ascending: _ascending,
          onTap: _onHeaderTap,
          rejectedWidth: _rejectedWidth,
          ageWidth: _ageWidth,
          indexerWidth: _indexerWidth,
          sizeWidth: _sizeWidth,
          seedsWidth: _seedsWidth,
          qualityWidth: _qualityWidth,
          languagesWidth: _languagesWidth,
          scoreWidth: _scoreWidth,
          actionWidth: _actionWidth,
        ),
        const Divider(height: 1, thickness: 1, color: AppColors.border),
        if (releases.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: AppSpacing.lg),
            child: Text(
              'Aucune release ne correspond aux filtres.',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          )
        else
          for (final (index, release) in releases.indexed)
            _ArrReleaseRow(
              key: ValueKey('${release.indexerId}:${release.guid}'),
              release: release,
              grabStatus:
                  widget.grabStatuses[release.guid] ?? ArrGrabStatus.idle,
              onGrab: () => _handleGrab(release),
              striped: index.isOdd,
              rejectedWidth: _rejectedWidth,
              ageWidth: _ageWidth,
              indexerWidth: _indexerWidth,
              sizeWidth: _sizeWidth,
              seedsWidth: _seedsWidth,
              qualityWidth: _qualityWidth,
              languagesWidth: _languagesWidth,
              scoreWidth: _scoreWidth,
              actionWidth: _actionWidth,
            ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final releases = _visible;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _ArrReleaseFilterBar(
          hideRejected: _hideRejected,
          minSeeders: _minSeeders,
          onHideRejectedChanged: (value) =>
              setState(() => _hideRejected = value),
          onMinSeedersChanged: (value) => setState(() => _minSeeders = value),
          shownCount: releases.length,
          totalCount: widget.releases.length,
        ),
        const SizedBox(height: AppSpacing.sm),
        // Le tableau ne rétrécit jamais ses colonnes sous leur largeur
        // minimale : sur une fenêtre étroite, il défile horizontalement
        // plutôt que de laisser deux colonnes se chevaucher.
        LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth < _minTableWidth
                ? _minTableWidth
                : constraints.maxWidth;
            return SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SizedBox(
                width: width,
                child: _buildTable(context, releases),
              ),
            );
          },
        ),
      ],
    );
  }
}

/// Barre de filtres rapides au-dessus du tableau : masquer les rejetées, et
/// un seuil de seeders minimum (torrent uniquement).
class _ArrReleaseFilterBar extends StatelessWidget {
  final bool hideRejected;
  final int minSeeders;
  final ValueChanged<bool> onHideRejectedChanged;
  final ValueChanged<int> onMinSeedersChanged;
  final int shownCount;
  final int totalCount;

  const _ArrReleaseFilterBar({
    required this.hideRejected,
    required this.minSeeders,
    required this.onHideRejectedChanged,
    required this.onMinSeedersChanged,
    required this.shownCount,
    required this.totalCount,
  });

  @override
  Widget build(BuildContext context) {
    final labelStyle = Theme.of(context)
        .textTheme
        .bodySmall
        ?.copyWith(color: AppColors.textSecondary);

    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: AppSpacing.md,
      runSpacing: AppSpacing.xs,
      children: [
        FocusRing(
          borderRadius: AppRadii.controlBorder,
          onActivate: () => onHideRejectedChanged(!hideRejected),
          child: ExcludeFocus(
            child: InkWell(
              borderRadius: AppRadii.controlBorder,
              onTap: () => onHideRejectedChanged(!hideRejected),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.xxs, vertical: AppSpacing.xxs),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Checkbox(
                      value: hideRejected,
                      onChanged: (value) =>
                          onHideRejectedChanged(value ?? false),
                    ),
                    const SizedBox(width: AppSpacing.xxs),
                    Text('Masquer les rejetées', style: labelStyle),
                  ],
                ),
              ),
            ),
          ),
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Seeders min.', style: labelStyle),
            const SizedBox(width: AppSpacing.xs),
            SizedBox(
              width: 64,
              child: TextFormField(
                initialValue: minSeeders == 0 ? '' : minSeeders.toString(),
                keyboardType: TextInputType.number,
                style: Theme.of(context).textTheme.bodySmall,
                decoration: const InputDecoration(
                  isDense: true,
                  hintText: '0',
                  hintStyle: TextStyle(color: AppColors.textDisabled),
                  contentPadding: EdgeInsets.symmetric(
                      horizontal: AppSpacing.xs, vertical: AppSpacing.xxs),
                  border: OutlineInputBorder(
                    borderRadius: AppRadii.controlBorder,
                    borderSide: BorderSide(color: AppColors.border),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: AppRadii.controlBorder,
                    borderSide: BorderSide(color: AppColors.border),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: AppRadii.controlBorder,
                    borderSide: BorderSide(color: AppColors.focus),
                  ),
                ),
                onChanged: (value) =>
                    onMinSeedersChanged(int.tryParse(value) ?? 0),
              ),
            ),
          ],
        ),
        Text('$shownCount / $totalCount', style: labelStyle),
      ],
    );
  }
}

class _ArrReleaseHeaderRow extends StatelessWidget {
  final _ArrReleaseColumn sortColumn;
  final bool ascending;
  final ValueChanged<_ArrReleaseColumn> onTap;
  final double rejectedWidth;
  final double ageWidth;
  final double indexerWidth;
  final double sizeWidth;
  final double seedsWidth;
  final double qualityWidth;
  final double languagesWidth;
  final double scoreWidth;
  final double actionWidth;

  const _ArrReleaseHeaderRow({
    required this.sortColumn,
    required this.ascending,
    required this.onTap,
    required this.rejectedWidth,
    required this.ageWidth,
    required this.indexerWidth,
    required this.sizeWidth,
    required this.seedsWidth,
    required this.qualityWidth,
    required this.languagesWidth,
    required this.scoreWidth,
    required this.actionWidth,
  });

  Widget _header(BuildContext context, String label, double width,
      _ArrReleaseColumn column,
      {TextAlign align = TextAlign.start}) {
    final selected = sortColumn == column;
    return SizedBox(
      width: width,
      child: FocusRing(
        borderRadius: AppRadii.controlBorder,
        onActivate: () => onTap(column),
        child: ExcludeFocus(
          child: InkWell(
            borderRadius: AppRadii.controlBorder,
            onTap: () => onTap(column),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
              child: Row(
                mainAxisAlignment: align == TextAlign.end
                    ? MainAxisAlignment.end
                    : MainAxisAlignment.start,
                children: [
                  if (align == TextAlign.end && selected) ...[
                    Icon(
                      ascending
                          ? Icons.arrow_upward_rounded
                          : Icons.arrow_downward_rounded,
                      size: 12,
                      color: AppColors.textPrimary,
                    ),
                    const SizedBox(width: AppSpacing.xxs),
                  ],
                  Flexible(
                    child: Text(
                      label,
                      textAlign: align,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: selected
                              ? AppColors.textPrimary
                              : AppColors.textSecondary),
                    ),
                  ),
                  if (align != TextAlign.end && selected) ...[
                    const SizedBox(width: AppSpacing.xxs),
                    Icon(
                      ascending
                          ? Icons.arrow_upward_rounded
                          : Icons.arrow_downward_rounded,
                      size: 12,
                      color: AppColors.textPrimary,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const gap = SizedBox(width: AppSpacing.xs);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
      child: Row(
        children: [
          SizedBox(width: rejectedWidth),
          gap,
          _header(context, 'Âge', ageWidth, _ArrReleaseColumn.age,
              align: TextAlign.end),
          gap,
          Expanded(
              child: _header(context, 'Release', double.infinity,
                  _ArrReleaseColumn.title)),
          gap,
          _header(context, 'Indexeur', indexerWidth, _ArrReleaseColumn.indexer),
          gap,
          _header(context, 'Taille', sizeWidth, _ArrReleaseColumn.size,
              align: TextAlign.end),
          gap,
          _header(context, 'Seeds/Peers', seedsWidth, _ArrReleaseColumn.seeds,
              align: TextAlign.end),
          gap,
          _header(context, 'Qualité', qualityWidth, _ArrReleaseColumn.quality),
          gap,
          _header(
              context, 'Langues', languagesWidth, _ArrReleaseColumn.languages),
          gap,
          _header(context, 'Score', scoreWidth, _ArrReleaseColumn.score,
              align: TextAlign.end),
          gap,
          SizedBox(width: actionWidth),
        ],
      ),
    );
  }
}

class _ArrReleaseRow extends StatelessWidget {
  final ArrRelease release;
  final ArrGrabStatus grabStatus;
  final VoidCallback onGrab;
  final bool striped;
  final double rejectedWidth;
  final double ageWidth;
  final double indexerWidth;
  final double sizeWidth;
  final double seedsWidth;
  final double qualityWidth;
  final double languagesWidth;
  final double scoreWidth;
  final double actionWidth;

  const _ArrReleaseRow({
    required this.release,
    required this.grabStatus,
    required this.onGrab,
    required this.striped,
    required this.rejectedWidth,
    required this.ageWidth,
    required this.indexerWidth,
    required this.sizeWidth,
    required this.seedsWidth,
    required this.qualityWidth,
    required this.languagesWidth,
    required this.scoreWidth,
    required this.actionWidth,
    super.key,
  });

  String get _ageLabel {
    final age = release.ageDays;
    if (age == null) return '—';
    if (age < 1) return '< 1j';
    return '${age.round()}j';
  }

  String get _seedsLabel {
    if (release.protocol != ArrReleaseProtocol.torrent) {
      return release.protocol.label;
    }
    final seeders = release.seeders ?? 0;
    final leechers = release.leechers ?? 0;
    return '$seeders / $leechers';
  }

  Widget _rejectionIndicator(BuildContext context) {
    if (!release.rejected) return const SizedBox.shrink();
    return ArrRejectionTooltip(
      reasons: release.rejections,
      child: const Icon(Icons.report_gmailerrorred_rounded,
          size: 16, color: AppColors.error),
    );
  }

  Widget _actionButton(BuildContext context) {
    final sending = grabStatus == ArrGrabStatus.sending;
    switch (grabStatus) {
      case ArrGrabStatus.success:
        return const Tooltip(
          message: 'Envoyée au téléchargement',
          child: Icon(Icons.check_circle_rounded,
              size: 18, color: AppColors.success),
        );
      case ArrGrabStatus.sending:
      case ArrGrabStatus.idle:
      case ArrGrabStatus.failed:
        return FocusRing(
          borderRadius: AppRadii.controlBorder,
          onActivate: sending ? null : onGrab,
          child: ExcludeFocus(
            child: Tooltip(
              message: grabStatus == ArrGrabStatus.failed
                  ? 'Échec — réessayer le téléchargement'
                  : 'Télécharger cette release',
              child: IconButton(
                onPressed: sending ? null : onGrab,
                iconSize: 18,
                visualDensity: VisualDensity.compact,
                icon: sending
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Icon(
                        grabStatus == ArrGrabStatus.failed
                            ? Icons.refresh_rounded
                            : Icons.download_rounded,
                        color: grabStatus == ArrGrabStatus.failed
                            ? AppColors.error
                            : AppColors.textSecondary,
                      ),
              ),
            ),
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final dimmed = release.rejected;
    final baseStyle = Theme.of(context).textTheme.bodySmall?.copyWith(
        color: dimmed
            ? AppColors.textDisabled
            : AppColors.textPrimary.withValues(alpha: 0.9));

    const gap = SizedBox(width: AppSpacing.xs);

    return ColoredBox(
      color: striped ? AppColors.surface : Colors.transparent,
      child: Padding(
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.xs, vertical: AppSpacing.sm),
        child: Row(
          children: [
            SizedBox(
              width: rejectedWidth,
              child: _rejectionIndicator(context),
            ),
            gap,
            SizedBox(
              width: ageWidth,
              child: Text(_ageLabel,
                  textAlign: TextAlign.end,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: baseStyle),
            ),
            gap,
            Expanded(
              child: Tooltip(
                message: release.title,
                child: Text(
                  release.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: baseStyle,
                ),
              ),
            ),
            gap,
            SizedBox(
              width: indexerWidth,
              child: Text(
                release.indexer,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: baseStyle,
              ),
            ),
            gap,
            SizedBox(
              width: sizeWidth,
              child: Text(
                formatFileSize(release.size) ?? '—',
                textAlign: TextAlign.end,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: baseStyle,
              ),
            ),
            gap,
            SizedBox(
              width: seedsWidth,
              child: Text(
                _seedsLabel,
                textAlign: TextAlign.end,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: baseStyle,
              ),
            ),
            gap,
            SizedBox(
              width: qualityWidth,
              child: Text(
                release.qualityName ?? '—',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: baseStyle,
              ),
            ),
            gap,
            SizedBox(
              width: languagesWidth,
              child: Text(
                release.languages.isEmpty ? '—' : release.languages.join(', '),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: baseStyle,
              ),
            ),
            gap,
            SizedBox(
              width: scoreWidth,
              child: Text(
                release.customFormatScore.toString(),
                textAlign: TextAlign.end,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: baseStyle,
              ),
            ),
            gap,
            SizedBox(
              width: actionWidth,
              child: Align(
                alignment: Alignment.centerRight,
                child: _actionButton(context),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
