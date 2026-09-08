/// URL de la jaquette telle que servie par l'instance Arr elle-même
/// (`/api/v3/mediacover/{id}/poster-500.jpg`), jamais TMDB/TVDB — à la
/// différence de [resolveArrPosterUrl] (utilisé par la recherche
/// interactive), qui préfère l'URL distante hébergée par le fournisseur
/// de métadonnées. La bibliothèque affiche délibérément la jaquette
/// locale : c'est celle que Radarr/Sonarr a effectivement mise en cache,
/// cohérente même quand le fournisseur distant est injoignable.
///
/// Authentification par en-tête `X-Api-Key` (pas de clé en query) : cette
/// URL est faite pour `Image.network(url, headers: {...})`, jamais pour
/// être partagée ou collée telle quelle.
String arrNativePosterUrl(int id, {required String baseUrl}) {
  final trimmed = baseUrl.trim();
  final normalized = trimmed.endsWith('/')
      ? trimmed.substring(0, trimmed.length - 1)
      : trimmed;
  return '$normalized/api/v3/mediacover/$id/poster-500.jpg';
}
