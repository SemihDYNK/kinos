# Fiche film : bannière et menu audio

Retour utilisateur après intégration de la maquette : image encore trop
sombre et trop courte ; menu audio trop compact et visuellement empilé.

- Fiche cinéma : hauteur cible 86 % et minimum 760 px, extensible au contenu.
  Voile uniforme 12 %, image conservée jusqu’à 78 % avant fondu, dégradé de
  lecture renforcé à partir du bas. Le carrousel conserve ses réglages.
- Popover : largeur 240–360 px, marges intérieures, option sélectionnée en
  rectangle arrondi translucide avec contour discret ; suppression du fond
  opaque rectangulaire qui masquait le verre.
- Les sélecteurs privilégient l’ouverture sous le bouton et se repositionnent
  au-dessus s’il manque de place. Callbacks, Échap et flèches inchangés.

Tests ciblés : sélection audio au clavier, popover dans une modale, hauteur
minimale du bandeau, contraste sur image blanche et luminosité de sa partie
haute. Rendus bureau et texte à 150 %, y compris menu audio ouvert :
`test/widgets/fixtures/rest/movie-audio-menu-desktop.png` et `-large.png`.

Logs : `/tmp/kinos-film-tuning/`. Rechargement à chaud envoyé à l’instance
existante, sans redémarrage. La capture réelle se trouve sur l’accueil où
l’utilisateur avait navigué ; le rendu de fiche est contrôlé par les tests
visuels, sans revendication de capture manuelle de cette route dans ce lot.

Résultat final : 696 tests réussis, compilation Linux debug réussie,
analyse aux 37 diagnostics préexistants et `git diff --check` propre.
