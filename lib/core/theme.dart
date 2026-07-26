import 'package:flutter/material.dart';

class AppTheme {
  // ── Palette Reelr — Liquid Glass violet / bleu néon ──────────────
  // (utilisée par le mode sombre ; le mode clair a sa propre section plus
  // bas et ne référence plus ces constantes)
  static const Color violet     = Color(0xFF7C3AED); // violet principal
  static const Color blue       = Color(0xFF2582F0); // bleu principal
  static const Color background = Color(0xFF0A0A1F); // fond principal sombre
  static const Color surface    = Color(0xFF181726); // surface principale sombre
  static const Color surfaceElevated = Color(0xFF222132); // surface élevée (nav, barre de recherche, hover)
  static const Color textAccent = Color(0xFFA78BFA); // texte accent

  // Texte du mode sombre — hiérarchie principal / secondaire
  static const Color darkTextPrimary   = Color(0xFFF7F7FB);
  static const Color darkTextSecondary = Color(0xFFAAA6B7);
  static Color get darkBorder => Colors.white.withValues(alpha: 0.11);

  // Alias conservés pour compatibilité avec les widgets existants
  static const Color orange     = violet;
  static const Color darkGreen  = background;
  static const Color shadowGrey = Color(0xFF4C1D95);

  /// Bleu exact du dégradé du logo Reelr (couleur médiane du `ShaderMask`
  /// du header : #8B5CF6 violet → #2563EB bleu → #22D3EE cyan). Référence
  /// unique réutilisée partout où l'on veut "le bleu du logo".
  static const Color logoBlue = Color(0xFF2563EB);

  /// Couleur de la dernière lettre ("r") du logo Reelr — extrémité cyan du
  /// dégradé du `ShaderMask` du header.
  static const Color logoLetterR = Color(0xFF22D3EE);

  /// Couleurs exactes du logo Reelr (violet → bleu → cyan), utilisées pour
  /// la tuile "Tout" / "All" en mode clair. Structure radiale douce
  /// ("fumée"), centrée en haut à gauche — même structure que le halo
  /// blanc de la tuile "Tout" en mode sombre (`Alignment(-0.7, -0.8)`,
  /// `radius: 0.9`), pour harmoniser l'aspect du dégradé entre les deux
  /// modes sans toucher aux couleurs propres à chacun.
  // Couleurs légèrement atténuées (alpha ~72%) pour un rendu moins saturé
  // qu'un aplat plein, tout en gardant les mêmes teintes.
  static const RadialGradient logoGradient = RadialGradient(
    center: Alignment(-0.7, -0.8),
    radius: 0.9,
    colors: [Color(0xB88B5CF6), Color(0xB82563EB), Color(0xB822D3EE)],
    stops: [0.0, 0.55, 1.0],
  );

  /// Même structure que `logoGradient` (mêmes stops, même direction) pour
  /// la tuile "Tout" en mode sombre — mais avec le bleu-gris utilisé
  /// auparavant à la place du bleu vif, pour rester cohérent avec
  /// l'identité du mode sombre.
  static const LinearGradient logoGradientDark = LinearGradient(
    colors: [Color(0xFF8B5CF6), Color(0xFF93C5FD), Color(0xFF22D3EE)],
    stops: [0.0, 0.6, 1.0],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  /// Accent de la tuile "Tout" / "All" en mode clair — bleu foncé repris du
  /// dégradé du logo Reelr (au lieu du violet, moins harmonieux avec le
  /// fond bleu glacier du mode clair). Le mode sombre garde `violet`.
  static const Color allTileAccentLight = logoBlue;

  // Gradient accent réutilisable
  static const LinearGradient accentGradient = LinearGradient(
    colors: [violet, blue],
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  );

  // ── Palette mode clair — direction "bleu-blanc premium" : fond opaque
  // uniforme, sans dégradé ni halo, cohérent avec l'identité bleu/violet/
  // cyan du mode sombre. Jamais gris chaud, jamais blanc cassé jaune,
  // jamais désaturé/boueux.
  // Fond principal — opaque, uniforme sur toute la hauteur, sans dégradé.
  static const Color lightBackground   = Color(0xFFEEF4FA);
  static const Color lightTextPrimary  = Color(0xFF18243A);
  static const Color lightTextSecondary= Color(0xFF66758B);
  // Placeholder de la barre de recherche — distinct du texte secondaire.
  static const Color lightPlaceholder  = Color(0xFF6C788C);
  // Texte principal et icône spécifiques à la barre de recherche.
  static const Color lightSearchText   = Color(0xFF283449);
  static const Color lightSearchIcon   = Color(0xFF63738A);
  static const Color lightBlue         = Color(0xFF2582F0);
  // Surface claire principale — opaque, distincte du fond principal.
  static const Color lightSurfaceBase = Color(0xFFF9FBFD);
  static Color lightSurface({double alpha = 0.82}) =>
      lightSurfaceBase.withValues(alpha: alpha.clamp(0.78, 0.85));
  static const Color lightBorder = Color(0xFFC8D6E5);

  /// Surface de la barre de recherche — opaque, sans transparence.
  static Color lightSearchSurface() => lightSurfaceBase;

  /// Icône inactive de la barre de navigation en mode clair — distincte de
  /// `lightTextSecondary` (utilisée pour le texte courant), propre au dock
  /// de navigation.
  static const Color navInactiveLight = Color(0xFF63738A);

  // ── Dock de navigation "classique" : grande capsule sombre uniforme +
  // carré arrondi visible derrière l'icône active (style restauré). ──────
  static const Color darkDockSolid        = Color(0xFF191827);
  static const Color darkDockActiveSquare = Color(0xFF343445);
  static const Color darkDockActiveIcon   = Color(0xFF93C5FD);
  static const Color darkDockInactiveIcon = Color(0xFFC5C3CE);

  /// Capsule claire — surface principale opaque, sans effet de verre.
  static const Color lightDockSolid = Color(0xFFF9FBFD);

  /// Carré actif, légèrement plus foncé que la capsule claire.
  static const Color lightDockActiveSquare = Color(0xFFEEF4FA);

  /// Marge horizontale d'écran — même valeur que celle utilisée par la
  /// grille de catégories (`home_screen.dart`), pour un alignement exact
  /// entre la grille et la barre de navigation.
  static const double screenHorizontalMargin = 16.0;

  // ── Bordures des cartes de catégorie (écran d'accueil) ───────────────
  // Neutres et discrètes pour les cartes normales — la couleur de marque
  // (violet) est réservée à la carte mise en avant ("Tout" / "All").
  static const double categoryCardBorderWidth = 1.0;
  static const double categoryCardBorderWidthSelected = 2.0;

  static Color categoryCardBorder(bool isDark) => isDark
      ? darkBorder
      : lightTextPrimary.withValues(alpha: 0.10);

  /// Lueur très discrète, réservée à la carte sélectionnée. `accent` permet
  /// de faire varier la couleur (violet en sombre, bleu foncé du logo en
  /// clair pour la tuile "Tout").
  static List<BoxShadow> categoryCardSelectedGlow(Color accent) => [
        BoxShadow(
          color: accent.withValues(alpha: 0.18),
          blurRadius: 8,
        ),
      ];

  // ── Typographie de l'écran d'accueil — centralisée ici plutôt que
  // répétée dans chaque widget. Aucune police externe : `fontFamily` n'est
  // jamais fixé, ce qui laisse Flutter utiliser la police système (San
  // Francisco sur iOS). Les tailles restent des `double` pures pour ne
  // pas interférer avec MediaQuery.textScaler / Dynamic Type.
  static const TextStyle homeCounterStyle = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w400,
  );

  static const TextStyle searchTextStyle = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w400,
  );

  static const TextStyle categoryTitleStyle = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w600,
    height: 1.15,
  );

  static const TextStyle categoryCounterStyle = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w400,
  );

  static const TextStyle navLabelStyle = TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w400,
  );
  static const TextStyle navLabelStyleActive = TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w600,
  );

  static ThemeData light() => _buildTheme(Brightness.light);
  static ThemeData dark()  => _buildTheme(Brightness.dark);

  static ThemeData _buildTheme(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final textPrimary   = isDark ? darkTextPrimary : lightTextPrimary;
    final textSecondary = isDark ? darkTextSecondary : lightTextSecondary;

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      scaffoldBackgroundColor: isDark ? background : lightBackground,
      colorScheme: ColorScheme.fromSeed(
        seedColor: violet,
        brightness: brightness,
        primary: violet,
        secondary: isDark ? blue : lightBlue,
        surface: isDark ? surface : lightSurface(),
        onSurface: textPrimary,
        onPrimary: Colors.white,
        onSecondary: Colors.white,
      ),
      // ── Typographie ───────────────────────────────────────────────────
      textTheme: TextTheme(
        // Titres écran
        displayLarge:  TextStyle(fontSize: 32, fontWeight: FontWeight.w800, color: textPrimary),
        displayMedium: TextStyle(fontSize: 28, fontWeight: FontWeight.w700, color: textPrimary),
        displaySmall:  TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: textPrimary),
        // Titres section
        headlineLarge:  TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: textPrimary),
        headlineMedium: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: textPrimary),
        headlineSmall:  TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: textPrimary),
        titleLarge:  TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: textPrimary),
        titleMedium: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: textPrimary),
        titleSmall:  TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: textPrimary),
        // Corps
        bodyLarge:  TextStyle(fontSize: 15, fontWeight: FontWeight.w400, color: textPrimary),
        bodyMedium: TextStyle(fontSize: 13, fontWeight: FontWeight.w400, color: textSecondary),
        bodySmall:  TextStyle(fontSize: 11, fontWeight: FontWeight.w400, color: textSecondary),
        // Labels
        labelLarge:  TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: textPrimary),
        labelMedium: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: textPrimary),
        labelSmall:  TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: textSecondary),
      ),
      // ── FAB — pill violet avec ombre ──────────────────────────────────
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: violet,
        foregroundColor: Colors.white,
        elevation: 8,
        focusElevation: 10,
        hoverElevation: 10,
        highlightElevation: 6,
        extendedPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(99)),
        ),
      ),
      // ── NavigationBar (override fin — pill géré dans main_shell) ──
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: Colors.transparent,
        indicatorColor: Colors.transparent,
        overlayColor: const WidgetStatePropertyAll(Colors.transparent),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: selected ? textAccent : Colors.white.withValues(alpha: 0.35),
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(
            color: selected
                ? textAccent
                : Colors.white.withValues(alpha: isDark ? 0.35 : 0.55),
          );
        }),
      ),
      // ── SegmentedButton (Settings) — bleu de marque plutôt que violet,
      // en harmonie avec le reste de l'app (nav bar, tuile "Tout"). ──────
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          backgroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return blue.withValues(alpha: 0.25);
            }
            return Colors.transparent;
          }),
          foregroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) return blue;
            return textPrimary.withValues(alpha: 0.55);
          }),
          side: WidgetStatePropertyAll(
            BorderSide(color: blue.withValues(alpha: 0.35), width: 1),
          ),
        ),
      ),
    );
  }
}
