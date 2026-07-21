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

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? AppTheme.background : AppTheme.lightBackground;
    final safeBottom = MediaQuery.of(context).padding.bottom;
    final navBarHeight = 62 + 16 + safeBottom; // dock + padding + safe area

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: (isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark)
          .copyWith(statusBarColor: Colors.transparent),
      child: Scaffold(
        backgroundColor: bg,
        extendBody: true,
        body: Stack(
          children: [
            GradientBackground(isDark: isDark),
            Padding(
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
    final bgColor = isDark
        ? AppTheme.darkDockSolid.withValues(alpha: 0.97)
        : AppTheme.lightDockSolid.withValues(alpha: 0.95);
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
    final activeIconColor =
        isDark ? AppTheme.darkDockActiveIcon : AppTheme.violet;
    final inactiveIconColor =
        isDark ? AppTheme.darkDockInactiveIcon : AppTheme.navInactiveLight;
    final activeSquareColor =
        isDark ? AppTheme.darkDockActiveSquare : AppTheme.lightDockActiveSquare;
    final activeSquareBorder = isDark
        ? Colors.white.withValues(alpha: 0.20)
        : Colors.white.withValues(alpha: 0.55);

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
