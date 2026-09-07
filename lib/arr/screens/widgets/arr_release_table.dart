import 'package:flutter/material.dart';

import 'package:fladder/arr/models/arr_grab_status.dart';
import 'package:fladder/arr/models/arr_release.dart';
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
/// pas de pastilles ni de badges arrondis. Une ligne = une release ;
/// cliquer dessus l'envoie au téléchargement (cf. [onGrab]).
///
/// Largeurs de colonnes fixes (hors Titre, seule colonne extensible) :
/// une table de données n'a pas d'échelle d'espacement à suivre comme un
/// padding ou un rayon, ces valeurs sont documentées ici plutôt que
/// reprises d'un jeton [AppSpacing].
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

  static const _rejectedWidth = 28.0;
  static const _ageWidth = 56.0;
  static const _indexerWidth = 128.0;
  static const _sizeWidth = 84.0;
  static const _seedsWidth = 96.0;
  static const _qualityWidth = 116.0;
  static const _languagesWidth = 116.0;
  static const _scoreWidth = 64.0;

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

  List<ArrRelease> get _sorted {
    final sorted = [...widget.releases];
    sorted.sort((a, b) {
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
    return sorted;
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

  @override
  Widget build(BuildContext context) {
    final releases = _sorted;
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
        ),
        const Divider(height: 1, thickness: 1, color: AppColors.border),
        for (final release in releases)
          _ArrReleaseRow(
            key: ValueKey('${release.indexerId}:${release.guid}'),
            release: release,
            grabStatus: widget.grabStatuses[release.guid] ?? ArrGrabStatus.idle,
            onGrab: () => widget.onGrab(release),
            rejectedWidth: _rejectedWidth,
            ageWidth: _ageWidth,
            indexerWidth: _indexerWidth,
            sizeWidth: _sizeWidth,
            seedsWidth: _seedsWidth,
            qualityWidth: _qualityWidth,
            languagesWidth: _languagesWidth,
            scoreWidth: _scoreWidth,
          ),
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
                  if (selected) ...[
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
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
      child: Row(
        children: [
          SizedBox(width: rejectedWidth),
          _header(context, 'Âge', ageWidth, _ArrReleaseColumn.age),
          Expanded(
              child: _header(context, 'Release', double.infinity,
                  _ArrReleaseColumn.title)),
          _header(context, 'Indexeur', indexerWidth, _ArrReleaseColumn.indexer),
          _header(context, 'Taille', sizeWidth, _ArrReleaseColumn.size,
              align: TextAlign.end),
          _header(context, 'Seeds/Peers', seedsWidth, _ArrReleaseColumn.seeds,
              align: TextAlign.end),
          _header(context, 'Qualité', qualityWidth, _ArrReleaseColumn.quality),
          _header(
              context, 'Langues', languagesWidth, _ArrReleaseColumn.languages),
          _header(context, 'Score', scoreWidth, _ArrReleaseColumn.score,
              align: TextAlign.end),
        ],
      ),
    );
  }
}

class _ArrReleaseRow extends StatelessWidget {
  final ArrRelease release;
  final ArrGrabStatus grabStatus;
  final VoidCallback onGrab;
  final double rejectedWidth;
  final double ageWidth;
  final double indexerWidth;
  final double sizeWidth;
  final double seedsWidth;
  final double qualityWidth;
  final double languagesWidth;
  final double scoreWidth;

  const _ArrReleaseRow({
    required this.release,
    required this.grabStatus,
    required this.onGrab,
    required this.rejectedWidth,
    required this.ageWidth,
    required this.indexerWidth,
    required this.sizeWidth,
    required this.seedsWidth,
    required this.qualityWidth,
    required this.languagesWidth,
    required this.scoreWidth,
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
    return Tooltip(
      message: release.rejections.isEmpty
          ? 'Rejetée'
          : release.rejections.join('\n'),
      child: const Icon(Icons.report_gmailerrorred_rounded,
          size: 16, color: AppColors.error),
    );
  }

  Widget _grabIndicator(BuildContext context) {
    switch (grabStatus) {
      case ArrGrabStatus.idle:
        return const SizedBox.shrink();
      case ArrGrabStatus.sending:
        return const SizedBox(
          width: 14,
          height: 14,
          child: CircularProgressIndicator(strokeWidth: 2),
        );
      case ArrGrabStatus.success:
        return const Icon(Icons.check_circle_rounded,
            size: 16, color: AppColors.success);
      case ArrGrabStatus.failed:
        return const Icon(Icons.error_rounded,
            size: 16, color: AppColors.error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final dimmed = release.rejected;
    final baseStyle = Theme.of(context).textTheme.bodySmall?.copyWith(
        color: dimmed
            ? AppColors.textDisabled
            : AppColors.textPrimary.withValues(alpha: 0.9));

    return FocusRing(
      onActivate: grabStatus == ArrGrabStatus.sending ? null : onGrab,
      child: ExcludeFocus(
        child: InkWell(
          onTap: grabStatus == ArrGrabStatus.sending ? null : onGrab,
          child: Padding(
            padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.xs, vertical: AppSpacing.xs),
            child: Row(
              children: [
                SizedBox(
                  width: rejectedWidth,
                  child: _rejectionIndicator(context),
                ),
                SizedBox(
                  width: ageWidth,
                  child: Text(_ageLabel, style: baseStyle),
                ),
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
                SizedBox(
                  width: indexerWidth,
                  child: Text(
                    release.indexer,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: baseStyle,
                  ),
                ),
                SizedBox(
                  width: sizeWidth,
                  child: Text(
                    formatFileSize(release.size) ?? '—',
                    textAlign: TextAlign.end,
                    style: baseStyle,
                  ),
                ),
                SizedBox(
                  width: seedsWidth,
                  child: Text(
                    _seedsLabel,
                    textAlign: TextAlign.end,
                    style: baseStyle,
                  ),
                ),
                SizedBox(
                  width: qualityWidth,
                  child: Text(
                    release.qualityName ?? '—',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: baseStyle,
                  ),
                ),
                SizedBox(
                  width: languagesWidth,
                  child: Text(
                    release.languages.isEmpty
                        ? '—'
                        : release.languages.join(', '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: baseStyle,
                  ),
                ),
                SizedBox(
                  width: scoreWidth,
                  child: Text(
                    release.customFormatScore.toString(),
                    textAlign: TextAlign.end,
                    style: baseStyle,
                  ),
                ),
                const SizedBox(width: AppSpacing.xs),
                SizedBox(width: 16, child: _grabIndicator(context)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
