import 'dart:ui';

import 'package:flutter/material.dart';

import '../app.dart';
import '../state/clips_state.dart';

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

  List<_PageData> _buildPages(bool isFr) => [
    _PageData(
      icon: Icons.ios_share_rounded,
      iconColor: const Color(0xFF7C3AED),
      title: isFr ? 'Partage depuis n\'importe quelle app' : 'Share from any app',
      subtitle: isFr
          ? 'Sur YouTube, TikTok, Instagram\u2026 appuie sur \u2191 Partager \u2192 Reelr. La vid\u00e9o est sauvegard\u00e9e instantan\u00e9ment.'
          : 'On YouTube, TikTok, Instagram\u2026 tap \u2191 Share \u2192 Reelr. The video is saved instantly.',
    ),
    _PageData(
      icon: Icons.auto_awesome_rounded,
      iconColor: const Color(0xFF2563EB),
      title: isFr ? 'Class\u00e9e automatiquement par l\'IA' : 'Auto-classified by AI',
      subtitle: isFr
          ? 'Reelr d\u00e9tecte le th\u00e8me et range ta vid\u00e9o dans la bonne cat\u00e9gorie. Z\u00e9ro effort.'
          : 'Reelr detects the topic and sorts your video into the right category. Zero effort.',
    ),
    _PageData(
      icon: Icons.video_library_rounded,
      iconColor: const Color(0xFF7C3AED),
      title: isFr ? 'Ta collection, toujours avec toi' : 'Your collection, always with you',
      subtitle: isFr
          ? 'Retrouve toutes tes vid\u00e9os favorites au m\u00eame endroit, organis\u00e9es et pr\u00eates \u00e0 regarder.'
          : 'Find all your favorite videos in one place, organized and ready to watch.',
    ),
  ];

  Future<void> _complete() async {
    if (!mounted) return;
    ClipsApp.of(context)?.markOnboardingDone();
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
    final isFr = Localizations.localeOf(context).languageCode == 'fr';
    final pages = _buildPages(isFr);
    final isLast = _currentPage == pages.length - 1;

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
                              child: Text(
                                isFr ? 'Passer' : 'Skip',
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
                    itemCount: pages.length,
                    onPageChanged: (i) => setState(() => _currentPage = i),
                    itemBuilder: (context, index) =>
                        _OnboardingPage(data: pages[index]),
                  ),
                ),

                // ── Dot indicators ──
                _DotIndicator(count: pages.length, current: _currentPage),
                const SizedBox(height: 24),

                // ── Action button ──
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: _GlassButton(
                      label: isLast ? (isFr ? "C'est parti !" : "Let's go!") : (isFr ? 'Suivant' : 'Next'),
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
