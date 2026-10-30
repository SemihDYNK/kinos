# Kinos — direction visuelle

Direction approuvée le 27 octobre 2026 : cinéma éditorial expressif.
Le caractère vient de l’échelle typographique, des images et du mouvement ;
les contrôles restent sobres, graphite et neutres, sans accent décoratif.

## Source des jetons

`lib/theme/app_theme.dart` centralise couleurs, dimensions et états partagés.
Toute nouvelle valeur de design y est définie, jamais dans un widget.

- `AppTypography.heroEditorial` : Barlow Condensed embarqué, graisse 700,
  interligne 0,95 ; taille adaptée par `AppHeroLayout`, bornée de 64 à 144.
  Les bandeaux cinéma portent ce registre ; Inter reste la police fonctionnelle.
- `AppColors` : fond `#0A0A0A`, surfaces `#141414` / `#1C1C1C`, survol
  `#232323`, texte principal et focus `#FAFAFA`.
- `AppRadii` : cartes 8, contrôles 10, panneaux 20 ; `AppNavigation`
  définit le rail (rayon 24, sélection 12, retrait 12).
- `AppDurations` : survol 120 ms, focus 100 ms, teinte 300 ms,
  transition de page 220 ms. Respecter le mouvement réduit.
- `AppMedia` : affiches 2:3, reprises 16:9 ; densité bureau de 6 à 8 colonnes
  dès 900 de largeur disponible selon `AppDensity.columnsFor`.

## Navigation du catalogue — 28 octobre 2026

Une top bar graphite dépolie reprend le matériau du rail : À la une, Films,
Séries, Découvrir (si Seerr est configuré), puis Bibliothèques. Les bibliothèques
films/séries viennent de Jellyfin et restent dans un menu déroulant.
Les onglets Films/Séries ouvrent un accueil cinéma filtré côté serveur
(bandeau, reprises et ajouts récents), avec accès au catalogue complet.
Le menu Bibliothèques ouvre directement la grille complète de la bibliothèque.
La capsule est centrée et ajuste sa largeur aux commandes ; les libellés
partagent la même ligne centrale, sans décalage dû au soulignement actif.
À la une conserve l’accueil configurable. Le rail regroupe Demandes, Arr,
réglages et profil. La top bar reste présente sur les outils pour revenir au
catalogue ; les fiches gardent leur retour existant.

La recherche s’ouvre en panneau dépoli au-dessus de la page avec Ctrl K ou le
bouton en haut à droite. Saisie temporisée, états chargement/vide/erreur,
flèche bas vers les résultats, Échap pour fermer. La sélection rapide propose
24 films/séries et un accès à tous les résultats au-delà. Chaque profil dispose
de son état et de ses requêtes. Le mode salon à navigation haute existante
reste distinct. Sur Linux, le chrome s’applique aussi aux fenêtres classées
« tablette » par les anciens seuils (600–1919 pixels).

## Composition et interaction

Grand carrousel manuel, titre monumental et métadonnées réelles. Les images
restent nettes ; les cartes peu nombreuses gardent leur largeur normale.
Le rail flottant graphite s’inspire de la cohérence des contrôles Apple,
avec les conventions Linux : sélection distincte du focus, repli explicite,
un seul avatar en bas à gauche, aucun second avatar dans l’en-tête desktop.
La capsule s’ajuste à la hauteur de son contenu, centrée verticalement à gauche.
Un séparateur suit le logo, un autre suit Arr ; réglages et profil restent
juste en dessous. Sur une fenêtre basse, le groupe central défile et conserve
son parcours au clavier, sans repousser les actions du bas hors de la capsule.
Chaque commande doit avoir un focus visible et être atteignable aux flèches.
Conserver survols, menus contextuels et raccourcis effectivement disponibles.

La dominante du film courant se prolonge en dégradé jusqu’à la fin des reprises,
ou du carrousel si elles sont absentes. Image et teinte passent derrière le
rail flottant, jusqu’au bord de la fenêtre ; seule sa capsule garde son matériau
graphite dépoli (flou 18, surface à 30 %, fin contour clair), découpé à ses
contours. Le mode contraste élevé emploie une surface opaque sans flou.
`sideBarWidth` réserve l’espace des textes et actions.
Les grilles suivantes restent sur `AppColors.background`.
Sur l’accueil desktop avec bandeau, l’image passe également sous la barre de
titre translucide : aucune bande vide n’est réservée au-dessus. Sans bandeau,
les rangées conservent leur espacement supérieur pour éviter les commandes
de fenêtre. La zone de déplacement et les commandes existantes sont conservées.
Palette bridée : luminance 0,06–0,22, saturation ≤ 0,40, contraste ≥ 4,5:1,
repli `AppColors.heroFallback`. Aucun flou d’image pour prolonger le fond.
Sur image : `textPrimary`, secondaire à 75 %, voile `scrim` jusqu’à 85 %.
Les bandeaux d’accueil et de fiche partagent un voile uniforme à 30 %,
avec un dégradé vertical qui renforce le contraste dans la zone de lecture
puis atteint 85 % en bas. La partie haute laisse davantage voir l’image.
Aucun assombrissement directionnel gauche/droite.
Focus, lecture principale et progressions restent neutres.

Le carrousel vise 75 % de la hauteur disponible (avec minimum selon densité),
avec cadrage haut de l’image. Le logo du film issu des métadonnées remplace
le titre lorsqu’il se charge, sans déformation ; le titre texte reste le repli
en cas d’absence, de chargement ou d’erreur.

## Portée de l’intégration

Accueil et navigation ; fiches films, séries et épisodes avec bandeau plein cadre,
logo officiel et synopsis à largeur de lecture bornée. La grille d’épisodes
emploie des cartes arrondies 16:9, un titre et un menu contextuel accessible
par clic droit, touche Menu ou Maj+F10.
Le titre propre d’un épisode reste affiché même si la série possède un logo.

Bibliothèque et recherche : en-têtes fonctionnels Inter, contrôles graphite,
fond neutre et grilles locales de 6 à 8 colonnes avec affiches 2:3.
Les réglages partagent un en-tête et des rangées sobres à largeur bornée.
Seerr partage les affiches, les fiches et les en-têtes ; ses demandes récentes
sont des rangées compactes avec statut réel. Arr reprend les en-têtes et
les onglets graphite ; ses tables conservent leurs fonctions existantes.

Le lecteur conserve la disposition de ses boutons. Les surfaces d’indicateurs
et du sélecteur de sous-titres reprennent les jetons graphite ; moteur,
raccourcis et logique de lecture restent ceux du projet.

Les quatorze rendus de régression de `test/widgets/fixtures/rest/` montrent les
composants de production avec des données de test, en bureau et texte à 150 %.
Ils couvrent fiche, épisodes, catalogue, réglages, demandes Seerr et table Arr et sous-menu dépoli ;
ils ne remplacent pas une validation de tous les parcours avec un serveur réel.

Les planches `docs/superpowers/specs/references/kinos-planche-cinema.png` et
`kinos-planche-gestion-lecteur.png` sont des concepts de huit écrans, sans
promesse de parité pixel ni preuve de validation interactive exhaustive.
Leurs options et contenus illustratifs ne définissent aucune nouvelle fonction.
L’image de test `coast.png` a été générée séparément ; une maquette ne sert
jamais de fond injecté dans l’application.
Voir aussi `docs/superpowers/specs/2026-10-27-kinos-accueil-design.md`.

## Sous-menus et panneaux flottants

`FrostedSurface` est le matériau commun des dialogues, menus contextuels,
menus de suggestions, sélecteurs ancrés et panneaux latéraux. Une seule couche
floutée, découpée au rayon du panneau, avec graphite à 60 % et contour clair.
Le mode contraste élevé emploie une surface opaque sans flou. Les routes,
résultats de sélection, raccourcis et fermeture par Échap sont conservés.
Les boutons du lecteur restent transparents au repos, avec survol et focus.
Le champ de recherche garde un seul cadre de focus, sans deuxième bordure
héritée du thème à l’intérieur.

Les en-têtes épinglés de recherche ont une surface neutre opaque : les
jaquettes défilant derrière ne doivent pas traverser les titres et filtres.
Le composant `OutlinedTextField` retire toutes les bordures internes héritées
du thème ; son anneau externe est l’unique cadre de focus, y compris Seerr.

## Fiche film — composition approuvée

La fiche film regroupe logo, métadonnées, actions, synopsis et sélection de
pistes dans un même bandeau. Le résumé conserve son texte complet avec une
largeur de lecture de 680 px ; la hauteur du bandeau grandit si nécessaire.
La barre de pistes est un seul matériau dépoli compact, uniquement si les
métadonnées proposent des pistes ou versions. Les choix restent liés au
provider existant.

Sous le bandeau : casting sur environ 70 % de la largeur et informations à
droite. Six portraits au maximum dans l’aperçu, largeur bornée à 152 px,
noms et rôles réels visibles. « Tout voir » ouvre le casting complet. Les
informations passent en lignes ou s’empilent selon la largeur et le texte.
Les films similaires gardent la rangée de jaquettes classiques existante.
La composition spécifique est opt-in : les séries et épisodes conservent
leur organisation. La grille partagée de casting ne reprend plus le padding
supérieur du système, qui coupait auparavant les noms sous les portraits.

Ajustement de la fiche film : bandeau à 86 % de la fenêtre, minimum 760 px
à densité bureau. Son voile uniforme descend à 12 % et le fondu de l’image
ne commence qu’à 78 % de la hauteur ; le dégradé de lisibilité atteint son
palier à 70 %. Ces réglages sont propres à la fiche cinéma, sans modifier
le carrousel. Les sélecteurs ouvrent leur menu de préférence sous le bouton,
avec repli automatique si l’espace manque. Le popover garde une seule
surface dépolie et une sélection translucide arrondie en retrait du bord.

## Fiche épisode

La fiche épisode reprend la composition cinéma de la fiche film : même
hauteur, voile et fondu, synopsis sous les actions, pistes dans la capsule
dépolie, casting et invités compacts avec rôles, informations à droite.
Son propre titre texte est toujours conservé, indépendamment du chargement
de la série parente et de la présence d’un logo hérité. Le lien vers la série,
le numéro de saison/épisode et la lecture contextuelle restent disponibles.
La fiche série conserve pour l’instant sa composition précédente.

Les fiches cinéma (films et épisodes) prolongent maintenant la dominante
extraite de leur image dans un fondu de 112 px sous la bannière. Le même
calque de dégradé couvre bandeau et prolongement, sans couture ni flou de
l’image. Il rejoint entièrement le fond neutre avant casting et jaquettes.
La teinte garde les bornes et le repli de PaletteService ainsi que la
transition respectant le mouvement réduit.

## Fiche série

La composition cinéma couvre désormais la série : logo officiel, résumé et
pistes du prochain épisode sous les actions, fondu de dominante jusqu’au
fond neutre. Le bandeau série vise 68 % de la fenêtre (minimum 560 px) avec
un prolongement de teinte de 64 px, pour laisser voir la section d’épisodes.
Ces dimensions restent distinctes de celles des fiches film et épisode.

La section Épisodes porte le sélecteur de saison dépoli et le nombre réel
d’épisodes. Une seule saison est affichée comme un libellé sans faux menu ;
plusieurs saisons offrent un choix au clavier. La saison du prochain épisode
reste présélectionnée. Les cartes 16:9 ont quatre colonnes maximum en bureau,
avec états vu/progression existants. Casting compact, informations et séries
similaires suivent, sur fond neutre. Les pistes restent celles du même
épisode que le bouton Lire/Reprendre.

Ajustement global de transparence : graphite des surfaces dépolies à 60 %
(au lieu de 72 %), capsule de navigation à 30 % (au lieu de 40 %). Les jetons
partagés appliquent ce réglage aux menus, dialogues, sélecteurs, panneaux et
barres de pistes ; le flou 18 et les contours sont conservés. Le mode
contraste élevé garde une surface opaque.

## Identité Signature

La piste A du 28 octobre 2026 est l’identité de Kinos : K sculpté en courbes vectorielles et
mot-symbole KINOS en tracés. Le rail replié affiche le monogramme ; déployé,
il emploie le mot-symbole. Le matériau ne déforme pas la silhouette. Les
actifs Linux associent le K blanc à une capsule graphite. Sources et usages :
`docs/brand/README.md`.

## Bibliothèques — 28 octobre 2026

Le nom et le compteur sont regroupés dans un en-tête compact. Recherche locale,
Genres, Année, Vu/Non vu précèdent le tri, Filtres et Actions. La ligne se
réorganise sur les fenêtres étroites et avec le texte agrandi. Les options
avancées et la taille d’affiches restent dans le panneau dépoli Filtres ;
lecture, mélange, sélection multiple et autres actions restent dans Actions.
Les filtres actifs se retirent individuellement ; Effacer conserve les types,
la recherche, le tri et la sélection de bibliothèque. Les vues Films/Séries
conservent leur titre, et le retour aux collections imbriquées reste visible.

L’en-tête entier est un SliverToBoxAdapter, jamais un PinnedHeaderSliver :
titre, recherche, filtres et actions défilent avec la grille. Seules la top bar
et la sidebar globales restent fixes. Grille 2:3 à 6–8 colonnes, fond neutre,
menus contextuels et parcours clavier existants conservés.

### Finition du chrome des bibliothèques

Le groupe Trier/Filtres/Actions s’aligne sur la marge de fin de la grille ;
Actions emploie le même survol arrondi que les boutons voisins. Sur les fenêtres
étroites, le groupe garde un alignement de fin sur une ligne dédiée.
La réserve sous la top bar passe par AdaptiveLayout.topBarHeight et le padding
du seul en-tête défilant : aucun Padding fixe ne découpe le viewport du catalogue.
Les affiches peuvent donc défiler derrière le verre de la capsule jusqu’en haut.

## Répartition finale de navigation

La top bar se limite aux accueils À la une / Films / Séries, à Découvrir
(si Seerr configuré) et à la recherche. Les bibliothèques films/séries du
serveur sont des entrées directes du rail, dans l’ordre renvoyé par Jellyfin,
avant Demandes et Arr. Elles ouvrent leur grille complète. Le rail replié
utilise des icônes de type et leurs infobulles ; déployé, il affiche les noms.
Le groupe défile si nécessaire et conserve le parcours directionnel.
Les animations restent celles déjà en place, avant leur refonte dédiée.

Le logo Kinos ramène à À la une et réinitialise le périmètre du catalogue.
La commande de déploiement se situe juste sous le logo, avant le premier
séparateur ; le profil conserve son rôle de changement d’utilisateur.

## Icônes cinéma

Les commandes cinéma partagent la famille Cupertino vectorielle déjà embarquée,
via `AppIcons` : sidebar (avion = Demandes), lecture et lecteur, favoris et vu.
Contours au repos, formes pleines pour les états actifs et lecture/pause.
Les badges de jaquette utilisent une capsule circulaire de verre graphite
(`AppMediaIcons`), avec repli opaque en contraste élevé. Le play au survol
conserve son triangle classique, une cible adaptée à la densité et un anneau
clavier blanc. Les overlays de jaquette participent au parcours de focus.
La disposition et les raccourcis du lecteur sont conservés.

## Mouvement — premier lot

Les favoris du carrousel et des fiches répondent au changement d’état par un
remplissage et un battement de 30 %, avec amortissement, sur 400 ms ; le retrait
se dégonfle doucement sur 180 ms. Les changements rapides repartent de la valeur
affichée, sans saut.
Les affiches se soulèvent de 4 px et grandissent de 2,5 % au survol, sur
260 ms avec un léger dépassement amorti. Les actions apparaissent en fondu et
passent de 88 % à leur taille normale. La sortie dure 120 ms et reste
réversible. Aucun déplacement de grille ; au clavier ou avec mouvements réduits,
les actions et le focus apparaissent immédiatement, sans déplacement.
Le même mouvement s’applique aux bibliothèques et aux cartes d’accueil :
reprise de lecture, ajouts récents, recommandations et découverte Seerr.
Le survol utilise un contour graphite translucide ; le blanc est réservé au
focus clavier.
La coche des fiches et badges se trace pendant la transition puis retrouve
exactement l’icône Cupertino au repos. Aucun effet n’est rejoué au montage.
Les menus ancrés en verre s’ouvrent depuis leur déclencheur avec un fondu
et une échelle de 95 % à 100 %, sur 180 ms, et suivent le chemin inverse
à la fermeture. Un nouveau clic inverse la transition depuis sa valeur réelle.
Les jetons sont regroupés dans AppMotion et AppDurations.
Le clavier et les mouvements réduits affichent directement l’état final,
y compris lorsqu’une transition est déjà en cours. La détection souris/clavier
s’appuie sur les événements réels, car le focus desktop reste « traditional »
avec une souris. Un clic souris reste prioritaire sur les touches encore
marquées enfoncées : le compositeur peut intercepter leur relâchement lors
d’un changement de fenêtre. L’indicateur de la top bar glisse entre les centres réels des onglets sur
240 ms, sans relancer son mouvement lors d’un nouveau clic. La sidebar se
déploie sur 320 ms et se replie sur 220 ms ; ses libellés apparaissent à partir
du premier quart du mouvement. Les icônes gardent leur position ; la marge du contenu suit la même
progression que la capsule, sans saut vers la largeur finale. La top bar reste
centrée dans la fenêtre, indépendamment de la sidebar. Le logo passe en fondu du
monogramme au mot-symbole. Le clavier et les mouvements réduits restent immédiats.
Le carrousel change d’image par fondu sur 420 ms, sans zoom ni mouvement de
l’image. Le titre entre d’abord, puis les métadonnées et le synopsis avec un
léger décalage vertical de 12 px ; les commandes restent immédiatement actives
sur le film courant. Les changements rapides conservent la dernière sélection.
La couleur du fond passe directement de la palette précédente à la suivante,
sans détour par le gris et sans réinterpoler un thème déjà animé. Une image
manquante ou une extraction en échec conserve le repli neutre. Au clavier ou avec
mouvements réduits, le nouvel état s’affiche immédiatement.
Un logo en cours de chargement garde sa place réservée, sans afficher d’abord
le titre texte. Les bannières et les logos des deux films voisins sont préchargés via le même
cache que leur affichage, avec bouclage et sans charger tout le carrousel ;
le texte reste le repli
en cas d’absence ou d’erreur.
Le lecteur reste à traiter.

Les onglets À la une, Films et Séries entrent en fondu avec un déplacement
horizontal de 24 px dans l’ordre des onglets, sur 220 ms ; Découvrir utilise
le même vocabulaire à l’échelle de sa route. Le chrome ne se déplace pas.
Chaque catalogue conserve sa position de défilement.
Les images des cartes et les bannières du carrousel rejoignent le bandeau de
la fiche par Hero, avec un fondu entre les deux cadrages ; le logo du carrousel
rejoint aussi celui de la fiche. Identités distinctes par carte, même si un
titre figure plusieurs fois. Ouverture sur 420 ms, épisode et retour sur
220 ms. La fiche utilise immédiatement son item disponible pendant le
chargement des détails. Le retour conserve le défilement, restaure le focus
source et la teinte précédente. Clavier et mouvements réduits : immédiat.

Chargement lent d’une fiche : la carte transmet son image déjà affichée au
bandeau. Celui-ci conserve ce repli, puis la dernière image décodée, jusqu’à
ce que le nouveau bandeau soit prêt ; un échec conserve l’image visible.
Cette attente ne bloque ni la navigation ni les commandes de la fiche.

Transition carrousel → film : la fiche affiche le résumé, les métadonnées et
les commandes du film source dès sa première frame, avant la réponse du
provider. Sa hauteur initiale ne repousse donc plus le logo vers le haut
pendant le vol Hero (régression vérifiée sur la géométrie du titre).

Rangées de recommandations : les entrées du cache « Pour vous » transmettent
un film ou une série amorcé avec leur affiche, de sorte que le Hero dispose
d’une destination dès la première frame. « Movies to discover » et « Series
to discover » utilisent aussi ces identités par carte, vers Jellyfin lorsque
le titre y est connu, sinon vers la fiche Seerr.
« Vous l’avez mis de côté » ouvre la fiche Jellyfin disponible (correspondance
unique du type, du nom ou titre original et de l’année), avec un indicateur
pendant la recherche. Sans correspondance, une fiche cinéma de consultation
utilise les métadonnées Arr ; sa gestion reste dans le menu « … ». Les
résultats d’une recherche devenue obsolète après départ, autre sélection ou
changement de profil ne déclenchent pas de navigation.
