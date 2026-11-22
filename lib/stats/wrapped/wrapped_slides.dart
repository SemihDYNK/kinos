import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:kinos/letterboxd/friends/letterboxd_friends_providers.dart'
    show letterboxdFriendsAccountProvider;
import 'package:kinos/letterboxd/friends/letterboxd_friends_store.dart'
    show FriendRating;
import 'package:kinos/models/items/images_models.dart';
import 'package:kinos/ratings/kinos_rating_button.dart' show formatStars;
import 'package:kinos/ratings/kinos_ratings.dart';
import 'package:kinos/theme/app_theme.dart';
import 'package:kinos/upcoming/upcoming_models.dart' show tmdbImage;
import 'package:kinos/util/kinos_image.dart';

import '../stats_screen.dart'
    show formatHours, statsDataColor, statsPersonProvider;
import '../viewing_log.dart';
import 'wrapped_data.dart';
import 'wrapped_media.dart';
import 'wrapped_motion.dart';
import 'wrapped_quotes.dart';

/// Une diapo : son identifiant (stable d'un calcul à l'autre), sa durée en
/// secondes et son contenu, posé dans une [WrappedClock].
class WrappedSlide {
  const WrappedSlide(
      {required this.id, required this.seconds, required this.builder});
  final String id;
  final double seconds;
  final WidgetBuilder builder;
}

/// Ce que les diapos lisent : les données, les images et les teintes.
class WrappedInputs {
  const WrappedInputs(
      {required this.data,
      required this.art,
      required this.tints,
      required this.ratings});
  final WrappedData data;
  final Map<String, WrappedArt> art;
  final Map<String, Color> tints;
  final Map<String, KinosRating> ratings;

  ImageData? backdrop(ViewingEvent e) => art[e.identity]?.backdrop;
  ImageData? poster(ViewingEvent e) => art[e.identity]?.poster;
  Color tint(ViewingEvent? e) =>
      (e == null ? null : tints[e.identity]) ?? AppColors.heroFallback;

  int? rating(ViewingEvent e) => (ratings[e.identity] ??
          (e.jellyfinId == null ? null : ratings['jellyfin:${e.jellyfinId}']))
      ?.value;
}

const _locale = 'fr';
const _numberWords = {
  1: 'un',
  2: 'deux',
  3: 'trois',
  4: 'quatre',
  5: 'cinq',
  6: 'six',
  7: 'sept',
  8: 'huit',
  9: 'neuf',
  10: 'dix',
};

/// « 1½ », « 4 » : une note sur 10 en étoiles chiffrées.
String _starsNumber(int value) =>
    value.isOdd ? '${value ~/ 2}½' : '${value ~/ 2}';

/// « 4,1 » : une note du public sur 10, ramenée sur 5.
String _publicNumber(double value) =>
    NumberFormat('0.0', _locale).format(value / 2);

/// « 1 étoile », « 3½ étoiles », « 4,1 étoiles ».
String _starsWord(double stars) => stars >= 2 ? 'étoiles' : 'étoile';

String _films(int n) => '$n ${n > 1 ? 'films' : 'film'}';

/// « soit six jours et demi », vide sous une journée.
String _daysPhrase(int seconds) {
  final days = seconds / 86400;
  if (days < 1) return '';
  final whole = days.floor();
  final word = _numberWords[whole] ?? '$whole';
  final half = days - whole >= .5 ? ' et demi' : '';
  return ', soit $word ${whole > 1 ? 'jours' : 'jour'}$half';
}

String _list(List<String> names) => names.length <= 1
    ? names.join()
    : '${names.sublist(0, names.length - 1).join(', ')} et ${names.last}';

/// Les diapos de l'année, dans l'ordre des trois actes. Une diapo sans
/// matière n'existe pas.
List<WrappedSlide> buildWrappedSlides(WrappedInputs w) {
  final data = w.data;
  final stats = data.stats;
  final films = {for (final e in data.timeline) e.identity: e}.values.toList();
  final genreTop = [...data.genreFilms]
    ..sort((a, b) => (w.rating(b) ?? 0).compareTo(w.rating(a) ?? 0));
  final filmOfYear = data.filmOfYear?.event;

  // Une image de film ne sert qu'une fois : les films qui ont leur propre
  // diapo (film de l'année, hot takes, amis, plus vieux voyage) sont
  // réservés, puis chaque diapo prend, dans l'ordre, des films pas encore
  // montrés. Faute de mieux, elle reprend un film déjà vu plutôt qu'un
  // fond vide.
  final used = <String>{
    if (filmOfYear != null) filmOfYear.identity,
    if (data.publicLoves case final t?) t.film.identity,
    if (data.youLove case final t?) t.film.identity,
    if ((data.friendsDisagree ?? data.friendsAgree) case final t?)
      t.film.identity,
    if (data.voyage.lastOrNull case final e?) e.identity,
  };
  List<ImageData> fresh(Iterable<ViewingEvent> candidates, {int take = 6}) {
    final picked = <ViewingEvent>[];
    for (final e in candidates) {
      if (picked.length >= take) break;
      if (used.contains(e.identity) || w.backdrop(e) == null) continue;
      if (picked.any((p) => p.identity == e.identity)) continue;
      picked.add(e);
    }
    if (picked.isEmpty) {
      picked.addAll(candidates.where((e) => w.backdrop(e) != null).take(1));
    }
    used.addAll(picked.map((e) => e.identity));
    return [for (final e in picked) w.backdrop(e)!];
  }

  final streak = stats.streak;
  final busy = stats.busiestDay;
  final streakEnd = streak == null
      ? null
      : DateTime(streak.start.year, streak.start.month,
          streak.start.day + streak.days);
  final rhythmImages = fresh(data.timeline.where((e) => streak == null
      ? busy != null && DateUtils.isSameDay(e.at, busy.day)
      : !e.at.isBefore(streak.start) && e.at.isBefore(streakEnd!)));
  final genreImages = fresh(genreTop);
  final directorImages = fresh(data.directorFilms);
  final actorImages = fresh(data.actorFilms);
  final ratingColumns = List.generate(10, (_) => <ViewingEvent>[]);
  for (final e in films) {
    if (w.rating(e) case final r?) ratingColumns[r - 1].add(e);
  }
  // La note la plus donnée : la colonne mise en avant, et son fond.
  var mode = -1;
  for (var i = 0; i < 10; i++) {
    if (ratingColumns[i].isNotEmpty &&
        (mode < 0 || ratingColumns[i].length >= ratingColumns[mode].length)) {
      mode = i;
    }
  }
  final ratingImages =
      mode < 0 ? const <ImageData>[] : fresh(ratingColumns[mode]);
  final agreementImages =
      fresh([for (final r in stats.topRated) r.event], take: 4);

  return [
    WrappedSlide(
        id: 'opening',
        seconds: AppWrapped.opening,
        builder: (_) => _Opening(inputs: w, films: films)),
    WrappedSlide(
        id: 'act1',
        seconds: AppWrapped.act,
        builder: (_) => _ActCard(
            number: 'Acte I',
            title: 'Le temps',
            colors: [
              for (final e in [
                ...data.timeline
                    .where((e) => e.at.month - 1 == stats.busiestBucket),
                ...films,
              ].take(3))
                w.tint(e)
            ],
            focus: const Alignment(-.6, -.4))),
    if (data.timeline.isNotEmpty)
      WrappedSlide(
          id: 'time',
          seconds: AppWrapped.time,
          builder: (_) => _TimeSlide(inputs: w)),
    if (stats.streak != null || stats.busiestDay != null)
      WrappedSlide(
          id: 'rhythm',
          seconds: AppWrapped.rhythm,
          builder: (_) => _RhythmSlide(inputs: w, images: rhythmImages)),
    WrappedSlide(
        id: 'act2',
        seconds: AppWrapped.act,
        builder: (_) => _ActCard(
            number: 'Acte II',
            title: 'Les goûts',
            colors: [for (final e in genreTop.take(3)) w.tint(e)],
            focus: const Alignment(.5, -.3))),
    if (stats.genres.isNotEmpty)
      WrappedSlide(
          id: 'genre',
          seconds: AppWrapped.genre,
          builder: (_) => _GenreSlide(inputs: w, images: genreImages)),
    if (data.series.isNotEmpty)
      WrappedSlide(
          id: 'series',
          seconds: AppWrapped.genre,
          builder: (_) => _SeriesSlide(inputs: w)),
    if (stats.directors.firstOrNull case final director?)
      WrappedSlide(
          id: 'director',
          seconds: AppWrapped.person,
          builder: (_) => _PersonSlide(
              inputs: w,
              label: 'Votre réalisateur',
              name: director.name,
              films: data.directorFilms,
              images: directorImages,
              quoteKey: 'director|${director.name}')),
    if (stats.actors.firstOrNull case final actor?)
      WrappedSlide(
          id: 'actor',
          seconds: AppWrapped.person,
          builder: (_) => _PersonSlide(
              inputs: w,
              label: 'Votre acteur',
              name: actor.name,
              films: data.actorFilms,
              images: actorImages,
              quoteKey: 'actor|${actor.name}|${[
                for (final e in data.actorFilms)
                  if (e.jellyfinId case final id?) id
              ].take(3).join(',')}')),
    if (stats.average != null)
      WrappedSlide(
          id: 'ratings',
          seconds: AppWrapped.ratings,
          builder: (_) => _RatingsSlide(
              inputs: w,
              columns: ratingColumns,
              mode: mode,
              images: ratingImages)),
    if (data.friendsDisagree ?? data.friendsAgree case final take?)
      WrappedSlide(
          id: 'friends',
          seconds: AppWrapped.friends,
          builder: (_) => _FriendsSlide(
              inputs: w, take: take, disagree: data.friendsDisagree != null)),
    if (data.publicLoves case final take?)
      WrappedSlide(
          id: 'public-loves',
          seconds: AppWrapped.hotTake,
          builder: (_) => _HotTakeSlide(inputs: w, take: take, youLove: false)),
    if (data.youLove case final take?)
      WrappedSlide(
          id: 'you-love',
          seconds: AppWrapped.hotTake,
          builder: (_) => _HotTakeSlide(inputs: w, take: take, youLove: true)),
    if (data.publicAgreement case final gap?)
      WrappedSlide(
          id: 'agreement',
          seconds: AppWrapped.hotTake,
          builder: (_) =>
              _AgreementSlide(inputs: w, gap: gap, images: agreementImages)),
    WrappedSlide(
        id: 'act3',
        seconds: AppWrapped.act,
        builder: (_) => _ActCard(
            number: 'Acte III',
            title: 'Les films',
            colors: [
              if (filmOfYear != null) w.tint(filmOfYear),
              for (final r in data.runnersUp.take(2)) w.tint(r.event),
            ],
            focus: const Alignment(0, .4))),
    if (data.voyage.length >= 2)
      WrappedSlide(
          id: 'voyage',
          seconds: AppWrapped.voyage,
          builder: (_) => _VoyageSlide(inputs: w)),
    if (stats.elsewhere > 0)
      WrappedSlide(
          id: 'elsewhere',
          seconds: AppWrapped.elsewhere,
          builder: (_) => _ElsewhereSlide(inputs: w, films: films)),
    if (data.filmOfYear case final best?)
      WrappedSlide(
          id: 'film-of-year',
          seconds: AppWrapped.filmOfYear,
          builder: (_) => _FilmOfYearSlide(
              inputs: w, film: best.event, rating: best.rating)),
    WrappedSlide(
        id: 'recap',
        seconds: AppWrapped.recap,
        builder: (_) => WrappedRecap(inputs: w)),
  ];
}

/// Une diapo pleine : son fond, son voile et son texte, avec les tailles de
/// texte de sa hauteur.
class _Frame extends StatelessWidget {
  const _Frame({required this.builder});
  final List<Widget> Function(BuildContext context, Size size, WrappedType type)
      builder;

  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (context, c) {
        final size = c.biggest;
        return ColoredBox(
          color: AppColors.scrim,
          child: Stack(
              fit: StackFit.expand,
              children: builder(context, size, WrappedType(size))),
        );
      });
}

// ---------------------------------------------------------------------------
// Ouverture et cartons d'acte
// ---------------------------------------------------------------------------

/// Un mur d'affiches incliné qui dérive lentement ; [lit] garde certaines
/// affiches éclairées quand [dim] monte.
class _PosterWall extends StatelessWidget {
  const _PosterWall(
      {required this.inputs, required this.films, this.lit, this.dim = 0});
  final WrappedInputs inputs;
  final List<ViewingEvent> films;
  final Set<String>? lit;
  final double dim;

  @override
  Widget build(BuildContext context) {
    final posters = [
      for (final e in films)
        if (inputs.poster(e) != null) (e, inputs.poster(e)!)
    ];
    if (posters.isEmpty) return const SizedBox();
    final drift = WrappedClock.at(context, 0,
        length: AppWrapped.opening * 3, curve: Curves.linear);
    return LayoutBuilder(builder: (context, c) {
      final width = c.maxWidth * 1.7;
      final posterW = width / AppWrapped.wallColumns;
      final rows = (c.maxHeight * 1.9 / (posterW * 1.5)).ceil();
      var k = 0;
      return ClipRect(
        child: OverflowBox(
          maxWidth: width,
          maxHeight: c.maxHeight * 1.9,
          child: Transform.translate(
            offset: Offset(-c.maxWidth * AppWrapped.wallDrift * drift,
                -c.maxHeight * AppWrapped.wallDrift * drift),
            child: Transform.rotate(
              angle: AppWrapped.wallTilt,
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                for (var r = 0; r < rows; r++)
                  Row(mainAxisSize: MainAxisSize.min, children: [
                    for (var col = 0; col < AppWrapped.wallColumns; col++)
                      Builder(builder: (context) {
                        final (event, image) =
                            posters[(k++ * 7) % posters.length];
                        final on = lit == null || lit!.contains(event.identity);
                        return Padding(
                          padding: const EdgeInsets.all(AppSpacing.xxs),
                          child: SizedBox(
                            width: posterW - AppSpacing.xxs * 2,
                            height: (posterW - AppSpacing.xxs * 2) * 1.5,
                            child: Opacity(
                              opacity: on ? 1 : 1 - dim * .8,
                              child: ClipRRect(
                                borderRadius:
                                    BorderRadius.circular(AppSpacing.xxs),
                                child:
                                    KinosImage(image: image, disableBlur: true),
                              ),
                            ),
                          ),
                        );
                      }),
                  ]),
              ]),
            ),
          ),
        ),
      );
    });
  }
}

class _Opening extends StatelessWidget {
  const _Opening({required this.inputs, required this.films});
  final WrappedInputs inputs;
  final List<ViewingEvent> films;

  @override
  Widget build(BuildContext context) => _Frame(
      builder: (context, size, type) => [
            _PosterWall(inputs: inputs, films: films),
            ColoredBox(
                color: AppColors.scrim.withValues(alpha: AppWrapped.wallVeil)),
            const WrappedScrim(veil: .3),
            WrappedTextBlock(children: [
              WrappedText('Kinos présente',
                  style: type.cap, at: .4, caps: true),
              SizedBox(height: size.height * .03),
              WrappedText('Votre année ${inputs.data.year}',
                  style: type.big, at: 1.6),
              if (inputs.data.hook case final hook?) ...[
                SizedBox(height: size.height * .035),
                WrappedText('« ${hook.text} »',
                    style: type.small.copyWith(
                        color: AppColors.textPrimary,
                        fontStyle: FontStyle.italic,
                        fontSize: type.small.fontSize! * 1.25),
                    at: 3.6),
              ],
            ]),
          ]);
}

/// Le carton d'un acte : son numéro et son titre, sur un dégradé léger de
/// la couleur de ce qui suit, qui recule doucement.
/// Le carton d'un acte, en 60-30-10 sur les couleurs de trois de ses
/// films : la teinte du premier en fond (60), celle du deuxième en grande
/// nappe qui dérive (30), celle du troisième pour le numéro de l'acte et
/// un halo discret derrière le titre (10). Le tout recule doucement.
class _ActCard extends StatelessWidget {
  const _ActCard(
      {required this.number,
      required this.title,
      required this.colors,
      required this.focus});
  final String number;
  final String title;

  /// Teintes de trois films de l'acte (les absentes reprennent la
  /// première).
  final List<Color> colors;
  final Alignment focus;

  @override
  Widget build(BuildContext context) {
    final settle = WrappedClock.at(context, 0, length: 6);
    final drift = WrappedClock.at(context, 0,
        length: AppWrapped.act, curve: Curves.easeInOutSine);
    Color pick(int i) => i < colors.length
        ? colors[i]
        : colors.isEmpty
            ? AppColors.heroFallback
            : colors.first;
    final base = pick(0);
    final second = statsDataColor(pick(1));
    final accent = statsDataColor(pick(2));
    return _Frame(builder: (context, size, type) {
      final secondCenter =
          Alignment.lerp(focus, Alignment(focus.x * .6, focus.y * .6), drift)!;
      return [
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [base, Color.lerp(base, AppColors.scrim, .55)!],
            ),
          ),
        ),
        Transform.scale(
          scale: 1.15 - .15 * settle,
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: secondCenter,
                radius: .95,
                colors: [
                  second.withValues(alpha: AppWrapped.actSecondAlpha),
                  second.withValues(alpha: 0),
                ],
              ),
            ),
          ),
        ),
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              radius: .32,
              colors: [
                accent.withValues(alpha: AppWrapped.actAccentAlpha * settle),
                accent.withValues(alpha: 0),
              ],
            ),
          ),
        ),
        Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            WrappedText(number,
                style: type.cap.copyWith(color: accent), at: .6, caps: true),
            SizedBox(height: size.height * .025),
            WrappedText(title, style: type.mid, at: 1.6),
          ]),
        ),
      ];
    });
  }
}

// ---------------------------------------------------------------------------
// La frise (le temps, le voyage à rebours)
// ---------------------------------------------------------------------------

double _easeInOut(double x) => Curves.easeInOutCubic.transform(x.clamp(0, 1));

/// Un trajet qui passe par chaque repère (avancement, position, vitesse)
/// avec une vitesse continue (Hermite cubique). Les vitesses trop fortes
/// pour un segment sont bridées, pour que la frise ne recule jamais.
double Function(double x) smoothPath(List<(double, double, double)> keys) {
  final k = [...keys];
  for (var j = 0; j < k.length; j++) {
    var v = k[j].$3;
    for (final n in [j - 1, j]) {
      if (n < 0 || n + 1 >= k.length) continue;
      final slope = (k[n + 1].$2 - k[n].$2) / (k[n + 1].$1 - k[n].$1);
      v = math.min(v, 3 * slope * .9);
    }
    k[j] = (k[j].$1, k[j].$2, math.max(0, v));
  }
  return (double x) {
    x = x.clamp(0.0, 1.0);
    var n = 0;
    while (n < k.length - 2 && x > k[n + 1].$1) {
      n++;
    }
    final (x0, p0, v0) = k[n];
    final (x1, p1, v1) = k[n + 1];
    final h = x1 - x0;
    final t = ((x - x0) / h).clamp(0.0, 1.0);
    final t2 = t * t, t3 = t2 * t;
    return (2 * t3 - 3 * t2 + 1) * p0 +
        (t3 - 2 * t2 + t) * h * v0 +
        (-2 * t3 + 3 * t2) * p1 +
        (t3 - t2) * h * v1;
  };
}

/// Une frise d'affiches qui défile selon [path] (indice fractionnaire du
/// film au centre, pour un avancement de 0 à 1 sur [travel] secondes). Le
/// fond suit la vitesse : la couleur des films qui passent quand elle va
/// vite, l'image du film central quand elle ralentit. À l'arrêt, la frise
/// se range et le voile de lecture arrive sous [texts].
class _Frise extends StatefulWidget {
  const _Frise({
    required this.inputs,
    required this.items,
    required this.travel,
    required this.path,
    required this.label,
    required this.texts,
    this.overlay,
  });
  final WrappedInputs inputs;
  final List<ViewingEvent> items;
  final double travel;
  final double Function(double x) path;
  final String Function(ViewingEvent e) label;
  final List<Widget> Function(WrappedType type, Size size) texts;
  final Widget? Function(double x, WrappedType type, Size size)? overlay;

  @override
  State<_Frise> createState() => _FriseState();
}

class _FriseState extends State<_Frise> {
  /// Le film dont l'image est en fond : il ne change que quand la frise
  /// ralentit assez pour qu'on la voie. À pleine vitesse, aucune image
  /// n'est chargée ni décodée pour rien.
  int _banner = 0;
  bool _warmed = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_warmed) return;
    _warmed = true;
    // Les images des moments lents : le départ, le ralenti, l'arrivée.
    final last = widget.items.length - 1;
    final stops = {
      0,
      for (final x in [.5, .57, .64, 1.0])
        widget.path(x).round().clamp(0, last),
      last,
    };
    for (final i in stops) {
      final image = widget.inputs.backdrop(widget.items[i]);
      if (image != null) {
        precacheImage(image.imageProvider, context, onError: (_, __) {});
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final inputs = widget.inputs;
    final items = widget.items;
    final travel = widget.travel;
    final path = widget.path;
    final label = widget.label;
    final texts = widget.texts;
    final overlay = widget.overlay;
    final motion = WrappedClock.motionOf(context);
    final t = WrappedClock.seconds(context);
    final x = motion ? (t / travel).clamp(0.0, 1.0) : 1.0;
    final last = (items.length - 1).toDouble();
    final i = path(x).clamp(0.0, last);
    const eps = .004;
    final speed = motion && x < 1
        ? ((path((x + eps).clamp(0, 1)) - path((x - eps).clamp(0, 1))) /
                (2 * eps) /
                travel)
            .abs()
        : 0.0;
    final settle = motion ? WrappedClock.at(context, travel, length: 1.6) : 1.0;
    final c = i.round().clamp(0, items.length - 1);
    final clear =
        x >= 1 ? 1.0 : (1 - speed / AppWrapped.friseClearSpeed).clamp(0.0, 1.0);
    if (clear > .02) _banner = c;

    Color tintAt(double at) {
      final a = at.floor().clamp(0, items.length - 1);
      final b = at.ceil().clamp(0, items.length - 1);
      return Color.lerp(inputs.tint(items[a]), inputs.tint(items[b]),
          at - at.floorToDouble())!;
    }

    return _Frame(builder: (context, size, type) {
      final posterH = size.height * AppWrapped.frisePoster;
      final posterW = posterH * 2 / 3;
      final step = posterW + AppWrapped.friseGap;
      final reach = (size.width / step / 2).ceil() + 2;
      final extra = overlay?.call(x, type, size);
      return [
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [
              tintAt((i - 4).clamp(0, last)),
              tintAt(i),
              tintAt((i + 4).clamp(0, last)),
            ]),
          ),
        ),
        Opacity(
          opacity: clear,
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 700),
            child: KenBurns(
                key: ValueKey(_banner),
                child: WrappedImage(inputs.backdrop(items[_banner]))),
          ),
        ),
        ColoredBox(color: AppColors.scrim.withValues(alpha: .35)),
        WrappedScrim(opacity: settle),
        Opacity(
          opacity: 1 - settle * (1 - AppWrapped.friseSettleOpacity),
          child: Transform.translate(
            offset:
                Offset(0, settle * size.height * AppWrapped.friseSettleOffset),
            child: Transform.scale(
              scale: 1 - settle * (1 - AppWrapped.friseSettleScale),
              child: Stack(children: [
                for (var k = math.max(0, c - reach);
                    k <= math.min(items.length - 1, c + reach);
                    k++)
                  Positioned(
                    left: size.width / 2 - posterW / 2 + (k - i) * step,
                    top: size.height / 2 - posterH / 2,
                    width: posterW,
                    height: posterH,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(AppSpacing.xxs),
                      child: inputs.poster(items[k]) == null
                          ? ColoredBox(color: inputs.tint(items[k]))
                          : KinosImage(
                              image: inputs.poster(items[k]),
                              disableBlur: true),
                    ),
                  ),
              ]),
            ),
          ),
        ),
        Positioned(
          top: size.height * .09,
          left: 0,
          right: 0,
          child: Opacity(
            opacity: 1 - settle,
            child: Text(label(items[c]).toUpperCase(),
                textAlign: TextAlign.center,
                style: type.cap.copyWith(
                    color: AppColors.textPrimary,
                    letterSpacing:
                        type.cap.fontSize! * AppWrapped.capTracking)),
          ),
        ),
        if (extra != null) extra,
        WrappedTextBlock(children: texts(type, size)),
      ];
    });
  }
}

class _TimeSlide extends StatelessWidget {
  const _TimeSlide({required this.inputs});
  final WrappedInputs inputs;

  @override
  Widget build(BuildContext context) {
    final data = inputs.data;
    final items = data.timeline;
    final last = (items.length - 1).toDouble();
    final peak = data.stats.busiestBucket;
    final peakStart =
        peak == null ? -1 : items.indexWhere((e) => e.at.month - 1 == peak);
    final peakCount =
        peak == null ? 0 : items.where((e) => e.at.month - 1 == peak).length;
    const travel = AppWrapped.time - 4;
    // Un seul élan : la frise accélère, traverse l'année, puis freine
    // jusqu'au dernier film. Pas de ralenti en chemin : le mois le plus
    // chargé se lit au passage.
    double path(double x) => _easeInOut(x) * last;
    final peakEnd = peakStart + peakCount - 1;

    final month = peak == null
        ? ''
        : toBeginningOfSentenceCase(
            DateFormat('MMMM', _locale).format(DateTime(data.year, peak + 1)));
    return _Frise(
      inputs: inputs,
      items: items,
      travel: travel,
      path: path,
      label: (e) => DateFormat('d MMMM', _locale).format(e.at),
      overlay: peak == null || peakCount < 2
          ? null
          : (x, type, size) {
              // Visible tant que la frise traverse ce mois-là.
              final i = path(x);
              final on = (i - peakStart + 1).clamp(0.0, 1.0) *
                  (peakEnd + 1 - i).clamp(0.0, 1.0);
              if (on == 0) return null;
              return Positioned(
                left: size.width * AppWrapped.inset,
                bottom: size.height * .12,
                child: Opacity(
                  opacity: on,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                        color: AppColors.scrim.withValues(alpha: .55),
                        borderRadius: AppRadii.cardBorder),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
                      child: Text(
                          '$month a compté pour ${formatHours(data.stats.buckets[peak])}.',
                          style: type.small
                              .copyWith(color: AppColors.textPrimary)),
                    ),
                  ),
                ),
              );
            },
      texts: (type, size) => [
        WrappedText('Vous avez passé',
            style: type.cap, at: travel + .6, caps: true),
        SizedBox(height: size.height * .025),
        WrappedText(
            formatHours(data.stats.seconds).replaceFirst(' h', ' heures'),
            style: type.big,
            at: travel + 1.6),
        SizedBox(height: size.height * .025),
        WrappedText(
            'devant l\'écran en ${data.year}${_daysPhrase(data.stats.seconds)}.',
            style: type.small,
            at: travel + 3),
      ],
    );
  }
}

/// Une matrice de saturation : 1 garde les couleurs, 0 donne du noir et
/// blanc.
ColorFilter _saturation(double s) {
  const r = .2126, g = .7152, b = .0722;
  final i = 1 - s;
  return ColorFilter.matrix([
    r * i + s, g * i, b * i, 0, 0, //
    r * i, g * i + s, b * i, 0, 0, //
    r * i, g * i, b * i + s, 0, 0, //
    0, 0, 0, 1, 0,
  ]);
}

/// Le voyage dans le temps, en fondus enchaînés : une image par décennie
/// (votre film le mieux noté de chaque époque), des années récentes aux
/// plus anciennes. À mesure qu'on recule, l'image perd ses couleurs et
/// gagne du grain ; on se pose sur le plus vieux film, sans repasser par
/// le noir.
class _VoyageSlide extends StatefulWidget {
  const _VoyageSlide({required this.inputs});
  final WrappedInputs inputs;

  @override
  State<_VoyageSlide> createState() => _VoyageSlideState();
}

class _VoyageSlideState extends State<_VoyageSlide> {
  /// Une époque : la décennie, ses films, et le film qui l'illustre.
  late final List<({int decade, int count, ViewingEvent film})> _epochs = () {
    final inputs = widget.inputs;
    final byDecade = <int, List<ViewingEvent>>{};
    for (final e in inputs.data.voyage) {
      (byDecade[e.year! ~/ 10 * 10] ??= []).add(e);
    }
    final oldest = inputs.data.voyage.last;
    final decades = byDecade.keys.toList()..sort((a, b) => b.compareTo(a));
    return [
      for (final d in decades)
        (
          decade: d,
          count: byDecade[d]!.length,
          // La dernière époque se termine sur le plus vieux film.
          film: d == decades.last
              ? oldest
              : ([...byDecade[d]!.where((e) => inputs.backdrop(e) != null)]
                        ..sort((a, b) => (inputs.rating(b) ?? 0)
                            .compareTo(inputs.rating(a) ?? 0)))
                      .firstOrNull ??
                  byDecade[d]!.first,
        )
    ];
  }();
  bool _warmed = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_warmed) return;
    _warmed = true;
    for (final epoch in _epochs) {
      if (widget.inputs.backdrop(epoch.film) case final image?) {
        precacheImage(image.imageProvider, context, onError: (_, __) {});
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final inputs = widget.inputs;
    final data = inputs.data;
    final epochs = _epochs;
    final oldest = data.voyage.last;
    final median = data.medianYear;
    final favourite = epochs.reduce((a, b) => b.count > a.count ? b : a);
    final n = epochs.length;
    const start = .4;
    final step = n <= 1
        ? 0.0
        : math.min(AppWrapped.epochStep, AppWrapped.epochSpan / (n - 1));
    final travel = start + (n - 1) * step + AppWrapped.epochHold;
    final motion = WrappedClock.motionOf(context);
    final t = WrappedClock.seconds(context);
    final current = !motion || step == 0
        ? n - 1
        : ((t - start) / step).floor().clamp(0, n - 1);
    final arrived = WrappedClock.at(context, travel, length: 1.6);
    // De la couleur pleine (la plus récente) au noir et blanc (la plus
    // ancienne), selon le rang de l'époque.
    double saturationOf(int i) => n <= 1 ? 1 : 1 - i / (n - 1);

    return _Frame(builder: (context, size, type) {
      final layers = <Widget>[];
      for (var i = 0; i < n; i++) {
        final at = start + i * step;
        final fadeIn = i == 0
            ? WrappedClock.at(context, 0, length: 1)
            : WrappedClock.at(context, at, length: AppWrapped.epochFade);
        // Une époque n'est plus peinte une fois recouverte par la suivante.
        final covered = i < n - 1 &&
            WrappedClock.at(context, at + step, length: AppWrapped.epochFade) >=
                1;
        if (fadeIn <= 0 || covered) continue;
        layers.add(Opacity(
          opacity: fadeIn,
          child: ColorFiltered(
            colorFilter: _saturation(saturationOf(i)),
            child: KenBurns(
                from: at,
                length: i == n - 1 ? AppWrapped.voyage : step * 2.5,
                child: WrappedImage(inputs.backdrop(epochs[i].film))),
          ),
        ));
      }
      final epoch = epochs[current];
      final label = 1 - arrived;
      return [
        ...layers,
        WrappedGrain(
            opacity: AppWrapped.grainMax *
                (n <= 1 ? 1 : (current / (n - 1)).clamp(0.0, 1.0))),
        ColoredBox(
            color: AppColors.scrim.withValues(alpha: .35 * (1 - arrived))),
        WrappedScrim(opacity: arrived),
        // L'époque en cours, au centre.
        Opacity(
          opacity: label,
          child: Center(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              WrappedText('Remonter le temps',
                  style: type.cap, at: .2, caps: true),
              SizedBox(height: size.height * .025),
              AnimatedSwitcher(
                duration:
                    motion ? const Duration(milliseconds: 900) : Duration.zero,
                child: Column(
                    key: ValueKey(epoch.decade),
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('Années ${epoch.decade}', style: type.mid),
                      SizedBox(height: size.height * .012),
                      Text('${_films(epoch.count)} · ${epoch.film.title}',
                          style: type.small),
                    ]),
              ),
            ]),
          ),
        ),
        WrappedTextBlock(children: [
          WrappedText('Votre plus vieux voyage',
              style: type.cap, at: travel + .6, caps: true),
          SizedBox(height: size.height * .025),
          WrappedText('${oldest.title} · ${oldest.year}',
              style: type.mid, at: travel + 1.6, maxLines: 2),
          SizedBox(height: size.height * .025),
          WrappedText(
              [
                if (median != null)
                  'Votre film moyen est sorti en $median.'
                      '${median <= data.year - 25 ? ' Le présent peut attendre.' : ''}',
                'Votre décennie : les années ${favourite.decade}, '
                    '${_films(favourite.count)}.',
              ].join(' '),
              style: type.small,
              at: travel + 2.8),
        ]),
      ];
    });
  }
}

// ---------------------------------------------------------------------------
// Le rythme, les goûts
// ---------------------------------------------------------------------------

class _RhythmSlide extends StatelessWidget {
  const _RhythmSlide({required this.inputs, required this.images});
  final WrappedInputs inputs;
  final List<ImageData> images;

  @override
  Widget build(BuildContext context) {
    final stats = inputs.data.stats;
    final streak = stats.streak;
    final busy = stats.busiestDay;
    String day(DateTime d) => DateFormat('d MMMM', _locale).format(d);
    final from = streak?.start;
    final to = streak == null
        ? null
        : DateTime(from!.year, from.month, from.day + streak.days - 1);
    return _Frame(
        builder: (context, size, type) => [
              CyclingBackdrops(images),
              const WrappedScrim(),
              WrappedTextBlock(children: [
                if (streak != null) ...[
                  WrappedText('Votre plus longue série',
                      style: type.cap, at: .4, caps: true),
                  SizedBox(height: size.height * .025),
                  WrappedText('${streak.days} jours', style: type.big, at: 1.4),
                  SizedBox(height: size.height * .02),
                  WrappedText('d\'affilée, du ${day(from!)} au ${day(to!)}.',
                      style: type.small, at: 2.8),
                ],
                if (busy != null) ...[
                  SizedBox(height: size.height * .04),
                  WrappedText(
                      'Votre journée la plus chargée : ${day(busy.day)}, '
                      '${_films(busy.titles).replaceAll('film', 'titre')}, '
                      '${formatHours(busy.seconds)}.',
                      style: streak == null ? type.mid : type.small,
                      at: streak == null ? 1.4 : 4.4),
                ],
              ]),
            ]);
  }
}

class _GenreSlide extends StatelessWidget {
  const _GenreSlide({required this.inputs, required this.images});
  final WrappedInputs inputs;
  final List<ImageData> images;

  @override
  Widget build(BuildContext context) {
    final genres = inputs.data.stats.genres;
    final top = genres.first;
    final others = [for (final g in genres.skip(1).take(4)) g.name];
    return _Frame(
        builder: (context, size, type) => [
              CyclingBackdrops(images),
              const WrappedScrim(),
              WrappedTextBlock(children: [
                WrappedText('Votre genre', style: type.cap, at: .4, caps: true),
                SizedBox(height: size.height * .025),
                WrappedText(top.name, style: type.big, at: 1.4),
                SizedBox(height: size.height * .025),
                WrappedText(
                    '${_films(top.count)}'
                    '${others.isEmpty ? '' : ' · puis ${_list(others)}'}.',
                    style: type.small,
                    at: 3),
              ]),
            ]);
  }
}

/// Vos séries : la plus regardée en tête, et la plus longue soirée.
class _SeriesSlide extends StatelessWidget {
  const _SeriesSlide({required this.inputs});
  final WrappedInputs inputs;

  @override
  Widget build(BuildContext context) {
    final data = inputs.data;
    final stats = data.stats;
    final top = data.series.first;
    final night = stats.longestNight;
    final count = stats.series;
    return _Frame(
        builder: (context, size, type) => [
              CyclingBackdrops([
                for (final s in data.series)
                  if (inputs.art['series:${s.name}']?.backdrop
                      case final image?)
                    image
              ]),
              const WrappedScrim(),
              WrappedTextBlock(children: [
                WrappedText('Vos séries', style: type.cap, at: .4, caps: true),
                SizedBox(height: size.height * .025),
                WrappedText(
                    '${stats.episodes} ${stats.episodes > 1 ? 'épisodes' : 'épisode'}',
                    style: type.big,
                    at: 1.4),
                SizedBox(height: size.height * .025),
                WrappedText(
                    '$count ${count > 1 ? 'séries' : 'série'}, ${top.name} en tête '
                    'avec ${top.episodes.length} '
                    '${top.episodes.length > 1 ? 'épisodes' : 'épisode'}.',
                    style: type.small,
                    at: 3),
                if (night != null) ...[
                  SizedBox(height: size.height * .015),
                  WrappedText(
                      'Plus longue soirée : ${night.episodes} épisodes'
                      '${night.series == null ? '' : ' de ${night.series}'}, '
                      'le ${DateFormat('d MMMM', _locale).format(night.day)}.',
                      style: type.small,
                      at: 4.2),
                ],
              ]),
            ]);
  }
}

/// Le réalisateur ou l'acteur de l'année : son portrait net devant ses
/// films qui se relaient.
class _PersonSlide extends ConsumerWidget {
  const _PersonSlide(
      {required this.inputs,
      required this.label,
      required this.name,
      required this.films,
      required this.images,
      required this.quoteKey});
  final WrappedInputs inputs;
  final String label;
  final String name;
  final List<ViewingEvent> films;
  final List<ImageData> images;

  /// La citation (réalisateur) ou la réplique (acteur), cherchée sur
  /// Wikiquote : cf. [wrappedQuoteProvider].
  final String quoteKey;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final person = ref.watch(statsPersonProvider(name)).valueOrNull;
    final quote = ref.watch(wrappedQuoteProvider(quoteKey)).valueOrNull;
    final portrait = WrappedClock.at(context, 1, length: 2.4);
    final titles = [for (final e in films.take(2)) e.title];
    return _Frame(builder: (context, size, type) {
      final h = size.height * AppWrapped.portraitFraction;
      return [
        CyclingBackdrops(images),
        const WrappedScrim(),
        Padding(
          padding:
              EdgeInsets.symmetric(horizontal: size.width * AppWrapped.inset),
          child: Row(children: [
            if (person?.image case final image?) ...[
              Opacity(
                opacity: portrait,
                child: ClipRRect(
                  borderRadius: AppRadii.cardBorder,
                  child: SizedBox(
                    height: h,
                    width: h * 3 / 4,
                    child: KinosImage(
                        image: ImageData(
                            path: tmdbImage(image, size: 'h632'),
                            key: 'wrapped:person:${person!.id}'),
                        alignment: Alignment.topCenter,
                        disableBlur: true),
                  ),
                ),
              ),
              SizedBox(width: size.width * .05),
            ],
            Expanded(
              child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    WrappedText(label, style: type.cap, at: 1.8, caps: true),
                    SizedBox(height: size.height * .02),
                    WrappedText(name, style: type.mid, at: 2.8, maxLines: 2),
                    SizedBox(height: size.height * .02),
                    WrappedText(
                        '${_films(films.length)} cette année'
                        '${titles.isEmpty ? '' : ', dont ${_list(titles)}'}.',
                        style: type.small,
                        at: 4),
                    if (quote != null) ...[
                      SizedBox(height: size.height * .045),
                      WrappedText(
                          quote.language == 'fr'
                              ? '« ${quote.text} »'
                              : '“${quote.text}”',
                          style: type.small.copyWith(
                              color: AppColors.textPrimary,
                              fontStyle: FontStyle.italic,
                              fontSize: type.small.fontSize! * 1.3),
                          at: 5.4),
                      if (quote.role != null) ...[
                        SizedBox(height: size.height * .012),
                        WrappedText(
                            '${quote.role}${quote.film == null ? '' : ' · ${quote.film}'}',
                            style: type.cap,
                            at: 6.4,
                            caps: true),
                      ],
                    ],
                  ]),
            ),
          ]),
        ),
      ];
    });
  }
}

/// Vos notes en piles d'affiches : chaque colonne, de ½ à 5 étoiles, se
/// remplit film après film, sur les images de votre note la plus donnée.
/// À la fin, cette colonne-là reste seule éclairée, et la phrase dit
/// pourquoi.
class _RatingsSlide extends StatelessWidget {
  const _RatingsSlide(
      {required this.inputs,
      required this.columns,
      required this.mode,
      required this.images});
  final WrappedInputs inputs;
  final List<List<ViewingEvent>> columns;
  final int mode;
  final List<ImageData> images;

  @override
  Widget build(BuildContext context) {
    final total = columns.fold(0, (a, c) => a + c.length);
    final step = total == 0 ? 0.0 : math.min(.09, 5.5 / total);
    final litAt = .6 + total * step + .6;
    final lit = WrappedClock.at(context, litAt, length: 1.4);
    final average = inputs.data.stats.average;
    const labels = ['½', '1', '', '2', '', '3', '', '4', '', '5'];
    final modeCount = mode < 0 ? 0 : columns[mode].length;
    return _Frame(builder: (context, size, type) {
      final left = size.width * AppWrapped.inset;
      final areaTop = size.height * .34;
      final areaBottom = size.height * .14;
      final areaH = size.height - areaTop - areaBottom;
      final colW = (size.width - left * 2) / 10;
      final posterW = colW * .84;
      final posterH = posterW * 1.5;
      var k = 0;
      final stacks = <Widget>[];
      for (var col = 0; col < 10; col++) {
        final n = columns[col].length;
        final offset =
            n <= 1 ? 0.0 : math.min(posterH * .3, (areaH - posterH) / (n - 1));
        // Les autres notes s'estompent : pas de cadre gris, juste moins de
        // lumière sur leurs affiches.
        final fade = col == mode ? 1.0 : 1 - lit * .7;
        for (var j = 0; j < n; j++) {
          final p = WrappedClock.at(context, .6 + k++ * step, length: .9);
          stacks.add(Positioned(
            left: left + col * colW + (colW - posterW) / 2,
            top: size.height - areaBottom - posterH - j * offset - (1 - p) * 12,
            width: posterW,
            height: posterH,
            child: Opacity(
              opacity: p * fade,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(AppSpacing.xxs),
                child: inputs.poster(columns[col][j]) == null
                    ? ColoredBox(color: inputs.tint(columns[col][j]))
                    : KinosImage(
                        image: inputs.poster(columns[col][j]),
                        disableBlur: true),
              ),
            ),
          ));
        }
        stacks.add(Positioned(
          left: left + col * colW,
          top: size.height - areaBottom + AppSpacing.xs,
          width: colW,
          child: Text(labels[col],
              textAlign: TextAlign.center,
              style: col == mode
                  ? type.small.copyWith(color: AppColors.textPrimary)
                  : type.cap),
        ));
      }
      return [
        CyclingBackdrops(images),
        ColoredBox(
            color: AppColors.scrim.withValues(alpha: AppWrapped.ratingsVeil)),
        ...stacks,
        Positioned(
          left: left,
          right: left,
          top: size.height * .1,
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            WrappedText('Vos notes', style: type.cap, at: .3, caps: true),
            SizedBox(height: size.height * .02),
            if (average != null)
              WrappedText(
                  'Moyenne ${NumberFormat('0.0', _locale).format(average)}',
                  style: type.mid,
                  at: litAt),
            if (mode >= 0) ...[
              SizedBox(height: size.height * .015),
              WrappedText(
                  'Votre note la plus fréquente : ${formatStars(mode + 1)}, '
                  'pour ${_films(modeCount)}.',
                  style: type.small,
                  at: litAt + .8),
            ],
          ]),
        ),
      ];
    });
  }
}

/// Le film où vos amis Letterboxd ne sont pas d'accord avec vous, ou le
/// seul qui vous a tous mis d'accord.
class _FriendsSlide extends ConsumerWidget {
  const _FriendsSlide(
      {required this.inputs, required this.take, required this.disagree});
  final WrappedInputs inputs;
  final FriendTake take;
  final bool disagree;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Votre photo Letterboxd, à côté de celles de vos amis.
    final me = ref.watch(letterboxdFriendsAccountProvider).valueOrNull;
    final friends = [...take.ratings]..sort((a, b) => b.rating - a.rating);
    final shown = friends.take(8).toList();
    final average = _publicNumber(take.friends);
    return _Frame(builder: (context, size, type) {
      final avatar = size.height * AppWrapped.avatarFraction;
      Widget person(String name, String? url, int rating, double at,
          {bool me = false}) {
        final p = WrappedClock.at(context, at, length: 1.2);
        return Opacity(
          opacity: p,
          child: Padding(
            padding: EdgeInsets.only(
                right: AppSpacing.md, left: me ? AppSpacing.lg : 0),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              ClipOval(
                child: SizedBox.square(
                  dimension: avatar,
                  child: url == null
                      ? ColoredBox(
                          color: AppColors.surface,
                          child: Center(
                              child: Text(name.isEmpty ? '' : name[0],
                                  style: type.small)))
                      : KinosImage(
                          image: ImageData(path: url, key: 'avatar:$url'),
                          disableBlur: true),
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(me ? 'Vous' : name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: type.cap),
              Text(formatStars(rating),
                  style: type.small.copyWith(color: AppColors.textPrimary)),
            ]),
          ),
        );
      }

      return [
        KenBurns(child: WrappedImage(inputs.backdrop(take.film))),
        const WrappedScrim(),
        WrappedTextBlock(widthFraction: .82, children: [
          WrappedText(
              disagree
                  ? 'Vos amis ne sont pas d\'accord'
                  : 'Pour une fois, d\'accord',
              style: type.cap,
              at: .4,
              caps: true),
          SizedBox(height: size.height * .02),
          WrappedText(take.film.title, style: type.mid, at: 1.4, maxLines: 2),
          SizedBox(height: size.height * .04),
          Wrap(runSpacing: AppSpacing.sm, children: [
            for (final (n, FriendRating f) in shown.indexed)
              person(
                  f.friend.name, f.friend.avatarUrl, f.rating, 2.6 + n * .35),
            person(me?.username ?? '', me?.avatarUrl, take.mine,
                2.6 + shown.length * .35 + .6,
                me: true),
          ]),
          SizedBox(height: size.height * .03),
          WrappedText(
              disagree
                  ? 'Ils lui donnent $average en moyenne. Vous, ${_starsNumber(take.mine)}.'
                  : '${take.ratings.length} amis, et vous, autour de $average.',
              style: type.small,
              at: 2.6 + shown.length * .35 + 1.6),
        ]),
      ];
    });
  }
}

class _HotTakeSlide extends StatelessWidget {
  const _HotTakeSlide(
      {required this.inputs, required this.take, required this.youLove});
  final WrappedInputs inputs;
  final HotTake take;
  final bool youLove;

  @override
  Widget build(BuildContext context) {
    final public =
        '${_publicNumber(take.public)} ${_starsWord(take.public / 2)}';
    final mine = '${_starsNumber(take.mine)} ${_starsWord(take.mine / 2)}';
    return _Frame(
        builder: (context, size, type) => [
              KenBurns(child: WrappedImage(inputs.backdrop(take.film))),
              const WrappedScrim(),
              WrappedTextBlock(children: [
                WrappedText(
                    youLove
                        ? 'Votre coup de cœur incompris'
                        : 'À contre-courant',
                    style: type.cap,
                    at: .4,
                    caps: true),
                SizedBox(height: size.height * .025),
                WrappedText(
                    youLove
                        ? 'Vous lui donnez $mine.\nLe public, $public.'
                        : 'Le public lui donne $public.\nVous, $mine.',
                    style: type.mid,
                    at: 1.6),
                SizedBox(height: size.height * .025),
                WrappedText(
                    '${take.film.title} · l\'écart le plus grand de votre année.',
                    style: type.small,
                    at: 3.2),
              ]),
            ]);
  }
}

class _AgreementSlide extends StatelessWidget {
  const _AgreementSlide(
      {required this.inputs, required this.gap, required this.images});
  final WrappedInputs inputs;
  final double gap;
  final List<ImageData> images;

  @override
  Widget build(BuildContext context) {
    final stars = NumberFormat('0.#', _locale).format(gap);
    return _Frame(
        builder: (context, size, type) => [
              CyclingBackdrops(images),
              const WrappedScrim(),
              WrappedTextBlock(children: [
                WrappedText('Vous et le public',
                    style: type.cap, at: .4, caps: true),
                SizedBox(height: size.height * .025),
                WrappedText(
                    'D\'accord à $stars ${gap >= 2 ? 'étoiles' : 'étoile'} près.',
                    style: type.mid,
                    at: 1.6),
                SizedBox(height: size.height * .025),
                WrappedText('Votre goût rejoint celui du plus grand nombre.',
                    style: type.small, at: 3.2),
              ]),
            ]);
  }
}

// ---------------------------------------------------------------------------
// Les films
// ---------------------------------------------------------------------------

class _ElsewhereSlide extends StatelessWidget {
  const _ElsewhereSlide({required this.inputs, required this.films});
  final WrappedInputs inputs;
  final List<ViewingEvent> films;

  @override
  Widget build(BuildContext context) {
    final lit = {
      for (final e in films)
        if (e.jellyfinId == null &&
            e.sources.length == 1 &&
            e.sources.contains(ViewingSource.letterboxd))
          e.identity
    };
    final dim = WrappedClock.at(context, 1.5, length: 2);
    final count = inputs.data.stats.elsewhere;
    return _Frame(
        builder: (context, size, type) => [
              _PosterWall(inputs: inputs, films: films, lit: lit, dim: dim),
              const WrappedScrim(veil: .35),
              WrappedTextBlock(children: [
                WrappedText('Hors de chez vous',
                    style: type.cap, at: .4, caps: true),
                SizedBox(height: size.height * .025),
                WrappedText(_films(count), style: type.big, at: 1.6),
                SizedBox(height: size.height * .025),
                WrappedText(
                    'vus ailleurs : en salle, chez des amis, en voyage.',
                    style: type.small,
                    at: 3),
              ]),
            ]);
  }
}

class _FilmOfYearSlide extends StatelessWidget {
  const _FilmOfYearSlide(
      {required this.inputs, required this.film, required this.rating});
  final WrappedInputs inputs;
  final ViewingEvent film;
  final int rating;

  @override
  Widget build(BuildContext context) {
    final rated = inputs.data.stats.ratings.fold(0, (a, b) => a + b);
    return _Frame(
        builder: (context, size, type) => [
              KenBurns(
                  amount: AppWrapped.kenBurns * 1.4,
                  child: WrappedImage(inputs.backdrop(film))),
              const WrappedScrim(),
              WrappedTextBlock(children: [
                WrappedText('Votre film de l\'année',
                    style: type.cap, at: .6, caps: true),
                SizedBox(height: size.height * .025),
                WrappedText(film.title, style: type.big, at: 1.8, maxLines: 2),
                SizedBox(height: size.height * .025),
                WrappedText(
                    '${formatStars(rating)} · parmi ${_films(rated)} notés cette année.',
                    style: type.small,
                    at: 3.4),
              ]),
            ]);
  }
}

/// Le récap : le film de l'année en bannière, quatre affiches et quatre
/// chiffres. Conçu d'abord en vertical (story), décliné en paysage.
class WrappedRecap extends StatelessWidget {
  const WrappedRecap({required this.inputs, super.key});
  final WrappedInputs inputs;

  @override
  Widget build(BuildContext context) {
    final data = inputs.data;
    final stats = data.stats;
    final best = data.filmOfYear;
    return _Frame(builder: (context, size, type) {
      final portrait = size.height > size.width;
      final posters = [
        for (final r in data.runnersUp)
          if (inputs.poster(r.event) case final image?) image
      ];
      Widget number(String value, String label, double at) => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                WrappedText(value, style: type.mid, at: at, maxLines: 1),
                WrappedText(label, style: type.small, at: at + .2),
              ]);
      final details = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (best != null) ...[
              WrappedText('Film de l\'année', style: type.small, at: 1),
              WrappedText(best.event.title,
                  style: type.mid.copyWith(
                      fontSize: type.mid.fontSize! * (portrait ? 1.2 : 1)),
                  at: 1.4,
                  maxLines: 2),
              WrappedText(formatStars(best.rating),
                  style: type.small.copyWith(color: AppColors.textPrimary),
                  at: 1.8),
            ],
            SizedBox(height: size.height * .03),
            Row(children: [
              for (final (n, image) in posters.indexed) ...[
                if (n > 0) const SizedBox(width: AppSpacing.xs),
                Expanded(
                  child: Opacity(
                    opacity: WrappedClock.at(context, 2.4 + n * .3),
                    child: AspectRatio(
                      aspectRatio: 2 / 3,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(AppSpacing.xxs),
                        child: KinosImage(image: image, disableBlur: true),
                      ),
                    ),
                  ),
                ),
              ],
              for (var n = posters.length; n < 4; n++) ...[
                const SizedBox(width: AppSpacing.xs),
                const Expanded(child: SizedBox()),
              ],
            ]),
            SizedBox(height: size.height * .035),
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(child: number('${stats.films}', 'films', 4)),
              Expanded(
                  child: number(
                      formatHours(stats.seconds), 'devant l\'écran', 4.3)),
            ]),
            SizedBox(height: size.height * .025),
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(
                  child: number(stats.genres.firstOrNull?.name ?? '—',
                      'genre de l\'année', 4.6)),
              Expanded(
                  child: number(
                      stats.directors.firstOrNull?.name.split(' ').last ?? '—',
                      'réalisateur de l\'année',
                      4.9)),
            ]),
          ]);
      final banner = best == null
          ? const ColoredBox(color: AppColors.heroFallback)
          : WrappedImage(inputs.backdrop(best.event));
      // L'image occupe [reach] de la diapo ; le dégradé vers le noir, lui,
      // couvre toute la diapo et atteint le noir plein avant le bord de
      // l'image. Ce bord tombe donc sous du noir opaque : deux bords
      // fractionnaires superposés (image et voile) laissaient filtrer un
      // liseré clair.
      final reach = portrait ? .52 : .62;
      final fade = LinearGradient(
        begin: portrait ? Alignment.topCenter : Alignment.centerLeft,
        end: portrait ? Alignment.bottomCenter : Alignment.centerRight,
        stops: [0, reach * .5, reach * .92],
        colors: [
          AppColors.scrim.withValues(alpha: 0),
          AppColors.scrim.withValues(alpha: 0),
          AppColors.scrim,
        ],
      );
      final pad = size.width * (portrait ? .07 : AppWrapped.inset * .7);
      return [
        Positioned(
          left: 0,
          top: 0,
          right: portrait ? 0 : size.width * (1 - reach),
          bottom: portrait ? size.height * (1 - reach) : 0,
          child: KenBurns(child: banner),
        ),
        Positioned.fill(
            child: IgnorePointer(
                child:
                    DecoratedBox(decoration: BoxDecoration(gradient: fade)))),
        Positioned(
          left: pad,
          top: pad,
          child: WrappedText('Kinos · ${data.year}',
              style: type.cap, at: .4, caps: true),
        ),
        Positioned(
          left: portrait ? pad : size.width * .56,
          right: pad,
          bottom: pad,
          top: portrait ? size.height * .4 : pad * 2,
          child: Align(alignment: Alignment.bottomLeft, child: details),
        ),
      ];
    });
  }
}
