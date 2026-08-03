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

  /// Accent de la tuile "Tout" / "All" en mode clair — bleu vif premium,
  /// cohérent avec le bleu de marque (au lieu du violet, moins harmonieux
  /// avec le fond bleu pastel du mode clair). Le mode sombre garde `violet`.
  static const Color allTileAccentLight = Color(0xFF2C75E8);

  /// Dégradé de fond de la tuile "Tout" / "All" en mode clair — bleu pastel
  /// dense, distinct du dégradé logo (réservé au mode sombre).
  static const LinearGradient allTileGradientLight = LinearGradient(
    colors: [Color(0xFFDDEAFE), Color(0xFFCFE0FA)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  /// Couleur du titre de la tuile "Tout" en mode clair.
  static const Color allTileTitleLight = Color(0xFF25476B);

  /// Couleur du sous-titre / compteur de la tuile "Tout" en mode clair.
  static const Color allTileSubtitleLight = Color(0xFF56708D);

  // Gradient accent réutilisable
  static const LinearGradient accentGradient = LinearGradient(
    colors: [violet, blue],
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  );

  // ── Palette mode clair — direction "bleu pastel premium" : fond bleu
  // dense (jamais blanc, jamais gris), cohérent avec l'identité bleu/violet/
  // cyan du mode sombre et le bleu du logo Reelr. Jamais gris chaud, jamais
  // blanc cassé jaune, jamais désaturé/boueux.
  // Fond principal — bleu pastel dense, opaque, uniforme sur toute la
  // hauteur, sans dégradé.
  static const Color lightBackground   = Color(0xFFF5F6F8);

  // Fond principal en dégradé (haut → centre → bas) — variante plus riche
  // du fond opaque ci-dessus, utilisée par `GradientBackground`.
  static const Color lightBackgroundTop    = Color(0xFFF5F6F8);
  static const Color lightBackgroundCenter = Color(0xFFF5F6F8);
  static const Color lightBackgroundBottom = Color(0xFFF5F6F8);
  static const LinearGradient lightBackgroundGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [lightBackgroundTop, lightBackgroundCenter, lightBackgroundBottom],
    stops: [0.0, 0.5, 1.0],
  );
  // Texte — hiérarchie complète, gris-bleu jamais neutre.
  static const Color lightTextPrimary   = Color(0xFF0A0E1F);
  static const Color lightTextSecondary = Color(0xFF84868F);
  static const Color lightTextTertiary  = Color(0xFF647C9A);
  // Métadonnées (dates, compteurs discrets, plateformes).
  static const Color lightTextMeta      = Color(0xFF6E85A3);
  // Placeholder de la barre de recherche.
  static const Color lightPlaceholder   = Color(0xFF657D9B);
  // Texte désactivé — jamais une opacité réduite, toujours cette teinte dédiée.
  static const Color lightTextDisabled  = Color(0xFF7A8EA7);
  // Texte principal spécifique à la barre de recherche.
  static const Color lightSearchText    = Color(0xFF203654);
  // Icône de la barre de recherche (loupe) — icône secondaire.
  static const Color lightSearchIcon    = Color(0xFF647F9F);

  // Bleus de marque en mode clair.
  static const Color lightBlue         = Color(0xFF2C75E8);
  // Accent bleu plus soutenu (CTA, focus, éléments à forte emphase).
  static const Color lightBlueStrong   = Color(0xFF2E5BFF);

  // ── Surfaces gris-bleu opaques (jamais de gris neutre, jamais de blanc
  // translucide) — hiérarchie : principale < secondaire < soutenue.
  static const Color lightSurfaceBase      = Color(0xFFFFFFFF); // cartes principales
  static const Color lightSurfaceSecondary = Color(0xFFD0DDEC); // surface secondaire / petits boutons
  static const Color lightSurfaceStrong    = Color(0xFFC7D6E9); // surface plus soutenue
  static const Color lightSearchSurfaceColor = Color(0xFFFFFFFF); // barre de recherche
  static const Color lightSelectedSurface  = Color(0xFFB7D2F5); // état sélectionné / pastille active
  static Color lightSurface({double alpha = 1.0}) =>
      lightSurfaceBase.withValues(alpha: alpha.clamp(0.92, 1.0));
  // Conteneurs élevés / cartes claires (alias de la surface principale,
  // conservé pour compatibilité avec les usages existants).
  static const Color lightElevatedSurface = lightSurfaceBase;

  // Bordures : principale, secondaire (légèrement plus visible) et active
  // (focus / sélection), fines et nettes, sans ombre grise sale.
  static const Color lightBorder = Color(0x470A0E1F); // ~28%, contraste ~1,9:1 avec carte blanche
  static const Color lightBorderStrong = Color(0xFFB7C9E0);
  static const Color lightBorderActive = Color(0xFF2C75E8);

  // Icônes en mode clair — jamais d'opacité réduite pour un état inactif :
  // toujours une teinte dédiée.
  static const Color lightIconActive    = Color(0xFF2C75E8);
  static const Color lightIconInactive  = Color(0xFF587395);
  static const Color lightIconSecondary = Color(0xFF647F9F);
  static const Color lightIconDisabled  = Color(0xFF7C91AB);
  // Icônes/texte de la barre de statut système en mode clair.
  static const Color lightStatusBarContent = Color(0xFF162A44);

  // Boutons d'action ("+", lien, etc.) — fond/contour neutres gris-bleu,
  // icône bleu soutenu.
  static const Color lightActionButtonFill = lightSurfaceBase;
  static const Color lightActionButtonBorder = lightBorder;
  static const Color lightActionButtonIcon = Color(0xFF2C5F96);

  // Icônes d'action dédiées (édition / suppression), toujours pleines,
  // jamais atténuées.
  static const Color lightEditIcon = Color(0xFF3F6F9E);
  static const Color lightDeleteIcon = Color(0xFFE34F5F);

  /// Surface de la barre de recherche — opaque, sans transparence.
  static Color lightSearchSurface() => lightSearchSurfaceColor;

  /// Icône inactive de la barre de navigation en mode clair — distincte de
  /// `lightTextSecondary` (utilisée pour le texte courant), propre au dock
  /// de navigation.
  static const Color navInactiveLight = Color(0xFF587395);
  static const Color navActiveLight = Color(0xFF2C75E8);

  // ── Dock de navigation "classique" : grande capsule sombre uniforme +
  // carré arrondi visible derrière l'icône active (style restauré). ──────
  static const Color darkDockSolid        = Color(0xFF191827);
  static const Color darkDockActiveSquare = Color(0xFF343445);
  static const Color darkDockActiveIcon   = Color(0xFF93C5FD);
  static const Color darkDockInactiveIcon = Color(0xFFC5C3CE);

  /// Capsule claire — surface de la barre de navigation, opaque.
  static const Color lightDockSolid = Color(0xFFFFFFFF);

  /// Carré actif — pastille bleu pastel bien visible derrière l'icône
  /// sélectionnée.
  static const Color lightDockActiveSquare = Color(0xFFE3EDFB);

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
      : lightBorder;

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
        primary: isDark ? violet : lightBlue,
        secondary: isDark ? blue : lightBlueStrong,
        surface: isDark ? surface : lightElevatedSurface,
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
      // ── Défauts génériques (icônes/dividers/AppBar/inputs non stylés
      // explicitement par un widget custom) — reprennent la même
      // hiérarchie que les composants sur-mesure, pour rester cohérents
      // si un composant Material par défaut est utilisé quelque part.
      // Mode sombre : reproduit le comportement implicite précédent
      // (dérivé de `colorScheme.onSurface`), donc inchangé visuellement.
      iconTheme: IconThemeData(
        color: isDark ? darkTextPrimary : lightIconInactive,
      ),
      primaryIconTheme: IconThemeData(
        color: isDark ? darkTextPrimary : lightIconActive,
      ),
      dividerColor: isDark ? darkBorder : lightBorder,
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        foregroundColor: textPrimary,
        elevation: 0,
        iconTheme: IconThemeData(color: textPrimary),
        titleTextStyle: TextStyle(
          color: textPrimary,
          fontSize: 20,
          fontWeight: FontWeight.w700,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isDark ? surface : lightElevatedSurface,
        hintStyle: TextStyle(color: isDark ? darkTextSecondary : lightPlaceholder),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: BorderSide(color: isDark ? darkBorder : lightBorderStrong),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: BorderSide(color: isDark ? darkBorder : lightBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: BorderSide(
            color: isDark ? violet.withValues(alpha: 0.45) : lightBorderActive,
            width: 1.3,
          ),
        ),
      ),
    );
  }
}
