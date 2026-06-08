import 'dart:ui';

import 'package:flutter/material.dart';

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
    final bg = isDark ? const Color(0xFF08081A) : const Color(0xFFF0EFFF);
    final safeBottom = MediaQuery.of(context).padding.bottom;
    final navBarHeight = 72 + 16 + safeBottom; // dock + padding + safe area

    return Scaffold(
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
            child: _buildNavBar(isDark),
          ),
        ],
      ),
      bottomNavigationBar: null,
    );
  }

  Widget _buildNavBar(bool isDark) {
    final bgColor = isDark
        ? const Color.fromRGBO(24, 29, 45, 0.62)
        : const Color.fromRGBO(235, 228, 255, 0.75);
    final borderColor = isDark
        ? Colors.white.withValues(alpha: 0.16)
        : Colors.white.withValues(alpha: 0.50);
    return ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 26, sigmaY: 26),
        child: Container(
          height: 72,
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: borderColor, width: 1.1),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.28 : 0.14),
                blurRadius: 28,
                offset: const Offset(0, 8),
              ),
              BoxShadow(
                color: Colors.white.withValues(alpha: isDark ? 0.04 : 0.55),
                blurRadius: 22,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _navItem(Icons.home_rounded, Icons.home_outlined, 0, isDark),
              _navItem(
                Icons.grid_view_rounded,
                Icons.grid_view_outlined,
                1,
                isDark,
              ),
              _navItem(
                Icons.settings_rounded,
                Icons.settings_outlined,
                2,
                isDark,
              ),
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
    final activeColor = isDark
        ? const Color(0xFF9DC8FF)
        : const Color(0xFF1967D2);
    final inactiveColor = isDark
        ? Colors.white.withValues(alpha: 0.70)
        : const Color(0xFF5A6575);
    final activeBg = isDark
        ? Colors.white.withValues(alpha: 0.12)
        : const Color(0xFFEAF2FF);

    return InkWell(
      onTap: () => setState(() => _index = idx),
      borderRadius: BorderRadius.circular(18),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        width: 58,
        height: 50,
        decoration: BoxDecoration(
          color: sel ? activeBg : Colors.transparent,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: sel
                ? (isDark
                    ? Colors.white.withValues(alpha: 0.22)
                    : const Color(0xFFCFE0FF))
                : Colors.transparent,
          ),
        ),
        child: Icon(
          sel ? selIcon : unselIcon,
          color: sel ? activeColor : inactiveColor,
          size: sel ? 25 : 23,
        ),
      ),
    );
  }
}
