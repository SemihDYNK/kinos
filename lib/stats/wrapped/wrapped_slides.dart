import 'dart:math' as math;
import 'dart:ui' as ui;

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
import 'package:kinos/screens/shared/kinos_icon.dart'
    show KinosIconOutlined, KinosWordmark;
import 'package:kinos/theme/app_theme.dart';
import 'package:kinos/upcoming/upcoming_models.dart' show tmdbImage;
import 'package:kinos/util/kinos_image.dart';

import '../stats_screen.dart'
    show formatHours, statsDataColor, statsPortraitProvider;
import '../viewing_log.dart';
import '../viewing_stats.dart' show Ranked;
import 'wrapped_data.dart';
import 'wrapped_export.dart' show WrappedPage, WrappedStoryLayout;
import 'wrapped_habits.dart';
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
      required this.ratings,
      this.finished = const [],
      this.nextYear = const [],
      this.userName});
  final WrappedData data;
  final Map<String, WrappedArt> art;
  final Map<String, Color> tints;
  final Map<String, KinosRating> ratings;

  /// Les séries terminées (demandées à Jellyfin), et les films conseillés
  /// pour l'an prochain : vides tant qu'ils ne sont pas arrivés.
  final List<WrappedFinished> finished;
  final List<WrappedPick> nextYear;

  /// Le nom affiché sur les pages de synthèse (à l'export, si demandé).
  final String? userName;

  WrappedInputs withName(String? name) => WrappedInputs(
      data: data,
      art: art,
      tints: tints,
      ratings: ratings,
      finished: finished,
      nextYear: nextYear,
      userName: name);

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

/// Les diapos de l'année, dans l'ordre des quatre actes. Une diapo sans
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
    if (data.hours case final hours?)
      WrappedSlide(
          id: 'when',
          seconds: AppWrapped.when,
          builder: (_) => _WhenSlide(inputs: w, hours: hours)),
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
    // Acte III : les séries, s'il y en a.
    if (data.series.isNotEmpty) ...[
      WrappedSlide(
          id: 'act3',
          seconds: AppWrapped.act,
          builder: (_) => _ActCard(
              number: 'Acte III',
              title: 'Les séries',
              colors: [
                for (final s in data.series.take(3))
                  w.tints['series:${s.name}'] ?? AppColors.heroFallback
              ],
              focus: const Alignment(-.4, .3))),
      WrappedSlide(
          id: 'series',
          seconds: AppWrapped.genre,
          builder: (_) => _SeriesSlide(inputs: w)),
      if (data.marathon case final marathon?)
        WrappedSlide(
            id: 'marathon',
            seconds: AppWrapped.genre,
            builder: (_) => _MarathonSlide(inputs: w, marathon: marathon)),
      if (data.pace case final pace?
          when pace.series != data.marathon?.series || data.marathon == null)
        WrappedSlide(
            id: 'pace',
            seconds: AppWrapped.pace,
            builder: (_) => _PaceSlide(inputs: w, pace: pace)),
      if (w.finished.isNotEmpty)
        WrappedSlide(
            id: 'finished',
            seconds: AppWrapped.finished,
            builder: (_) => _FinishedSlide(inputs: w)),
      if (data.series.firstOrNull case final show?)
        WrappedSlide(
            id: 'series-of-year',
            seconds: AppWrapped.genre,
            builder: (_) => _SeriesOfYearSlide(inputs: w, series: show)),
    ],
    // Acte IV : vous.
    WrappedSlide(
        id: 'act4',
        seconds: AppWrapped.act,
        builder: (_) => _ActCard(
            number: 'Acte IV',
            title: 'Vous',
            colors: [
              if (filmOfYear != null) w.tint(filmOfYear),
              for (final r in data.runnersUp.take(2)) w.tint(r.event),
            ],
            focus: const Alignment(0, .4))),
    WrappedSlide(
        id: 'profile',
        seconds: AppWrapped.profile,
        builder: (_) => _ProfileSlide(inputs: w)),
    if (w.nextYear.isNotEmpty)
      WrappedSlide(
          id: 'next-year',
          seconds: AppWrapped.nextYear,
          builder: (_) => _NextYearSlide(inputs: w)),
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
      // Autant de rangées que la hauteur du mur en contient, marges
      // comprises.
      final rowH = (posterW - AppSpacing.xxs * 2) * 1.5 + AppSpacing.xxs * 2;
      final rows = (c.maxHeight * 1.9 / rowH).floor();
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
              // L'année roule chiffre par chiffre, comme un compteur ; la
              // ligne du dessous s'efface avant que la suivante n'arrive,
              // sans jamais les mêler.
              Row(mainAxisSize: MainAxisSize.min, children: [
                Text('Années ', style: type.mid),
                RollingText('${epoch.decade}', style: type.mid),
              ]),
              SizedBox(height: size.height * .02),
              AnimatedSwitcher(
                duration:
                    motion ? const Duration(milliseconds: 700) : Duration.zero,
                switchInCurve: const Interval(.5, 1),
                switchOutCurve: const Interval(.5, 1),
                child: Text('${_films(epoch.count)} · ${epoch.film.title}',
                    key: ValueKey(epoch.decade), style: type.small),
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
    final night = stats.longestNight;
    final count = stats.series;
    return _Frame(
        builder: (context, size, type) => [
              // La première série a sa propre diapo à l'acte III : ici, les
              // suivantes (ou elle seule, faute d'autres).
              CyclingBackdrops([
                for (final s in data.series.length > 1
                    ? data.series.skip(1)
                    : data.series)
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
                    '$count ${count > 1 ? 'séries' : 'série'} suivies cette année.',
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

/// Le plus long marathon : une série enchaînée épisode après épisode.
class _MarathonSlide extends StatelessWidget {
  const _MarathonSlide({required this.inputs, required this.marathon});
  final WrappedInputs inputs;
  final WrappedMarathon marathon;

  @override
  Widget build(BuildContext context) {
    final m = marathon;
    final days = DateUtils.dateOnly(m.end)
            .difference(DateUtils.dateOnly(m.start))
            .inDays +
        1;
    final day = DateFormat('d MMMM', _locale);
    final when = days == 1
        ? 'le ${day.format(m.start)}'
        : m.start.month == m.end.month
            ? 'du ${m.start.day} au ${day.format(m.end)}'
            : 'du ${day.format(m.start)} au ${day.format(m.end)}';
    final image = inputs.art['series:${m.series}']?.backdrop ??
        inputs.data.series
            .map((s) => inputs.art['series:${s.name}']?.backdrop)
            .nonNulls
            .firstOrNull;
    return _Frame(
        builder: (context, size, type) => [
              KenBurns(child: WrappedImage(image)),
              const WrappedScrim(),
              WrappedTextBlock(children: [
                WrappedText('Votre marathon',
                    style: type.cap, at: .4, caps: true),
                SizedBox(height: size.height * .025),
                WrappedText('${m.episodes} épisodes', style: type.big, at: 1.4),
                SizedBox(height: size.height * .025),
                WrappedText(
                    '${m.series}, ${days == 1 ? 'd\'une traite' : 'en $days jours'}, '
                    '$when.',
                    style: type.small,
                    at: 3),
                if (m.seconds > 0) ...[
                  SizedBox(height: size.height * .015),
                  WrappedText('${formatHours(m.seconds)} sans décrocher.',
                      style: type.small, at: 4.2),
                ],
              ]),
            ]);
  }
}

/// La série de l'année : la plus regardée, en grand.
class _SeriesOfYearSlide extends StatelessWidget {
  const _SeriesOfYearSlide({required this.inputs, required this.series});
  final WrappedInputs inputs;
  final ({String name, List<ViewingEvent> episodes}) series;

  @override
  Widget build(BuildContext context) {
    final episodes = [...series.episodes]..sort((a, b) => a.at.compareTo(b.at));
    final seconds = episodes.fold(0, (sum, e) => sum + e.seconds);
    final month = DateFormat('MMMM', _locale);
    final first = episodes.first.at;
    final last = episodes.last.at;
    final seasons = {for (final e in episodes) e.season}.nonNulls.length;
    final span = first.month == last.month
        ? 'en ${month.format(first)}'
        : 'de ${month.format(first)} à ${month.format(last)}';
    return _Frame(
        builder: (context, size, type) => [
              KenBurns(
                  amount: AppWrapped.kenBurns * 1.4,
                  child: WrappedImage(
                      inputs.art['series:${series.name}']?.backdrop)),
              const WrappedScrim(),
              WrappedTextBlock(children: [
                WrappedText('Votre série de l\'année',
                    style: type.cap, at: .6, caps: true),
                SizedBox(height: size.height * .025),
                WrappedText(series.name, style: type.big, at: 1.8, maxLines: 2),
                SizedBox(height: size.height * .025),
                WrappedText(
                    [
                      '${episodes.length} ${episodes.length > 1 ? 'épisodes' : 'épisode'}',
                      if (seasons > 1) '$seasons saisons',
                      if (seconds > 0) formatHours(seconds),
                      span,
                    ].join(' · '),
                    style: type.small,
                    at: 3.4),
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
    final photo = ref.watch(statsPortraitProvider(name)).valueOrNull;
    final quote = ref.watch(wrappedQuoteProvider(quoteKey)).valueOrNull;
    final portrait = WrappedClock.at(context, 1, length: 2.4);
    final titles = [for (final e in films.take(2)) e.title];
    return _Frame(builder: (context, size, type) {
      final vertical = size.height > size.width;
      final h = size.height * (vertical ? .3 : AppWrapped.portraitFraction);
      return [
        CyclingBackdrops(images),
        const WrappedScrim(),
        Padding(
          padding:
              EdgeInsets.symmetric(horizontal: size.width * AppWrapped.inset),
          // En vertical (story), le portrait passe au-dessus du texte.
          child: Flex(
              direction: vertical ? Axis.vertical : Axis.horizontal,
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: vertical
                  ? CrossAxisAlignment.start
                  : CrossAxisAlignment.center,
              children: [
                if (photo != null) ...[
                  Opacity(
                    opacity: portrait,
                    child: ClipRRect(
                      borderRadius: AppRadii.cardBorder,
                      child: SizedBox(
                        height: h,
                        width: h * 3 / 4,
                        child: KinosImage(
                            image: ImageData(
                                path: tmdbImage(photo, size: 'h632'),
                                key: 'wrapped:person:$photo'),
                            alignment: AppStatsLayout.portraitAlignment,
                            disableBlur: true),
                      ),
                    ),
                  ),
                  vertical
                      ? SizedBox(height: size.height * .04)
                      : SizedBox(width: size.width * .05),
                ],
                Flexible(
                  fit: vertical ? FlexFit.loose : FlexFit.tight,
                  child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        WrappedText(label,
                            style: type.cap, at: 1.8, caps: true),
                        SizedBox(height: size.height * .02),
                        WrappedText(name,
                            style: type.mid, at: 2.8, maxLines: 2),
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

/// Les quatre pages de synthèse : le récap de l'année et un par acte.
enum WrappedSummaryKind { year, time, taste, films }

/// Ce qu'une page de synthèse montre à l'écran (16:9) : une bannière, un
/// intitulé, un titre et sa ligne, quatre affiches et quatre chiffres. En
/// story (9:16), la même page est composée pour le vertical par
/// [_StoryPage], d'après son [kind].
class WrappedSummary {
  const WrappedSummary({
    required this.kind,
    required this.label,
    required this.headline,
    this.sub,
    this.banner,
    this.posters = const [],
    this.numbers = const [],
    this.continuesFilmOfYear = false,
  });
  final WrappedSummaryKind kind;
  final String label;
  final String headline;
  final String? sub;
  final ImageData? banner;
  final List<ImageData> posters;
  final List<(String value, String label)> numbers;

  /// Le récap de l'année : il prolonge la diapo du film de l'année.
  final bool continuesFilmOfYear;
}

List<ImageData> _postersOf(WrappedInputs w, Iterable<ViewingEvent> films,
        {int take = 4}) =>
    [
      for (final e in films)
        if (w.poster(e) case final image?) image
    ].take(take).toList();

String _lastName(String name) => name.split(' ').last;

/// Les films du mois le plus chargé, du mieux noté au moins bien noté.
List<ViewingEvent> _peakFilms(WrappedInputs w) {
  final peak = w.data.stats.busiestBucket;
  return [
    for (final e in w.data.timeline)
      if (peak != null && e.at.month - 1 == peak) e
  ]..sort((a, b) => (w.rating(b) ?? 0).compareTo(w.rating(a) ?? 0));
}

/// Les films du genre de l'année, du mieux noté au moins bien noté.
List<ViewingEvent> _genreFilms(WrappedInputs w) => [...w.data.genreFilms]
  ..sort((a, b) => (w.rating(b) ?? 0).compareTo(w.rating(a) ?? 0));

/// La note la plus donnée (indice de 0 à 9), -1 sans note.
int _ratingMode(List<int> ratings) {
  var mode = -1;
  for (var i = 0; i < ratings.length; i++) {
    if (ratings[i] > 0 && (mode < 0 || ratings[i] >= ratings[mode])) mode = i;
  }
  return mode;
}

/// Le récap de l'année : le film de l'année, ses quatre suivants, et
/// l'année en quatre chiffres.
WrappedSummary yearSummary(WrappedInputs w) {
  final stats = w.data.stats;
  final best = w.data.filmOfYear;
  return WrappedSummary(
    kind: WrappedSummaryKind.year,
    label: 'Film de l\'année',
    headline: best?.event.title ?? '${stats.films} films',
    sub: best == null ? null : formatStars(best.rating),
    banner: best == null ? null : w.backdrop(best.event),
    posters: _postersOf(w, [for (final r in w.data.runnersUp) r.event]),
    numbers: [
      ('${stats.films}', 'films'),
      (formatHours(stats.seconds), 'devant l\'écran'),
      (stats.genres.firstOrNull?.name ?? '—', 'genre de l\'année'),
      (
        _lastName(stats.directors.firstOrNull?.name ?? '—'),
        'réalisateur de l\'année'
      ),
    ],
    continuesFilmOfYear: best != null,
  );
}

/// Acte I, le temps : les heures, le mois le plus chargé, la série.
WrappedSummary timeSummary(WrappedInputs w) {
  final data = w.data;
  final stats = data.stats;
  final peak = stats.busiestBucket;
  final peakFilms = _peakFilms(w);
  final lead = peakFilms.firstOrNull ?? data.timeline.lastOrNull;
  return WrappedSummary(
    kind: WrappedSummaryKind.time,
    label: 'Acte I · Le temps',
    headline: formatHours(stats.seconds).replaceFirst(' h', ' heures'),
    sub: 'devant l\'écran en ${data.year}${_daysPhrase(stats.seconds)}',
    banner: lead == null ? null : w.backdrop(lead),
    posters: _postersOf(w, [...peakFilms.skip(1), ...data.timeline.reversed]),
    numbers: [
      ('${stats.films}', 'films'),
      if (stats.episodes > 0)
        ('${stats.episodes}', 'épisodes')
      else
        ('${stats.elsewhere}', 'vus ailleurs'),
      if (peak != null)
        (
          toBeginningOfSentenceCase(DateFormat('MMMM', _locale)
              .format(DateTime(data.year, peak + 1))),
          'mois le plus chargé'
        ),
      if (stats.streak case final streak?)
        ('${streak.days} jours', 'plus longue série')
      else if (stats.busiestDay case final day?)
        (
          DateFormat('d MMMM', _locale).format(day.day),
          'journée la plus chargée'
        ),
    ],
  );
}

/// Acte II, les goûts : le genre, le réalisateur, l'acteur, les notes.
WrappedSummary tasteSummary(WrappedInputs w) {
  final data = w.data;
  final stats = data.stats;
  final genre = stats.genres.firstOrNull;
  final films = _genreFilms(w);
  final mode = _ratingMode(stats.ratings);
  return WrappedSummary(
    kind: WrappedSummaryKind.taste,
    label: 'Acte II · Les goûts',
    headline: genre?.name ?? 'Vos goûts',
    sub: genre == null ? null : '${_films(genre.count)} cette année',
    banner: films.isEmpty ? null : w.backdrop(films.first),
    posters: _postersOf(w, data.directorFilms),
    numbers: [
      if (stats.directors.firstOrNull case final d?)
        (_lastName(d.name), 'réalisateur'),
      if (stats.actors.firstOrNull case final a?) (_lastName(a.name), 'acteur'),
      if (stats.average case final average?)
        (NumberFormat('0.0', _locale).format(average), 'note moyenne'),
      if (mode >= 0) (formatStars(mode + 1), 'note la plus donnée'),
    ],
  );
}

/// Les décennies de sortie de l'année, de la plus vue à la moins vue.
List<({int decade, int count})> _decades(WrappedData data) {
  final decades = <int, int>{};
  for (final e in data.voyage) {
    decades[e.year! ~/ 10 * 10] = (decades[e.year! ~/ 10 * 10] ?? 0) + 1;
  }
  return [for (final e in decades.entries) (decade: e.key, count: e.value)]
    ..sort((a, b) => b.count.compareTo(a.count));
}

/// Acte III, les films : le plus vieux voyage, les époques, l'ailleurs.
WrappedSummary filmsSummary(WrappedInputs w) {
  final data = w.data;
  final stats = data.stats;
  final oldest = data.voyage.lastOrNull;
  final decades = _decades(data);
  final byEra = <int, ViewingEvent>{};
  for (final e in data.voyage) {
    byEra.putIfAbsent(e.year! ~/ 10 * 10, () => e);
  }
  return WrappedSummary(
    kind: WrappedSummaryKind.films,
    label: 'Acte IV · Vous',
    headline: oldest == null
        ? '${stats.films} films'
        : '${oldest.title} · ${oldest.year}',
    sub: oldest == null ? null : 'votre plus vieux voyage',
    banner: oldest == null ? null : w.backdrop(oldest),
    posters: _postersOf(w, byEra.values),
    numbers: [
      if (decades.firstOrNull case final d?)
        ('Années ${d.decade}', 'décennie préférée'),
      if (data.medianYear case final median?) ('$median', 'film moyen'),
      ('${stats.elsewhere}', 'vus ailleurs'),
      ('${stats.ratings.fold(0, (a, b) => a + b)}', 'films notés'),
    ],
  );
}

/// La couleur d'une story : la teinte du film, franche et saturée ; un
/// papier crème pour une image sans couleur (un film en noir et blanc).
Color storyColor(Color tint) {
  final hsl = HSLColor.fromColor(tint);
  if (hsl.saturation < AppWrapped.storyGraySaturation) {
    return AppWrapped.storyPaper;
  }
  return hsl
      .withSaturation(hsl.saturation
          .clamp(AppWrapped.storySaturationMin, AppWrapped.storySaturationMax))
      .withLightness(AppWrapped.storyLightness)
      .toColor();
}

/// L'encre d'une story : claire sur un fond sombre, sombre sur un fond
/// clair (l'ocre, le crème).
Color storyInk(Color ground) => ground.computeLuminance() > .3
    ? AppColors.background
    : AppColors.textPrimary;

/// Le cadran des douze mois : une branche par mois, plus longue quand on a
/// regardé davantage, le mois le plus chargé en plein, les initiales
/// autour.
class _MonthDial extends CustomPainter {
  _MonthDial(
      {required this.months,
      required this.peak,
      required this.ink,
      required this.label});
  final List<int> months;
  final int? peak;
  final Color ink;
  final TextStyle label;

  static const _initials = 'JFMAMJJASOND';

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.shortestSide / 2;
    final inner = radius * .6, outer = radius * .86;
    final top = months.fold(0, (a, b) => a > b ? a : b);
    final width = radius * .06;
    for (var i = 0; i < 12; i++) {
      final angle = (i + .5) / 12 * 2 * math.pi - math.pi / 2;
      final direction = Offset(math.cos(angle), math.sin(angle));
      final value = top == 0 ? 0.0 : months[i] / top;
      final length = inner + (outer - inner) * math.max(.04, value);
      // Le rail du mois, en entier et en transparence…
      canvas.drawLine(
          center + direction * inner,
          center + direction * outer,
          Paint()
            ..color = ink.withValues(alpha: .12)
            ..strokeWidth = width
            ..strokeCap = StrokeCap.round);
      // …et ses heures par-dessus.
      canvas.drawLine(
          center + direction * inner,
          center + direction * length,
          Paint()
            ..color = ink.withValues(alpha: i == peak ? 1 : .55)
            ..strokeWidth = width
            ..strokeCap = StrokeCap.round);
      final text = TextPainter(
          text: TextSpan(
              text: _initials[i],
              style: label.copyWith(
                  color: ink.withValues(alpha: i == peak ? 1 : .6))),
          textDirection: ui.TextDirection.ltr)
        ..layout();
      text.paint(
          canvas,
          center +
              direction * (radius * .97) -
              Offset(text.width / 2, text.height / 2));
    }
  }

  @override
  bool shouldRepaint(_MonthDial old) =>
      old.months != months || old.peak != peak || old.ink != ink;
}

/// Le film de chaque story (sa couleur, son affiche) : jamais
/// le même d'une page à l'autre. Le film de l'année et le plus vieux sont
/// fixés ; le genre et le mois le plus chargé prennent le premier film qui
/// n'est pas déjà pris.
Map<WrappedSummaryKind, ViewingEvent?> _storyLeads(WrappedInputs w) {
  final data = w.data;
  final year = data.filmOfYear?.event;
  final films = data.voyage.lastOrNull;
  final taken = {year?.identity, films?.identity};
  ViewingEvent? free(Iterable<ViewingEvent> candidates) {
    final pick =
        candidates.where((e) => !taken.contains(e.identity)).firstOrNull ??
            candidates.firstOrNull;
    taken.add(pick?.identity);
    return pick;
  }

  final taste = free(_genreFilms(w));
  final time = free([..._peakFilms(w), ...data.timeline.reversed]);
  return {
    WrappedSummaryKind.year: year,
    WrappedSummaryKind.time: time,
    WrappedSummaryKind.taste: taste,
    WrappedSummaryKind.films: films,
  };
}

/// Une page de synthèse composée pour le vertical (story), d'après les
/// bilans annuels des services de musique : un aplat de la couleur du
/// film de la page en nappes, son affiche, un chiffre géant en filigrane
/// qui déborde, le contenu centré, des chiffres séparés de filets, et le
/// pied de page à la même place sur chaque page (le K à gauche, l'année à
/// droite).
/// Le contenu d'une page de synthèse : sa pièce maîtresse ([hero]), le
/// reste ([rest], posé [gap] plus bas en vertical, à droite en paysage) et
/// ses chiffres du bas.
typedef _Story = ({
  Widget hero,
  Widget? rest,
  double gap,
  List<(String, String)> numbers,
});

class _StoryPage extends ConsumerWidget {
  const _StoryPage({required this.inputs, required this.kind});
  final WrappedInputs inputs;
  final WrappedSummaryKind kind;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final w = inputs;
    final data = w.data;
    final stats = data.stats;
    // Le film qui donne sa couleur et son image à la page.
    final lead = _storyLeads(w)[kind];
    // L'acte IV est la story de votre archétype : sa matière à lui.
    final look = kind == WrappedSummaryKind.films ? _archetypeLook(w) : null;
    final ground = look?.ground ?? storyColor(look?.tint ?? w.tint(lead));
    final ink = storyInk(ground);
    final soft = ink.withValues(alpha: .72);
    final line = ink.withValues(alpha: .26);
    final watermark = switch (kind) {
      WrappedSummaryKind.year => '${data.year}',
      WrappedSummaryKind.time => formatHours(stats.seconds).split(' ').first,
      WrappedSummaryKind.taste =>
        (stats.genres.firstOrNull?.name ?? '').toUpperCase(),
      WrappedSummaryKind.films => look!.watermark,
    };

    return LayoutBuilder(builder: (context, box) {
      final size = box.biggest;
      // En paysage (16:9), la même page en deux colonnes ; l'unité suit la
      // hauteur, pour garder les proportions de la story.
      final landscape = size.width > size.height;
      final u = (landscape ? size.height : size.width) / 100;
      final cond = AppTypography.heroEditorial
          .copyWith(color: ink, height: .9, letterSpacing: 0);
      final cap = AppTypography.overline.copyWith(
          color: soft, fontSize: 2.8 * u, letterSpacing: 2.8 * u * .4);
      final body = AppTypography.body
          .copyWith(color: soft, fontSize: 3.1 * u, height: 1.3);
      Widget capText(String text) =>
          Text(text.toUpperCase(), textAlign: TextAlign.center, style: cap);
      // Sur une ligne, un mot trop long (« Adventure ») rétrécit pour tenir
      // en entier plutôt que d'être coupé.
      Widget condText(String text, double fontSize,
              {int maxLines = 1}) =>
          maxLines == 1
              ? FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(text.toUpperCase(),
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      softWrap: false,
                      style: cond.copyWith(fontSize: fontSize)))
              : Text(text.toUpperCase(),
                  textAlign: TextAlign.center,
                  maxLines: maxLines,
                  overflow: TextOverflow.ellipsis,
                  style: cond.copyWith(fontSize: fontSize));
      Widget poster(ImageData? image, double width) => ClipRRect(
            borderRadius: BorderRadius.circular(1.4 * u),
            child: SizedBox(
              width: width,
              height: width * 1.5,
              child: image == null
                  ? ColoredBox(color: ink.withValues(alpha: .15))
                  : KinosImage(image: image, disableBlur: true),
            ),
          );
      // Les chiffres du bas : chaque colonne centrée sur sa moitié (ou son
      // tiers), les filets posés à part sans rien décaler.
      Widget numbers(List<(String, String)> items) => SizedBox(
            height: 15 * u,
            child: LayoutBuilder(
                builder: (context, box) => Stack(children: [
                      Row(children: [
                        for (final (value, label) in items)
                          Expanded(
                            // Une marge de chaque côté : un long nom de mois
                            // (« NOVEMBRE ») venait toucher le filet.
                            child: Padding(
                              padding:
                                  EdgeInsets.symmetric(horizontal: 2.5 * u),
                              child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    FittedBox(
                                        fit: BoxFit.scaleDown,
                                        // La police condensée n'a pas d'étoile.
                                        child: Text(value.toUpperCase(),
                                            maxLines: 1,
                                            style: value.contains('★')
                                                ? body.copyWith(
                                                    color: ink,
                                                    fontSize: 6.5 * u)
                                                : cond.copyWith(
                                                    fontSize: 9 * u))),
                                    SizedBox(height: .8 * u),
                                    Text(label,
                                        textAlign: TextAlign.center,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style:
                                            body.copyWith(fontSize: 2.8 * u)),
                                  ]),
                            ),
                          ),
                      ]),
                      for (var i = 1; i < items.length; i++)
                        Positioned(
                          left: box.maxWidth * i / items.length,
                          top: 2 * u,
                          bottom: 2 * u,
                          child: Container(width: 1, color: line),
                        ),
                    ])),
          );

      final content = switch (kind) {
        WrappedSummaryKind.year =>
          _yearStory(context, u, capText, condText, poster, body, soft),
        WrappedSummaryKind.time =>
          _timeStory(u, capText, condText, poster, body, ink),
        WrappedSummaryKind.taste =>
          _tasteStory(ref, u, capText, condText, body, ink, soft, line),
        WrappedSummaryKind.films =>
          _profileStory(u, capText, condText, body, ground, look!),
      };

      return ClipRect(
        child: ColoredBox(
          color: ground,
          child: Stack(fit: StackFit.expand, children: [
            // Des nappes de couleur tirées du film de la page, qui se
            // fondent sous le grain : l'affiche nette reste la seule image.
            CustomPaint(
                painter: StoryMesh(
                    ground: ground,
                    seed: (look?.watermark ?? lead?.identity ?? '').hashCode ^
                        kind.index)),
            // Le chiffre géant en filigrane, qui déborde du cadre.
            // (Pas pour le temps : son cadran porte déjà le chiffre.)
            if (kind != WrappedSummaryKind.time)
              Positioned(
                left: -6 * u,
                top: 18 * u,
                child: Text(watermark,
                    maxLines: 1,
                    softWrap: false,
                    overflow: TextOverflow.visible,
                    style: cond.copyWith(
                        fontSize: (watermark.length <= 3 ? 150 : 62) * u,
                        color: ink.withValues(alpha: .1))),
              ),
            const WrappedGrain(opacity: AppWrapped.storyGrain),
            if (landscape) ...[
              // En paysage : la pièce maîtresse à gauche…
              Positioned(
                left: 7.5 * u,
                width: 72 * u,
                top: 7 * u,
                bottom: 19 * u,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: SizedBox(width: 85 * u, child: content.hero),
                ),
              ),
              Positioned(
                left: 86 * u,
                top: 10 * u,
                bottom: 22 * u,
                child: Container(width: 1, color: line),
              ),
              // …le reste et les chiffres à droite.
              Positioned(
                left: 93 * u,
                right: 7.5 * u,
                top: 7 * u,
                bottom: 19 * u,
                child: Column(children: [
                  Expanded(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: SizedBox(
                          width: 85 * u,
                          child: content.rest ?? const SizedBox()),
                    ),
                  ),
                  SizedBox(height: 3 * u),
                  numbers(content.numbers),
                ]),
              ),
            ] else ...[
              // Le contenu, qui se réduit plutôt que de déborder s'il
              // manque de place…
              Positioned(
                left: 7.5 * u,
                right: 7.5 * u,
                top: 9 * u,
                bottom: 40 * u,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.topCenter,
                  child: SizedBox(
                      width: 85 * u,
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                        content.hero,
                        if (content.rest case final rest?) ...[
                          SizedBox(height: content.gap),
                          rest,
                        ],
                      ])),
                ),
              ),
              // …et les chiffres, à la même place sur chaque page, juste
              // au-dessus du pied de page.
              Positioned(
                left: 7.5 * u,
                right: 7.5 * u,
                bottom: 21 * u,
                height: 15 * u,
                child: numbers(content.numbers),
              ),
            ],
            // Le pied de page, toujours à la même place.
            Positioned(
              left: 7.5 * u,
              right: 7.5 * u,
              bottom: (landscape ? 4 : 7) * u,
              height: 11 * u,
              child: DecoratedBox(
                decoration:
                    BoxDecoration(border: Border(top: BorderSide(color: line))),
                child: Padding(
                  padding: EdgeInsets.only(top: 3 * u),
                  child: Row(children: [
                    KinosIconOutlined(size: 7 * u, color: ink),
                    const Spacer(),
                    if (w.userName case final name?) ...[
                      Text(name, style: body.copyWith(fontSize: 3 * u)),
                      SizedBox(width: 3 * u),
                    ],
                    Text('${data.year}',
                        style: cond.copyWith(
                            fontSize: 6.5 * u, letterSpacing: 6.5 * u * .06)),
                  ]),
                ),
              ),
            ),
          ]),
        ),
      );
    });
  }

  _Story _yearStory(
      BuildContext context,
      double u,
      Widget Function(String) cap,
      Widget Function(String, double, {int maxLines}) cond,
      Widget Function(ImageData?, double) poster,
      TextStyle body,
      Color soft) {
    final data = inputs.data;
    final stats = data.stats;
    final best = data.filmOfYear;
    return (
      hero: Column(mainAxisSize: MainAxisSize.min, children: [
        cap('Film de l\'année'),
        SizedBox(height: 5 * u),
        poster(best == null ? null : inputs.poster(best.event), 50 * u),
        SizedBox(height: 4 * u),
        cond(best?.event.title ?? '${stats.films} films', 11 * u, maxLines: 2),
        if (best != null) ...[
          SizedBox(height: 1.5 * u),
          Text(formatStars(best.rating),
              style: body.copyWith(
                  color: body.color!.withValues(alpha: 1),
                  fontSize: 3.6 * u,
                  letterSpacing: 3.6 * u * .3)),
        ],
      ]),
      gap: 5 * u,
      rest: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        for (final (i, r) in data.runnersUp.take(4).indexed) ...[
          if (i > 0) SizedBox(width: 2.4 * u),
          Expanded(
            child: Column(children: [
              Text('${i + 2}',
                  style: body.copyWith(fontSize: 3.4 * u, color: soft)),
              SizedBox(height: 1 * u),
              poster(inputs.poster(r.event), (85 - 7.2) * u / 4),
              SizedBox(height: 1.2 * u),
              Text(r.event.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: body.copyWith(fontSize: 2.6 * u)),
            ]),
          ),
        ],
      ]),
      numbers: [
        ('${stats.films}', 'films'),
        (formatHours(stats.seconds), 'à l\'écran'),
        if (stats.genres.firstOrNull case final g?) (g.name, 'genre'),
      ]
    );
  }

  _Story _timeStory(
      double u,
      Widget Function(String) cap,
      Widget Function(String, double, {int maxLines}) cond,
      Widget Function(ImageData?, double) poster,
      TextStyle body,
      Color ink) {
    final data = inputs.data;
    final stats = data.stats;
    final peak = stats.busiestBucket;
    // Les affiches du mois le plus chargé : ses films, puis ses séries
    // (un mois de séries n'a parfois aucun film).
    final peakPosters = [
      ..._postersOf(inputs, _peakFilms(inputs)),
      for (final show in data.series)
        if (peak != null && show.episodes.any((e) => e.at.month - 1 == peak))
          if (inputs.art['series:${show.name}']?.poster case final image?)
            image,
    ].take(4).toList();
    final hours = formatHours(stats.seconds).split(' ');
    return (
      hero: Column(mainAxisSize: MainAxisSize.min, children: [
        cap('Acte I · Le temps'),
        SizedBox(height: 5 * u),
        SizedBox.square(
          dimension: 72 * u,
          child: CustomPaint(
            painter: _MonthDial(
                months: stats.buckets,
                peak: peak,
                ink: ink,
                label: body.copyWith(
                    fontSize: 3 * u, fontWeight: FontWeight.w600)),
            child: Center(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                cond(hours.first, 20 * u),
                cap(hours.length > 1 && hours.last == 'h'
                    ? 'heures'
                    : hours.last),
              ]),
            ),
          ),
        ),
        SizedBox(height: 3 * u),
        Text('devant l\'écran en ${data.year}${_daysPhrase(stats.seconds)}',
            textAlign: TextAlign.center, style: body),
      ]),
      gap: 7 * u,
      rest: peak == null || peakPosters.isEmpty
          ? null
          : Column(mainAxisSize: MainAxisSize.min, children: [
              cap('En ${DateFormat('MMMM', _locale).format(DateTime(data.year, peak + 1))}'),
              SizedBox(height: 3 * u),
              Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                for (final (i, image) in peakPosters.indexed) ...[
                  if (i > 0) SizedBox(width: 2.4 * u),
                  poster(image, (85 - 7.2) * u / 4),
                ],
              ]),
            ]),
      numbers: [
        if (peak != null)
          (
            DateFormat('MMMM', _locale).format(DateTime(data.year, peak + 1)),
            'votre mois · ${formatHours(stats.buckets[peak])}'
          ),
        if (stats.streak case final streak?) ('${streak.days} j', 'd\'affilée'),
        if (stats.busiestDay case final day?)
          (DateFormat('d MMM', _locale).format(day.day), 'journée record'),
      ]
    );
  }

  _Story _tasteStory(
      WidgetRef ref,
      double u,
      Widget Function(String) cap,
      Widget Function(String, double, {int maxLines}) cond,
      TextStyle body,
      Color ink,
      Color soft,
      Color line) {
    final stats = inputs.data.stats;
    final genres = stats.genres;
    final mode = _ratingMode(stats.ratings);
    final top = stats.ratings.fold(0, (a, b) => a > b ? a : b);
    Widget person(Ranked? p, String role) => p == null
        ? const SizedBox()
        : Column(children: [
            ClipOval(
              child: SizedBox.square(
                dimension: 31 * u,
                child: switch (
                    ref.watch(statsPortraitProvider(p.name)).valueOrNull) {
                  final path? => KinosImage(
                      image: ImageData(
                          path: tmdbImage(path, size: 'w342'),
                          key: 'story:person:$path'),
                      alignment: AppStatsLayout.portraitAlignment,
                      disableBlur: true),
                  _ => ColoredBox(color: ink.withValues(alpha: .15)),
                },
              ),
            ),
            SizedBox(height: 3 * u),
            cond(_lastName(p.name), 6.5 * u),
            SizedBox(height: 1 * u),
            Text('$role · ${_films(p.count)}',
                style: body.copyWith(fontSize: 2.8 * u)),
          ]);
    const labels = ['½', '1', '', '2', '', '3', '', '4', '', '5'];
    return (
      hero: Column(mainAxisSize: MainAxisSize.min, children: [
        cap('Acte II · Les goûts'),
        SizedBox(height: 6 * u),
        cond(genres.firstOrNull?.name ?? '', 22 * u),
        SizedBox(height: 2.5 * u),
        Text(
            [
              for (final (i, g) in genres.skip(1).take(4).indexed)
                '${i + 2} ${g.name}'
            ].join(' · '),
            textAlign: TextAlign.center,
            maxLines: 2,
            style: body),
      ]),
      gap: 7 * u,
      rest: Column(mainAxisSize: MainAxisSize.min, children: [
        Row(children: [
          Expanded(child: person(stats.directors.firstOrNull, 'réalisateur')),
          Expanded(child: person(stats.actors.firstOrNull, 'acteur')),
        ]),
        if (top > 0) ...[
          SizedBox(height: 6 * u),
          cap('Vos notes'),
          SizedBox(height: 2.4 * u),
          SizedBox(
            height: 17 * u,
            child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
              for (var i = 0; i < 10; i++)
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: .8 * u),
                    child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Container(
                            height: math.max(
                                .4 * u, 11 * u * stats.ratings[i] / top),
                            decoration: BoxDecoration(
                              color: ink.withValues(alpha: i == mode ? 1 : .35),
                              borderRadius: BorderRadius.vertical(
                                  top: Radius.circular(.6 * u)),
                            ),
                          ),
                          SizedBox(height: 1 * u),
                          Text(labels[i],
                              style: body.copyWith(fontSize: 2.4 * u)),
                        ]),
                  ),
                ),
            ]),
          ),
        ],
      ]),
      numbers: [
        if (stats.average case final average?)
          (NumberFormat('0.0', _locale).format(average), 'note moyenne'),
        if (mode >= 0) (formatStars(mode + 1), 'la plus donnée'),
      ]
    );
  }

  /// La story de l'archétype : son affiche (une grille de films pour
  /// l'explorateur), son nom en très grand, sa phrase, ses chiffres.
  _Story _profileStory(
      double u,
      Widget Function(String) cap,
      Widget Function(String, double, {int maxLines}) cond,
      TextStyle body,
      Color ground,
      _ArchetypeLook look) {
    final profile = inputs.data.profile;
    // L'affiche dans ses vraies couleurs : le fond en nappes porte déjà
    // la couleur du film.
    Widget poster(ImageData? image, double width) => ClipRRect(
          borderRadius: BorderRadius.circular(1.4 * u),
          child: SizedBox(
            width: width,
            height: width * 1.5,
            child: image == null
                ? ColoredBox(color: ground.withValues(alpha: .3))
                : KinosImage(image: image, disableBlur: true),
          ),
        );
    final grid = look.grid.take(6).toList();
    return (
      hero: Column(mainAxisSize: MainAxisSize.min, children: [
        cap('Acte IV · Vous'),
        SizedBox(height: 6 * u),
        if (grid.length >= 3)
          SizedBox(
            width: 3 * 24 * u + 2 * 1.5 * u,
            child: Wrap(
              spacing: 1.5 * u,
              runSpacing: 1.5 * u,
              children: [for (final image in grid) poster(image, 24 * u)],
            ),
          )
        else
          poster(look.image, 50 * u),
        SizedBox(height: 6 * u),
        cond(profile.title, 15 * u),
        SizedBox(height: 2.5 * u),
        Text(profile.line,
            textAlign: TextAlign.center,
            style: body.copyWith(fontSize: 3.8 * u)),
      ]),
      gap: 0,
      rest: null,
      numbers: look.numbers,
    );
  }
}

/// Une page de synthèse : la bannière à gauche (en haut en vertical), qui
/// se fond dans le noir, et à droite l'intitulé, le titre, quatre affiches
/// et quatre chiffres. Conçue d'abord en vertical (story).
class WrappedRecap extends StatelessWidget {
  const WrappedRecap({required this.inputs, this.summary, super.key});
  final WrappedInputs inputs;

  /// Le récap de l'année par défaut ([yearSummary]).
  final WrappedSummary? summary;

  @override
  Widget build(BuildContext context) {
    final data = inputs.data;
    final content = summary ?? yearSummary(inputs);
    final best = data.filmOfYear;
    // Arrivé du film de l'année : on reprend son image où elle en était,
    // son texte s'efface, la bannière glisse à gauche, puis le récap
    // s'installe dans la place libérée.
    final entry = WrappedEntry.of(context);
    final joined = WrappedClock.motionOf(context) &&
        content.continuesFilmOfYear &&
        entry?.from == 'film-of-year' &&
        best != null;
    final d = joined ? AppWrapped.recapJoin : 0.0;
    final shift = joined
        ? WrappedClock.at(context, .4,
            length: AppWrapped.recapShift, curve: Curves.easeInOutCubic)
        : 1.0;
    final leave = joined ? 1 - WrappedClock.at(context, 0, length: .6) : 0.0;
    final startScale =
        1 + AppWrapped.kenBurns * 1.4 * (joined ? entry!.progress : 0);
    return LayoutBuilder(builder: (context, box) {
      // En vertical (story), une page composée pour le vertical.
      if (box.maxHeight > box.maxWidth || WrappedStoryLayout.of(context)) {
        return _StoryPage(inputs: inputs, kind: content.kind);
      }
      return _landscape(
          context, content, best, joined, d, shift, leave, startScale);
    });
  }

  Widget _landscape(
      BuildContext context,
      WrappedSummary content,
      ({ViewingEvent event, int rating})? best,
      bool joined,
      double d,
      double shift,
      double leave,
      double startScale) {
    final data = inputs.data;
    final stats = data.stats;
    return _Frame(builder: (context, size, type) {
      final portrait = size.height > size.width;
      final posters = content.posters;
      final header = [
        if (inputs.userName case final name?) name,
        '${data.year}',
      ].join(' · ');
      Widget number((String, String) n, double at) => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                WrappedText(n.$1, style: type.mid, at: at + d, maxLines: 1),
                WrappedText(n.$2, style: type.small, at: at + d + .2),
              ]);
      final numbers = content.numbers.take(4).toList();
      final details = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            WrappedText(content.label, style: type.small, at: 1 + d),
            WrappedText(content.headline,
                style: type.mid.copyWith(
                    fontSize: type.mid.fontSize! * (portrait ? 1.2 : 1)),
                at: 1.4 + d,
                maxLines: 2),
            if (content.sub case final sub?)
              WrappedText(sub,
                  style: type.small.copyWith(color: AppColors.textPrimary),
                  at: 1.8 + d),
            if (posters.isNotEmpty) ...[
              SizedBox(height: size.height * .03),
              Row(children: [
                for (final (n, image) in posters.indexed) ...[
                  if (n > 0) const SizedBox(width: AppSpacing.xs),
                  Expanded(
                    child: Opacity(
                      opacity: WrappedClock.at(context, 2.4 + d + n * .3),
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
            ],
            for (var row = 0; row < numbers.length; row += 2) ...[
              SizedBox(height: size.height * (row == 0 ? .035 : .025)),
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Expanded(child: number(numbers[row], 4 + row * .3)),
                Expanded(
                    child: row + 1 < numbers.length
                        ? number(numbers[row + 1], 4.3 + row * .3)
                        : const SizedBox()),
              ]),
            ],
            // Le pied de page : le logo à gauche, l'année à droite.
            SizedBox(height: size.height * .05),
            Opacity(
              opacity: WrappedClock.at(context, 5.2 + d),
              child: Row(children: [
                KinosWordmark(width: size.width * AppWrapped.storyLogo * .5),
                const Spacer(),
                Text(header,
                    style: type.small.copyWith(color: AppColors.textPrimary)),
              ]),
            ),
          ]);
      final banner = content.banner == null
          ? const ColoredBox(color: AppColors.heroFallback)
          : WrappedImage(content.banner);
      // L'image reste visible sur [reach] de la diapo : le dégradé vers le
      // noir couvre toute la diapo et atteint le noir plein bien avant le
      // bord de l'image, décalée vers la gauche. Aucun bord d'image ne
      // reste visible.
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
        // L'image garde la taille du plein cadre et glisse simplement vers
        // la gauche (vers le haut en vertical) ; le dégradé noir couvre ce
        // qui dépasse. Aucun recadrage pendant le mouvement.
        Positioned.fill(
          child: ClipRect(
            child: Transform.translate(
              offset: portrait
                  ? Offset(0, -size.height * (1 - reach) * .5 * shift)
                  : Offset(-size.width * (1 - reach) * .5 * shift, 0),
              child: joined
                  ? Transform.scale(
                      scale: startScale + (1 - startScale) * shift,
                      child: banner)
                  : KenBurns(child: banner),
            ),
          ),
        ),
        if (joined && shift < 1) WrappedScrim(opacity: 1 - shift * shift),
        Positioned.fill(
            child: IgnorePointer(
                child: Opacity(
                    opacity: shift,
                    child: DecoratedBox(
                        decoration: BoxDecoration(gradient: fade))))),
        // Le texte du film de l'année, tel qu'on le quitte, qui s'efface.
        if (joined && leave > 0 && best != null)
          Opacity(
            opacity: leave,
            child: WrappedTextBlock(children: [
              WrappedText('Votre film de l\'année',
                  style: type.cap, at: -99, caps: true),
              SizedBox(height: size.height * .025),
              WrappedText(best.event.title,
                  style: type.big, at: -99, maxLines: 2),
              SizedBox(height: size.height * .025),
              WrappedText(
                  '${formatStars(best.rating)} · parmi '
                  '${_films(stats.ratings.fold(0, (a, b) => a + b))} notés cette année.',
                  style: type.small,
                  at: -99),
            ]),
          ),
        Positioned(
          left: portrait ? pad : size.width * .56,
          right: pad,
          bottom: pad,
          top: portrait ? size.height * .4 : pad * 2,
          // Un titre sur deux lignes peut manquer de place en story : le
          // bloc rétrécit plutôt que de déborder.
          // Réduit, il reste calé à droite : l'espace libre passe côté
          // image, jamais au bord de l'écran.
          child: Align(
              alignment:
                  portrait ? Alignment.bottomLeft : Alignment.bottomRight,
              child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment:
                      portrait ? Alignment.bottomLeft : Alignment.bottomRight,
                  child: SizedBox(
                      width: portrait
                          ? size.width - pad * 2
                          : size.width * .44 - pad,
                      child: details))),
        ),
      ];
    });
  }
}

/// Les pages d'un export : le récap de l'année, ceux des trois actes, et
/// toutes les diapos (sauf le récap, déjà là), dans l'ordre du Wrapped.
List<WrappedPage> wrappedExportPages(
  WrappedInputs w,
  List<WrappedSlide> slides, {
  required bool year,
  required bool acts,
  required bool allSlides,
}) =>
    [
      if (year)
        WrappedPage(
            file: '00-recap',
            seconds: AppWrapped.recap,
            summary: true,
            builder: (_) => WrappedRecap(inputs: w)),
      if (acts) ...[
        WrappedPage(
            file: '01-acte-1-le-temps',
            seconds: AppWrapped.recap,
            summary: true,
            builder: (_) => WrappedRecap(inputs: w, summary: timeSummary(w))),
        WrappedPage(
            file: '02-acte-2-les-gouts',
            seconds: AppWrapped.recap,
            summary: true,
            builder: (_) => WrappedRecap(inputs: w, summary: tasteSummary(w))),
        WrappedPage(
            file: '03-acte-4-vous',
            seconds: AppWrapped.recap,
            summary: true,
            builder: (_) => WrappedRecap(inputs: w, summary: filmsSummary(w))),
      ],
      if (allSlides)
        for (final (i, slide) in slides.indexed)
          if (slide.id != 'recap')
            WrappedPage(
                file: '${10 + i}-${slide.id}',
                seconds: slide.seconds,
                builder: slide.builder),
    ];

// ---------------------------------------------------------------------------
// Quand vous regardez, le rythme des séries, les séries terminées, le
// profil et l'an prochain
// ---------------------------------------------------------------------------

const _weekdays = [
  'lundi',
  'mardi',
  'mercredi',
  'jeudi',
  'vendredi',
  'samedi',
  'dimanche'
];

/// « 22 h – 1 h » : la tranche de trois heures la plus regardée.
String _hourRange(int start) => '$start h – ${(start + 3) % 24} h';

/// Quand vous regardez : une horloge de vingt-quatre heures, la tranche la
/// plus regardée en blanc plein.
class _WhenSlide extends StatelessWidget {
  const _WhenSlide({required this.inputs, required this.hours});
  final WrappedInputs inputs;
  final WrappedHours hours;

  @override
  Widget build(BuildContext context) {
    final peak = peakHour(hours);
    final day = _weekdays[peakWeekday(hours)];
    final weekend = (weekendShare(hours) * 100).round();
    final grow = WrappedClock.at(context, .8, length: 2.4);
    return _Frame(
        builder: (context, size, type) => [
              Align(
                alignment: const Alignment(.62, 0),
                child: SizedBox.square(
                  dimension: size.shortestSide * .62,
                  child: CustomPaint(
                      painter: _HourDial(
                          hours: hours.hours,
                          peak: peak,
                          grow: grow,
                          ink: AppColors.textPrimary,
                          label: type.cap)),
                ),
              ),
              WrappedTextBlock(widthFraction: .45, children: [
                WrappedText('Quand vous regardez',
                    style: type.cap, at: .4, caps: true),
                SizedBox(height: size.height * .025),
                WrappedText(_hourRange(peak), style: type.big, at: 1.4),
                SizedBox(height: size.height * .025),
                WrappedText('Votre heure, le plus souvent le $day.',
                    style: type.small, at: 3),
                SizedBox(height: size.height * .015),
                WrappedText('$weekend % de vos séances le week-end.',
                    style: type.small, at: 4.2),
              ]),
            ]);
  }
}

class _HourDial extends CustomPainter {
  _HourDial(
      {required this.hours,
      required this.peak,
      required this.grow,
      required this.ink,
      required this.label});
  final List<int> hours;
  final int peak;
  final double grow;
  final Color ink;
  final TextStyle label;

  bool _inPeak(int h) => (h - peak) % 24 < 3;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.shortestSide / 2;
    final inner = radius * .5, outer = radius * .86;
    final top = hours.fold(0, (a, b) => a > b ? a : b);
    final width = radius * .045;
    for (var h = 0; h < 24; h++) {
      // Minuit en haut, comme une horloge.
      final angle = h / 24 * 2 * math.pi - math.pi / 2;
      final direction = Offset(math.cos(angle), math.sin(angle));
      final value = top == 0 ? 0.0 : hours[h] / top * grow;
      final length = inner + (outer - inner) * math.max(.04, value);
      canvas.drawLine(
          center + direction * inner,
          center + direction * outer,
          Paint()
            ..color = ink.withValues(alpha: .1)
            ..strokeWidth = width
            ..strokeCap = StrokeCap.round);
      canvas.drawLine(
          center + direction * inner,
          center + direction * length,
          Paint()
            ..color = ink.withValues(alpha: _inPeak(h) ? 1 : .4)
            ..strokeWidth = width
            ..strokeCap = StrokeCap.round);
      if (h % 6 == 0) {
        final text = TextPainter(
            text: TextSpan(
                text: '$h h',
                style: label.copyWith(color: ink.withValues(alpha: .6))),
            textDirection: ui.TextDirection.ltr)
          ..layout();
        text.paint(
            canvas,
            center +
                direction * (radius * .98) -
                Offset(text.width / 2, text.height / 2));
      }
    }
  }

  @override
  bool shouldRepaint(_HourDial old) =>
      old.grow != grow || old.peak != peak || old.hours != hours;
}

/// Votre rythme : la saison avalée le plus vite.
class _PaceSlide extends StatelessWidget {
  const _PaceSlide({required this.inputs, required this.pace});
  final WrappedInputs inputs;
  final WrappedPace pace;

  @override
  Widget build(BuildContext context) {
    final p = pace;
    final when = p.days == 1 ? 'en une seule journée' : 'en ${p.days} jours';
    final perDay = p.episodes / p.days;
    return _Frame(
        builder: (context, size, type) => [
              KenBurns(
                  child:
                      WrappedImage(inputs.art['series:${p.series}']?.backdrop)),
              const WrappedScrim(),
              WrappedTextBlock(children: [
                WrappedText('Votre rythme',
                    style: type.cap, at: .4, caps: true),
                SizedBox(height: size.height * .025),
                WrappedText('${p.episodes} épisodes', style: type.big, at: 1.4),
                SizedBox(height: size.height * .025),
                WrappedText('$when : la saison ${p.season} de ${p.series}.',
                    style: type.small, at: 3),
                if (p.days > 1) ...[
                  SizedBox(height: size.height * .015),
                  WrappedText('Près de ${perDay.round()} épisodes par jour.',
                      style: type.small, at: 4.2),
                ],
              ]),
            ]);
  }
}

/// Les séries terminées : leurs affiches en rangée, qui entrent une à une.
class _FinishedSlide extends StatelessWidget {
  const _FinishedSlide({required this.inputs});
  final WrappedInputs inputs;

  @override
  Widget build(BuildContext context) {
    final finished = inputs.finished;
    final count = finished.length;
    final posters = [
      for (final f in finished)
        if (inputs.art['series:${f.name}']?.poster case final image?) image
    ].take(5).toList();
    final longest = finished.first;
    final backdrops = [
      for (final f in finished)
        if (inputs.art['series:${f.name}']?.backdrop case final image?) image
    ];
    return _Frame(
        builder: (context, size, type) => [
              CyclingBackdrops(backdrops),
              const WrappedScrim(),
              if (posters.isNotEmpty)
                Align(
                  alignment: const Alignment(.85, 0),
                  child: SizedBox(
                    width: size.width * .5,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        for (final (i, image) in posters.indexed)
                          Builder(builder: (context) {
                            final t = WrappedClock.at(context, .8 + i * .35);
                            return Opacity(
                              opacity: t,
                              child: Transform.translate(
                                offset: Offset(0, size.height * .04 * (1 - t)),
                                child: Padding(
                                  padding:
                                      EdgeInsets.only(left: size.width * .01),
                                  child: SizedBox(
                                    width: size.width * .085,
                                    child: AspectRatio(
                                      aspectRatio: AppMedia.posterAspectRatio,
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(
                                            AppSpacing.xxs),
                                        child: KinosImage(
                                            image: image, disableBlur: true),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            );
                          }),
                      ],
                    ),
                  ),
                ),
              WrappedTextBlock(widthFraction: .42, children: [
                WrappedText('Allé jusqu\'au bout',
                    style: type.cap, at: .4, caps: true),
                SizedBox(height: size.height * .025),
                WrappedText('$count ${count > 1 ? 'séries' : 'série'}',
                    style: type.big, at: 1.4),
                SizedBox(height: size.height * .025),
                WrappedText(
                    count > 1
                        ? 'terminées cette année, dont ${longest.name} '
                            'et ses ${longest.episodes} épisodes.'
                        : '${longest.name}, terminée cette année : '
                            '${longest.episodes} épisodes.',
                    style: type.small,
                    at: 3),
              ]),
            ]);
  }
}

/// Votre profil de spectateur : son nom en très grand, sur la couleur du
/// film de l'année.
class _ProfileSlide extends StatelessWidget {
  const _ProfileSlide({required this.inputs});
  final WrappedInputs inputs;

  @override
  Widget build(BuildContext context) {
    final profile = inputs.data.profile;
    final tint = storyColor(inputs.tint(inputs.data.filmOfYear?.event));
    final glow = WrappedClock.at(context, 0, length: 4);
    return _Frame(
        builder: (context, size, type) => [
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: const Alignment(-.4, -.2),
                    radius: 1.2,
                    colors: [
                      Color.lerp(AppColors.scrim, tint, .55 * glow)!,
                      AppColors.scrim,
                    ],
                  ),
                ),
              ),
              WrappedTextBlock(widthFraction: .8, children: [
                WrappedText('Votre profil de spectateur',
                    style: type.cap, at: .5, caps: true),
                SizedBox(height: size.height * .03),
                WrappedText(profile.title,
                    style:
                        type.big.copyWith(fontSize: type.big.fontSize! * 1.35),
                    at: 1.6,
                    maxLines: 2),
                SizedBox(height: size.height * .03),
                WrappedText(profile.line,
                    style: type.mid, at: 3.2, maxLines: 2),
                for (final (i, fact) in profile.facts.indexed) ...[
                  SizedBox(height: size.height * .015),
                  WrappedText(fact, style: type.small, at: 4.6 + i * .8),
                ],
              ]),
            ]);
  }
}

/// L'an prochain : trois films de la bibliothèque, pas encore vus, que vos
/// goûts recommandent.
class _NextYearSlide extends StatelessWidget {
  const _NextYearSlide({required this.inputs});
  final WrappedInputs inputs;

  @override
  Widget build(BuildContext context) {
    final picks = inputs.nextYear;
    final next = inputs.data.year + 1;
    return _Frame(
        builder: (context, size, type) => [
              CyclingBackdrops([
                for (final pick in picks)
                  if (pick.backdrop case final image?) image
              ]),
              const WrappedScrim(),
              Align(
                alignment: const Alignment(.82, 0),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final (i, pick) in picks.indexed)
                      Builder(builder: (context) {
                        final t = WrappedClock.at(context, 1 + i * .5);
                        return Opacity(
                          opacity: t,
                          child: Transform.translate(
                            offset: Offset(0, size.height * .05 * (1 - t)),
                            child: Padding(
                              padding: EdgeInsets.only(left: size.width * .02),
                              child: SizedBox(
                                width: size.width * .12,
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    AspectRatio(
                                      aspectRatio: AppMedia.posterAspectRatio,
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(
                                            AppSpacing.xxs),
                                        child: ColoredBox(
                                          color: AppColors.surface,
                                          child: KinosImage(
                                              image: pick.poster,
                                              disableBlur: true),
                                        ),
                                      ),
                                    ),
                                    SizedBox(height: size.height * .012),
                                    Text(pick.title,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: type.small.copyWith(
                                            color: AppColors.textPrimary)),
                                    if (pick.year != null)
                                      Text('${pick.year}', style: type.cap),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      }),
                  ],
                ),
              ),
              WrappedTextBlock(widthFraction: .38, children: [
                WrappedText('Pour $next', style: type.cap, at: .4, caps: true),
                SizedBox(height: size.height * .025),
                WrappedText('Par où commencer',
                    style: type.big, at: 1.4, maxLines: 2),
                SizedBox(height: size.height * .025),
                WrappedText(
                    'Trois films de votre bibliothèque, pas encore vus, '
                    'choisis d\'après vos goûts.',
                    style: type.small,
                    at: 3),
              ]),
            ]);
  }
}

/// Ce qui habille la story d'un archétype : son image, sa couleur, son
/// chiffre en filigrane, ses chiffres du bas et, pour l'explorateur, une
/// grille de films.
typedef _ArchetypeLook = ({
  ImageData? image,
  Color tint,

  /// Un fond propre à l'archétype (la nuit, le papier), sinon celui de son
  /// film.
  Color? ground,
  String watermark,
  List<(String, String)> numbers,
  List<ImageData> grid,
});

_ArchetypeLook _archetypeLook(WrappedInputs w) {
  final data = w.data;
  final stats = data.stats;
  final profile = data.profile;
  final best = data.filmOfYear?.event;
  final bestNumber = (best?.title ?? '${stats.films}', 'film de l\'année');
  String percent(double share) => '${(share * 100).round()} %';
  final topSeries = data.series.firstOrNull?.name;
  final seriesArt = topSeries == null ? null : w.art['series:$topSeries'];
  final seriesTint = topSeries == null ? null : w.tints['series:$topSeries'];

  ViewingEvent? lead = best;
  ImageData? image;
  Color? tint;
  var watermark = '${stats.films}';
  var numbers = <(String, String)>[];
  var grid = <ImageData>[];

  switch (profile.id) {
    case 'night':
      final hours = data.hours!;
      // La séance commencée le plus tard dans la nuit : la journée bascule
      // à 4 h, une séance à 2 h passe après une à 23 h 50.
      int lateness(DateTime at) => ((at.hour + 20) % 24) * 60 + at.minute;
      final timed = [
        for (final e in data.timeline)
          if (e.sources.contains(ViewingSource.kinos)) e
      ];
      lead = timed.isEmpty
          ? best
          : timed.reduce((a, b) => lateness(b.at) > lateness(a.at) ? b : a);
      watermark = '${peakHour(hours)}H';
      numbers = [
        (percent(lateShare(hours)), 'après 23 h'),
        if (lead != null && lead != best)
          (
            '${lead.at.hour} H ${lead.at.minute.toString().padLeft(2, '0')}',
            'votre plus tardive'
          )
        else
          (_weekdays[peakWeekday(hours)].substring(0, 3), 'votre soir'),
        bestNumber,
      ];
    case 'weekend':
      final hours = data.hours!;
      final saturday = hours.weekdays[5] >= hours.weekdays[6];
      lead = data.timeline
              .where((e) => e.at.weekday == (saturday ? 6 : 7))
              .lastOrNull ??
          best;
      watermark = saturday ? 'SAM.' : 'DIM.';
      numbers = [
        (percent(weekendShare(hours)), 'le week-end'),
        ('${peakHour(hours)} h', 'votre heure'),
        bestNumber,
      ];
    case 'binge':
      image = seriesArt?.poster;
      tint = seriesTint;
      final run = data.marathon?.episodes ?? data.pace?.episodes;
      watermark = '${run ?? stats.episodes}';
      numbers = [
        (percent(bingeShare(data.allSeries) ?? 0), 'en binge'),
        if (run != null) ('$run', 'd\'affilée'),
        (topSeries ?? '${stats.series}', 'série de l\'année'),
      ];
    case 'series':
      image = seriesArt?.poster;
      tint = seriesTint;
      final seconds = [for (final s in data.allSeries) ...s.episodes]
          .fold(0, (sum, e) => sum + e.seconds);
      watermark = '${(seconds / 3600).round()}H';
      numbers = [
        ('${stats.series}', 'séries'),
        ('${stats.episodes}', 'épisodes'),
        (topSeries ?? '', 'série de l\'année'),
      ];
    case 'explorer':
      // Un film par genre, les six premiers genres.
      final seen = <String>{};
      for (final e in data.timeline.reversed) {
        final genre = e.genres.firstOrNull;
        final poster = w.poster(e);
        if (genre == null || poster == null || !seen.add(genre)) continue;
        grid.add(poster);
        if (grid.length == 6) break;
      }
      watermark = '${stats.genres.length}';
      numbers = [
        ('${stats.genres.length}', 'genres'),
        if (stats.genres.lastOrNull case final rare?)
          (rare.name, 'le plus rare'),
        bestNumber,
      ];
    case 'world':
      final languages = <String, int>{};
      for (final e in data.timeline) {
        final language =
            e.tmdbId == null ? null : data.facts[e.tmdbId]?.language;
        if (language != null && language != 'en') {
          languages[language] = (languages[language] ?? 0) + 1;
        }
      }
      final top = languages.entries
          .fold<MapEntry<String, int>?>(
              null, (a, b) => a == null || b.value > a.value ? b : a)
          ?.key;
      lead = data.timeline.reversed.firstWhere(
          (e) => e.tmdbId != null && data.facts[e.tmdbId]?.language == top,
          orElse: () => best ?? data.timeline.last);
      watermark = (top ?? '').toUpperCase();
      numbers = [
        (profile.facts.first.split(' ').take(2).join(' '), 'non anglophones'),
        ((top ?? '').toUpperCase(), 'votre langue'),
        bestNumber,
      ];
    case 'classic':
      lead = data.voyage.lastOrNull ?? best;
      watermark = '${data.medianYear ?? ''}';
      numbers = [
        ('${data.medianYear ?? ''}', 'film moyen'),
        ('${data.voyage.lastOrNull?.year ?? ''}', 'le plus vieux'),
        if (stats.decade case final d?)
          ('${d.decade % 100}\'S', 'votre décennie'),
      ];
    case 'faithful':
      final most = stats.mostSeen;
      lead = most?.event ?? best;
      watermark = '×${most?.times ?? 2}';
      numbers = [
        ('×${most?.times ?? 2}', most?.event.title ?? 'le plus revu'),
        (profile.facts.first.split(' ').first, 'films revus'),
        bestNumber,
      ];
    default:
      watermark = '${stats.films}';
      numbers = [
        ('${stats.films}', 'films'),
        if (stats.episodes > 0) ('${stats.episodes}', 'épisodes'),
        bestNumber,
      ];
  }
  return (
    image: image ?? (lead == null ? null : w.poster(lead)),
    tint: tint ?? w.tint(lead),
    ground: switch (profile.id) {
      'night' => AppWrapped.nightGround,
      'classic' => AppWrapped.storyPaper,
      _ => null,
    },
    watermark: watermark,
    numbers: numbers,
    grid: grid,
  );
}

/// Le fond d'une story : la couleur du film en nappes douces, une plus
/// profonde, une plus claire, une voisine, posées en larges taches qui se
/// fondent. [seed] varie leur place d'une page à l'autre.
class StoryMesh extends CustomPainter {
  StoryMesh({required this.ground, required this.seed});
  final Color ground;
  final int seed;

  // Profil de chaque tache, du centre au bord : une courbe en S, sans
  // anneau.
  static const _stops = [0.0, .25, .5, .75, 1.0];
  static const _falloff = [1.0, .85, .5, .15, 0.0];

  List<Color> get colors {
    final hsl = HSLColor.fromColor(ground);
    HSLColor shift(double hue, double saturation, double lightness) => hsl
        .withHue((hsl.hue + hue) % 360)
        .withSaturation((hsl.saturation * saturation).clamp(0.0, 1.0))
        .withLightness(lightness.clamp(0.0, 1.0));
    return [
      shift(0, 1.1, hsl.lightness * AppWrapped.meshDeep).toColor(),
      shift(AppWrapped.meshHueShift * .5, .9,
              hsl.lightness + AppWrapped.meshLift)
          .toColor(),
      shift(-AppWrapped.meshHueShift, 1, hsl.lightness * .8).toColor(),
      shift(0, 1.1, hsl.lightness * AppWrapped.meshDeep).toColor(),
      shift(AppWrapped.meshHueShift * .25, .8,
              hsl.lightness + AppWrapped.meshLift * .7)
          .toColor(),
    ];
  }

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = ground);
    final random = math.Random(seed);
    final radius = size.longestSide * AppWrapped.meshRadius;
    for (final color in colors) {
      final center = Offset(size.width * (.1 + random.nextDouble() * .8),
          size.height * (.1 + random.nextDouble() * .8));
      final r = radius * (.7 + random.nextDouble() * .6);
      canvas.drawCircle(
          center,
          r,
          Paint()
            ..shader = ui.Gradient.radial(
                center,
                r,
                [
                  for (final a in _falloff)
                    color.withValues(alpha: a * AppWrapped.meshStrength)
                ],
                _stops));
    }
  }

  @override
  bool shouldRepaint(StoryMesh old) => old.ground != ground || old.seed != seed;
}
