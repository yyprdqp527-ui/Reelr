import 'dart:ui';

import 'package:flutter/material.dart';

import '../core/l10n.dart';
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

  const MainShell({super.key, required this.state});

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
    final l = AppL10n.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF08081A) : const Color(0xFFF0EFFF);
    final safeBottom = MediaQuery.of(context).padding.bottom;
    final navBarHeight = 60 + 16 + safeBottom; // nav + padding + safe area

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
                HomeScreen(state: widget.state),
                CategoriesScreen(state: widget.state),
                SettingsScreen(state: widget.state),
              ],
            ),
          ),
          if (_index == 0 || _index == 1)
            Positioned(
              bottom: navBarHeight + 8,
              right: 24,
              child: FloatingActionButton.extended(
                onPressed: () => _openAddSheet(context),
                icon: const Icon(Icons.add_rounded),
                label: Text(l.t('add_clip')),
                elevation: 2,
              ),
            ),
          Positioned(
            bottom: safeBottom + 16,
            left: 16,
            right: 16,
            child: _buildNavBar(l, isDark),
          ),
        ],
      ),
      bottomNavigationBar: null,
    );
  }

  Widget _buildNavBar(AppL10n l, bool isDark) {
    final bgColor = isDark
        ? const Color.fromRGBO(10, 14, 31, 0.85)
        : const Color.fromRGBO(242, 242, 247, 0.95);
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          height: 60,
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.10),
                blurRadius: 20,
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _navItem(Icons.home_rounded, Icons.home_outlined, l.t('home'), 0),
              _navItem(Icons.grid_view_rounded, Icons.grid_view_outlined, l.t('categories'), 1),
              _navItem(Icons.settings_rounded, Icons.settings_outlined, l.t('settings'), 2),
            ],
          ),
        ),
      ),
    );
  }

  Widget _navItem(IconData selIcon, IconData unselIcon, String label, int idx) {
    final sel = _index == idx;
    const activeColor = Color(0xFF7C3AED);
    const inactiveColor = Colors.grey;
    final color = sel ? activeColor : inactiveColor;
    return GestureDetector(
      onTap: () => setState(() => _index = idx),
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(sel ? selIcon : unselIcon, color: color, size: 22),
            const SizedBox(height: 3),
            Text(label, style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }

  void _openAddSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AddClipSheet(state: widget.state),
    );
  }
}
