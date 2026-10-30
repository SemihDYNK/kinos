# Bibliothèques — validation du 28 octobre 2026

Maquette validée dans le chat, intégrée dans LibraryAppBar et LibraryFilterChips.
En-tête compact non épinglé ; filtres rapides, panneau avancé dépoli,
menu Actions et filtres actifs supprimables. La grille reprend plus haut et
les marges de l’en-tête suivent celles du catalogue.

Le retour aux collections imbriquées et le contrôle de taille des affiches sont
conservés. Fermer le dialogue de filtres utilise son propre contexte pour
préserver la route sous-jacente. Effacer les raffinements conserve le périmètre
et le tri. Les entrées de découverte dupliquées ont été retirées des filtres.

Validation : 716 tests réussis ; analyse aux 37 diagnostics préexistants ;
compilation Linux debug réussie ; git diff --check réussi.
Nouveaux tests : défilement de l’en-tête, ouverture/fermeture des filtres,
suppression d’un genre, texte agrandi et effacement préservant le périmètre.
Capture réelle de Movies après rechargement à chaud :
`references/kinos-bibliotheques-linux.png`.
Les autres bibliothèques n’ont pas été parcourues manuellement.

Prowl indisponible faute de workspace. Le provider conserve une remise en forme
mécanique en plus du nouvel ajout clearRefinements : le contrôle automatique a
refusé une réécriture depuis HEAD pour protéger les changements locaux ; aucun
contournement de ce refus n’a été effectué.

## Finition des marges et du chrome

Groupe d’actions aligné sur la marge droite et bord de survol Actions arrondi.
La réserve de la top bar est portée par AdaptiveLayout.topBarHeight et consommée
par l’en-tête ; le viewport défilant reste plein cadre. Cela conserve la marge
initiale sans bande noire persistante au scroll.
14 tests ciblés et 2 rendus bibliothèque réussis ; analyse inchangée à 37 diagnostics.
Rechargement à chaud effectué. Suite complète non relancée pour cette retouche.

### Espacement initial

Suppression du second ajout de topBarHeight dans LibraryAppBar : la page le
transmet déjà via MediaQuery. Régression reproduite à 224 px contre moins de
156 px dans le test ; la réserve est désormais comptée une seule fois.
