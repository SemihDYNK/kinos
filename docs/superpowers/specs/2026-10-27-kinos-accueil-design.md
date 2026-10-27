# Kinos — accueil cinéma éditorial

Date : 27 octobre 2026.
Statut : direction visuelle approuvée en conversation ; spécification à relire
avant le plan d’implémentation.

## Intention et référence

Faire de l’accueil un espace de cinéma expressif, confortable à la souris et
entièrement navigable au clavier : choisir un film, reprendre une lecture et
parcourir sa bibliothèque. Le caractère vient de l’image et de la typographie.
Les contrôles restent sobres, monochromes et immédiatement compréhensibles.

Référence : `references/kinos-accueil-colore.png`, maquette générée dans cette
conversation. Elle fixe l’ambition et la composition, pas des données de produit.
« Le Chant du Large », le synopsis et les illustrations sont fictifs. Aucun
contenu de cette image ne sera injecté dans la bibliothèque.

Corrections explicitement demandées, prioritaires sur les pixels de la maquette :

- Affiches strictement en 2:3 et vignettes de reprise strictement en 16:9.
- Grand carrousel conservé ; il n’adopte pas les dimensions des petites vignettes.
- Un seul avatar, en bas de la barre latérale gauche.
- Fond influencé par le film actuellement affiché au carrousel.

## Premier lot et limites

Ce lot porte sur l’accueil, ses cartes et les éléments de navigation qui
l’encadrent. Les fiches détaillées, la bibliothèque complète, les réglages,
Arr et le lecteur feront l’objet de lots suivants.

Préserver les sources de données, les recommandations, les rangées configurées,
la découverte Seerr en cours de développement et les destinations existantes.
La maquette simplifie les rangées pour montrer la composition : elle n’autorise
pas leur suppression ni leur réordonnancement fonctionnel.

Ne pas ajouter de nouvel onglet ou de fausse fonction pour reproduire le dessin.
Seerr reste visible uniquement lorsqu’il est configuré pour le profil actif.
Pas de modification des moteurs vidéo, du profil de lecture ou du stockage.

## Composition

### Navigation

Conserver `SideNavigationRail`, son repli/dépli et ses destinations. État actif,
survol et focus doivent rester distincts. Les icônes de la barre repliée ont
des libellés accessibles et des infobulles affichables au focus.

Le profil du bas demeure le point d’accès au changement d’utilisateur.
L’en-tête desktop ne doit afficher aucun second avatar. Vérifier le chemin
réel de l’en-tête : `NestedSliverAppBar` est limité à la branche téléphone
dans le dashboard et ne doit pas être modifié au hasard pour corriger le bureau.
La recherche garde sa destination existante. Un raccourci n’est affiché que
s’il est effectivement branché et testé ; le « Ctrl K » du dessin n’est pas
une preuve d’implémentation.

### Carrousel éditorial

Conserver le défilement manuel et la sélection existante de films, stable
par session/profil. Ne pas ajouter de rotation automatique.

Image large, nette et non recolorisée, cadrage couvert sans déformation.
Titre très grand, serré, en caractère condensé, aligné à gauche. Introduire
une police condensée embarquée sous licence redistribuable, uniquement pour
ce titre, avec licence conservée dans les assets. Le texte courant conserve
Inter. Vérifier la provenance et la couverture des accents avant intégration.

La taille et la largeur du titre dépendent des contraintes disponibles :
deux lignes privilégiées ; réduction bornée pour les titres longs, puis
troncature visuelle avec titre complet accessible. Ne pas convertir le texte
en image ni l’étirer horizontalement. L’agrandissement du texte utilisateur
reste pris en compte ; le bloc peut grandir pour éviter tout débordement.

Métadonnées réelles uniquement : année, genre et durée disponibles. Synopsis
réel limité à quelques lignes. Action primaire de lecture, accès à la fiche,
favori et commandes précédent/suivant conservés et atteignables aux flèches.
Un compteur indique la position réelle ; les commandes sont absentes si une
seule diapo est disponible. Aucune accroche éditoriale inventée dans le produit.

### Fond teinté et contraste

Réutiliser `PaletteService` et `heroPaletteProvider`, cache compris. La diapo
affichée pilote l’image et la palette ; une extraction terminée en retard
ne doit jamais appliquer la teinte de la diapo précédente.

La couleur sombre et peu saturée se prolonge en dégradé derrière la reprise,
puis disparaît complètement au plus tard à la fin de cette section. Toutes
les rangées suivantes reposent sur `AppColors.background` (#0A0A0A).
Si la reprise est vide, terminer le dégradé à la fin du carrousel.

La limite gauche suit `AdaptiveLayout.of(context).sideBarWidth`, y compris
pendant les changements de largeur de navigation. Aucune teinte sous la barre.
Conserver les limites de palette du projet : plage 0,06–0,22, saturation au
plus 0,40, contraste du texte au moins 4,5:1 et repli #141414.

Image nette dans le carrousel ; couleur seule dans le prolongement du fond.
Aucun `BackdropFilter`. Sur image, texte principal `textPrimary`, secondaire
à 75 % d’opacité, avec voile sombre montant à 0,85 sur environ les 60 % bas.
Bouton de lecture, anneaux de focus et progressions restent neutres.

### Reprise et affiches

Réutiliser la section de reprise et ses actions. Vignettes 16:9, quatre
colonnes à la largeur desktop de référence, adaptation aux contraintes sans
écraser les images. Titres, épisode et progression réels ; aucun pourcentage
factice. Une rangée peu remplie garde la largeur normale des cartes.

Les affiches restent en 2:3. Viser 6–8 colonnes aux largeurs desktop usuelles,
sept à la largeur de référence si l’espace disponible le permet. Les ratios
concernent les images ; les libellés disposent de leur propre hauteur.
Si une image manque, utiliser un repli neutre sans déformer le substitut.
L’écran défile verticalement : ne pas raccourcir les affiches pour tout faire
tenir dans le premier viewport. Conserver l’accès « tout voir » existant.

## Composants et jetons

Étendre `lib/theme/app_theme.dart` avec les seuls concepts manquants :
typographie du bandeau, contraintes de composition, ratios et rythmes partagés.
Toutes les dimensions et couleurs ajoutées aux widgets passent par ces jetons.
Ne pas remplacer globalement l’échelle typographique des écrans hors lot.

Points d’intégration identifiés :

- `lib/screens/dashboard/dashboard_screen.dart` : composition et limite du fond.
- `lib/screens/dashboard/hero_carousel.dart` : titre, synopsis et contrôles.
- `lib/screens/dashboard/continue_watching_section.dart` : reprise en 16:9.
- `lib/screens/dashboard/single_row_section.dart` : affiches en 2:3.
- `lib/widgets/navigation_scaffold/components/side_navigation_bar.dart` et
  `top_navigation_bar.dart` : navigation et unicité de l’avatar selon le chemin actif.
- `lib/widgets/shared/fading_hero_backdrop.dart` : composant également utilisé
  par les fiches ; préserver son rendu sur ces écrans via une option explicite
  ou un composant de composition propre à l’accueil.

## États et interactions

- Chargement du bandeau : surface neutre stable, aucune action vers un faux film.
- Image ou palette indisponible : repli lisible, métadonnées et actions conservées.
- Carrousel vide : pas de grand espace vide ; les autres rangées restent accessibles.
- Reprise vide : section masquée et dégradé terminé avant la rangée suivante.
- Navigation rapide : dernière diapo sélectionnée prioritaire, focus conservé.
- Survol : retour court et discret ; aucune mise à l’échelle qui déplace les cartes.
- Clavier : parcours directionnel complet, retour à la barre et focus visible.
- Mouvement réduit : suppression des déplacements décoratifs et transitions adaptées.
- Clic droit : conserver les menus existants ; aucune action existante perdue.

## Vérification et critères d’acceptation

Comparer des captures Flutter avant/après avec les mêmes données locales de test,
sans compte ni identifiants dans les artefacts. La maquette ImageGen n’est pas
une preuve du rendu Flutter.

Matrice : 1280×800, 1440×900 et 1920×1080, densité bureau ; fumée en densité
salon existante sans ajouter sa bascule. Thème sombre prescrit, texte à 100 %
et 150 %, français et au moins un libellé long. Aucun thème clair à inventer.

Captures peuplées, titre très long, images manquantes et carrousel/reprise vides.
Mesurer les ratios, la fin du dégradé et les contrastes avec images claires
et sombres. Vérifier chaque commande au clavier et les menus à la souris.
Tester un changement rapide de diapo pendant une extraction de palette.

Exécuter les tests existants pertinents, dont le rafraîchissement du carrousel,
les routes des rangées et la découverte Seerr ; ajouter des tests ciblés pour
les comportements nouveaux et des captures stables pour la composition.
Analyse statique sans nouvelle régression et vérification du formatage ciblé.

Succès : titre expressif lisible, couleur liée au bon film et limitée à sa zone,
formats classiques exacts, un seul avatar, fonctions et rangées préservées,
aucun débordement ni action inaccessible dans la matrice.
