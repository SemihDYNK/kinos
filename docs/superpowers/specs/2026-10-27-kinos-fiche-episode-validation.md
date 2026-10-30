# Kinos — fiche épisode cinéma

Demande utilisateur : reprendre le style de la fiche film validée, en
réservant la fiche série à une étape suivante.

- `EpisodeDetailScreen` active le bandeau cinéma et réutilise le bloc
  synopsis/pistes dépoli de la fiche film. Le synopsis et les sélecteurs ne
  sont plus répétés sous le bandeau.
- Casting et invités existants passent au format compact avec rôles et
  informations à droite. Aucune donnée de casting supprimée.
- Le titre propre de l’épisode est garanti par `useTitleLogo: false`, même
  lorsque la série parente n’a pas encore été chargée. Son lien, métadonnées,
  bouton Lire/Reprendre contextualisé et actions restent existants.
- Le provider de détail et la modification de pistes sont conservés, sans
  évolution du lecteur ou des modèles. Le repli d’image initial peut utiliser
  celle de l’item reçu. La fiche série n’est pas modifiée par ce lot.

Vérifications ciblées : titre épisode avec et sans série chargée, label de
lecture, hauteur et position du synopsis dans le bandeau ; sélection audio
au clavier par le composant partagé. Rendus de vrais composants avec données
synthetiques : `test/widgets/fixtures/rest/episode-detail-desktop.png` et
`episode-detail-large.png`, à 150 % de texte pour le second.

Logs : `/tmp/kinos-episode-redesign/` (`targeted.log`, `visual.log`,
`analyze-final.log`, `full.log`, `build.log`). Rechargement à chaud envoyé
au pilote de l’instance existante, sans redémarrage.

Résultat : 699 tests réussis, compilation Linux debug réussie, analyse aux
37 diagnostics préexistants, `git diff --check` propre. Capture après
rechargement : `/tmp/kinos-episode-redesign/live.png`.
