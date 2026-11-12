import 'package:flutter/material.dart';
import 'package:kinos/models/items/media_streams_model.dart';
import 'package:kinos/screens/details_screens/components/media_stream_selectors.dart';
import 'package:kinos/theme/app_theme.dart';
import 'package:kinos/widgets/shared/frosted_surface.dart';

/// Film and episode reading block and track controls in the cinematic hero.
class MovieHeroContent extends StatelessWidget {
  const MovieHeroContent(
      {required this.summary,
      required this.streams,
      required this.onStreamsChanged,
      this.onSearchSubtitles,
      this.trackMemory,
      this.footer,
      super.key});
  final String summary;
  final MediaStreamsModel streams;
  final ValueChanged<MediaStreamsModel> onStreamsChanged;
  final VoidCallback? onSearchSubtitles;

  /// Rappel facultatif sous les sélecteurs (langues retenues d'une série).
  final Widget? trackMemory;

  /// Sous les pistes, toujours dans le bandeau (ex. notes des amis).
  final Widget? footer;
  @override
  Widget build(BuildContext context) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (summary.isNotEmpty)
            ConstrainedBox(
                constraints: const BoxConstraints(
                    maxWidth: AppDetailLayout.movieSynopsisWidth),
                child: ExpandableSynopsis(summary)),
          if (streams.audioStreams.isNotEmpty ||
              streams.subStreams.isNotEmpty ||
              streams.versionStreams.length > 1) ...[
            const SizedBox(height: AppSpacing.md),
            FrostedSurface(
                borderRadius: AppRadii.controlBorder,
                child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.xs),
                    child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          MediaStreamSelectors(
                              mediaStream: streams,
                              onChanged: onStreamsChanged,
                              onSearchSubtitles: onSearchSubtitles),
                          if (trackMemory case final memory?) memory,
                        ]))),
          ],
          if (footer case final footer?) ...[
            const SizedBox(height: AppSpacing.md),
            footer,
          ],
        ],
      );
}

/// Synopsis replié à [AppDetailLayout.synopsisCollapsedLines] lignes, avec
/// « Voir plus » quand il dépasse ; le dépliage s'anime.
class ExpandableSynopsis extends StatefulWidget {
  const ExpandableSynopsis(this.text, {super.key});
  final String text;

  @override
  State<ExpandableSynopsis> createState() => _ExpandableSynopsisState();
}

class _ExpandableSynopsisState extends State<ExpandableSynopsis> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context)
        .textTheme
        .bodyMedium
        ?.copyWith(color: AppColors.textPrimary);
    return LayoutBuilder(builder: (context, constraints) {
      final painter = TextPainter(
        text: TextSpan(text: widget.text, style: style),
        maxLines: AppDetailLayout.synopsisCollapsedLines,
        textDirection: Directionality.of(context),
        textScaler: MediaQuery.textScalerOf(context),
      )..layout(maxWidth: constraints.maxWidth);
      final overflows = painter.didExceedMaxLines;
      painter.dispose();
      // Points de suspension seulement une fois replié : sans limite de
      // lignes, Flutter tronquerait sinon dès la première ligne.
      final folded = overflows && !_expanded;
      final text = Text(widget.text,
          style: style,
          maxLines: folded ? AppDetailLayout.synopsisCollapsedLines : null,
          overflow: folded ? TextOverflow.ellipsis : null);
      if (!overflows) return text;
      // Jamais d'AnimatedSize à durée nulle : sans mouvement, pas
      // d'animation (cf. AppMotion).
      final animated = AppMotion.enabled(context)
          ? AnimatedSize(
              duration: AppDurations.unroll,
              curve: AppMotion.easeOut,
              alignment: Alignment.topLeft,
              child: text)
          : text;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          animated,
          FocusRing(
            borderRadius: AppRadii.controlBorder,
            onActivate: () => setState(() => _expanded = !_expanded),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxs),
              child: Text(_expanded ? 'Voir moins' : 'Voir plus',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      );
    });
  }
}
