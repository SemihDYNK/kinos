# Kinos — validation des écrans restants

27 octobre 2026. Prolongement de la direction validée pour l’accueil.

## Intégration

- Fiches films/séries/épisodes : bandeau plein cadre, logo partagé avec
  l’accueil, titre de repli, synopsis borné à 760 px, actions graphite.
  Le logo parent ne remplace pas le titre propre d’un épisode.
- Épisodes : liste avec vignettes 16:9, progression, durée et menu
  contextuel conservés, actions distinctes atteignables au clavier.
- Bibliothèque/recherche : titres fonctionnels, outils graphite, fond neutre,
  grilles calculées sur la largeur disponible, affiches 2:3 à 6–8 colonnes.
- Réglages : en-tête partagé et rangées graphite à largeur bornée.
- Seerr : en-têtes, recherche, grilles 2:3, synopsis et demandes récentes
  en liste compacte. Statuts et actions existants conservés.
- Arr : en-têtes et onglets harmonisés ; correction de la largeur des deux
  actions de ligne, dont les anneaux de focus dépassaient la colonne.
- Lecteur : surfaces d’indicateurs et de sous-titres migrées aux jetons,
  sans déplacement des boutons ni modification du moteur.

La seule correction de cycle de vie dans un provider concerne la microtâche
existante de `window_title_provider` : elle vérifie `mounted` avant d’écrire
après destruction. Le démontage de fiche est couvert par un test.

## Vérifications exécutées

- `fvm flutter test --no-pub` : **682 tests réussis**.
- `fvm flutter build linux --debug --no-pub` : réussite.
- `fvm flutter analyze --no-pub` : **37 diagnostics préexistants**,
  aucun diagnostic supplémentaire issu de ce lot.
- `git diff --check` : réussite.
- Revue indépendante : défaut de logo parent sur épisode corrigé et
  couvert par un test de régression.
- 12 rendus de régression : fiche, épisodes, bibliothèque, réglages,
  demandes Seerr, table Arr, en 1440×1000 et 1280×1000 avec texte à 150 %.
  Inspection visuelle ; aucun débordement Flutter dans ces cas.
- Rechargement à chaud de l’instance Linux existante par son pilote Flutter ;
  capture après rechargement contrôlée, sans écran d’erreur ni redémarrage.

## Preuves et limites

Les rendus sont dans `test/widgets/fixtures/rest/` et construisent les vrais
composants avec des données de test. Arr et réglages sont des compositions
de composants de production, pas des captures de toutes leurs routes.
La capture de l’instance ouverte reste sur son accueil ; aucun parcours
exhaustif Jellyfin/Seerr/Arr ni lecture réseau n’est revendiqué par ce lot.

Logs locaux : `/tmp/kinos-ui-rest-baseline/` (`full-suite-final.log`,
`build-final.log`, `analyze-clean.log`, `visual-final.log`).
Capture locale : `kinos-rest-final-live.png` dans ce même dossier.
Les modifications préexistantes du lot Seerr ont été conservées.
