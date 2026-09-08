import 'package:kinos/util/video_properties.dart';

/// Étiquette du badge qualité affiché dans le lecteur — jamais le profil
/// source brut (ex. "DoVi/HDR10") : le HDR est tonemappé vers SDR par
/// libplacebo, et Flutter compose en SDR 8-bit (cf. CLAUDE.md §
/// Contraintes techniques). Le badge annonce ce qui est réellement
/// affiché à l'écran, pas la source du fichier — qui, elle, reste
/// affichée telle quelle ailleurs (panneau "Informations" de l'écran de
/// détail, propriété du fichier).
///
/// Scindé de [DisplayProfile] lui-même plutôt que d'y ajouter cette
/// étiquette : cette lecture "ce qui s'affiche" n'a de sens que dans le
/// lecteur, pas partout où [DisplayProfile] est utilisé.
String playerHdrBadgeLabel(DisplayProfile? profile, Resolution? resolution) {
  final hdrLabel = switch (profile) {
    null => null,
    DisplayProfile.dolbyVision ||
    DisplayProfile.dolbyVisionHdr10 ||
    DisplayProfile.dolbyVisionHdr10Plus ||
    DisplayProfile.dolbyVisionHlg =>
      'DoVi → SDR',
    DisplayProfile.hdr ||
    DisplayProfile.hdr10 ||
    DisplayProfile.hdr10Plus ||
    DisplayProfile.hlg =>
      'HDR10 → SDR',
    DisplayProfile.sdr => 'SDR',
  };
  return [hdrLabel, resolution?.value].nonNulls.join(' · ');
}
