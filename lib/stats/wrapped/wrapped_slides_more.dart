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

/// Les records : les affiches debout, chacune à la hauteur de sa durée,
/// qui montent depuis le bas ; le plus revu en dernier, si vous en avez un.
class _RecordsSlide extends StatelessWidget {
  const _RecordsSlide({required this.inputs, required this.records});
  final WrappedInputs inputs;
  final WrappedRecords records;

  @override
  Widget build(BuildContext context) {
    final r = records;
    final columns = [
      (r.longest, 'Le plus long'),
      if (r.mostSeen case final e? when e.runtimeSeconds != null)
        (e, 'Revu ${r.times} fois'),
      (r.shortest, 'Le plus court'),
    ];
    final longest = r.longest.runtimeSeconds!;
    final ground = storyColor(inputs.tint(r.longest));
    return _Frame(builder: (context, size, type) {
      final portrait = size.height > size.width;
      // La place des affiches : à droite en 16:9, en bas en story.
      final areaW = size.width * (portrait ? .84 : .46);
      final tallest = size.height * (portrait ? .42 : .6);
      final gap = size.width * .015;
      final ratio = AppMedia.posterAspectRatio;
      final total = columns.fold(
              0.0,
              (sum, c) =>
                  sum + tallest * c.$1.runtimeSeconds! / longest * ratio) +
          gap * (columns.length - 1);
      final scale = total > areaW ? areaW / total : 1.0;
      return [
        CustomPaint(painter: StoryMesh(ground: ground, seed: longest)),
        const WrappedGrain(opacity: AppWrapped.storyGrain),
        // En 16:9, les affiches occupent la moitié droite, centrées dans
        // l'espace que le texte laisse ; en story, le bas de l'image.
        Positioned(
          left: size.width * (portrait ? 0 : .46),
          right: size.width * (portrait ? 0 : .04),
          top: size.height * (portrait ? .45 : .1),
          bottom: size.height * (portrait ? .08 : .08),
          child: Align(
            alignment: portrait ? Alignment.bottomCenter : Alignment.center,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (final (i, (film, label)) in columns.indexed)
                  Builder(builder: (context) {
                    final grow = WrappedClock.at(context, 1.6 + i * .5,
                        length: 1.4, curve: Curves.easeOutCubic);
                    final h = tallest * scale * film.runtimeSeconds! / longest;
                    return Padding(
                      padding: EdgeInsets.only(left: i == 0 ? 0 : gap),
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                        SizedBox(
                          width: h * ratio,
                          height: h,
                          child: Align(
                            alignment: Alignment.bottomCenter,
                            child: ClipRRect(
                              borderRadius:
                                  BorderRadius.circular(AppSpacing.xxs),
                              child: SizedBox(
                                width: h * ratio,
                                height: h * grow,
                                child: inputs.poster(film) == null
                                    ? const ColoredBox(
                                        color: AppColors.heroFallback)
                                    : KinosImage(
                                        image: inputs.poster(film)!,
                                        alignment: Alignment.bottomCenter,
                                        disableBlur: true),
                              ),
                            ),
                          ),
                        ),
                        SizedBox(height: size.height * .015),
                        // Les légendes ne dépassent jamais leur affiche.
                        SizedBox(
                          width: h * ratio,
                          // Même hauteur pour toutes : les affiches gardent
                          // leurs pieds alignés.
                          height: type.mid.fontSize! * type.mid.height! +
                              type.cap.fontSize! * 1.6,
                          child: Opacity(
                            opacity: grow,
                            child: Column(
                                mainAxisAlignment: MainAxisAlignment.start,
                                children: [
                                  FittedBox(
                                      fit: BoxFit.scaleDown,
                                      child: Text(
                                          _runtime(film.runtimeSeconds!),
                                          style: type.mid)),
                                  FittedBox(
                                      fit: BoxFit.scaleDown,
                                      child: Text(label.toUpperCase(),
                                          style: type.cap)),
                                ]),
                          ),
                        ),
                      ]),
                    );
                  }),
              ],
            ),
          ),
        ),
        WrappedTextBlock(
            alignment:
                portrait ? const Alignment(-1, -.75) : Alignment.centerLeft,
            widthFraction: portrait ? .9 : .34,
            children: [
              WrappedText('Vos records', style: type.cap, at: .4, caps: true),
              SizedBox(height: size.height * .025),
              WrappedText(_runtime(longest), style: type.big, at: 1),
              SizedBox(height: size.height * .025),
              WrappedText('${r.longest.title}, votre plus long film.',
                  style: type.small, at: 2.4, maxLines: 2),
              SizedBox(height: size.height * .012),
              WrappedText(
                  'Le plus court : ${r.shortest.title}, '
                  '${_runtime(r.shortest.runtimeSeconds!)}.',
                  style: type.small,
                  at: 3.4,
                  maxLines: 2),
              if (r.mostSeen case final e?) ...[
                SizedBox(height: size.height * .012),
                WrappedText('${e.title}, revu ${r.times} fois.',
                    style: type.small, at: 4.4, maxLines: 2),
              ],
            ]),
      ];
    });
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
