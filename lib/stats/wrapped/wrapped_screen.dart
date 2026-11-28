import 'dart:async';
import 'dart:io';

import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:kinos/providers/user_provider.dart';
import 'package:kinos/ratings/kinos_ratings.dart';
import 'package:kinos/theme/app_theme.dart';
import 'package:kinos/widgets/shared/frosted_surface.dart';

import 'wrapped_audio.dart';
import 'wrapped_export.dart';
import 'wrapped_media.dart';
import 'wrapped_motion.dart';
import 'wrapped_providers.dart';
import 'wrapped_slides.dart';

/// Le Wrapped de [year] s'ouvre à tout moment pour une année passée, et à
/// partir du 1er décembre pour l'année en cours. `KINOS_WRAPPED_ANYTIME=1`
/// l'ouvre quand même (mise au point).
bool wrappedAvailable(int year, {DateTime? now}) {
  final today = now ?? DateTime.now();
  if (year < today.year || today.month == 12) return true;
  return year == today.year &&
      Platform.environment['KINOS_WRAPPED_ANYTIME'] == '1';
}

/// Le Wrapped d'une année, en plein écran. Chaque diapo joue son
/// mouvement puis reste à l'écran le temps qu'on la lise : les flèches
/// passent ou reviennent, Espace lance ou coupe la lecture automatique,
/// Échap referme.
@RoutePage()
class YearWrappedScreen extends ConsumerStatefulWidget {
  const YearWrappedScreen({@PathParam('year') required this.year, super.key});
  final int year;

  @override
  ConsumerState<YearWrappedScreen> createState() => _YearWrappedScreenState();
}

class _YearWrappedScreenState extends ConsumerState<YearWrappedScreen> {
  String? _current;

  /// Lecture automatique : chaque diapo passe à la suivante à sa fin.
  bool _auto = false;

  /// Le panneau d'export est ouvert (E, ou le bouton en haut à droite).
  bool _exporting = false;

  /// La diapo qu'on vient de quitter en avançant, et l'avancée de son
  /// horloge : cf. [WrappedEntry].
  String? _from;
  double _fromProgress = 0;
  bool _hint = true;
  Timer? _hintTimer;
  final _progress = ValueNotifier<double>(0);
  final _focus = FocusNode(debugLabel: 'wrapped');

  /// La musique : une ambiance par acte, le thème du film de l'année.
  final _audio = WrappedAudio.create();
  bool _warmed = false;

  /// Toutes les affiches de l'année, chargées pendant l'ouverture : la
  /// frise défile ensuite sans case vide ni à-coup de décodage.
  Future<void> _warm(Map<String, WrappedArt> art) async {
    for (final a in art.values) {
      if (!mounted) return;
      if (a.poster case final poster?) {
        await precacheImage(poster.imageProvider, context, onError: (_, __) {});
      }
    }
  }

  @override
  void initState() {
    super.initState();
    _showHint();
    // Les adresses Letterboxd manquantes, pour comparer vos notes à celles
    // de vos amis : en arrière-plan, la diapo arrive quand elles sont là.
    unawaited(resolveWrappedSlugs(ref, widget.year).then((found) {
      if (found > 0 && mounted) {
        ref.invalidate(wrappedDataProvider(widget.year));
      }
    }).catchError((Object _) {}));
  }

  @override
  void dispose() {
    unawaited(_audio?.dispose());
    _hintTimer?.cancel();
    _progress.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _showHint() {
    _hintTimer?.cancel();
    if (!_hint) setState(() => _hint = true);
    _hintTimer = Timer(AppWrapped.hintDelay, () {
      if (mounted) setState(() => _hint = false);
    });
  }

  void _go(List<WrappedSlide> slides, int delta) {
    final index = slides.indexWhere((s) => s.id == _current);
    final next = (index < 0 ? 0 : index) + delta;
    if (next >= slides.length) {
      // Le récap reste à l'écran : on ne boucle pas.
      setState(() => _auto = false);
      return;
    }
    final leaving = slides[index < 0 ? 0 : index].id;
    final progress = _progress.value;
    setState(() {
      _from = delta > 0 ? leaving : null;
      _fromProgress = progress;
      _current = slides[next.clamp(0, slides.length - 1)].id;
      _progress.value = 0;
    });
  }

  void _toggleSound() {
    final on = !ref.read(wrappedSoundProvider);
    setWrappedSound(ref, on);
    _audio?.mute(!on);
  }

  void _openExport() => setState(() {
        _exporting = true;
        _auto = false;
      });

  void _closeExport() {
    setState(() => _exporting = false);
    _focus.requestFocus();
  }

  void _toggleAuto(List<WrappedSlide> slides) {
    setState(() => _auto = !_auto);
    // Une diapo déjà finie passe tout de suite à la suivante.
    if (_auto && _progress.value >= 1) _go(slides, 1);
  }

  KeyEventResult _onKey(List<WrappedSlide> slides, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    _showHint();
    final key = event.logicalKey;
    if (_exporting) {
      // Le panneau garde le clavier ; Échap le referme.
      if (key != LogicalKeyboardKey.escape) return KeyEventResult.ignored;
      _closeExport();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.keyE) {
      _openExport();
    } else if (key == LogicalKeyboardKey.arrowRight ||
        key == LogicalKeyboardKey.enter) {
      _go(slides, 1);
    } else if (key == LogicalKeyboardKey.arrowLeft) {
      _go(slides, -1);
    } else if (key == LogicalKeyboardKey.space) {
      _toggleAuto(slides);
    } else if (key == LogicalKeyboardKey.keyM) {
      _toggleSound();
    } else if (key == LogicalKeyboardKey.escape) {
      context.router.maybePop();
    } else {
      return KeyEventResult.ignored;
    }
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    final data = ref.watch(wrappedDataProvider(widget.year));
    final art = ref.watch(wrappedArtProvider(widget.year));
    final tints =
        ref.watch(wrappedTintsProvider(widget.year)).valueOrNull ?? const {};
    final ratings = ref.watch(kinosRatingsProvider);
    final shows = ref.watch(wrappedShowsProvider(widget.year)).valueOrNull;
    final returning =
        ref.watch(wrappedReturningProvider(widget.year)).valueOrNull ??
            const <WrappedReturning>[];
    final nextYear =
        ref.watch(wrappedNextYearProvider(widget.year)).valueOrNull ??
            const <WrappedPick>[];
    final text = Theme.of(context).textTheme;

    Widget message(String label) => Center(
        child: Text(label,
            style: text.bodyMedium?.copyWith(color: AppColors.textSecondary)));

    final ready = data.valueOrNull != null && art.valueOrNull != null;
    if (ready && !_warmed) {
      _warmed = true;
      WidgetsBinding.instance
          .addPostFrameCallback((_) => unawaited(_warm(art.value!)));
    }
    final inputs = !ready
        ? null
        : WrappedInputs(
            data: data.value!,
            art: art.value!,
            tints: tints,
            ratings: ratings,
            finished: shows?.finished ?? const [],
            abandoned: shows?.abandoned ?? const [],
            anime: shows?.anime ?? const {},
            returning: returning,
            nextYear: nextYear);
    final slides =
        inputs == null ? const <WrappedSlide>[] : buildWrappedSlides(inputs);
    final index = slides.indexWhere((s) => s.id == _current);
    final current = slides.isEmpty ? null : slides[index < 0 ? 0 : index];

    // La musique de la diapo : l'ambiance de son acte, ou le thème du film
    // de l'année pour la clôture.
    final sound = ref.watch(wrappedSoundProvider);
    final best = data.valueOrNull?.filmOfYear?.event.jellyfinId;
    final theme = best == null
        ? null
        : ref.watch(wrappedThemeSongProvider(best)).valueOrNull;
    if (current != null && inputs != null) {
      final closing = current.id == 'film-of-year' || current.id == 'recap';
      final source = closing && theme != null
          ? theme
          : wrappedMoodAsset(inputs.data.moods[wrappedActOf(current.id)]);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _audio?.mute(!sound);
        unawaited(_audio?.play(source));
      });
    }
    final motion = AppMotion.enabled(context);

    return Scaffold(
      backgroundColor: AppColors.scrim,
      body: Focus(
        focusNode: _focus,
        autofocus: true,
        onKeyEvent: (_, event) => _onKey(slides, event),
        child: MouseRegion(
          onHover: (_) => _showHint(),
          child: data.hasError || art.hasError
              ? message('Impossible de préparer votre année.')
              : current == null
                  ? message(ready
                      ? 'Rien à raconter sur ${widget.year}.'
                      : 'Préparation de votre année ${widget.year}…')
                  : Stack(fit: StackFit.expand, children: [
                      GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTapUp: (details) {
                          final width = context.size?.width ?? 1;
                          _go(slides,
                              details.localPosition.dx < width / 3 ? -1 : 1);
                        },
                        child: AnimatedSwitcher(
                          // Le récap prolonge le film de l'année : même
                          // image, sans fondu.
                          duration: motion &&
                                  !(current.id == 'recap' &&
                                      _from == 'film-of-year')
                              ? AppWrapped.fade
                              : Duration.zero,
                          child: _SlideHost(
                            key: ValueKey(current.id),
                            slide: current,
                            motion: motion,
                            from: _from,
                            fromProgress: _fromProgress,
                            // L'ancienne diapo, encore là pendant le fondu,
                            // ne pilote plus rien.
                            onTick: (value) {
                              if (current.id == (_current ?? slides.first.id)) {
                                _progress.value = value;
                              }
                            },
                            onDone: () {
                              if (_auto &&
                                  current.id == (_current ?? slides.first.id)) {
                                _go(slides, 1);
                              }
                            },
                          ),
                        ),
                      ),
                      _Progress(
                          slides: slides,
                          current: slides.indexOf(current),
                          progress: _progress),
                      _Controls(
                        visible: _hint && !_exporting,
                        sound: sound,
                        onSound: _toggleSound,
                        onExport: _openExport,
                        auto: _auto,
                        onAuto: () => _toggleAuto(slides),
                        onClose: () => context.router.maybePop(),
                      ),
                      if (_exporting && inputs != null)
                        _ExportPanel(
                            inputs: inputs,
                            slides: slides,
                            onClose: _closeExport),
                    ]),
        ),
      ),
    );
  }
}

/// Une diapo à l'écran : sa propre horloge, qui avance jusqu'à sa durée
/// puis passe la main.
class _SlideHost extends StatefulWidget {
  const _SlideHost(
      {required this.slide,
      required this.motion,
      required this.from,
      required this.fromProgress,
      required this.onTick,
      required this.onDone,
      super.key});
  final WrappedSlide slide;
  final bool motion;
  final String? from;
  final double fromProgress;
  final ValueChanged<double> onTick;
  final VoidCallback onDone;

  @override
  State<_SlideHost> createState() => _SlideHostState();
}

class _SlideHostState extends State<_SlideHost>
    with SingleTickerProviderStateMixin {
  late final _clock = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: (widget.slide.seconds * 1000).round()))
    ..addListener(_tick)
    ..addStatusListener((status) {
      if (status == AnimationStatus.completed && mounted) widget.onDone();
    });
  void _tick() => widget.onTick(_clock.value);

  @override
  void initState() {
    super.initState();
    _clock.forward();
  }

  @override
  void dispose() {
    _clock.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => WrappedClock(
        duration: widget.slide.seconds,
        motion: widget.motion,
        progress: _clock,
        child: WrappedEntry(
            from: widget.from,
            progress: widget.fromProgress,
            child: Builder(builder: widget.slide.builder)),
      );
}

/// Une fine barre par diapo, en haut : passées pleines, la courante qui se
/// remplit.
class _Progress extends StatelessWidget {
  const _Progress(
      {required this.slides, required this.current, required this.progress});
  final List<WrappedSlide> slides;
  final int current;
  final ValueNotifier<double> progress;

  @override
  Widget build(BuildContext context) => Positioned(
        left: AppSpacing.screenPadding,
        right: AppSpacing.screenPadding,
        top: MediaQuery.paddingOf(context).top + AppSpacing.sm,
        child: IgnorePointer(
          child: Row(children: [
            for (var i = 0; i < slides.length; i++) ...[
              if (i > 0) const SizedBox(width: AppSpacing.xxs),
              Expanded(
                child: SizedBox(
                  height: AppWrapped.progressHeight,
                  child: ValueListenableBuilder<double>(
                    valueListenable: progress,
                    builder: (context, value, _) => LinearProgressIndicator(
                      value: i < current
                          ? 1
                          : i > current
                              ? 0
                              : value,
                      backgroundColor:
                          AppColors.textPrimary.withValues(alpha: .2),
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
              ),
            ],
          ]),
        ),
      );
}

/// Lecture automatique et fermeture en haut à droite, et les raccourcis en bas : visibles
/// au mouvement de la souris ou à une touche, puis ils s'effacent.
class _Controls extends StatelessWidget {
  const _Controls(
      {required this.visible,
      required this.auto,
      required this.onAuto,
      required this.onExport,
      required this.sound,
      required this.onSound,
      required this.onClose});
  final bool visible;
  final bool sound;
  final VoidCallback onSound;
  final VoidCallback onExport;
  final bool auto;
  final VoidCallback onAuto;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    final hint = AppTypography.meta
        .copyWith(color: AppColors.textPrimary.withValues(alpha: .75));
    Widget button(IconData icon, String label, VoidCallback onTap) => Tooltip(
          message: label,
          child: FocusRing(
            borderRadius: AppRadii.controlBorder,
            onActivate: onTap,
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.xs),
              child: Icon(icon,
                  color: AppColors.textPrimary, semanticLabel: label),
            ),
          ),
        );
    return AnimatedOpacity(
      opacity: visible ? 1 : 0,
      duration: AppDurations.hover,
      child: Stack(children: [
        Positioned(
          top: top + AppSpacing.md,
          right: AppSpacing.screenPadding,
          child: Row(children: [
            button(
                auto ? Icons.pause_rounded : Icons.play_arrow_rounded,
                auto
                    ? 'Arrêter la lecture automatique (Espace)'
                    : 'Lecture automatique (Espace)',
                onAuto),
            button(sound ? Icons.volume_up_rounded : Icons.volume_off_rounded,
                sound ? 'Couper le son (M)' : 'Remettre le son (M)', onSound),
            button(Icons.ios_share_rounded, 'Exporter (E)', onExport),
            button(Icons.close_rounded, 'Fermer (Échap)', onClose),
          ]),
        ),
        Positioned(
          right: AppSpacing.screenPadding,
          bottom: AppSpacing.lg,
          child: IgnorePointer(
            child: Text(
                '← →  naviguer   ·   Espace  lecture auto   ·   M  son   ·   E  exporter   ·   Échap  quitter',
                style: hint),
          ),
        ),
      ]),
    );
  }
}

/// Le panneau d'export, en verre dépoli au-dessus du Wrapped : quelles
/// pages (le récap de l'année, ceux des actes, toutes les diapos), quels
/// formats (story, écran), le nom ou non, puis les PNG dans le dossier
/// d'images. Tout se règle au clavier ; Échap le referme.
class _ExportPanel extends ConsumerStatefulWidget {
  const _ExportPanel(
      {required this.inputs, required this.slides, required this.onClose});
  final WrappedInputs inputs;
  final List<WrappedSlide> slides;
  final VoidCallback onClose;

  @override
  ConsumerState<_ExportPanel> createState() => _ExportPanelState();
}

class _ExportPanelState extends ConsumerState<_ExportPanel> {
  bool _year = true;
  bool _acts = true;
  bool _slides = false;
  final _formats = {WrappedFormat.story};
  bool _name = false;
  (int, int)? _progress;
  Directory? _done;
  String? _error;

  List<WrappedPage> _pages() => wrappedExportPages(
      widget.inputs.withName(_name ? ref.read(userProvider)?.name : null),
      widget.slides,
      year: _year,
      acts: _acts,
      allSlides: _slides);

  Future<void> _export() async {
    final pages = _pages();
    if (wrappedExportCount(pages, _formats) == 0) return;
    setState(() {
      _progress = (0, wrappedExportCount(pages, _formats));
      _done = null;
      _error = null;
    });
    try {
      final dir = await wrappedExportDirectory(widget.inputs.data.year);
      if (!mounted) return;
      await exportWrapped(context,
          dir: dir,
          pages: pages,
          formats: _formats,
          warm: [
            for (final a in widget.inputs.art.values)
              if (a.poster case final poster?) poster.imageProvider,
          ], onProgress: (done, total) {
        if (mounted) setState(() => _progress = (done, total));
      });
      if (mounted) setState(() => _done = dir);
    } catch (error) {
      if (mounted) setState(() => _error = '$error');
    } finally {
      if (mounted) setState(() => _progress = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final busy = _progress != null;
    final count = wrappedExportCount(_pages(), _formats);
    Widget check(String label, bool value, ValueChanged<bool> onChanged,
            {bool autofocus = false}) =>
        CheckboxListTile(
          autofocus: autofocus,
          dense: true,
          contentPadding: EdgeInsets.zero,
          controlAffinity: ListTileControlAffinity.leading,
          title: Text(label),
          value: value,
          onChanged: busy ? null : (v) => setState(() => onChanged(v ?? false)),
        );
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: AppWrapped.exportWidth),
        child: FrostedSurface(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: FocusTraversalGroup(
              child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Exporter votre Wrapped', style: text.titleLarge),
                    const SizedBox(height: AppSpacing.md),
                    Text('Pages',
                        style: text.labelMedium
                            ?.copyWith(color: AppColors.textSecondary)),
                    check('Le récap de l\'année', _year, (v) => _year = v,
                        autofocus: true),
                    check('Un récap par acte (le temps, les goûts, les films)',
                        _acts, (v) => _acts = v),
                    check('Toutes les diapos', _slides, (v) => _slides = v),
                    const SizedBox(height: AppSpacing.sm),
                    Text('Formats',
                        style: text.labelMedium
                            ?.copyWith(color: AppColors.textSecondary)),
                    check(
                        'Story (9:16)',
                        _formats.contains(WrappedFormat.story),
                        (v) => v
                            ? _formats.add(WrappedFormat.story)
                            : _formats.remove(WrappedFormat.story)),
                    check(
                        'Écran (16:9), comme les diapos',
                        _formats.contains(WrappedFormat.screen),
                        (v) => v
                            ? _formats.add(WrappedFormat.screen)
                            : _formats.remove(WrappedFormat.screen)),
                    check(
                        'Écran (16:9), comme les stories (récaps seulement)',
                        _formats.contains(WrappedFormat.screenStory),
                        (v) => v
                            ? _formats.add(WrappedFormat.screenStory)
                            : _formats.remove(WrappedFormat.screenStory)),
                    const SizedBox(height: AppSpacing.sm),
                    check('Afficher mon nom', _name, (v) => _name = v),
                    const SizedBox(height: AppSpacing.md),
                    if (_progress case (final done, final total))
                      Text(
                          'Image ${done + 1 > total ? total : done + 1} sur $total…',
                          style: text.bodyMedium)
                    else if (_done case final dir?)
                      Text('Enregistré dans ${dir.path}',
                          style: text.bodyMedium
                              ?.copyWith(color: AppColors.textSecondary))
                    else if (_error case final error?)
                      Text('L\'export a échoué : $error',
                          style: text.bodyMedium),
                    const SizedBox(height: AppSpacing.sm),
                    Wrap(
                        spacing: AppSpacing.xs,
                        runSpacing: AppSpacing.xs,
                        children: [
                          FilledButton(
                              onPressed: busy || count == 0 ? null : _export,
                              child: Text(count == 0
                                  ? 'Rien à exporter'
                                  : 'Exporter ($count ${count > 1 ? 'images' : 'image'})')),
                          if (_done case final dir?)
                            OutlinedButton(
                                onPressed: () => openWrappedDirectory(dir),
                                child: const Text('Ouvrir le dossier')),
                          TextButton(
                              onPressed: busy ? null : widget.onClose,
                              child: const Text('Fermer (Échap)')),
                        ]),
                  ]),
            ),
          ),
        ),
      ),
    );
  }
}
