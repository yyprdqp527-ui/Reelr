import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/theme.dart';
import '../screens/categories_screen.dart';
import '../screens/home_screen.dart';
import '../screens/settings_screen.dart';
import '../state/clips_state.dart';
import 'background.dart';

// ─────────────────────────────────────────────
// MAIN SHELL — Navigation
// ─────────────────────────────────────────────

class MainShell extends StatefulWidget {
  final ClipsState state;

  final Future<void> Function(String url)? onPasteUrl;
  const MainShell({super.key, required this.state, this.onPasteUrl});

  static void switchTab(BuildContext context, int index) {
    final state = context.findAncestorStateOfType<_MainShellState>();
    state?.setIndex(index);
  }

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _index = 0;

  void setIndex(int i) => setState(() => _index = i);

  static const int _pageCount = 3;

  /// Vitesse minimale, en pixels par seconde, pour qu'un balayage change
  /// de page. Évite qu'un mouvement hésitant pendant un défilement
  /// vertical ne fasse basculer d'écran par accident.
  static const double _swipeVelocityThreshold = 250;

  void _onHorizontalSwipe(DragEndDetails details) {
    final velocity = details.primaryVelocity ?? 0;
    if (velocity.abs() < _swipeVelocityThreshold) return;
    // Vitesse négative = doigt vers la gauche = page suivante.
    final next = velocity < 0 ? _index + 1 : _index - 1;
    if (next < 0 || next >= _pageCount) return;
    setState(() => _index = next);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? AppTheme.background : AppTheme.lightBackground;
    final safeBottom = MediaQuery.of(context).padding.bottom;
    final navBarHeight = 62 + 16 + safeBottom; // dock + padding + safe area

    // Barre de statut transparente ; icônes (heure, Wi-Fi, batterie)
    // sombres en mode clair, blanches en mode sombre. Propriétés
    // explicites plutôt que les presets `.light`/`.dark` : statusBarBrightness
    // pilote iOS, statusBarIconBrightness pilote Android — dépend en
    // permanence de Theme.of(context).brightness, recalculé à chaque build.
    final overlayStyle = SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarBrightness: isDark ? Brightness.dark : Brightness.light, // iOS
      statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark, // Android
    );

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: overlayStyle,
      child: Scaffold(
        backgroundColor: bg,
        extendBody: true,
        body: Stack(
          children: [
            GradientBackground(isDark: isDark),
            // Balayage horizontal pour changer de page, en plus de la
            // barre de navigation. L'IndexedStack est conservé : les trois
            // pages restent construites et gardent intégralement leur état,
            // position de défilement comprise. Un PageView aurait offert
            // une animation suivant le doigt, au prix de la reconstruction
            // des pages sortant de l'écran.
            //
            // Seul le geste horizontal est capté : le défilement vertical
            // des listes n'est pas affecté, et les rares défilements
            // horizontaux internes (chips de sous-catégories) gagnent
            // l'arbitrage puisqu'ils sont plus proches du doigt.
            GestureDetector(
              behavior: HitTestBehavior.translucent,
              onHorizontalDragEnd: _onHorizontalSwipe,
              child: Padding(
                padding: EdgeInsets.only(bottom: navBarHeight + 8),
                child: IndexedStack(
                  index: _index,
                  children: [
                    HomeScreen(state: widget.state, onPasteUrl: widget.onPasteUrl),
                    CategoriesScreen(state: widget.state),
                    SettingsScreen(state: widget.state),
                  ],
                ),
              ),
            ),
            if (!(_index == 0 && widget.state.totalClipsCount == 0))
              Positioned(
                bottom: safeBottom + 16,
                // Même marge que la grille de catégories, pour un alignement
                // exact des bords gauche/droit.
                left: AppTheme.screenHorizontalMargin,
                right: AppTheme.screenHorizontalMargin,
                child: _buildNavBar(isDark),
              ),
          ],
        ),
        bottomNavigationBar: null,
      ),
    );
  }

  Widget _buildNavBar(bool isDark) {
    // Grande capsule sombre uniforme (style restauré) : pas de libellé,
    // pas d'effet verre marqué, pas de transparence excessive.
    // Clair : capsule totalement opaque (pas de transparence sur les
    // surfaces principales). Sombre : inchangé.
    final bgColor = isDark
        ? AppTheme.darkDockSolid.withValues(alpha: 0.97)
        : AppTheme.lightDockSolid;
    final borderColor =
        isDark ? Colors.white.withValues(alpha: 0.15) : AppTheme.lightBorder;
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: Container(
        height: 62,
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: borderColor, width: 1.0),
          // Ombre discrète uniquement — pas d'ombre lourde.
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.14 : 0.06),
              blurRadius: 14,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _navItem(Icons.home_rounded, Icons.home_outlined, 0, isDark),
            _navItem(
                Icons.grid_view_rounded, Icons.grid_view_outlined, 1, isDark),
            _navItem(
                Icons.settings_rounded, Icons.settings_outlined, 2, isDark),
          ],
        ),
      ),
    );
  }

  Widget _navItem(
    IconData selIcon,
    IconData unselIcon,
    int idx,
    bool isDark,
  ) {
    final sel = _index == idx;
    // Mode sombre revenu à la référence d'origine : bleu clair
    // AppTheme.darkDockActiveIcon (#93C5FD), visible sur la capture de
    // référence. Mode clair : bleu de marque (AppTheme.navActiveLight).
    // Comportement inchangé : seule l'icône active est colorée, les icônes
    // inactives restent grises (inactiveIconColor).
    final activeIconColor =
        isDark ? AppTheme.darkDockActiveIcon : AppTheme.navActiveLight;
    final inactiveIconColor =
        isDark ? AppTheme.darkDockInactiveIcon : AppTheme.navInactiveLight;
    final activeSquareColor =
        isDark ? AppTheme.darkDockActiveSquare : AppTheme.lightDockActiveSquare;
    final activeSquareBorder = isDark
        ? Colors.white.withValues(alpha: 0.20)
        : AppTheme.lightBorderStrong.withValues(alpha: 0.7);

    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _index = idx),
        borderRadius: BorderRadius.circular(16),
        child: Center(
          // Carré arrondi visible uniquement derrière l'icône active —
          // rien derrière les icônes inactives. Taille d'icône fixe
          // (pas d'agrandissement), aucune animation.
          child: Container(
            width: 46,
            height: 46,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: sel ? activeSquareColor : Colors.transparent,
              borderRadius: BorderRadius.circular(16),
              border:
                  sel ? Border.all(color: activeSquareBorder, width: 1.0) : null,
            ),
            child: Icon(
              sel ? selIcon : unselIcon,
              size: 26,
              color: sel ? activeIconColor : inactiveIconColor,
            ),
          ),
        ),
      ),
    );
  }
}
