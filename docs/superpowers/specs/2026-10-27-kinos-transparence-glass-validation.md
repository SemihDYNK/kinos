# Verre dépoli — transparence globale

Retour utilisateur : rendre le matériau un peu plus transparent partout.

Deux jetons modifiés : `AppGlass.surface` passe de 72 % à 60 % de graphite,
`AppNavigation.surface` de 40 % à 30 %. Les consommateurs partagés couvrent
menus, dialogues, sélecteurs, panneaux et barres de pistes, ainsi que le rail.
Flou, contours, états d’interaction et repli opaque en contraste élevé conservés.

Vérifications : 7 tests ciblés réussis (verre, navigation, sélection de pistes),
29 tests de rendus réussis avec références actualisées ; matériau inspecté
devant une image contrastée. Analyse aux 37 diagnostics préexistants et
`git diff --check` propre. Rechargement à chaud envoyé, sans redémarrage.
Logs : `/tmp/kinos-glass-transparency/`.
