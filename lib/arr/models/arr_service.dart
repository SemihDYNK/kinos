/// Les deux services *Arr pris en charge — Radarr (films) et Sonarr
/// (séries), même API v3.
enum ArrService {
  radarr,
  sonarr;

  String get label => switch (this) {
        ArrService.radarr => 'Radarr',
        ArrService.sonarr => 'Sonarr',
      };
}
