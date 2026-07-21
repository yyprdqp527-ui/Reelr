import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/l10n.dart';
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
    final l = AppL10n.of(context);
    final bg = isDark ? AppTheme.background : AppTheme.lightBackground;
    final safeBottom = MediaQuery.of(context).padding.bottom;
    final navBarHeight = 64 + 16 + safeBottom; // dock + padding + safe area

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
              left: 16,
              right: 16,
              child: _buildNavBar(isDark, l),
            ),
          ],
        ),
        bottomNavigationBar: null,
      ),
    );
  }

  Widget _buildNavBar(bool isDark, AppL10n l) {
    // Surface élevée : distincte du fond ET des cartes (hiérarchie
    // fond < surface < surface élevée), pour une barre de nav identifiable
    // sans redevenir un aplat gris massif.
    final bgColor = isDark
        ? AppTheme.surfaceElevated.withValues(alpha: 0.72)
        : AppTheme.lightSurface(alpha: 0.80);
    final borderColor = isDark
        ? AppTheme.darkBorder
        : Colors.white.withValues(alpha: 0.50);
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 26, sigmaY: 26),
        child: Container(
          // Hauteur réduite (72 → 64) malgré l'ajout des libellés.
          height: 64,
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(24),
            // Bordure très fine (1.1 → 1.0).
            border: Border.all(color: borderColor, width: 1.0),
            boxShadow: [
              // Ombre allégée en sombre (faible élévation plutôt qu'une
              // ombre noire lourde) — inchangée en clair.
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.16 : 0.14),
                blurRadius: isDark ? 16 : 28,
                offset: Offset(0, isDark ? 4 : 8),
              ),
              BoxShadow(
                color: Colors.white.withValues(alpha: isDark ? 0.04 : 0.55),
                blurRadius: 22,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: Row(
            children: [
              _navItem(Icons.home_rounded, Icons.home_outlined, 0, isDark,
                  l.t('home')),
              _navItem(Icons.grid_view_rounded, Icons.grid_view_outlined, 1,
                  isDark, l.t('categories')),
              _navItem(Icons.settings_rounded, Icons.settings_outlined, 2,
                  isDark, l.t('settings')),
            ],
          ),
        ),
      ),
    );
  }

  Widget _navItem(
    IconData selIcon,
    IconData unselIcon,
    int idx,
    bool isDark,
    String label,
  ) {
    final sel = _index == idx;
    // Couleur de marque réservée à l'état actif (violet Reelr) — plus de
    // bleu ad hoc distinct du reste de l'identité.
    final activeColor = AppTheme.violet;
    final inactiveColor =
        isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary;

    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _index = idx),
        borderRadius: BorderRadius.circular(16),
        child: SizedBox(
          height: double.infinity,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Petite capsule discrète — plus de grand carré arrondi —
              // et taille d'icône identique quel que soit l'état.
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOutCubic,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                decoration: BoxDecoration(
                  color: sel
                      ? activeColor.withValues(alpha: isDark ? 0.18 : 0.12)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  sel ? selIcon : unselIcon,
                  size: 24,
                  color: sel ? activeColor : inactiveColor,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: sel ? FontWeight.w600 : FontWeight.w400,
                  color: sel ? activeColor : inactiveColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
