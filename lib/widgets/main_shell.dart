import 'dart:ui';

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
    final navBarHeight = 80 + 16 + safeBottom; // dock + padding + safe area

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
              left: 24,
              right: 24,
              child: _buildNavBar(isDark),
            ),
          ],
        ),
        bottomNavigationBar: null,
      ),
    );
  }

  Widget _buildNavBar(bool isDark) {
    // Dock translucide façon iOS : juste 3 icônes, pas de libellé, pas de
    // pastille derrière l'icône active.
    final bgColor = isDark
        ? const Color(0xFF19162B).withValues(alpha: 0.60)
        // Blanc mélangé au fond lavande — jamais blanc pur — pour rester
        // cohérent avec le nouveau fond du mode clair.
        : AppTheme.lightDockSurface();
    final borderColor = isDark ? AppTheme.darkBorder : AppTheme.lightBorder;
    return ClipRRect(
      borderRadius: BorderRadius.circular(30),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 26, sigmaY: 26),
        child: Container(
          height: 80,
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(30),
            border: Border.all(color: borderColor, width: 1.0),
            // Ombre très légère uniquement — pas d'ombre lourde.
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.10 : 0.08),
                blurRadius: 20,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            children: [
              _navItem(Icons.home_rounded, Icons.home_outlined, 0, isDark),
              _navItem(
                  Icons.grid_view_rounded, Icons.grid_view_outlined, 1, isDark),
              _navItem(
                  Icons.settings_rounded, Icons.settings_outlined, 2, isDark),
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
  ) {
    final sel = _index == idx;
    final activeColor = AppTheme.violet;
    final inactiveColor =
        isDark ? AppTheme.darkTextSecondary : AppTheme.navInactiveLight;

    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _index = idx),
        borderRadius: BorderRadius.circular(30),
        // Aucun fond individuel derrière l'icône : seules la couleur et
        // une très légère variation de taille (≤5%) distinguent l'état actif.
        child: SizedBox(
          height: double.infinity,
          child: Center(
            child: Icon(
              sel ? selIcon : unselIcon,
              size: sel ? 27 : 26,
              color: sel ? activeColor : inactiveColor,
            ),
          ),
        ),
      ),
    );
  }
}
