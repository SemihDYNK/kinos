import 'package:kinos/util/motion_input.dart';
import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

/// Jetons de design du client.
///
/// Règle : aucune couleur, taille ou espacement codé en dur dans un widget.
/// Tout passe par ce fichier.

// ---------------------------------------------------------------------------
// Couleurs
// ---------------------------------------------------------------------------

abstract final class AppColors {
  /// Fond principal. Neutre, sans teinte bleue.
  static const background = Color(0xFF0A0A0A);

  /// Surface élevée. L'élévation se fait par la valeur, jamais par l'ombre.
  static const surface = Color(0xFF141414);
  static const surfaceHigh = Color(0xFF1C1C1C);
  static const surfaceHover = Color(0xFF232323);

  static const textPrimary = Color(0xFFFAFAFA);
  static const textSecondary = Color(0xFF8A8A8A);
  static const textDisabled = Color(0xFF4A4A4A);

  static const border = Color(0xFF1F1F1F);
  static const borderStrong = Color(0xFF3A3A3A);
  static const posterHoverBorder = Color(0xCC646464);

  /// Anneau de focus. Constant, jamais teinté par la palette dynamique.
  /// C'est le repère du mode salon : il doit être identique partout.
  static const focus = Color(0xFFFAFAFA);

  /// Repli du bandeau quand l'extraction de palette échoue ou rend un gris.
  static const heroFallback = surface;

  /// Voile de contraste sous un texte posé sur une image (bandeaux,
  /// jaquettes). Noir pur : indépendant de la teinte de fond, il ne sert
  /// qu'à garantir la lisibilité quelle que soit la jaquette en dessous.
  static const scrim = Color(0xFF000000);

  static const error = Color(0xFFE05252);
  static const success = Color(0xFF4CAF7D);

  /// État intermédiaire — ni l'échec net d'[error], ni la réussite
  /// franche de [success] : un import bloqué en attente d'action, un
  /// téléchargement en retard... Introduit pour le module Arr (file
  /// d'attente Radarr/Sonarr), aucun état de ce type ailleurs jusqu'ici.
  static const warning = Color(0xFFE0A852);

  /// Piste des barres de progression posées sur une image (vignettes de
  /// reprise). Distincte de [border] : plus claire, pensée pour rester
  /// visible sur une jaquette sombre comme sur une jaquette claire.
  static const progressTrack = Color(0xFF333333);

  /// Statuts calendrier Radarr/Sonarr (film/épisode annoncé, déjà
  /// téléchargé, ou en retard sur bibliothèque) — distincts d'
  /// [error]/[success]/[warning] : ce ne sont pas des résultats
  /// d'action, mais l'état d'une sortie dans le temps.
  static const calendarAnnounced = Color(0xFF6B8AB8);
  static const calendarDownloaded = success;
  static const calendarMissing = Color(0xFFB86B6B);
}

// ---------------------------------------------------------------------------
// Espacement — multiples de 8
// ---------------------------------------------------------------------------

abstract final class AppSpacing {
  static const xxs = 4.0;
  static const xs = 8.0;
  static const sm = 12.0;
  static const md = 16.0;
  static const lg = 24.0;
  static const xl = 32.0;
  static const xxl = 48.0;

  /// Marge horizontale des écrans.
  static const screenPadding = 32.0;

  /// Écart entre cartes d'une grille.
  static const gridGap = 12.0;
}

abstract final class AppMedia {
  static const posterHeightRatio = 1.5;
  static const posterAspectRatio = 2 / 3;
  static const resumeAspectRatio = 16 / 9;
  static const resumeTargetWidth = 280.0;
  static const denseGridMinWidth = 900.0;
  static const denseGridMinColumns = 6;
  static const denseGridMaxColumns = 8;
}

abstract final class AppMediaIcons {
  static const badgeSize = 28.0;
  static const badgeIconSize = 16.0;
  static const playTargetSize = 48.0;
  static const playIconSize = 22.0;
  static const circle = BorderRadius.all(Radius.circular(999));
  static const surface = Color(0xB3141414);
}

abstract final class AppBrand {
  static const markSize = 28.0;
  static const wordmarkWidth = 132.0;
  static const startupMarkSize = 128.0;
  static const startupGuideWidth = 1.5;
  static const startupGuideOpacity = .6;
  static const startupApertureFeather = 28.0;
  // Creux du K (jonction des deux branches), en fraction de la taille du
  // signe depuis son centre : point d'où part l'ouverture.
  static const startupMarkNotch = Offset(-48 / 256, 0);
  static const startupWaitWidth = 96.0;
  static const startupWaitSegment = 28.0;
  static const startupWaitGap = AppSpacing.xl;
  static const startupWaitOpacity = .55;
  static const startupWaitTrackOpacity = .08;
  // Dégradé du clap (intro longue) : de la dominante du film, derrière le
  // K, vers le fond. Rayon en fraction du plus petit côté de l'écran, au
  // départ de l'onde puis posé.
  static const startupBloomFrom = .30;
  static const startupBloomRadius = .95;
  static const wordmarkAspectRatio = 949 / 256;
}

abstract final class AppNavigation {
  static const surface = Color(0x4D141414);
  static const glassBorder = Color(0x33FFFFFF);
  static const blurSigma = 18.0;
  static const inset = 12.0;
  static const collapsedWidth = 68.0;
  static const expandedWidth = 240.0;
  static const radius = 24.0;
  static const selectionRadius = 12.0;
  static const rowHeight = 48.0;
  static const iconSize = 22.0;
  static const avatarSize = 32.0;
  static const itemGap = 4.0;
  static const borderWidth = 1.0;
  static const border = BorderRadius.all(Radius.circular(radius));
  static const selection = BorderRadius.all(Radius.circular(selectionRadius));
}

abstract final class AppLibraryLayout {
  static const searchWidth = 320.0;
  static const filterPanelWidth = 800.0;
  static const inlineWidth = 1300.0;
}

abstract final class AppTopNavigation {
  static const indicatorHeight = 2.0;

  /// Hauteur mesurée de la capsule : sert à centrer d'autres commandes sur
  /// elle (bouton retour épinglé).
  static const capsuleHeight = 63.0;

  /// Rayon concentrique à la capsule : le sien moins l'espace qui les sépare.
  static const tabBorder = BorderRadius.all(
      Radius.circular(AppNavigation.radius - AppSpacing.xxs));
  static const searchFieldWidth = 280.0;

  /// Hauteur commune du bouton loupe et du champ ouvert : celle des onglets.
  static const searchControlHeight = AppNavigation.rowHeight;

  /// Écart entre le bas de la capsule et le voile de résultats.
  static const searchPopoverGap = AppSpacing.xs;
  static const searchPopoverWidth = 460.0;
  static const searchPopoverHeightFraction = .60;
  static const searchPopoverEmptyHeight = 96.0;
  static const resultPosterWidth = 48.0;
  static const contentInset = 100.0;
}

/// Bandeau d'une page de genre : une part de la hauteur de la fenêtre,
/// bornée.
abstract final class AppGenrePage {
  static const bannerHeightFraction = .42;
  static const bannerMinHeight = 340.0;
  static const bannerMaxHeight = 480.0;
}

abstract final class AppGlass {
  static const blur = 18.0;
  static const surface = Color(0x99141414);
  static const border = Color(0x33FFFFFF);
  static const episodeTargetWidth = 260.0;
}

abstract final class AppPlayerStyle {
  static const segmentBottomInset = 160.0;
  static const staticLoadingProgress = .75;
  static const segmentPartialOpacity = .75;
  static const surface = Color(0xD91C1C1C);
  static const controlSurface = Color(0xA6141414);
}

abstract final class AppHeroLayout {
  /// Débord, en pixels, de la couche masquée du bandeau sous sa zone
  /// affichée : le bord fractionnaire de son calque n'y laisse plus de ligne.
  static const seamGuard = 3.0;

  static const minHeight = 520.0;
  static const couchHeight = 620.0;
  static const viewportHeightFraction = .75;
  static const imageAlignment = Alignment.topCenter;
  static const logoWidth = 480.0;
  static const logoHeight = 180.0;
  static const textWidthFraction = .48;
  static const narrowTextWidthFraction = .88;
  static const narrowWidth = 1000.0;
  static const synopsisWidth = 520.0;
  static const titleMin = 64.0;
  static const titleMax = 144.0;
  static const imageFadeStart = .55;
  static const imageUniformScrimOpacity = .30;
  static const imageScrimOpacity = .85;
  static const imageReadingScrimOpacity = .75;
  static const imageUpperScrimOpacity = .20;
  static const imageReadingScrimStart = .55;
  static const imageUpperScrimStart = .25;
  static const secondaryOpacity = .75;
  static const titleBottomSpace = 88.0;
  static double titleSizeFor(double width, AppDensity density) =>
      (width * .084 * density.scale).clamp(titleMin, titleMax);
}

abstract final class AppDetailLayout {
  /// Avatars des amis Letterboxd, dans le bandeau d'un film : une seule
  /// rangée qui tient dans la largeur du synopsis.
  static const friendAvatarSize = 40.0;

  /// Largeur d'une cellule d'ami : cinq étoiles et demie ([friendStarSize]
  /// × 5,5) y tiennent. Avec l'anneau de focus (8 px) et l'écart entre
  /// cellules, sept amis et « +N » tiennent sur une seule ligne du synopsis.
  static const friendCellWidth = 68.0;

  /// Taille d'une étoile de note : fixe pour toutes les notes.
  static const friendStarSize = 12.0;

  /// Barre verticale entre ta cellule (photo et note) et celles des amis.
  static const friendDividerHeight = 52.0;

  /// Amis affichés avant « +N ».
  static const friendsVisible = 7;
  static const seriesViewportFraction = .68;
  static const seriesMinHeight = 560.0;
  static const seriesTintTailHeight = 64.0;
  static const seriesEpisodeWidth = 320.0;
  static const seriesEpisodeColumns = 4;
  static const tintTailHeight = 112.0;
  static const tintFadeStart = .80;
  static const movieViewportFraction = .86;
  static const movieMinHeight = 760.0;
  static const movieBottomPadding = 48.0;
  static const movieImageFadeStart = .78;
  static const movieImageScrim = .12;
  static const movieReadingScrimStart = .70;
  static const popoverMinWidth = 240.0;
  static const popoverMaxWidth = 360.0;
  static const popoverCheckSize = 18.0;
  static const popoverHighlight = Color(0x1AFFFFFF);
  static const movieSynopsisWidth = 680.0;
  static const synopsisCollapsedLines = 4;
  static const castWidthFraction = .70;
  static const castMaxWidth = 152.0;
  static const infoLabelWidth = 104.0;
  static const infoColumnsMinWidth = 360.0;
  static const viewportHeightFraction = .60;
  static const topPadding = 112.0;
  static const readingWidth = 760.0;
  static double minHeightFor(AppDensity density) => density == AppDensity.couch
      ? AppHeroLayout.couchHeight
      : AppHeroLayout.minHeight;
}

abstract final class AppManagementLayout {
  static const settingsNavigationWidth = 272.0;
  static const settingsSplitWidth = 1000.0;
  static const settingsValueWidth = 220.0;
  static const numberFieldWidth = 88.0;
  static const requestPosterWidth = 40.0;
  static const avatarSize = 28.0;
  static const requesterWidth = 200.0;
  static const requestStatusWidth = 260.0;
  static const requestWideWidth = 1000.0;
  static const statusDotSize = 8.0;
}

abstract final class AppPageLayout {
  static const titleSize = 42.0;
  static const titleHeight = 1.1;
  static const titleTracking = -1.2;
  static const compactWidth = 760.0;
  static const settingsWidth = 1120.0;
  static const toolbarHeight = 48.0;
  static const rowHeight = 64.0;
  static const episodeWidth = 160.0;
  static const episodeCompactWidth = 112.0;
  static const requestPosterWidth = 64.0;
}

/// Écran de connexion : deux étapes (serveur, compte) sur une seule
/// colonne de lecture. Les largeurs restent bornées pour que les rangées
/// de serveurs et le formulaire ne s'étirent pas sur un écran 4K.
abstract final class AppLoginLayout {
  static const maxWidth = 1000.0;
  static const contentWidth = 640.0;
  static const descriptionWidth = 520.0;
  static const dialogWidth = 440.0;
  static const leadingBox = 40.0;
  static const leadingIcon = 18.0;
  static const trailingIcon = 18.0;
  static const statusIcon = 20.0;
  static const spinner = 18.0;
  static const progressStroke = 2.0;
  static const statusBorder = 1.0;
  static const errorSurfaceOpacity = .12;
}

abstract final class AppRadii {
  static const card = 8.0;
  static const control = 10.0;
  static const sheet = 20.0;

  static const cardBorder = BorderRadius.all(Radius.circular(card));
  static const controlBorder = BorderRadius.all(Radius.circular(control));
  static const sheetBorder = BorderRadius.all(Radius.circular(sheet));
}

abstract final class AppDurations {
  static const bufferingDelay = Duration(milliseconds: 180);
  static const hover = Duration(milliseconds: 120);
  static const selection = Duration(milliseconds: 240);
  static const favourite = Duration(milliseconds: 400);
  static const posterHover = Duration(milliseconds: 260);
  static const navigationExpand = Duration(milliseconds: 320);
  static const navigationCollapse = Duration(milliseconds: 220);
  static const navigationSelection = Duration(milliseconds: 240);
  static const favouriteRemoval = Duration(milliseconds: 180);
  static const popover = Duration(milliseconds: 180);
  static const unroll = Duration(milliseconds: 260);
  static const focusRing = Duration(milliseconds: 100);
  // Clic sur une tuile : enfoncement, d'où part la transition de page.
  static const pressIn = Duration(milliseconds: 90);
  static const pressSettle = Duration(milliseconds: 180);
  static const heroTint = Duration(milliseconds: 300);
  static const heroSlide = Duration(milliseconds: 420);
  static const pageTransition = Duration(milliseconds: 220);
  static const startupLogo = Duration(milliseconds: 1300);
  // Avance maximale des animations de démarrage par image affichée : une
  // image bloquée (l'accueil qui se construit) les ralentit au lieu de les
  // faire sauter.
  static const startupFrameCap = Duration(milliseconds: 25);
  // Avant l'ouverture, le rideau attend que les images sortent à temps
  // (écart entre deux images au plus [startupSettleFrame], plusieurs
  // d'affilée), au plus [startupSettleMax].
  static const startupSettleFrame = Duration(milliseconds: 20);
  static const startupSettleMax = Duration(milliseconds: 700);
  // Premier lancement de la session : allumage, assemblage en profondeur,
  // clap, puis le mot (cf. AppMotion.startupIntro*).
  static const startupIntro = Duration(milliseconds: 2850);
  static const startupReveal = Duration(milliseconds: 900);
  // Ouverture après l'intro longue : le faisceau du K s'allume et s'élargit.
  static const startupIntroReveal = Duration(milliseconds: 2000);
  // Attente de l'accueil au-delà de ce délai : un trait signale que l'app
  // travaille. En deçà, rien ne s'affiche.
  static const startupWaitDelay = Duration(milliseconds: 400);
  static const startupWaitFade = Duration(milliseconds: 300);
  static const startupWaitSweep = Duration(milliseconds: 1400);
  // Le texte du bandeau d'accueil se pose pendant l'ouverture.
  static const startupContentDelay = Duration(milliseconds: 320);
  static const startupLoadTimeout = Duration(seconds: 30);
  // Attente maximale des vignettes de l'accueil avant d'ouvrir le rideau.
  static const startupArtworkBudget = Duration(milliseconds: 600);
}

abstract final class AppMotion {
  static const startupMarkCloseup = 7.0;
  static const startupMarkTilt = .65;
  static const startupMarkAngle = -.32;
  // Profondeur du pivot initial, en fraction de la taille du signe : plus
  // la valeur est grande, plus la perspective est marquée.
  static const startupMarkPerspective = .9;
  // Largeur du bord adouci du remplissage, en fraction du signe.
  static const startupMarkFillEdge = .18;
  static const startupMarkOffsets = [
    Offset(-.30, 0),
    Offset(.34, -.25),
    Offset(.34, .25),
  ];
  static const startupMarkAssembly = [
    Interval(.06, .55, curve: easeOut),
    Interval(.14, .66, curve: easeOut),
    Interval(.22, .74, curve: easeOut),
  ];
  static const startupMarkTrace = Interval(0, .45, curve: easeOut);

  // Version longue (premier lancement de la session). L'assemblage et le
  // clap occupent le début de AppDurations.startupIntro, jusqu'à
  // [startupIntroAssemblyEnd] ; les intervalles ci-dessous sont en
  // fraction de cette partie. Ensuite vient le mot : le K glisse pour que
  // « KINOS » soit centré, les lettres INOS arrivent écartées et se
  // resserrent, puis le mot complet se pose.
  static const startupIntroAssemblyEnd = .754;
  static const startupIntroWord = Interval(.754, .912);
  // Dans le mot (fraction de [startupIntroWord]) : glissement du K, puis
  // chaque lettre, en décalé.
  static const startupIntroWordSlide = Interval(0, .8, curve: easeOut);
  static const startupIntroLetters = [
    Interval(.05, .70, curve: easeOut),
    Interval(.12, .78, curve: easeOut),
    Interval(.19, .86, curve: easeOut),
    Interval(.26, .94, curve: easeOut),
  ];
  // Écart supplémentaire entre lettres à leur arrivée, en unités du signe.
  static const startupIntroTracking = 48.0;

  // Assemblage (fraction de la partie assemblage). La caméra part d'un
  // gros plan : le contour
  // du K se dessine en fantôme à l'échelle de l'écran, les pièces
  // arrivent des bords et du fond pendant qu'elle recule ; la branche du
  // haut, arrivée ouverte autour du creux du K, prend son élan puis se
  // referme comme un clap, et la marque encaisse le choc.
  static const startupIntroTrace = Interval(0, .50, curve: Cubic(.45, 0, .25, 1));
  static const startupIntroTraceFade = Interval(0, .12, curve: easeOut);
  static const startupIntroArrivals = [
    Interval(.14, .52, curve: easeOut),
    Interval(.26, .64, curve: easeOut),
    Interval(.20, .58, curve: easeOut),
  ];
  // Taille d'une pièce au fond, avant d'arriver (1 = à sa place).
  static const startupIntroDepth = .6;
  // Distance de départ des pièces, en multiple des écarts de l'assemblage
  // court : assez loin pour qu'elles entrent par les bords de l'écran.
  static const startupIntroSpread = 2.2;
  // Gros plan de départ (en multiple de la taille finale), et recul de la
  // caméra : lent au départ pour laisser voir le trait, posé avant l'élan.
  static const startupIntroCloseup = 6.0;
  static const startupIntroCamera = Interval(.10, .68, curve: Cubic(.75, 0, .25, 1));
  // Inclinaison de départ de la caméra, résorbée pendant le recul.
  static const startupIntroTilt = .35;
  // Images d'affilée sorties à temps avant de lancer l'ouverture.
  static const startupSettleFrames = 8;
  // Branche du haut : ouverte (radians), élan, puis fermeture accélérée.
  static const startupIntroClapOpen = -.32;
  static const startupIntroClapLift = -.07;
  static const startupIntroClapWindup = Interval(.62, .71, curve: easeOut);
  static const startupIntroClapClose = Interval(.71, .78, curve: Cubic(.6, 0, 1, .6));
  // Instant du clap (fin de la fermeture), puis choc encaissé sans rebond.
  static const startupIntroClap = .78;
  static const startupIntroImpact = .02;
  static const startupIntroImpactIn = Interval(.78, .80);
  static const startupIntroImpactOut = Interval(.80, .94, curve: easeOut);
  static const startupIntroGhostOut = Interval(.78, .88, curve: easeOut);
  // Le dégradé de couleur naît au clap (fraction de toute l'intro :
  // startupIntroAssemblyEnd × startupIntroClap ≈ .588) et s'étend comme une
  // onde avant de se poser.
  static const startupIntroBloom = Interval(.588, .72, curve: easeOut);
  // Passage du repli neutre à la vraie dominante, si elle arrive tard.
  static const startupTintFade = Duration(milliseconds: 400);
  // Balayage du blanc : régulier sur toute sa durée, pour qu'on le voie
  // traverser le K plutôt que surgir.
  static const startupMarkFill = Interval(.28, .78, curve: Cubic(.45, 0, .25, 1));
  static const startupMarkCamera =
      Interval(.12, .87, curve: Cubic(.65, 0, .2, 1));
  static const startupMarkFade = Interval(.08, .40, curve: easeOut);
  // Sortie : la caméra plonge dans le creux du K, qui grandit en
  // s'effaçant pendant que l'ouverture part de ce creux.
  static const startupExitZoom = 4.0;
  static const startupExitDive = Interval(0, .55, curve: Cubic(.55, 0, .8, .3));
  static const startupAperture = Interval(.08, 1, curve: Cubic(.65, 0, .35, 1));
  // Ouverture après l'intro longue (fraction de
  // AppDurations.startupIntroReveal) : les deux branches du K sont un
  // projecteur. L'espace entre elles s'allume sur l'accueil, puis elles
  // pivotent autour du creux du K en s'écartant, et le faisceau s'élargit
  // jusqu'à couvrir l'écran. INOS, dans le faisceau, s'efface à l'allumage.
  static const startupIntroBeamOn = Interval(0, .16, curve: easeOut);
  // La lumière s'allonge depuis le creux du K (jusqu'à 1,5 fois le plus
  // grand côté de l'écran), derrière un front adouci (part de sa longueur).
  // Sa pointe va à vitesse presque régulière : sur une courbe qui démarre
  // vite, elle traversait l'écran en quatre images.
  static const startupIntroBeamReach = Interval(.02, .40, curve: Cubic(.4, 0, .4, 1));
  static const startupIntroBeamFront = .45;
  // Lueur du cône de lumière (opacité maximale près du K), éteinte
  // pendant l'élargissement.
  static const startupIntroBeamGlow = .28;
  static const startupIntroBeamGlowOut = Interval(.50, .85, curve: easeOut);
  // Le rayon traverse l'écran et tient un instant à l'angle de la bouche
  // du K avant de s'élargir : sinon on ne voit jamais le projecteur.
  static const startupIntroBeamOpen = Interval(.48, 1, curve: Cubic(.6, 0, .3, 1));
  // Demi-angle final du faisceau : l'écran entier (il part de celui de la
  // bouche du K, cf. StartupIntroBeam.mouthAngle).
  static const startupIntroBeamTo = 3.1416;
  static const startupIntroWordOut = Interval(0, .25, curve: easeOut);
  // Les volets (branches du K) bordent le faisceau jusqu'à la verticale
  // (vers 74 %) et s'effacent en l'approchant : au-delà, ils se
  // retourneraient par-dessus la hampe en K à l'envers.
  static const startupIntroMarkOut = Interval(.62, .76, curve: easeOut);
  static const easeOut = Cubic(.23, 1, .32, 1);
  static const heroTitleReveal = Interval(0, .75, curve: easeOut);
  static const heroSynopsisReveal = Interval(.16, 1, curve: easeOut);
  static const pageTravelFraction = .015;
  static const playerSeekTravel = .12;
  static const playerVolumePulse = 1.12;
  static const heroTextTravel = AppSpacing.sm;
  // Changement de diapo : le texte glisse du côté de la navigation, et
  // l'image entrante se pose depuis un léger agrandissement.
  static const heroTextSlideTravel = AppSpacing.xl;
  static const heroImageSettle = .04;
  // Opacité d'un élément caché qui doit rester dessiné (prêt à apparaître
  // sans coût à sa première image) : imperceptible.
  static const hiddenButPainted = .004;
  // Défilement de l'accueil : l'image du bandeau ne suit le contenu qu'à
  // moitié (elle paraît plus loin) et s'éteint avant d'avoir quitté
  // l'écran ; le texte, au premier plan, défile normalement et s'efface en
  // approchant du haut.
  static const heroParallax = .5;
  static const heroScrollFadeEnd = 1.0;
  static const heroScrollFade = Curves.easeIn;
  // Opacité plancher de l'image : elle ne disparaît jamais tout à fait.
  static const heroScrollMinOpacity = .3;
  static const heroTextFadeLead = AppSpacing.xxl;
  static const menuScale = .95;
  static const pressScale = .96;

  /// Part du déroulé pendant laquelle le voile finit d'apparaître en fondu.
  static const unrollFadeEnd = .35;
  static const navigationReveal = Cubic(.2, 1, .3, 1);
  static const navigationLabels = Interval(.25, 1, curve: Curves.easeOut);
  static const posterReveal = Cubic(.2, 1.3, .35, 1);
  static const posterZoom = .025;
  // Marge qu'un conteneur qui découpe (défilement horizontal) doit laisser
  // autour des jaquettes : le soulèvement plus la moitié du grossissement
  // d'une carte de ~300 px.
  static const posterLiftRoom = AppSpacing.xs;
  // Tuile paysage (genres) : l'image s'avance dans son cadre au survol et
  // au focus.
  static const tileImageZoom = .06;
  static const posterLift = 4.0;
  static const posterActionScale = .88;
  static const heartLift = .30;
  static const heartRecoil = .94;
  static const heartSettle = 1.04;
  static const iconGrid = 24.0;
  static const iconStroke = 1.8;
  // Les raccourcis du compositeur peuvent laisser une touche enfoncée côté Flutter.
  static bool enabled(BuildContext context) =>
      !MediaQuery.disableAnimationsOf(context) &&
      !MediaQuery.accessibleNavigationOf(context) &&
      !MotionInputBoundary.keyboardOf(context);
}

// ---------------------------------------------------------------------------
// Densité — bureau vs salon
// ---------------------------------------------------------------------------

enum AppDensity {
  desk,
  couch;

  /// Facteur appliqué aux tailles de cible et aux espacements.
  double get scale => switch (this) {
        AppDensity.desk => 1.0,
        AppDensity.couch => 1.35,
      };

  /// Taille minimale d'une cible interactive.
  double get minTarget => switch (this) {
        AppDensity.desk => 36.0,
        AppDensity.couch => 52.0,
      };

  /// Épaisseur de l'anneau de focus. Plus épais à trois mètres.
  double get focusWidth => switch (this) {
        AppDensity.desk => 2.0,
        AppDensity.couch => 3.0,
      };

  /// Colonnes de la grille de jaquettes selon la largeur disponible.
  int columnsFor(double width) {
    final target = switch (this) {
      AppDensity.desk => 180.0,
      AppDensity.couch => 240.0,
    };
    if (this == AppDensity.desk && width >= AppMedia.denseGridMinWidth) {
      return (width / target)
          .floor()
          .clamp(AppMedia.denseGridMinColumns, AppMedia.denseGridMaxColumns);
    }
    return (width / target).floor().clamp(3, 10);
  }
}

// ---------------------------------------------------------------------------
// Typographie
// ---------------------------------------------------------------------------
//
// L'échelle est le principal levier de caractère du projet : rapport de 1 à 3
// entre le titre d'écran et les métadonnées. Ne pas l'aplatir.

abstract final class AppTypography {
  /// Police variable embarquée (`assets/fonts/inter/`), même convention que
  /// Rubik : un seul fichier, un axe `wght` piloté par [fontVariations].
  /// `null` retomberait sur la police système ; ne jamais laisser ce cas ici.
  static const fontFamily = 'Inter';

  static const heroEditorial = TextStyle(
    fontFamily: 'BarlowCondensed',
    fontSize: 112,
    fontWeight: FontWeight.w700,
    height: .95,
    letterSpacing: -1.5,
    color: AppColors.textPrimary,
  );

  /// Titre de bandeau. 40–48 px selon la densité.
  static const display = TextStyle(
    fontFamily: fontFamily,
    fontSize: 44,
    fontWeight: FontWeight.w600,
    fontVariations: [FontVariation('wght', 600)],
    letterSpacing: -1.1, // ≈ -0.025em
    height: 1.05,
    color: AppColors.textPrimary,
  );

  /// Palier intermédiaire de [display], même rapport -0.025em/1.05.
  static const displayMedium = TextStyle(
    fontFamily: fontFamily,
    fontSize: 36,
    fontWeight: FontWeight.w600,
    fontVariations: [FontVariation('wght', 600)],
    letterSpacing: -0.9, // ≈ -0.025em
    height: 1.05,
    color: AppColors.textPrimary,
  );

  /// Palier le plus bas de [display], même rapport -0.025em/1.05.
  static const displaySmall = TextStyle(
    fontFamily: fontFamily,
    fontSize: 30,
    fontWeight: FontWeight.w600,
    fontVariations: [FontVariation('wght', 600)],
    letterSpacing: -0.75, // ≈ -0.025em
    height: 1.05,
    color: AppColors.textPrimary,
  );

  /// Titre de section ("Continuer à regarder").
  static const sectionTitle = TextStyle(
    fontFamily: fontFamily,
    fontSize: 22,
    fontWeight: FontWeight.w600,
    fontVariations: [FontVariation('wght', 600)],
    letterSpacing: -0.33, // ≈ -0.015em
    height: 1.2,
    color: AppColors.textPrimary,
  );

  /// [sectionTitle] réduit, pour les emplacements Material plus modestes
  /// (headlineSmall, titleLarge) : même rapport -0.015em/1.2.
  static const sectionTitleSmall = TextStyle(
    fontFamily: fontFamily,
    fontSize: 20,
    fontWeight: FontWeight.w600,
    fontVariations: [FontVariation('wght', 600)],
    letterSpacing: -0.3, // ≈ -0.015em
    height: 1.2,
    color: AppColors.textPrimary,
  );

  /// Rupture de registre sur les titres de rangée d'inventaire du
  /// catalogue ("Bien notés, jamais vus", "Genres étroits"...) — cf.
  /// spec du lot graines/inventaire : visible mais sobre, entre
  /// [sectionTitleSmall] (20px) et [cardTitle] (14px). `textSecondary`
  /// (pas `textPrimary`) et sans le `letterSpacing` négatif des titres
  /// `sectionTitle*` — un changement de registre typographique, jamais
  /// un titre de section explicite superposé ("Votre catalogue" n'existe
  /// pas, cf. spec : "aucune rangée ni titre de transition explicite").
  static const catalogSectionTitle = TextStyle(
    fontFamily: fontFamily,
    fontSize: 18,
    fontWeight: FontWeight.w500,
    fontVariations: [FontVariation('wght', 500)],
    height: 1.2,
    color: AppColors.textSecondary,
  );

  /// Titre de carte.
  static const cardTitle = TextStyle(
    fontFamily: fontFamily,
    fontSize: 14,
    fontWeight: FontWeight.w500,
    fontVariations: [FontVariation('wght', 500)],
    height: 1.3,
    color: AppColors.textPrimary,
  );

  static const body = TextStyle(
    fontFamily: fontFamily,
    fontSize: 15,
    fontWeight: FontWeight.w400,
    fontVariations: [FontVariation('wght', 400)],
    height: 1.5,
    color: AppColors.textPrimary,
  );

  /// Métadonnées : année, durée, résolution, temps restant.
  static const meta = TextStyle(
    fontFamily: fontFamily,
    fontSize: 13,
    fontWeight: FontWeight.w400,
    fontVariations: [FontVariation('wght', 400)],
    height: 1.4,
    color: AppColors.textSecondary,
  );

  /// Sur-titre en capitales espacées ("reprendre la lecture").
  static const overline = TextStyle(
    fontFamily: fontFamily,
    fontSize: 12,
    fontWeight: FontWeight.w400,
    fontVariations: [FontVariation('wght', 400)],
    letterSpacing: 0.96, // ≈ 0.08em
    color: AppColors.textSecondary,
  );

  static const button = TextStyle(
    fontFamily: fontFamily,
    fontSize: 14,
    fontWeight: FontWeight.w500,
    fontVariations: [FontVariation('wght', 500)],
    height: 1.2,
  );
}

// ---------------------------------------------------------------------------
// Extension de thème — accès aux jetons non couverts par ThemeData
// ---------------------------------------------------------------------------

@immutable
class AppTokens extends ThemeExtension<AppTokens> {
  const AppTokens({
    required this.density,
    required this.heroTint,
    required this.heroTextSecondary,
  });

  final AppDensity density;

  /// Dominante courante du bandeau. Déjà bridée par le service de palette.
  final Color heroTint;

  /// Gris secondaire décalé en teinte, à luminance constante.
  final Color heroTextSecondary;

  static const fallback = AppTokens(
    density: AppDensity.desk,
    heroTint: AppColors.heroFallback,
    heroTextSecondary: AppColors.textSecondary,
  );

  @override
  AppTokens copyWith({
    AppDensity? density,
    Color? heroTint,
    Color? heroTextSecondary,
  }) =>
      AppTokens(
        density: density ?? this.density,
        heroTint: heroTint ?? this.heroTint,
        heroTextSecondary: heroTextSecondary ?? this.heroTextSecondary,
      );

  @override
  AppTokens lerp(covariant AppTokens? other, double t) {
    if (other == null) return this;
    return AppTokens(
      density: t < 0.5 ? density : other.density,
      heroTint: Color.lerp(heroTint, other.heroTint, t) ?? heroTint,
      heroTextSecondary:
          Color.lerp(heroTextSecondary, other.heroTextSecondary, t) ??
              heroTextSecondary,
    );
  }
}

extension AppTokensAccess on BuildContext {
  AppTokens get tokens =>
      Theme.of(this).extension<AppTokens>() ?? AppTokens.fallback;
}

// ---------------------------------------------------------------------------
// Construction du thème
// ---------------------------------------------------------------------------

ThemeData buildAppTheme({
  AppDensity density = AppDensity.desk,
  Color heroTint = AppColors.heroFallback,
  Color heroTextSecondary = AppColors.textSecondary,
}) {
  const scheme = ColorScheme.dark(
    surface: AppColors.background,
    onSurface: AppColors.textPrimary,
    surfaceContainer: AppColors.surface,
    surfaceContainerHigh: AppColors.surfaceHigh,
    primary: AppColors.textPrimary,
    onPrimary: AppColors.background,
    primaryContainer: AppColors.surfaceHigh,
    onPrimaryContainer: AppColors.textPrimary,
    secondary: AppColors.textSecondary,
    onSecondary: AppColors.background,
    secondaryContainer: AppColors.surfaceHigh,
    onSecondaryContainer: AppColors.textPrimary,
    outline: AppColors.border,
    outlineVariant: AppColors.borderStrong,
    error: AppColors.error,
  );

  final base = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: scheme,
    scaffoldBackgroundColor: AppColors.background,
    fontFamily: AppTypography.fontFamily,
    visualDensity: VisualDensity.standard,
    splashFactory: NoSplash.splashFactory,
  );

  return base.copyWith(
    extensions: [
      AppTokens(
        density: density,
        heroTint: heroTint,
        heroTextSecondary: heroTextSecondary,
      ),
    ],
    // Les 15 slots Material sont couverts explicitement : aucun ne doit
    // retomber sur le style par défaut de ThemeData (Roboto, tailles Material
    // stock) — l'échelle du projet est le seul levier de caractère de l'UI.
    textTheme: base.textTheme.copyWith(
      displayLarge: AppTypography.heroEditorial
          .copyWith(fontSize: AppHeroLayout.titleMin),
      displayMedium: AppTypography.displayMedium,
      displaySmall: AppTypography.displaySmall,
      headlineLarge: AppTypography.sectionTitle,
      headlineMedium: AppTypography.sectionTitle,
      headlineSmall: AppTypography.sectionTitleSmall,
      titleLarge: AppTypography.sectionTitleSmall,
      titleMedium: AppTypography.cardTitle,
      titleSmall: AppTypography.cardTitle,
      bodyLarge: AppTypography.body,
      bodyMedium: AppTypography.body,
      bodySmall: AppTypography.meta,
      labelLarge: AppTypography.button,
      labelMedium: AppTypography.overline,
      labelSmall: AppTypography.overline,
    ),

    // Élévation par la valeur, jamais par l'ombre.
    cardTheme: const CardThemeData(
      color: AppColors.surface,
      elevation: 0,
      shadowColor: Colors.transparent,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: AppRadii.cardBorder),
    ),

    dividerTheme: const DividerThemeData(
      color: AppColors.border,
      thickness: 1,
      space: 1,
    ),

    // Bouton principal : blanc plein, jamais teinté par la palette.
    filledButtonTheme: FilledButtonThemeData(
      style: ButtonStyle(
        backgroundColor: const WidgetStatePropertyAll(AppColors.textPrimary),
        foregroundColor: const WidgetStatePropertyAll(AppColors.background),
        textStyle: const WidgetStatePropertyAll(AppTypography.button),
        minimumSize: WidgetStatePropertyAll(Size(0, density.minTarget)),
        padding: const WidgetStatePropertyAll(
          EdgeInsets.symmetric(horizontal: AppSpacing.lg),
        ),
        shape: const WidgetStatePropertyAll(
          RoundedRectangleBorder(borderRadius: AppRadii.controlBorder),
        ),
        elevation: const WidgetStatePropertyAll(0),
      ),
    ),

    outlinedButtonTheme: OutlinedButtonThemeData(
      style: ButtonStyle(
        foregroundColor: const WidgetStatePropertyAll(AppColors.textPrimary),
        textStyle: const WidgetStatePropertyAll(AppTypography.button),
        minimumSize: WidgetStatePropertyAll(Size(0, density.minTarget)),
        side: const WidgetStatePropertyAll(
          BorderSide(color: AppColors.borderStrong, width: 0.5),
        ),
        shape: const WidgetStatePropertyAll(
          RoundedRectangleBorder(borderRadius: AppRadii.controlBorder),
        ),
        overlayColor: const WidgetStatePropertyAll(AppColors.surfaceHover),
      ),
    ),

    iconButtonTheme: IconButtonThemeData(
      style: ButtonStyle(
        foregroundColor: const WidgetStatePropertyAll(AppColors.textPrimary),
        minimumSize: WidgetStatePropertyAll(
          Size.square(density.minTarget),
        ),
        overlayColor: const WidgetStatePropertyAll(AppColors.surfaceHover),
      ),
    ),

    inputDecorationTheme: const InputDecorationThemeData(
      filled: true,
      fillColor: AppColors.surface,
      hintStyle: TextStyle(color: AppColors.textSecondary),
      contentPadding: EdgeInsets.symmetric(
          horizontal: AppSpacing.md, vertical: AppSpacing.sm),
      border: OutlineInputBorder(
          borderRadius: AppRadii.controlBorder,
          borderSide: BorderSide(color: AppColors.borderStrong)),
      enabledBorder: OutlineInputBorder(
          borderRadius: AppRadii.controlBorder,
          borderSide: BorderSide(color: AppColors.borderStrong)),
      focusedBorder: OutlineInputBorder(
          borderRadius: AppRadii.controlBorder,
          borderSide: BorderSide(color: AppColors.focus)),
    ),
    // Interrupteurs et cases monochromes : l'état se lit au contraste, jamais
    // à une couleur d'accent.
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith((states) =>
          states.contains(WidgetState.disabled)
              ? AppColors.textDisabled
              : states.contains(WidgetState.selected)
                  ? AppColors.background
                  : AppColors.textSecondary),
      trackColor: WidgetStateProperty.resolveWith((states) =>
          states.contains(WidgetState.selected) &&
                  !states.contains(WidgetState.disabled)
              ? AppColors.textPrimary
              : AppColors.surfaceHigh),
      trackOutlineColor: WidgetStateProperty.resolveWith((states) =>
          states.contains(WidgetState.selected)
              ? AppColors.textPrimary
              : AppColors.borderStrong),
      overlayColor: const WidgetStatePropertyAll(Colors.transparent),
    ),
    checkboxTheme: CheckboxThemeData(
      fillColor: WidgetStateProperty.resolveWith((states) =>
          states.contains(WidgetState.selected)
              ? AppColors.textPrimary
              : Colors.transparent),
      checkColor: const WidgetStatePropertyAll(AppColors.background),
      side: const BorderSide(color: AppColors.borderStrong, width: 1.5),
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(4))),
    ),
    popupMenuTheme: const PopupMenuThemeData(
      textStyle: AppTypography.cardTitle,
      color: AppColors.surfaceHigh,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      shape: RoundedRectangleBorder(
          borderRadius: AppRadii.sheetBorder,
          side: BorderSide(color: AppColors.borderStrong)),
    ),
    dialogTheme: const DialogThemeData(
      titleTextStyle: AppTypography.sectionTitle,
      contentTextStyle: AppTypography.body,
      actionsPadding: EdgeInsets.fromLTRB(
          AppSpacing.lg, AppSpacing.sm, AppSpacing.lg, AppSpacing.lg),
      alignment: Alignment.center,
      backgroundColor: AppColors.surface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: AppRadii.sheetBorder),
    ),
    menuTheme: const MenuThemeData(
        style: MenuStyle(
      backgroundColor: WidgetStatePropertyAll(AppColors.surfaceHigh),
      surfaceTintColor: WidgetStatePropertyAll(Colors.transparent),
      elevation: WidgetStatePropertyAll(0),
      shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(borderRadius: AppRadii.sheetBorder)),
    )),
    tooltipTheme: const TooltipThemeData(
      decoration: BoxDecoration(
        color: AppColors.surfaceHigh,
        borderRadius: AppRadii.controlBorder,
      ),
      textStyle: AppTypography.meta,
      waitDuration: Duration(milliseconds: 500),
    ),

    // Le défilement lisse trackpad/souris, pas le rebond mobile.
    scrollbarTheme: const ScrollbarThemeData(
      thumbColor: WidgetStatePropertyAll(AppColors.borderStrong),
      thickness: WidgetStatePropertyAll(6),
      radius: Radius.circular(3),
      crossAxisMargin: 2,
    ),
  );
}

// ---------------------------------------------------------------------------
// Anneau de focus
// ---------------------------------------------------------------------------
//
// À utiliser sur TOUT élément interactif. C'est la règle absolue du projet :
// rien ne doit être atteignable à la souris sans l'être au clavier.

class PosterHoverMotion extends StatelessWidget {
  const PosterHoverMotion(
      {required this.active, required this.builder, super.key});
  final bool active;
  final Widget Function(BuildContext context, double reveal) builder;

  @override
  Widget build(BuildContext context) {
    final motion = AppMotion.enabled(context);
    return TweenAnimationBuilder<double>(
      tween: Tween(end: motion && active ? 1 : 0),
      duration: !motion
          ? Duration.zero
          : active
              ? AppDurations.posterHover
              : AppDurations.hover,
      curve: AppMotion.posterReveal,
      builder: (context, progress, _) => Transform.translate(
        offset: Offset(0, -AppMotion.posterLift * progress),
        child: Transform.scale(
          scale: 1 + AppMotion.posterZoom * progress,
          child: builder(
              context,
              motion
                  ? progress
                  : active
                      ? 1
                      : 0),
        ),
      ),
    );
  }
}

/// Retour de clic d'une tuile : elle s'enfonce sous le pointeur, et
/// l'action (ouvrir la fiche, la page d'un genre…) part de cette taille
/// réduite. La transition de page prolonge le geste d'un seul trait :
/// l'enfoncement est l'élan, l'extension vers la bannière la détente, sans
/// arrêt entre les deux. Au clavier, [trigger] joue l'enfoncement avant
/// l'action. Sans mouvement, l'action part tout de suite.
class PressBounce extends StatefulWidget {
  const PressBounce({required this.child, super.key});
  final Widget child;

  @override
  State<PressBounce> createState() => PressBounceState();
}

class PressBounceState extends State<PressBounce>
    with SingleTickerProviderStateMixin {
  late final _scale = AnimationController(
      vsync: this, value: 1, lowerBound: 0, upperBound: 2);
  bool _triggering = false;

  @override
  void dispose() {
    _scale.dispose();
    super.dispose();
  }

  bool get _motion => mounted && AppMotion.enabled(context);

  void _down(PointerDownEvent event) {
    if (!_motion || event.buttons != kPrimaryButton || _triggering) return;
    _scale.animateTo(AppMotion.pressScale,
        duration: AppDurations.pressIn, curve: AppMotion.easeOut);
  }

  void _up(PointerEvent _) {
    // Le tap (qui appelle [trigger]) arrive dans la même distribution
    // d'événement : on attend de savoir s'il a eu lieu.
    scheduleMicrotask(() {
      if (!mounted || _triggering) return;
      _scale.animateTo(1,
          duration: AppDurations.pressSettle, curve: AppMotion.easeOut);
    });
  }

  /// Enfonce la tuile si elle ne l'est pas encore (clavier, clic très
  /// bref), puis appelle [action].
  Future<void> trigger(VoidCallback action) async {
    if (!_motion || _triggering) {
      if (!_triggering) action();
      return;
    }
    _triggering = true;
    try {
      // Un clic bref a à peine commencé à enfoncer la tuile : l'élan doit
      // se voir avant la détente. Le reste de l'enfoncement est court.
      if (_scale.value > AppMotion.pressScale + .005) {
        await _scale.animateTo(AppMotion.pressScale,
            duration: AppDurations.pressIn, curve: AppMotion.easeOut);
      }
      if (!mounted) return;
      action();
      // La transition mesure la tuile à l'image qui suit l'ouverture : elle
      // part donc de la taille enfoncée. La tuile, alors masquée par le
      // vol, reprend sa taille ensuite, sans que cela se voie.
      for (var frame = 0; frame < 3; frame++) {
        await SchedulerBinding.instance.endOfFrame;
      }
      if (!mounted) return;
      _scale.animateTo(1,
          duration: AppDurations.pressSettle, curve: AppMotion.easeOut);
    } on TickerCanceled {
      // Démonté pendant le geste : rien à rétablir.
    } finally {
      _triggering = false;
    }
  }

  @override
  Widget build(BuildContext context) => Listener(
        onPointerDown: _down,
        onPointerUp: _up,
        onPointerCancel: _up,
        child: ScaleTransition(scale: _scale, child: widget.child),
      );
}

class FocusRing extends StatefulWidget {
  /// Espace vertical (et horizontal, la valeur est la même dans les deux
  /// sens) que le padding interne de [FocusRing] retire à son enfant —
  /// deux fois `density.focusWidth` (une fois de chaque côté). À budgéter
  /// explicitement dans toute cellule de grille à hauteur fixe
  /// (`mainAxisExtent`) qui enrobe son contenu dans un [FocusRing] :
  /// l'oublier a causé un débordement de 0.5 px sous les vignettes
  /// d'épisode (`season_episode_section.dart`) — l'anneau ne se dessine
  /// *pas* "en dehors du contenu" comme le suggérait un commentaire
  /// obsolète ci-dessous, son padding réduit bien la boîte disponible.
  static double contentInset(BuildContext context) =>
      context.tokens.density.focusWidth * 2;

  /// Insets du bord et du padding, tous deux inclus dans la boîte Flutter.
  static double boxInset(BuildContext context) => contentInset(context) * 2;

  const FocusRing({
    super.key,
    required this.child,
    this.onActivate,
    this.borderRadius = AppRadii.cardBorder,
    this.autofocus = false,
    this.focusNode,
    this.posterMotion = false,
    this.pressMotion = false,
  });

  final Widget child;
  final VoidCallback? onActivate;
  final BorderRadius borderRadius;
  final bool autofocus;
  final FocusNode? focusNode;
  final bool posterMotion;

  /// Rebond au clic avant l'action (cf. [PressBounce]) ; toujours actif avec
  /// [posterMotion].
  final bool pressMotion;

  @override
  State<FocusRing> createState() => _FocusRingState();
}

class _FocusRingState extends State<FocusRing> {
  bool _focused = false;
  bool _hovered = false;
  final _bounce = GlobalKey<PressBounceState>();

  bool get _pressMotion => widget.pressMotion || widget.posterMotion;

  void _activate() {
    final action = widget.onActivate;
    if (action == null) return;
    final bounce = _pressMotion ? _bounce.currentState : null;
    bounce == null ? action() : bounce.trigger(action);
  }

  @override
  Widget build(BuildContext context) {
    return FocusableActionDetector(
      focusNode: widget.focusNode,
      autofocus: widget.autofocus,
      onShowFocusHighlight: (v) => setState(() => _focused = v),
      onShowHoverHighlight:
          widget.posterMotion ? null : (v) => setState(() => _hovered = v),
      shortcuts: const {
        SingleActivator(LogicalKeyboardKey.enter): ActivateIntent(),
        SingleActivator(LogicalKeyboardKey.space): ActivateIntent(),
        SingleActivator(LogicalKeyboardKey.select): ActivateIntent(),
      },
      actions: {
        ActivateIntent: CallbackAction<ActivateIntent>(
          onInvoke: (_) {
            _activate();
            return null;
          },
        ),
      },
      mouseCursor: widget.onActivate != null
          ? SystemMouseCursors.click
          : MouseCursor.defer,
      child: MouseRegion(
        onEnter:
            widget.posterMotion ? (_) => setState(() => _hovered = true) : null,
        onExit: widget.posterMotion
            ? (_) => setState(() => _hovered = false)
            : null,
        child: GestureDetector(
          onTap: widget.onActivate == null ? null : _activate,
          child: _withPress(
            // Le focus clavier soulève la jaquette comme le survol : au
            // clavier directionnel (mode salon), c'est le seul retour de
            // mouvement.
            widget.posterMotion
                ? PosterHoverMotion(
                    active: _hovered || _focused,
                    builder: (context, _) => _surface(context))
                : _surface(context),
          ),
        ),
      ),
    );
  }

  Widget _withPress(Widget child) => _pressMotion && widget.onActivate != null
      ? PressBounce(key: _bounce, child: child)
      : child;

  Widget _surface(BuildContext context) {
    final density = context.tokens.density;
    return AnimatedContainer(
      duration: MediaQuery.disableAnimationsOf(context)
          ? Duration.zero
          : AppDurations.focusRing,
      curve: Curves.easeOut,
      decoration: BoxDecoration(
        borderRadius: widget.borderRadius,
        border: Border.all(
          color: _focused
              ? AppColors.focus
              : _hovered
                  ? widget.posterMotion
                      ? AppColors.posterHoverBorder
                      : AppColors.borderStrong
                  : Colors.transparent,
          width: density.focusWidth,
        ),
      ),
      // Ce padding retire bien de l'espace à l'enfant (il ne se
      // dessine pas "en dehors" du contenu) — cf. [contentInset], à
      // budgéter dans toute cellule de grille à hauteur fixe.
      padding: EdgeInsets.all(density.focusWidth),
      child: widget.child,
    );
  }
}
