/// État d'envoi au téléchargement d'une release — affiché sur sa ligne
/// dans le tableau de résultats.
enum ArrGrabStatus {
  idle,
  sending,
  success,
  failed,
}
