# Kinos — accueil éditorial Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Réaliser l’accueil expressif validé, avec titre monumental, médias aux proportions classiques, fond teinté par la diapo active et navigation desktop accessible.

**Architecture:** Garder les providers et les rangées fonctionnelles actuels. Isoler la composition et le fond de l’accueil dans des composants locaux, sans changer le rendu de `FadingHeroBackdrop` dans les fiches. Étendre les jetons existants pour la typographie du bandeau et ses dimensions.

**Tech Stack:** Flutter 3.35.7 via FVM, Dart, Riverpod, sliver_tools, flutter_test, polices embarquées.

**Spec:** `docs/superpowers/specs/2026-10-27-kinos-accueil-design.md`

## Global Constraints

- Linux desktop, films et séries uniquement ; préserver le lecteur mpv et les couches données.
- Affiches strictement en 2:3 et vignettes de reprise strictement en 16:9.
- Grand carrousel conservé ; défilement manuel sans rotation automatique.
- Un seul avatar, en bas de la barre latérale gauche, dans le chemin desktop standard.
- Luminance HSL de palette 0,06–0,22 ; saturation ≤ 0,40 ; contraste texte ≥ 4,5:1 ; repli #141414.
- Dégradé terminé au plus tard à la fin de la reprise, avant toutes les autres rangées sur #0A0A0A.
- Barre latérale, focus, bouton de lecture et progressions neutres ; aucun BackdropFilter.
- Toutes les couleurs, tailles et durées nouvelles passent par les jetons.
- Direction globale validée : graphite neutre, contrôles aux formes douces,
  navigation flottante et mouvements courts ; déploiement écran par écran.
- Premier lot limité à l’accueil et sa navigation : pas de restylage implicite
  de tous les boutons et menus via un changement global de ThemeData.
- Préserver les rangées, leur configuration et les changements Seerr actuellement non committés.
- Aucun appel jellyApiProvider depuis un widget, aucune donnée de production fictive.
- Tout contrôle atteignable aux flèches, avec focus visible, survol et menus existants conservés.
- Matrice visuelle 1280×800, 1440×900, 1920×1080 ; texte 100 %/150 %, densité bureau et fumée salon.

## Review Focus

1. Un titre très long avec accents à 150 % ne doit pas masquer les actions : tâche 2.
2. Une palette ancienne terminant après une nouvelle diapo ne doit pas revenir à l’écran : tâche 3.
3. Une reprise absente et une barre dépliée ne doivent laisser aucune teinte hors zone : tâche 3.
4. Une seule reprise ou une image absente ne doit pas étirer/déformer les médias : tâche 4.
5. Une commande de carrousel interceptant les flèches ne doit pas emprisonner le focus : tâche 5.

## État initial et frontières

La spécification et la référence sont au commit `ee11d66c`. Le code existant
contient un lot découverte Seerr non committé, y compris des modifications de
`dashboard_screen.dart`, `hero_carousel.dart`, `app_theme.dart` et des tests.
Ne jamais utiliser de reset, restore ou ajout global pour isoler ce lot.

Prowl est installé mais sans workspace configuré. `prowl-agent wip` échoue
avec « no .prowl workspace found » ; utiliser les fichiers ciblés déjà identifiés.
Ne pas configurer un nouvel index comme effet secondaire de cette refonte.

Le bureau standard passe par `NavigationBody` → `SideNavigationRail` ;
`TopNavigationBar` appartient à la variante TV et `NestedSliverAppBar` à la
branche téléphone. Aucun de ces deux en-têtes ne doit être modifié pour
« supprimer un doublon » absent du chemin desktop. La barre de fenêtre
`KinosAppBar`/`DefaultTitleBar` conserve ses actions natives.

### Tâche 1 : fixture locale et état de référence

**Files:** Create `test/widgets/support/home_visual_fixture.dart`, `test/widgets/home_visual_test.dart`, `test/widgets/fixtures/home/`.

**Interfaces:** produit `Widget homeVisualFixture({required Size viewport, double textScale = 1, AppDensity density = AppDensity.desk})`, un shell local avec localisation, thème, AdaptiveLayout et contenu de test. Aucune requête réseau ou identité réelle.

- [ ] Lire la spec, le diff de travail et les tests actuels ; consigner les seuls échecs réellement observés comme état initial.
- [ ] Exécuter `fvm flutter test test/widgets/hero_carousel_refresh_test.dart test/widgets/home_rows_route_test.dart test/widgets/seerr_discovery_section_test.dart test/theme/palette_service_test.dart` et `fvm flutter analyze`, conserver les sorties dans `/tmp/kinos-ui-baseline/`.
- [ ] Construire la fixture avec `MovieModel.fromBaseDto`, images locales de test et palettes déterministes. Charger les polices dans le test de rendu. Inclure un titre long accentué et des images claires/sombres ; n’utiliser aucune capture ImageGen comme fond de l’UI Flutter.
- [ ] Créer un test `home fixture renders without network` qui monte la fixture, vérifie le titre attendu, puis `expect(tester.takeException(), isNull)`. En cas de requête réseau, faire échouer le test.
- [ ] Capturer l’état initial à 1440×900 avec les composants existants via `matchesGoldenFile('fixtures/home/before-1440.png')` et `fvm flutter test --update-goldens test/widgets/home_visual_test.dart`. Examiner l’image avant toute modification visuelle.

### Tâche 2 : typographie et composition du carrousel

**Files:** Modify `lib/theme/app_theme.dart`, `lib/screens/dashboard/hero_carousel.dart`, `pubspec.yaml`; Create `assets/fonts/barlow_condensed/`, `test/widgets/hero_carousel_layout_test.dart`.

**Interfaces:** conserver `HeroCarousel({required List<ItemBaseModel> items, ValueChanged<ItemBaseModel>? onCurrentChanged, Key? key})`. Ajouter `AppTypography.heroEditorial` et `AppHeroLayout` (contraintes, marges et méthode `titleSizeFor(double contentWidth, AppDensity density)`). La typographie globale Inter reste inchangée.

- [ ] Ajouter un test `long accented hero title keeps actions visible at 150 percent` : titre long, viewport 1280×800, facteur 1,5, aucune exception, rectangles des actions contenus dans le bandeau, libellé sémantique complet.
- [ ] Exécuter le test et confirmer l’échec attendu sur le cas de débordement ou de composition ciblé, sans inventer un échec si le comportement existe déjà.
- [ ] Télécharger Barlow Condensed depuis sa source officielle, vérifier la licence OFL et les accents français, embarquer les graisses nécessaires et la licence. Aucune police distante à l’exécution.
- [ ] Définir le titre condensé 112 px cible à 1440 px, borné de 64 à 144 px selon largeur, poids 700, interligne 0,95 ; deux lignes privilégiées, réduction bornée puis ellipse avec sémantique complète. Ajuster la hauteur du bandeau aux besoins du texte agrandi ; pas de FittedBox annulant l’accessibilité.
- [ ] Afficher les métadonnées disponibles et le synopsis réel en quelques lignes. Préserver lecture, fiche, favori et toutes les commandes. Utiliser `textPrimary` et son opacité 75 % sur image ; localiser les nouvelles chaînes via les fichiers ARB existants, sans écraser les ajouts Seerr.
- [ ] Exécuter `fvm flutter test test/widgets/hero_carousel_layout_test.dart test/widgets/hero_carousel_refresh_test.dart`, puis vérifier une capture peuplée avant de retenir les dimensions.

### Tâche 3 : fond de l’accueil et synchronisation de palette

**Files:** Create `lib/screens/dashboard/home_hero_backdrop.dart`, `lib/screens/dashboard/home_hero_section.dart`, `test/widgets/home_hero_background_test.dart`; Modify `lib/screens/dashboard/dashboard_screen.dart`, `lib/screens/dashboard/hero_carousel.dart`, `lib/theme/app_theme.dart`.

**Interfaces:** `HomeHeroBackdrop({required ImageData? image, required Color heroTint, required double heroHeight, required double totalHeight, Key? key})` peint l’image limitée au bandeau et la couleur dans son prolongement ; `HomeHeroSection({required List<ItemBaseModel> heroItems, required List<ItemBaseModel> resumeItems, required EdgeInsets contentPadding, Key? key})` est un sliver qui mesure les hauteurs réelles du bandeau et de la reprise. La section possède le callback de diapo ; la palette reste dans les providers existants.

- [ ] Tester `empty resume ends tint at hero boundary` et `expanded rail stays neutral` sur des captures locales : échantillons hors zone égaux à `AppColors.background`, image absente sous la reprise et limite gauche suivant `sideBarWidth`.
- [ ] Ajouter `late palette cannot replace active slide` avec un faux `PaletteService` piloté par deux Completer : sélectionner A puis B, terminer B puis A, vérifier que `heroPaletteProvider` garde B. Tester aussi le démontage pendant l’extraction.
- [ ] Exécuter ces tests et vérifier le comportement existant ; ne changer la logique asynchrone que si le test en montre le besoin.
- [ ] Implémenter le fond dédié à l’accueil, sans modifier le rendu partagé de `FadingHeroBackdrop`. Dimensionner la fin du dégradé avec les hauteurs réelles, et non les hauteurs constantes 900/1000 actuelles. Utiliser un fondu animé de palette selon `AppDurations.heroTint` ; durée nulle en mouvement réduit.
- [ ] Déplacer le groupe carrousel/reprise dans `HomeHeroSection`. Retirer du dashboard uniquement le code rendu redondant ; préserver les rangées et leur ordre. Ne pas dupliquer l’état actif du carrousel.
- [ ] Exécuter `fvm flutter test test/widgets/home_hero_background_test.dart test/widgets/hero_carousel_refresh_test.dart test/theme/palette_service_test.dart` ; comparer les captures avec et sans reprise et avec barre repliée/dépliée.

### Tâche 4 : cartes aux proportions classiques et rythme des rangées

**Files:** Modify `lib/screens/dashboard/continue_watching_section.dart`, `lib/screens/dashboard/single_row_section.dart`, `lib/theme/app_theme.dart`; Create `test/widgets/home_media_layout_test.dart`.

**Interfaces:** garder les constructeurs publics des deux sections ; ajouter `AppMedia.resumeAspectRatio = 16 / 9`, `AppMedia.posterAspectRatio = 2 / 3`. Les libellés ont une hauteur propre, hors ratio d’image.

- [ ] Ajouter `resume images keep 16 by 9 with one or four items` et `poster images keep 2 by 3 at desktop widths` : mesurer les RenderBox des images, tolérance ≤ 0,01 ; titres longs et image absente inclus.
- [ ] Ajouter `desktop poster row has six to eight columns` pour 1280, 1440 et 1920 px avec largeur de barre déduite ; fumée salon séparée, sans forcer huit colonnes à trois mètres.
- [ ] Exécuter les tests ; conserver tout comportement déjà correct et ne modifier que densité, rythme et présentation nécessaires à la direction validée.
- [ ] Aligner les marges du bandeau et des sections ; conserver 16:9 pour l’image de reprise même si titre/sous-titre sont placés dessous. Conserver les actions et les cartes peu nombreuses à leur largeur normale. Progressions blanches et affiches jamais teintées.
- [ ] Exécuter `fvm flutter test test/widgets/home_media_layout_test.dart test/widgets/home_rows_route_test.dart test/widgets/seerr_discovery_section_test.dart` ; comparer une capture à la maquette pour densité et lisibilité.

### Tâche 5 : parcours clavier et navigation desktop

**Files:** Create `test/widgets/home_keyboard_navigation_test.dart`; Modify `lib/widgets/navigation_scaffold/components/side_navigation_bar.dart`, `lib/theme/app_theme.dart` et, uniquement si nécessaire pour le focus, `lib/screens/dashboard/hero_carousel.dart` et les composants locaux du lot.

**Interfaces:** réutiliser `FocusRing`, `GridFocusTraveler`, `FocusRow`, `navBarNode` et les destinations existantes. Aucun nouveau système de navigation. Aucun nouveau raccourci « Ctrl K » dans ce lot si sa fonction n’existe pas déjà.

- [ ] Tester `hero actions and arrows remain directionally reachable` : lecture, fiche, favori, précédent et suivant accessibles aux flèches ; flèche bas mène à la reprise, flèche gauche en bord de rangée revient à la barre.
- [ ] Tester `desktop has one profile entry` avec barre repliée et dépliée ; monter le vrai chemin `NavigationBody` avec providers de test, pas une copie artificielle de la barre.
- [ ] Implémenter le rail flottant graphite validé avec les jetons `AppNavigation` : retrait 12 px, rayon de conteneur 24 px, rayon de sélection 12 px, surface neutre `AppColors.surface`. Conserver la largeur de contenu utile des modes existants ; inclure les retraits dans la largeur totale déclarée à AdaptiveLayout. État actif, survol et focus blanc distincts ; aucun fond de film sous le gutter et aucun flou permanent.
- [ ] Vérifier `floating rail respects safe areas and large text` : 1280×800, texte à 150 %, barre repliée puis dépliée ; aucune commande coupée et aucun changement de largeur au simple survol. Recapturer le fond de tâche 3 avec les nouvelles largeurs.
- [ ] Tester le passage de 1 à 0 puis plusieurs diapositives sans focus perdu vers un widget démonté ; comparer également avec mouvement réduit.
- [ ] Corriger uniquement les problèmes révélés, notamment l’interception globale gauche/droite du carrousel si elle empêche le parcours de ses boutons. Préserver l’accès manuel aux diapositives et les actions de clic droit déjà disponibles.
- [ ] Exécuter `fvm flutter test test/widgets/home_keyboard_navigation_test.dart test/widgets/hero_carousel_layout_test.dart` ; vérifier le focus visuellement sur les captures.

### Tâche 6 : preuves visuelles et validation finale

**Files:** Modify `test/widgets/home_visual_test.dart`; Create captures finales dans `test/widgets/fixtures/home/`, compte rendu `docs/superpowers/specs/2026-10-27-kinos-accueil-validation.md`.

**Interfaces:** la fixture de tâche 1 utilise les vrais nouveaux composants, les mêmes films et les mêmes images que les captures initiales.

- [ ] Générer les captures finales aux trois tailles prescrites, texte 100 %/150 %, un cas salon, un titre long et un état vide. Utiliser `fvm flutter test --update-goldens test/widgets/home_visual_test.dart`, examiner chaque capture, corriger les écarts matériels puis recapturer.
- [ ] Mesurer contraste des textes/voiles sur les fixtures claires et sombres ; vérifier visuellement les défauts qu’un test géométrique ne couvre pas : image trop sombre, titre écrasant, disparition trop abrupte de la teinte, densité et alignements.
- [ ] Exécuter `fvm flutter test test/widgets test/theme test/providers/hero_items_provider_test.dart test/providers/home_discovery_settings_test.dart` et `fvm flutter analyze`. Comparer à l’état initial ; ne pas attribuer les avertissements antérieurs à la refonte.
- [ ] Exécuter `fvm flutter build linux --debug` pour vérifier les assets et la compilation native. Si le lancement local est possible, contrôler à la souris et aux flèches sans publier ni transmettre de données.
- [ ] Exécuter `fvm dart format --output=none --set-exit-if-changed` avec la liste explicite des fichiers Dart modifiés par ce lot, puis `git diff --check`.
- [ ] Faire une relecture indépendante du diff du lot et des captures selon la méthode d’exécution approuvée. Consigner honnêtement tout blocage de rendu, test antérieur en échec ou écart restant ; aucune affirmation de fidélité fondée sur le seul code.
- [ ] Documenter les fichiers modifiés, les commandes réellement exécutées, leurs résultats et les captures. Si un commit de code est créé, exclure les modifications préexistantes ; ne pas embarquer le lot Seerr avec un ajout global.

## Exécution proposée

La demande d’appliquer ce style partout est enregistrée dans la spécification
comme direction globale et feuille de route. Les lots bibliothèque/fiches,
gestion et lecteur suivront ce premier lot ; ils ne sont pas inclus dans
les six tâches ci-dessus. Leurs contrôles adopteront les mêmes principes
sans transformer les tableaux d’administration en bandeaux cinéma.

Recommandation : exécution native dans cette conversation, tâches séquentielles,
puis une revue indépendante finale. Les tâches partagent le thème, le bandeau
et les fixtures ; un seul exécutant évite les chevauchements de fichiers.
La méthode reste à choisir avec la relecture de ce plan. Aucun code produit
n’est modifié pendant la phase de planification.

## Exécution locale — 27 octobre 2026

L’instruction « lance l’intégration » autorise l’exécution native de ce plan.
Les composants d’accueil, la navigation, les grilles et les preuves Flutter
sont implémentés, avec revue indépendante et corrections de largeur locale,
sélection du backdrop et libellés au focus. Les contrôles communs et le lecteur
reçoivent aussi les jetons visuels approuvés ; le placement des boutons du
lecteur est conservé.

Deux adaptations de réalisation :

- La hauteur du fond suit directement `SliverPositioned.fill` dans le groupe
  carrousel/reprise, plutôt qu’un aller-retour de mesures manuelles.
- Le point de comparaison initial est une capture réelle de Kinos ouvert ;
  les références Flutter locales commencent avec l’intégration. Il n’existe
  donc pas de golden avant refonte avec exactement les mêmes données.

Les fichiers et preuves sont détaillés dans le rapport de validation voisin.
Le travail Seerr préexistant reste non committé et n’a pas été réinitialisé.
