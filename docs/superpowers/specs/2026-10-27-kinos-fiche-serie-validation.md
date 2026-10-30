# Kinos — intégration de la fiche série

Direction approuvée après la maquette `references/kinos-fiche-serie-maquette.png`.

- Composition cinéma propre aux séries : hauteur 68 %, minimum 560 px,
  prolongement de dominante 64 px et même image plus visible que les fiches
  précédentes. Logo officiel et repli texte conservés.
- Synopsis et pistes du prochain épisode sous les actions. Lecture et
  sélecteurs partagent le même `nextUp` ; aucun changement de provider.
- Épisodes en premier : titre de section, saison et compteur réel. Choix
  dépoli pour plusieurs saisons, libellé simple pour une seule. Saison du
  prochain épisode présélectionnée. Quatre colonnes maximum en bureau ;
  images 16:9, progression, vu et menus contextuels conservés.
- Casting et informations compacts ensuite, puis séries similaires. La
  section ne reprend plus le padding système dans sa grille.
- `LabeledSelector` accepte un libellé vide sans séparateur parasite ; les
  anciens appelants gardent leur libellé. Les films/épisodes gardent leurs
  hauteurs distinctes, pilotées par les jetons du thème.

## Vérifications

- **702 tests réussis**. Test spécifique : présélection de saison 2, choix
  de saison 1 par Tab/Entrée/flèche/Entrée, mise à jour du nombre d’épisodes,
  quatre colonnes à 1920 px. Sélection de pistes partagée déjà testée.
- 20 rendus de régression réussis, dont nouvelle fiche série en bureau et
  texte à 150 %, avec les vrais composants et des données synthétiques.
- Analyse : 37 diagnostics préexistants. Compilation Linux debug réussie.
- `git diff --check` propre. Revue indépendante sans défaut concret trouvé.
- Rechargement à chaud envoyé au pilote de l’instance existante, sans relance.

Logs : `/tmp/kinos-series-redesign/` (`targeted.log`, `visual.log`,
`analyze-final.log`, `full.log`, `build.log`). Les rendus ne constituent pas
un parcours exhaustif de toutes les bibliothèques sur serveur réel.
