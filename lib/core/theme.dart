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

  // Gradient accent réutilisable
  static const LinearGradient accentGradient = LinearGradient(
    colors: [violet, blue],
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  );

  // ── Palette mode clair — pastel affirmé, lumineux, cohérent avec le
  // dégradé violet/bleu du logo. Toujours pastel (jamais saturé/flashy),
  // jamais blanc pur ni gris terne, jamais de ton chaud.
  static const Color lightBackgroundSecondary = Color(0xFFE9DDF8); // lavande pastel (haut)
  static const Color lightBackground          = Color(0xFFE6DDF9); // lilas pastel (centre, référence générale)
  static const Color lightBackgroundDeep      = Color(0xFFDEE7FB); // bleu pastel (bas)
  static const Color lightTextPrimary  = Color(0xFF332E45);
  static const Color lightTextSecondary= Color(0xFF6C6781);
  // Placeholder de la barre de recherche — distinct du texte secondaire.
  static const Color lightPlaceholder  = Color(0xFF7B748C);
  // Texte principal et icône spécifiques à la barre de recherche.
  static const Color lightSearchText   = Color(0xFF5F5971);
  static const Color lightSearchIcon   = Color(0xFF6C6781);
  static const Color lightBlue         = Color(0xFF2582F0);
  static Color lightSurface({double alpha = 0.82}) =>
      Colors.white.withValues(alpha: alpha.clamp(0.78, 0.85));
  static const Color lightBorder = Color(0xFFCFC4E4);

  /// Surface translucide de la barre de recherche : blanc teinté lavande,
  /// jamais blanc neutre.
  static Color lightSearchSurface({double alpha = 0.64}) =>
      Color.lerp(Colors.white, lightBackground, 0.22)!
          .withValues(alpha: alpha.clamp(0.58, 0.70));

  /// Surface translucide du dock de navigation : lavande givrée, plus
  /// teintée que la barre de recherche pour bien se distinguer du fond
  /// tout en restant cohérente avec lui.
  static Color lightDockSurface({double alpha = 0.62}) =>
      Color.lerp(Colors.white, lightBackgroundDeep, 0.48)!
          .withValues(alpha: alpha.clamp(0.55, 0.70));

  /// Icône inactive de la barre de navigation en mode clair — distincte de
  /// `lightTextSecondary` (utilisée pour le texte courant), propre au dock
  /// de navigation.
  static const Color navInactiveLight = Color(0xFF777485);

  // ── Dock de navigation "classique" : grande capsule sombre uniforme +
  // carré arrondi visible derrière l'icône active (style restauré). ──────
  static const Color darkDockSolid        = Color(0xFF191827);
  static const Color darkDockActiveSquare = Color(0xFF343445);
  static const Color darkDockActiveIcon   = Color(0xFF93C5FD);
  static const Color darkDockInactiveIcon = Color(0xFFC5C3CE);

  /// Capsule claire, légèrement teintée lavande — plus opaque que
  /// `lightDockSurface` (pas d'effet verre pour ce style).
  static Color get lightDockSolid =>
      Color.lerp(Colors.white, lightBackground, 0.55)!;

  /// Carré actif, légèrement plus foncé que la capsule claire.
  static Color get lightDockActiveSquare =>
      Color.lerp(Colors.white, lightBackground, 0.85)!;

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

  /// Lueur très discrète, réservée à la carte sélectionnée.
  static List<BoxShadow> get categoryCardSelectedGlow => [
        BoxShadow(
          color: violet.withValues(alpha: 0.18),
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
      // ── SegmentedButton (Settings) ─────────────────────────────────
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          backgroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return violet.withValues(alpha: 0.25);
            }
            return Colors.transparent;
          }),
          foregroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) return violet;
            return textPrimary.withValues(alpha: 0.55);
          }),
          side: WidgetStatePropertyAll(
            BorderSide(color: violet.withValues(alpha: 0.35), width: 1),
          ),
        ),
      ),
    );
  }
}
