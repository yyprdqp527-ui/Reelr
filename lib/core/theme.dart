import 'package:flutter/material.dart';

class AppTheme {
  // ── Palette Reelr — Liquid Glass violet / bleu néon ──────────────
  static const Color violet     = Color(0xFF7C3AED); // accent primaire
  static const Color blue       = Color(0xFF2563EB); // accent secondaire
  static const Color background = Color(0xFF0A0E1F); // fond principal
  static const Color surface    = Color(0xFF10142A); // surface
  static const Color textAccent = Color(0xFFA78BFA); // texte accent

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

  // ── Bordures des cartes de catégorie (écran d'accueil) ───────────────
  // Neutres et discrètes pour les cartes normales — la couleur de marque
  // (violet) est réservée à la carte mise en avant ("Tout" / "All").
  static const Color _cardBorderLightBase = Color(0xFF171622);
  static const double categoryCardBorderWidth = 1.0;
  static const double categoryCardBorderWidthSelected = 2.0;

  static Color categoryCardBorder(bool isDark) => isDark
      ? Colors.white.withValues(alpha: 0.12)
      : _cardBorderLightBase.withValues(alpha: 0.10);

  /// Lueur très discrète, réservée à la carte sélectionnée.
  static List<BoxShadow> get categoryCardSelectedGlow => [
        BoxShadow(
          color: violet.withValues(alpha: 0.18),
          blurRadius: 8,
        ),
      ];

  static ThemeData light() => _buildTheme(Brightness.light);
  static ThemeData dark()  => _buildTheme(Brightness.dark);

  static ThemeData _buildTheme(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final textPrimary   = isDark ? Colors.white : const Color(0xFF1A1A2E);
    final textSecondary = isDark
        ? Colors.white.withValues(alpha: 0.55)
        : background.withValues(alpha: 0.55);

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      scaffoldBackgroundColor: isDark ? background : const Color(0xFFF5F3FF),
      colorScheme: ColorScheme.fromSeed(
        seedColor: violet,
        brightness: brightness,
        primary: violet,
        secondary: blue,
        surface: isDark ? surface : const Color(0xFFEEECFF),
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
