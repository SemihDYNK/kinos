part of 'wrapped_slides.dart';

// ---------------------------------------------------------------------------
// Deuxième vague : l'an dernier, le monde, les records, la chaîne, l'anime,
// les séries laissées de côté, celles qui reviennent, l'âme sœur.
// ---------------------------------------------------------------------------

/// « 2 h 58 », « 1 h », « 46 min ».
String _runtime(int seconds) {
  final h = seconds ~/ 3600;
  final m = (seconds % 3600) ~/ 60;
  if (h == 0) return '$m min';
  return m == 0 ? '$h h' : '$h h ${m.toString().padLeft(2, '0')}';
}

/// « +34 % », « −12 % ».
String _delta(num now, num before) {
  final change = ((now - before) / before * 100).round();
  return change >= 0 ? '+$change %' : '−${change.abs()} %';
}

String _plural(int n, String one, String many) => '$n ${n > 1 ? many : one}';

/// Cette année face à l'an dernier.
class _VersusSlide extends StatelessWidget {
  const _VersusSlide(
      {required this.inputs, required this.versus, required this.images});
  final WrappedInputs inputs;
  final WrappedVersus versus;
  final List<ImageData> images;

  @override
  Widget build(BuildContext context) {
    final v = versus;
    final last = inputs.data.year - 1;
    final change = (v.seconds - v.lastSeconds) / v.lastSeconds;
    final headline =
        change.abs() < .05 ? 'Autant' : _delta(v.seconds, v.lastSeconds);
    return _Frame(
        builder: (context, size, type) => [
              CyclingBackdrops(images),
              const WrappedScrim(),
              WrappedTextBlock(children: [
                WrappedText('Face à $last',
                    style: type.cap, at: .4, caps: true),
                SizedBox(height: size.height * .025),
                WrappedText(headline, style: type.big, at: 1.4),
                SizedBox(height: size.height * .025),
                WrappedText(
                    '${formatHours(v.seconds)} devant l\'écran cette année, '
                    'contre ${formatHours(v.lastSeconds)} en $last.',
                    style: type.small,
                    at: 3),
                if (v.lastFilms > 0) ...[
                  SizedBox(height: size.height * .015),
                  WrappedText('${_films(v.films)}, contre ${v.lastFilms}.',
                      style: type.small, at: 4),
                ],
                if (v.genre != null && v.lastGenre != null) ...[
                  SizedBox(height: size.height * .015),
                  WrappedText(
                      v.genre == v.lastGenre
                          ? 'Toujours fidèle au genre ${v.genre!.toLowerCase()}.'
                          : 'Votre genre passe de ${v.lastGenre!.toLowerCase()} '
                              'à ${v.genre!.toLowerCase()}.',
                      style: type.small,
                      at: 5),
                ],
                if (v.newDirectors > 0) ...[
                  SizedBox(height: size.height * .015),
                  WrappedText(
                      '${_plural(v.newDirectors, 'réalisateur découvert', 'réalisateurs découverts')}.',
                      style: type.small,
                      at: 6),
                ],
              ]),
            ]);
  }
}

/// Le tour du monde : les pays de vos films, en colonne.
class _WorldSlide extends StatelessWidget {
  const _WorldSlide(
      {required this.inputs, required this.world, required this.images});
  final WrappedInputs inputs;
  final WrappedWorld world;
  final List<ImageData> images;

  @override
  Widget build(BuildContext context) {
    final countries = world.countries;
    final shown = countries.take(AppWrapped.worldCountries).toList();
    final rest = countries.length - shown.length;
    return _Frame(
        builder: (context, size, type) => [
              CyclingBackdrops(images),
              const WrappedScrim(),
              WrappedTextBlock(children: [
                WrappedText('Votre tour du monde',
                    style: type.cap, at: .4, caps: true),
                SizedBox(height: size.height * .025),
                WrappedText(_plural(countries.length, 'pays', 'pays'),
                    style: type.big, at: 1.4),
                SizedBox(height: size.height * .03),
                for (final (i, c) in shown.indexed) ...[
                  WrappedText('${countryName(c.code)}  ·  ${_films(c.films)}',
                      style: i == 0 ? type.mid : type.small, at: 2.6 + i * .45),
                  SizedBox(height: size.height * .008),
                ],
                if (rest > 0) ...[
                  SizedBox(height: size.height * .01),
                  WrappedText(
                      'Et ${_plural(rest, 'autre pays', 'autres pays')}, '
                      'jusqu\'à ${countryName(countries.last.code)}.',
                      style: type.small,
                      at: 2.6 + shown.length * .45 + .6),
                ],
              ]),
            ]);
  }
}

/// Les records : le plus long, le plus court, le plus revu.
class _RecordsSlide extends StatelessWidget {
  const _RecordsSlide({required this.inputs, required this.records});
  final WrappedInputs inputs;
  final WrappedRecords records;

  @override
  Widget build(BuildContext context) {
    final r = records;
    final rows = [
      ('Le plus long', r.longest.title, _runtime(r.longest.runtimeSeconds!)),
      ('Le plus court', r.shortest.title, _runtime(r.shortest.runtimeSeconds!)),
      if (r.mostSeen case final e?)
        ('Le plus revu', e.title, '${r.times} fois'),
    ];
    return _Frame(
        builder: (context, size, type) => [
              CyclingBackdrops([
                for (final e in [
                  r.longest,
                  r.shortest,
                  if (r.mostSeen case final e?) e
                ])
                  if (inputs.backdrop(e) case final image?) image
              ]),
              const WrappedScrim(),
              WrappedTextBlock(children: [
                WrappedText('Vos records', style: type.cap, at: .4, caps: true),
                for (final (i, (label, title, value)) in rows.indexed) ...[
                  SizedBox(height: size.height * .045),
                  WrappedText(label.toUpperCase(),
                      style: type.cap, at: 1.2 + i * 1.3, caps: true),
                  SizedBox(height: size.height * .008),
                  WrappedText(title,
                      style: type.mid, at: 1.5 + i * 1.3, maxLines: 2),
                  WrappedText(value, style: type.small, at: 1.9 + i * 1.3),
                ],
              ]),
            ]);
  }
}

/// La chaîne de l'année.
class _ChannelSlide extends StatelessWidget {
  const _ChannelSlide({required this.inputs, required this.channel});
  final WrappedInputs inputs;
  final WrappedChannel channel;

  @override
  Widget build(BuildContext context) {
    final c = channel;
    final names = c.series.take(3).toList();
    return _Frame(
        builder: (context, size, type) => [
              CyclingBackdrops([
                for (final name in c.series)
                  if (inputs.art['series:$name']?.backdrop case final image?)
                    image
              ]),
              const WrappedScrim(),
              WrappedTextBlock(children: [
                WrappedText('Votre chaîne de l\'année',
                    style: type.cap, at: .4, caps: true),
                SizedBox(height: size.height * .025),
                WrappedText(c.name, style: type.big, at: 1.4, maxLines: 2),
                SizedBox(height: size.height * .025),
                WrappedText(
                    '${_plural(c.episodes, 'épisode', 'épisodes')}, '
                    'de ${_list(names)}'
                    '${c.series.length > names.length ? ' et d\'autres' : ''}.',
                    style: type.small,
                    at: 3),
              ]),
            ]);
  }
}

/// La part d'anime parmi les épisodes.
class _AnimeSlide extends StatelessWidget {
  const _AnimeSlide(
      {required this.inputs,
      required this.share,
      required this.top,
      required this.episodes});
  final WrappedInputs inputs;
  final double share;
  final String top;
  final int episodes;

  @override
  Widget build(BuildContext context) => _Frame(
      builder: (context, size, type) => [
            KenBurns(child: WrappedImage(inputs.art['series:$top']?.backdrop)),
            const WrappedScrim(),
            WrappedTextBlock(children: [
              WrappedText('Côté anime', style: type.cap, at: .4, caps: true),
              SizedBox(height: size.height * .025),
              WrappedText('${(share * 100).round()} %',
                  style: type.big, at: 1.4),
              SizedBox(height: size.height * .025),
              WrappedText('de vos épisodes étaient des anime.',
                  style: type.small, at: 3),
              SizedBox(height: size.height * .015),
              WrappedText(
                  'En tête : $top, ${_plural(episodes, 'épisode', 'épisodes')}.',
                  style: type.small,
                  at: 4.2),
            ]),
          ]);
}

/// Les séries commencées cette année puis laissées de côté. Sans
/// reproche : elles attendent.
class _AbandonedSlide extends StatelessWidget {
  const _AbandonedSlide({required this.inputs});
  final WrappedInputs inputs;

  @override
  Widget build(BuildContext context) {
    final shows = inputs.abandoned;
    final shown = shows.take(3).toList();
    String where(WrappedAbandoned a) => a.played == 0
        ? '${a.name}, à peine commencée'
        : '${a.name}, arrêtée à l\'épisode ${a.played} sur ${a.total}';
    return _Frame(
        builder: (context, size, type) => [
              CyclingBackdrops([
                for (final a in shows)
                  if (inputs.art['series:${a.name}']?.backdrop
                      case final image?)
                    image
              ]),
              const WrappedScrim(),
              WrappedTextBlock(children: [
                WrappedText('Laissées en chemin',
                    style: type.cap, at: .4, caps: true),
                SizedBox(height: size.height * .025),
                WrappedText(_plural(shows.length, 'série', 'séries'),
                    style: type.big, at: 1.4),
                SizedBox(height: size.height * .025),
                for (final (i, a) in shown.indexed) ...[
                  WrappedText('${where(a)}.',
                      style: type.small, at: 2.8 + i * .6),
                  SizedBox(height: size.height * .008),
                ],
                SizedBox(height: size.height * .015),
                WrappedText(
                    shows.length > 1
                        ? 'Elles vous attendent.'
                        : 'Elle vous attend.',
                    style: type.mid,
                    at: 2.8 + shown.length * .6 + .8),
              ]),
            ]);
  }
}

/// Les séries de l'année qui reviennent : la prochaine saison annoncée.
class _ReturningSlide extends StatelessWidget {
  const _ReturningSlide({required this.inputs});
  final WrappedInputs inputs;

  @override
  Widget build(BuildContext context) {
    final shows = inputs.returning;
    final first = shows.first;
    final day = DateFormat('d MMMM y', _locale);
    final month = DateFormat('MMMM y', _locale);
    String season(WrappedReturning r) =>
        r.season == null ? 'la suite' : 'saison ${r.season}';
    final images = [
      for (final r in shows)
        if (r.backdrop ?? inputs.art['series:${r.title}']?.backdrop
            case final image?)
          image
    ];
    return _Frame(
        builder: (context, size, type) => [
              CyclingBackdrops(images),
              const WrappedScrim(),
              WrappedTextBlock(children: [
                WrappedText('Ce qui revient',
                    style: type.cap, at: .4, caps: true),
                SizedBox(height: size.height * .025),
                WrappedText(first.title, style: type.big, at: 1.4, maxLines: 2),
                SizedBox(height: size.height * .02),
                WrappedText(
                    '${season(first)[0].toUpperCase()}${season(first).substring(1)}, '
                    'le ${day.format(first.date)}.',
                    style: type.mid,
                    at: 2.6),
                for (final (i, r) in shows.skip(1).take(3).indexed) ...[
                  SizedBox(height: size.height * .012),
                  WrappedText(
                      '${r.title}, ${season(r)} · ${month.format(r.date)}',
                      style: type.small,
                      at: 3.8 + i * .5),
                ],
              ]),
            ]);
  }
}

/// L'âme sœur cinéphile : l'ami Letterboxd qui note comme vous.
class _SoulmateSlide extends ConsumerWidget {
  const _SoulmateSlide({required this.inputs, required this.soulmate});
  final WrappedInputs inputs;
  final WrappedSoulmate soulmate;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final me = ref.watch(letterboxdFriendsAccountProvider).valueOrNull;
    final s = soulmate;
    final gap = NumberFormat('0.0', _locale).format(s.gap);
    final posters = [
      for (final shared in s.shared)
        if (inputs.poster(shared.film) case final image?) (shared, image)
    ].take(AppWrapped.soulmatePosters).toList();
    return _Frame(builder: (context, size, type) {
      final avatar = size.height * AppWrapped.avatarFraction * 1.4;
      Widget face(String name, String? url, double at) => Opacity(
            opacity: WrappedClock.at(context, at, length: 1.2),
            child: ClipOval(
              child: SizedBox.square(
                dimension: avatar,
                child: url == null
                    ? ColoredBox(
                        color: AppColors.surface,
                        child: Center(
                            child: Text(name.isEmpty ? '' : name[0],
                                style: type.mid)))
                    : KinosImage(
                        image: ImageData(path: url, key: 'avatar:$url'),
                        disableBlur: true),
              ),
            ),
          );
      return [
        KenBurns(
            child: WrappedImage(s.shared.isEmpty
                ? null
                : inputs.backdrop(s.shared.first.film))),
        const WrappedScrim(),
        WrappedTextBlock(widthFraction: .8, children: [
          WrappedText('Votre âme sœur cinéphile',
              style: type.cap, at: .4, caps: true),
          SizedBox(height: size.height * .03),
          Row(mainAxisSize: MainAxisSize.min, children: [
            face(s.friend.name, s.friend.avatarUrl, 1),
            const SizedBox(width: AppSpacing.md),
            face(me?.username ?? '', me?.avatarUrl, 1.4),
          ]),
          SizedBox(height: size.height * .03),
          WrappedText(s.friend.name, style: type.big, at: 1.8, maxLines: 1),
          SizedBox(height: size.height * .025),
          WrappedText(
              '${_plural(s.shared.length, 'film noté', 'films notés')} en commun, '
              '$gap ${s.gap >= 2 ? 'étoiles' : 'étoile'} d\'écart en moyenne.',
              style: type.small,
              at: 3.2),
          if (posters.isNotEmpty) ...[
            SizedBox(height: size.height * .03),
            Row(mainAxisSize: MainAxisSize.min, children: [
              for (final (i, (shared, image)) in posters.indexed)
                Opacity(
                  opacity: WrappedClock.at(context, 4 + i * .3),
                  child: Padding(
                    padding: EdgeInsets.only(right: size.width * .01),
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      SizedBox(
                        width: size.height * .12,
                        child: AspectRatio(
                          aspectRatio: AppMedia.posterAspectRatio,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(AppSpacing.xxs),
                            child: KinosImage(image: image, disableBlur: true),
                          ),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xxs),
                      Text(
                          '${_starsNumber(shared.mine)} · ${_starsNumber(shared.theirs)}',
                          style: type.cap),
                    ]),
                  ),
                ),
            ]),
          ],
          if (s.opposite case final far?) ...[
            SizedBox(height: size.height * .03),
            WrappedText(
                'Votre opposé : ${far.name}, '
                '${NumberFormat('0.0', _locale).format(s.oppositeGap)} '
                'étoiles d\'écart.',
                style: type.small,
                at: 5.4),
          ],
        ]),
      ];
    });
  }
}
