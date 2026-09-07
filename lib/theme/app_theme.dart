import 'package:flutter/material.dart';
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

  /// Piste des barres de progression posées sur une image (vignettes de
  /// reprise). Distincte de [border] : plus claire, pensée pour rester
  /// visible sur une jaquette sombre comme sur une jaquette claire.
  static const progressTrack = Color(0xFF333333);
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

abstract final class AppRadii {
  static const card = 8.0;
  static const control = 4.0;
  static const sheet = 12.0;

  static const cardBorder = BorderRadius.all(Radius.circular(card));
  static const controlBorder = BorderRadius.all(Radius.circular(control));
  static const sheetBorder = BorderRadius.all(Radius.circular(sheet));
}

abstract final class AppDurations {
  static const hover = Duration(milliseconds: 120);
  static const focusRing = Duration(milliseconds: 100);
  static const heroTint = Duration(milliseconds: 300);
  static const pageTransition = Duration(milliseconds: 220);
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
    secondary: AppColors.textSecondary,
    onSecondary: AppColors.background,
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
      displayLarge: AppTypography.display,
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

    tooltipTheme: const TooltipThemeData(
      decoration: BoxDecoration(
        color: AppColors.surfaceHigh,
        borderRadius: AppRadii.controlBorder,
      ),
      textStyle: AppTypography.meta,
      waitDuration: Duration(milliseconds: 500),
    ),

    // Le défilement lisse trackpad/souris, pas le rebond mobile.
    scrollbarTheme: ScrollbarThemeData(
      thumbColor: const WidgetStatePropertyAll(AppColors.borderStrong),
      thickness: const WidgetStatePropertyAll(6),
      radius: const Radius.circular(3),
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

class FocusRing extends StatefulWidget {
  const FocusRing({
    super.key,
    required this.child,
    this.onActivate,
    this.borderRadius = AppRadii.cardBorder,
    this.autofocus = false,
    this.focusNode,
  });

  final Widget child;
  final VoidCallback? onActivate;
  final BorderRadius borderRadius;
  final bool autofocus;
  final FocusNode? focusNode;

  @override
  State<FocusRing> createState() => _FocusRingState();
}

class _FocusRingState extends State<FocusRing> {
  bool _focused = false;
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final density = context.tokens.density;

    return FocusableActionDetector(
      focusNode: widget.focusNode,
      autofocus: widget.autofocus,
      onShowFocusHighlight: (v) => setState(() => _focused = v),
      onShowHoverHighlight: (v) => setState(() => _hovered = v),
      shortcuts: const {
        SingleActivator(LogicalKeyboardKey.enter): ActivateIntent(),
        SingleActivator(LogicalKeyboardKey.space): ActivateIntent(),
        SingleActivator(LogicalKeyboardKey.select): ActivateIntent(),
      },
      actions: {
        ActivateIntent: CallbackAction<ActivateIntent>(
          onInvoke: (_) {
            widget.onActivate?.call();
            return null;
          },
        ),
      },
      mouseCursor: widget.onActivate != null
          ? SystemMouseCursors.click
          : MouseCursor.defer,
      child: GestureDetector(
        onTap: widget.onActivate,
        child: AnimatedContainer(
          duration: AppDurations.focusRing,
          curve: Curves.easeOut,
          decoration: BoxDecoration(
            borderRadius: widget.borderRadius,
            border: Border.all(
              color: _focused ? AppColors.focus : Colors.transparent,
              width: density.focusWidth,
            ),
          ),
          // L'anneau se dessine en dehors du contenu, sans le décaler.
          padding: EdgeInsets.all(density.focusWidth),
          child: AnimatedScale(
            duration: AppDurations.hover,
            scale: _hovered ? 1.015 : 1.0,
            child: widget.child,
          ),
        ),
      ),
    );
  }
}
