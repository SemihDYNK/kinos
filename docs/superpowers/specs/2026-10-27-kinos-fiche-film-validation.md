# Kinos — intégration de la maquette de fiche film

Direction approuvée par l’utilisateur après génération de la maquette
`references/kinos-fiche-film-maquette.png`.

## Implémentation

- `MovieDetailScreen` active la composition cinéma de `MediaDetailScaffold`.
  Le synopsis est déplacé sous les actions dans le bandeau, sans suppression
  de texte. Les sélecteurs audio/sous-titres/versions existants vivent dans
  une barre dépolie compacte via `MovieHeroContent`.
- Bandeau à 68 % de la fenêtre, minimum 600 px à densité bureau, extensible
  au contenu. L’image et le logo sont ceux des métadonnées ; aucune image
  de maquette n’est injectée dans l’application.
- `MediaInfoSection` emploie une répartition casting/informations de 70/30
  pour les films. Portraits bornés, noms sur deux lignes, rôles réels sur une
  ligne ; informations adaptables à la largeur et au texte agrandi.
- Correction du padding implicite de GridView qui repoussait et masquait les
  noms sous les portraits. Les choix de pistes, lecture, favoris, vu, menus,
  personne détaillée, casting complet et films similaires sont conservés.
- Les nouvelles dimensions sont dans les jetons de thème ; aucune évolution
  des providers, modèles, codecs ni du lecteur.

## Preuves

- Suite complète : 694 tests réussis, dont rendus fiche bureau/texte à 150 %
  et trois régressions de casting mesurant noms et rôles dans la grille avec
  padding système et texte agrandi.
- Test de détail : synopsis réellement sous le bouton Lire et à l’intérieur
  du bandeau ; repli de titre épisode conservé.
- Test complémentaire de la barre de pistes : clavier Tab/Entrée/flèche/
  Entrée, choix transmis au callback, modèle initial inchangé.
- Analyse : 37 diagnostics préexistants. Compilation Linux debug réussie.
- `git diff --check` propre. Revue indépendante sans défaut bloquant.
- Rechargement à chaud de l’instance existante, sans relance. Capture réelle
  du Robot sauvage inspectée : `/tmp/kinos-film-redesign/live.png`.
- Rendus de test : `test/widgets/fixtures/rest/movie-desktop.png` et
  `movie-large.png`. Ils utilisent les vrais composants et des données de
  test ; pas de revendication de parité pixel avec une image générée ni de
  parcours exhaustif sur toutes les bibliothèques.

Logs locaux : `/tmp/kinos-film-redesign/` (`full.log`, `build.log`,
`analyze-final.log`, `visual-final.log`, `targeted.log`, `keyboard.log`).
