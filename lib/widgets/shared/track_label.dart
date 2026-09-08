import 'package:flutter/material.dart';

import 'package:kinos/models/items/media_streams_model.dart';
import 'package:kinos/theme/app_theme.dart';
import 'package:kinos/util/localization_helper.dart';

/// Libellé d'une piste audio ou sous-titre, décomposé plutôt que le
/// `DisplayTitle` brut de Jellyfin (souvent une concaténation illisible,
/// ex. "Fre - AC3 - 5.1 - Default").
///
/// [primary] : langue, puis canaux et codec pour l'audio ("Français ·
/// 5.1 · E-AC3") — langue seule pour un sous-titre.
/// [secondaryFlags] : uniquement les drapeaux qui s'appliquent — Forcé,
/// Par défaut, SDH, et le conteneur pour les sous-titres — jamais une
/// liste à trous.
class TrackLabelInfo {
  final String primary;
  final List<String> secondaryFlags;

  const TrackLabelInfo({required this.primary, required this.secondaryFlags});

  String get secondaryLine => secondaryFlags.join(' · ');
}

TrackLabelInfo formatAudioTrackLabel(
    BuildContext context, AudioStreamModel stream) {
  if (stream.index == -1) {
    return TrackLabelInfo(
        primary: context.localized.off, secondaryFlags: const []);
  }
  final language = _languageName(stream.language) ?? stream.name;
  final channelLayout = formatChannelLayout(stream.channelLayout);
  final codec = formatCodecName(stream.codec);
  final primary = [
    if (language.isNotEmpty) language,
    if (channelLayout != null) channelLayout,
    if (codec != null) codec,
  ].join(' · ');
  return TrackLabelInfo(
    primary: primary.isEmpty ? stream.displayTitle : primary,
    secondaryFlags: [
      if (stream.isDefault) 'Par défaut',
    ],
  );
}

TrackLabelInfo formatSubtitleTrackLabel(
    BuildContext context, SubStreamModel stream) {
  if (stream.index == -1) {
    return TrackLabelInfo(
        primary: context.localized.off, secondaryFlags: const []);
  }
  final language = _languageName(stream.language) ?? stream.name;
  final container = formatCodecName(stream.codec);
  return TrackLabelInfo(
    primary: language.isEmpty ? stream.displayTitle : language,
    secondaryFlags: [
      if (stream.isForced) 'Forcé',
      if (stream.isDefault) 'Par défaut',
      if (stream.isHearingImpaired) 'SDH',
      if (container != null) container,
    ],
  );
}

/// "5.1(side)" -> "5.1", "stereo" -> "2.0", "mono" -> "1.0" — `null` si
/// absent, pour ne rien afficher plutôt qu'une chaîne vide entre deux
/// séparateurs.
String? formatChannelLayout(String raw) {
  final base = raw.trim().split('(').first.trim();
  if (base.isEmpty) return null;
  return switch (base.toLowerCase()) {
    'mono' => '1.0',
    'stereo' => '2.0',
    _ => base,
  };
}

/// Nom d'affichage d'un codec audio ou d'un conteneur de sous-titres —
/// même fonction pour les deux, un "conteneur" de sous-titre est du même
/// ordre qu'un codec audio (un identifiant de format brut à afficher
/// proprement). `null` si absent.
String? formatCodecName(String raw) {
  final code = raw.trim().toLowerCase();
  if (code.isEmpty) return null;
  return switch (code) {
    'eac3' => 'E-AC3',
    'ac3' => 'AC3',
    'dts' => 'DTS',
    'dtshd' || 'dts-hd' => 'DTS-HD',
    'truehd' => 'TrueHD',
    'aac' => 'AAC',
    'flac' => 'FLAC',
    'opus' => 'Opus',
    'mp3' || 'mp3float' => 'MP3',
    'pcm' || 'pcm_s16le' || 'pcm_s24le' || 'pcm_s32le' => 'PCM',
    'subrip' || 'srt' => 'SRT',
    'ass' => 'ASS',
    'ssa' => 'SSA',
    'webvtt' || 'vtt' => 'VTT',
    'pgssub' || 'pgs' => 'PGS',
    'dvdsub' || 'dvd_subtitle' || 'dvbsub' => 'DVD',
    'mov_text' => 'MOV Text',
    _ => code.toUpperCase(),
  };
}

/// ISO 639-1/639-2 -> nom français — couvre les langues courantes, pas
/// l'intégralité d'ISO 639 : au-delà, replie sur le code capitalisé
/// plutôt que de planter ou d'afficher un vide.
const _languageNames = <String, String>{
  'fre': 'Français',
  'fra': 'Français',
  'fr': 'Français',
  'eng': 'Anglais',
  'en': 'Anglais',
  'spa': 'Espagnol',
  'es': 'Espagnol',
  'ger': 'Allemand',
  'deu': 'Allemand',
  'de': 'Allemand',
  'ita': 'Italien',
  'it': 'Italien',
  'por': 'Portugais',
  'pt': 'Portugais',
  'jpn': 'Japonais',
  'ja': 'Japonais',
  'kor': 'Coréen',
  'ko': 'Coréen',
  'chi': 'Chinois',
  'zho': 'Chinois',
  'zh': 'Chinois',
  'rus': 'Russe',
  'ru': 'Russe',
  'ara': 'Arabe',
  'ar': 'Arabe',
  'hin': 'Hindi',
  'hi': 'Hindi',
  'dut': 'Néerlandais',
  'nld': 'Néerlandais',
  'nl': 'Néerlandais',
  'swe': 'Suédois',
  'sv': 'Suédois',
  'nor': 'Norvégien',
  'no': 'Norvégien',
  'dan': 'Danois',
  'da': 'Danois',
  'fin': 'Finnois',
  'fi': 'Finnois',
  'pol': 'Polonais',
  'pl': 'Polonais',
  'tur': 'Turc',
  'tr': 'Turc',
  'cze': 'Tchèque',
  'ces': 'Tchèque',
  'cs': 'Tchèque',
  'gre': 'Grec',
  'ell': 'Grec',
  'el': 'Grec',
  'heb': 'Hébreu',
  'he': 'Hébreu',
  'tha': 'Thaï',
  'th': 'Thaï',
  'vie': 'Vietnamien',
  'vi': 'Vietnamien',
  'ukr': 'Ukrainien',
  'uk': 'Ukrainien',
  'hun': 'Hongrois',
  'hu': 'Hongrois',
  'ron': 'Roumain',
  'rum': 'Roumain',
  'ro': 'Roumain',
  'und': 'Inconnu',
  'unk': 'Inconnu',
  'mis': 'Inconnu',
};

String? _languageName(String rawLanguage) {
  final code = rawLanguage.trim();
  if (code.isEmpty) return null;
  final mapped = _languageNames[code.toLowerCase()];
  if (mapped != null) return mapped;
  return code.length <= 3 ? code.toUpperCase() : code;
}

/// Rendu à deux lignes de [TrackLabelInfo] — les deux pistes en
/// `textPrimary` (une option grisée a l'air désactivée alors qu'elle
/// reste cliquable), secondaire en `textSecondary` uniquement si des
/// drapeaux s'appliquent (jamais de ligne vide). Piste active :
/// typographie (gras) + coche discrète, jamais une couleur atténuée.
class TrackLabelText extends StatelessWidget {
  final TrackLabelInfo info;
  final bool selected;

  const TrackLabelText({required this.info, this.selected = false, super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          info.primary,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppColors.textPrimary,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
              ),
        ),
        if (info.secondaryFlags.isNotEmpty)
          Text(
            info.secondaryLine,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: AppColors.textSecondary),
          ),
      ],
    );
  }
}
