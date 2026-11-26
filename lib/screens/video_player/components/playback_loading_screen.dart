import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:kinos/models/item_base_model.dart';
import 'package:kinos/models/items/episode_model.dart';
import 'package:kinos/models/items/images_models.dart';
import 'package:kinos/theme/app_theme.dart';
import 'package:kinos/util/kinos_image.dart';
import 'package:kinos/util/localization_helper.dart';

/// L'écran de chargement d'un film ou d'un épisode, en plein cadre : son
/// image s'ouvre et avance lentement, son titre (le logo s'il existe) entre
/// en bas à gauche, un trait balaie dessous. Échap ou « Annuler » arrête le
/// chargement.
///
/// Sans titre (file de lecture), seuls le trait et l'annulation restent.
Future<void> showPlaybackLoadingScreen(BuildContext context,
    {required ItemBaseModel? item, required VoidCallback onCancel}) {
  final motion = AppMotion.enabled(context);
  return showGeneralDialog<void>(
    context: context,
    useRootNavigator: true,
    barrierDismissible: false,
    barrierColor: AppColors.background,
    transitionDuration: motion ? AppDurations.pageTransition : Duration.zero,
    transitionBuilder: (context, animation, _, child) => FadeTransition(
        opacity: CurvedAnimation(parent: animation, curve: AppMotion.easeOut),
        child: child),
    pageBuilder: (context, _, __) =>
        PlaybackLoadingScreen(item: item, onCancel: onCancel),
  );
}

class PlaybackLoadingScreen extends StatefulWidget {
  const PlaybackLoadingScreen(
      {required this.item, required this.onCancel, super.key});
  final ItemBaseModel? item;
  final VoidCallback onCancel;

  @override
  State<PlaybackLoadingScreen> createState() => _PlaybackLoadingScreenState();
}

class _PlaybackLoadingScreenState extends State<PlaybackLoadingScreen>
    with TickerProviderStateMixin {
  late final _entrance =
      AnimationController(vsync: this, duration: AppPlaybackLoading.entrance);
  late final _drift =
      AnimationController(vsync: this, duration: AppPlaybackLoading.drift);
  late final _sweep =
      AnimationController(vsync: this, duration: AppPlaybackLoading.sweep);

  /// Choisie une fois : les accesseurs d'image tirent au sort.
  late final ImageData? _backdrop = _imageOf(widget.item);
  late final ImageData? _logo = widget.item?.getPosters?.logo;

  static ImageData? _imageOf(ItemBaseModel? item) {
    final posters = item?.getPosters;
    return posters?.backDrop?.firstOrNull ??
        item?.images?.primary ??
        posters?.primary;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_entrance.isAnimating || _entrance.value > 0) return;
    if (AppMotion.enabled(context)) {
      _entrance.forward();
      _drift.forward();
      _sweep.repeat();
    } else {
      _entrance.value = 1;
      _sweep.value = .5;
    }
  }

  @override
  void dispose() {
    _entrance.dispose();
    _drift.dispose();
    _sweep.dispose();
    super.dispose();
  }

  /// Une étape de l'entrée, de [begin] à [end] (fractions de l'entrée).
  Animation<double> _step(double begin, double end) => CurvedAnimation(
      parent: _entrance, curve: Interval(begin, end, curve: AppMotion.easeOut));

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final size = MediaQuery.sizeOf(context);
    return Focus(
      autofocus: true,
      onKeyEvent: (_, event) {
        if (event is KeyDownEvent &&
            (event.logicalKey == LogicalKeyboardKey.escape ||
                event.logicalKey == LogicalKeyboardKey.goBack)) {
          widget.onCancel();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: Material(
        color: AppColors.background,
        child: Stack(fit: StackFit.expand, children: [
          if (_backdrop != null)
            FadeTransition(
              opacity: _step(0, .7),
              child: ScaleTransition(
                scale: Tween(begin: 1.0, end: AppPlaybackLoading.driftScale)
                    .animate(CurvedAnimation(
                        parent: _drift, curve: Curves.easeOutSine)),
                child: KinosImage(
                    image: _backdrop,
                    fit: BoxFit.cover,
                    disableBlur: true,
                    decodeHeight: size.height.round()),
              ),
            ),
          // Le voile : uniforme pour l'ambiance, plus dense en bas et à
          // gauche, là où vit le texte.
          ColoredBox(
              color: AppColors.scrim
                  .withValues(alpha: AppPlaybackLoading.scrim * .45)),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
                stops: const [0, .6],
                colors: [
                  AppColors.scrim.withValues(alpha: AppPlaybackLoading.scrim),
                  AppColors.scrim.withValues(alpha: 0),
                ],
              ),
            ),
          ),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                stops: const [0, .55],
                colors: [
                  AppColors.scrim
                      .withValues(alpha: AppPlaybackLoading.scrim * .7),
                  AppColors.scrim.withValues(alpha: 0),
                ],
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(
                AppSpacing.screenPadding + AppSpacing.lg,
                AppSpacing.xxl,
                AppSpacing.screenPadding + AppSpacing.lg,
                AppSpacing.xxl + MediaQuery.paddingOf(context).bottom),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: Align(
                    alignment: Alignment.bottomLeft,
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                          maxWidth: size.width * AppPlaybackLoading.textWidth),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (item != null) ...[
                            _Rise(
                                animation: _step(.15, .65),
                                child: _overline(context, item)),
                            const SizedBox(height: AppSpacing.sm),
                            _Rise(
                                animation: _step(.25, .8),
                                child: _title(context, item)),
                            if (_subtitle(context, item) case final line?) ...[
                              const SizedBox(height: AppSpacing.sm),
                              _Rise(
                                animation: _step(.4, .95),
                                child: Text(line,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleMedium
                                        ?.copyWith(
                                            color: AppColors.textPrimary
                                                .withValues(alpha: .75))),
                              ),
                            ],
                            const SizedBox(height: AppSpacing.lg),
                          ],
                          FadeTransition(
                            opacity: _step(.5, 1),
                            child: AnimatedBuilder(
                              animation: _sweep,
                              builder: (context, _) => CustomPaint(
                                size: const Size(AppPlaybackLoading.lineWidth,
                                    AppPlaybackLoading.lineHeight),
                                painter: _SweepPainter(
                                    Curves.easeInOut.transform(_sweep.value)),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                FadeTransition(
                  opacity: _step(.5, 1),
                  child: FocusRing(
                    borderRadius: AppRadii.controlBorder,
                    onActivate: widget.onCancel,
                    child: ExcludeFocus(
                      child: TextButton(
                        onPressed: widget.onCancel,
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          const _KeyCap(label: 'Échap'),
                          const SizedBox(width: AppSpacing.xs),
                          Text(context.localized.cancel,
                              style: const TextStyle(
                                  color: AppColors.textPrimary)),
                        ]),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ]),
      ),
    );
  }

  Widget _overline(BuildContext context, ItemBaseModel item) => Text(
        context.localized.loading.toUpperCase(),
        style: AppTypography.overline
            .copyWith(color: AppColors.textPrimary.withValues(alpha: .75)),
      );

  Widget _title(BuildContext context, ItemBaseModel item) {
    final text = Text(item.title,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: AppTypography.heroEditorial
            .copyWith(fontSize: AppPlaybackLoading.titleSize));
    final logo = _logo;
    if (logo == null) return text;
    return ConstrainedBox(
      constraints: BoxConstraints(
          maxHeight: AppPlaybackLoading.logoHeight,
          maxWidth: MediaQuery.sizeOf(context).width * .4),
      child: KinosImage(
        image: logo,
        fit: BoxFit.contain,
        alignment: Alignment.bottomLeft,
        disableBlur: true,
        imageErrorBuilder: (_, __, ___) => text,
      ),
    );
  }

  String? _subtitle(BuildContext context, ItemBaseModel item) => switch (item) {
        EpisodeModel episode =>
          '${episode.seasonEpisodeLabel(context.localized)} · ${episode.name}',
        _ => item.subText,
      };
}

/// Monte et apparaît avec [animation].
class _Rise extends StatelessWidget {
  const _Rise({required this.animation, required this.child});
  final Animation<double> animation;
  final Widget child;

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: animation,
        child: child,
        builder: (context, child) => Opacity(
          opacity: animation.value,
          child: Transform.translate(
            offset: Offset(0, AppPlaybackLoading.rise * (1 - animation.value)),
            child: child,
          ),
        ),
      );
}

/// La touche d'un raccourci, affichée dans l'interface.
class _KeyCap extends StatelessWidget {
  const _KeyCap({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) => DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: AppRadii.controlBorder,
          border:
              Border.all(color: AppColors.textPrimary.withValues(alpha: .35)),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.xs, vertical: AppSpacing.xxs / 2),
          child: Text(label,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: AppColors.textPrimary.withValues(alpha: .75))),
        ),
      );
}

/// Un fil discret, et un segment qui le parcourt.
class _SweepPainter extends CustomPainter {
  const _SweepPainter(this.progress);
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRect(
        rect, Paint()..color = AppColors.textPrimary.withValues(alpha: .18));
    const segment = AppPlaybackLoading.segment;
    final left = -segment + (size.width + segment) * progress;
    canvas.save();
    canvas.clipRect(rect);
    canvas.drawRect(Rect.fromLTWH(left, 0, segment, size.height),
        Paint()..color = AppColors.textPrimary);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_SweepPainter oldDelegate) =>
      oldDelegate.progress != progress;
}
