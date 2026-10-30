import 'package:flutter/cupertino.dart';

/// Une famille vectorielle commune aux commandes cinéma de Kinos.
abstract final class AppIcons {
  static const films = CupertinoIcons.film;
  static const filmsSelected = CupertinoIcons.film_fill;
  static const series = CupertinoIcons.tv;
  static const seriesSelected = CupertinoIcons.tv_fill;
  static const requests = CupertinoIcons.paperplane;
  static const requestsSelected = CupertinoIcons.paperplane_fill;
  static const activity = CupertinoIcons.chart_bar;
  static const activitySelected = CupertinoIcons.chart_bar_fill;
  static const settings = CupertinoIcons.gear_alt;
  static const favourite = CupertinoIcons.heart;
  static const favouriteSelected = CupertinoIcons.heart_fill;
  static const watched = CupertinoIcons.checkmark;
  static const watchedCircle = CupertinoIcons.checkmark_circle;
  static const watchedSelected = CupertinoIcons.checkmark_circle_fill;
  static const play = CupertinoIcons.play_fill;
  static const pause = CupertinoIcons.pause_fill;
  static const stop = CupertinoIcons.stop_fill;
  static const previous = CupertinoIcons.backward_end;
  static const next = CupertinoIcons.forward_end;
  static const rewind10 = CupertinoIcons.gobackward_10;
  static const forward10 = CupertinoIcons.goforward_10;
  static const subtitles = CupertinoIcons.captions_bubble;
  static const audio = CupertinoIcons.music_note_2;
  static const crop = CupertinoIcons.crop;
  static const speed = CupertinoIcons.speedometer;
  static const quality = CupertinoIcons.slider_horizontal_3;
  static const muted = CupertinoIcons.speaker_slash;
  static const volumeLow = CupertinoIcons.speaker_1;
  static const volumeHigh = CupertinoIcons.speaker_3;
  static const fullscreen = CupertinoIcons.arrow_up_left_arrow_down_right;
  static const exitFullscreen = CupertinoIcons.arrow_down_right_arrow_up_left;
  static const more = CupertinoIcons.ellipsis;
}
