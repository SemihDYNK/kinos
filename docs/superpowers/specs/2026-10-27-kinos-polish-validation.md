# Kinos — corrections après retour visuel

27 octobre 2026. Retour utilisateur sur recherche, bandeau, lecteur,
épisodes et sous-menus.

- Recherche : suppression des bordures internes héritées du thème qui
  doublaient l’anneau externe ; suggestions sur matériau dépoli.
- Bandeau : voile uniforme renforcé de 65 à 75 %, voile inférieur conservé.
- Lecteur : fonds permanents des boutons retirés ; positions et interactions
  conservées. Suppression de la couche opaque en double dans les sous-titres.
- Épisodes : retour à la grille de rectangles arrondis 16:9. Les images Primary
  d’épisodes au format paysage sont traitées comme des vignettes paysage.
  Clic droit et Menu/Maj+F10 exposent les actions existantes ; le raccourci
  figure dans l’infobulle.
- Sous-menus : matériau `FrostedSurface` commun aux Dialog/AlertDialog/
  SimpleDialog, PopupMenuButton/showMenu, suggestions, AnchoredPopover,
  feuille de rangées d’accueil, feuille modale et panneaux latéraux.
  Le matériau est découpé au panneau, sans flou plein écran ; opaque en
  contraste élevé. Les options/callbacks et routes restent existants.

## Vérification

Les tests dédiés couvrent la fermeture Échap des dialogues, la sélection au
clavier d’un menu et son résultat de route, le découpage du flou et le repli
contraste élevé. La régression des cartes épisodes a échoué sur la liste
avant restauration puis passe. Le rendu de bibliothèque vérifie l’absence
de bordures internes supplémentaires.

Rendus de régression mis à jour pour l’accueil, fiches, recherche et épisodes,
avec deux rendus supplémentaires de sous-menu devant une image contrastée.
Données de test et vrais composants ; cela ne constitue pas un parcours
exhaustif de tous les sous-menus sur les serveurs de l’utilisateur.

La revue indépendante a identifié la surface des suggestions et l’accès
clavier au menu d’épisode ; les deux sont corrigés. Les nouveaux wrappers
n’exposent pas `initialValue`, inutilisé par les appelants actuels : aucune
promesse d’alignement ou surbrillance d’un élément initial n’est ajoutée.

Logs locaux : `/tmp/kinos-ui-polish/`.

Résultat final : **687 tests réussis**, compilation Linux debug réussie,
`git diff --check` propre et analyse aux **37 diagnostics préexistants**.
Logs : `full-complete.log`, `analyze-complete.log`, `build-complete.log`.
Rechargement à chaud envoyé au pilote parent de l’instance Kinos ouverte,
sans redémarrage. Capture de l’instance après un premier rechargement :
`/tmp/kinos-ui-polish/kinos-polish-live.png`, sans écran d’erreur.
