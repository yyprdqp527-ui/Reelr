import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../state/clips_state.dart';
import '../widgets/main_shell.dart';

// ─────────────────────────────────────────────
// ONBOARDING SCREEN
// ─────────────────────────────────────────────

class OnboardingScreen extends StatefulWidget {
  final ClipsState state;

  const OnboardingScreen({super.key, required this.state});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _controller = PageController();
  int _currentPage = 0;

  static const _pages = [
    _PageData(
      icon: Icons.bookmark_add_outlined,
      iconColor: Color(0xFF7C3AED),
      title: 'Sauvegarde en un clic',
      subtitle:
          'Colle n\'importe quel lien vidéo et Reelr '
          'récupère automatiquement le titre et la miniature.',
    ),
    _PageData(
      icon: Icons.grid_view_rounded,
      iconColor: Color(0xFF2563EB),
      title: 'Organise par catégories',
      subtitle:
          'Classe tes vidéos par thème. '
          'L\'IA suggère automatiquement la bonne catégorie.',
    ),
    _PageData(
      icon: Icons.share_outlined,
      iconColor: Color(0xFF7C3AED),
      title: 'Partage avec tes amis',
      subtitle:
          'Partage une vidéo ou toute une catégorie '
          'en un seul geste.',
    ),
  ];

  Future<void> _complete() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboarding_done', true);
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => MainShell(state: widget.state),
      ),
    );
  }

  void _skip() => _complete();

  void _next() {
    _controller.nextPage(
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeInOut,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isLast = _currentPage == _pages.length - 1;

    return Scaffold(
      backgroundColor: const Color(0xFF0A0E1F),
      body: Stack(
        children: [
          // ── Background gradient blobs ──
          Positioned(
            top: -120,
            left: -80,
            child: _Blob(color: const Color(0xFF7C3AED).withValues(alpha: 0.25), size: 340),
          ),
          Positioned(
            bottom: -100,
            right: -60,
            child: _Blob(color: const Color(0xFF2563EB).withValues(alpha: 0.20), size: 300),
          ),

          // ── Page content ──
          SafeArea(
            child: Column(
              children: [
                // "Passer" button (top right, hidden on last page)
                SizedBox(
                  height: 48,
                  child: isLast
                      ? const SizedBox.shrink()
                      : Align(
                          alignment: Alignment.centerRight,
                          child: Padding(
                            padding: const EdgeInsets.only(right: 16),
                            child: TextButton(
                              onPressed: _skip,
                              child: const Text(
                                'Passer',
                                style: TextStyle(
                                  color: Colors.white54,
                                  fontSize: 15,
                                ),
                              ),
                            ),
                          ),
                        ),
                ),

                // ── PageView ──
                Expanded(
                  child: PageView.builder(
                    controller: _controller,
                    itemCount: _pages.length,
                    onPageChanged: (i) => setState(() => _currentPage = i),
                    itemBuilder: (context, index) =>
                        _OnboardingPage(data: _pages[index]),
                  ),
                ),

                // ── Dot indicators ──
                _DotIndicator(count: _pages.length, current: _currentPage),
                const SizedBox(height: 24),

                // ── Action button ──
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: _GlassButton(
                      label: isLast ? "C'est parti !" : 'Suivant',
                      onPressed: isLast ? _complete : _next,
                    ),
                  ),
                ),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// DATA MODEL
// ─────────────────────────────────────────────

class _PageData {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;

  const _PageData({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
  });
}

// ─────────────────────────────────────────────
// PAGE WIDGET
// ─────────────────────────────────────────────

class _OnboardingPage extends StatelessWidget {
  final _PageData data;

  const _OnboardingPage({required this.data});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Center(
        child: ClipRRect(
          borderRadius: BorderRadius.circular(28),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 40, sigmaY: 40),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 48),
              decoration: BoxDecoration(
                gradient: const RadialGradient(
                  center: Alignment(-0.8, -0.8),
                  radius: 1.5,
                  colors: [
                    Color.fromRGBO(255, 255, 255, 0.13),
                    Color.fromRGBO(255, 255, 255, 0.05),
                  ],
                ),
                borderRadius: BorderRadius.circular(28),
                border: Border.all(
                  color: const Color.fromRGBO(255, 255, 255, 0.12),
                  width: 1,
                ),
                boxShadow: const [
                  BoxShadow(
                    color: Color.fromRGBO(0, 0, 20, 0.4),
                    blurRadius: 40,
                    offset: Offset(0, 16),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Icon with glow
                  Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: data.iconColor.withValues(alpha: 0.12),
                    ),
                    child: Icon(
                      data.icon,
                      size: 80,
                      color: data.iconColor,
                    ),
                  ),
                  const SizedBox(height: 36),
                  // Title
                  Text(
                    data.title,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Subtitle
                  Text(
                    data.subtitle,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 16,
                      color: Color.fromRGBO(255, 255, 255, 0.60),
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// DOT INDICATOR
// ─────────────────────────────────────────────

class _DotIndicator extends StatelessWidget {
  final int count;
  final int current;

  const _DotIndicator({required this.count, required this.current});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(count, (i) {
        final active = i == current;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          margin: const EdgeInsets.symmetric(horizontal: 5),
          width: active ? 24 : 8,
          height: 8,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(4),
            color: active
                ? const Color(0xFF7C3AED)
                : const Color.fromRGBO(255, 255, 255, 0.25),
          ),
        );
      }),
    );
  }
}

// ─────────────────────────────────────────────
// GLASS BUTTON
// ─────────────────────────────────────────────

class _GlassButton extends StatelessWidget {
  final String label;
  final VoidCallback onPressed;

  const _GlassButton({required this.label, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: ElevatedButton(
          onPressed: onPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF7C3AED).withValues(alpha: 0.85),
            foregroundColor: Colors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: const BorderSide(
                color: Color.fromRGBO(255, 255, 255, 0.18),
                width: 1,
              ),
            ),
          ),
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.3,
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// BACKGROUND BLOB
// ─────────────────────────────────────────────

class _Blob extends StatelessWidget {
  final Color color;
  final double size;

  const _Blob({required this.color, required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
      ),
    );
  }
}
