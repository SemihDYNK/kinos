# Kinos — visibilité des bannières et recherche

Retour utilisateur : images trop assombries, superposition de l’en-tête de
bibliothèque aux affiches, double bordure persistante côté recherche Seerr.

- `SearchHeaderSurface` masque les jaquettes sous les en-têtes épinglés de
  bibliothèque et de recherche Seerr. Le comportement de défilement reste
  existant ; titres et filtres ont maintenant un fond neutre opaque.
- `OutlinedTextField` neutralise les six bordures internes d’InputDecoration,
  y compris celles héritées du thème. L’anneau externe reste seul responsable
  du focus. La correction s’applique aux deux recherches.
- Le voile uniforme commun au carrousel et aux fiches passe de 75 à 30 %.
  Un dégradé vertical progressif protège la zone de lecture et la transition
  basse, sans voile directionnel horizontal. Le repli et la teinte restent
  ceux du projet. L’image est ainsi plus apparente, conformément à la demande.

## Vérifications

- 689 tests réussis, dont deux nouvelles régressions : saisie dans un champ
  à décoration personnalisée et masquage des images sous un en-tête épinglé
  après défilement réel avec vérification du pixel de fond.
- Test du bandeau sur image blanche : contraste principal et secondaire
  d’au moins 4,5:1 dans la zone de lecture ; luminosité de la partie haute
  explicitement vérifiée. Test d’absence de couture basse conservé.
- 23 tests de rendu accueil/autres écrans réussis ; références actualisées
  et inspection de la fiche avec image de test.
- Compilation Linux debug réussie ; analyse aux 37 diagnostics préexistants.
- `git diff --check` propre.
- Rechargement à chaud envoyé au pilote de l’instance ouverte, sans relance.
  Capture `/tmp/kinos-ui-visibility/live.png` inspectée : accueil éclairci,
  aucune page d’erreur. Le défilement épinglé est testé automatiquement,
  pas présenté comme un parcours manuel exhaustif sur serveur réel.

Logs : `/tmp/kinos-ui-visibility/` (`full.log`, `analyze-clean.log`, `build.log`,
`search-tests.log`, `contrast.log`, `visual.log`).
