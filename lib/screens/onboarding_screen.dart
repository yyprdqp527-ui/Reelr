import 'package:flutter/material.dart';

import '../app.dart';
import '../state/clips_state.dart';

// ─────────────────────────────────────────────
// ONBOARDING SCREEN
// DA alignée sur PaywallScreen : cartes plates, eyebrow label,
// bouton dégradé violet. Pas de blur/glassmorphism ici.
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
      accentColor: const Color(0xFFA855F7),
      iconBgColor: const Color(0xFF7C3AED),
      eyebrow: isFr ? 'PARTAGE EXPRESS' : 'QUICK SHARE',
      title: isFr ? "Partage depuis n'importe quelle app" : 'Share from any app',
      subtitle: isFr
          ? "Sur YouTube, TikTok, Instagram... appuie sur ↑ Partager → Reelr. La vidéo est sauvegardée instantanément."
          : 'On YouTube, TikTok, Instagram... tap ↑ Share → Reelr. The video is saved instantly.',
    ),
    _PageData(
      icon: Icons.more_horiz_rounded,
      accentColor: const Color(0xFFA855F7),
      iconBgColor: const Color(0xFF7C3AED),
      eyebrow: isFr ? 'ASTUCE RAPIDE' : 'QUICK TIP',
      title: isFr ? 'Tu ne vois pas Reelr ?' : "Don't see Reelr?",
      subtitle: isFr
          ? "Certaines apps cachent les nouvelles options. Appuie sur ··· Plus, active Reelr une fois : il restera épinglé ensuite."
          : "Some apps hide new options. Tap ··· More, turn on Reelr once — it'll stay pinned after that.",
      showDiagram: true,
    ),
    _PageData(
      icon: Icons.grid_view_rounded,
      accentColor: const Color(0xFF60A5FA),
      iconBgColor: const Color(0xFF2563EB),
      eyebrow: isFr ? 'RANGEMENT AUTO' : 'AUTO-SORTED',
      title: isFr ? 'Toujours bien rangée' : 'Always neatly sorted',
      subtitle: isFr
          ? "Reelr repère le thème de chaque vidéo et la classe dans la bonne catégorie. Zéro tri à faire."
          : 'Reelr spots the topic of each video and files it into the right category. Zero sorting needed.',
    ),
    _PageData(
      icon: Icons.video_library_rounded,
      accentColor: const Color(0xFFA855F7),
      iconBgColor: const Color(0xFF7C3AED),
      eyebrow: isFr ? 'TA COLLECTION' : 'YOUR COLLECTION',
      title: isFr ? 'Toujours avec toi' : 'Always with you',
      subtitle: isFr
          ? "Retrouve toutes tes vidéos favorites au même endroit, organisées et prêtes à regarder."
          : 'Find all your favorite videos in one place, organized and ready to watch.',
    ),
  ];

  Future<void> _complete() async {
    if (!mounted) return;
    await ClipsApp.of(context)?.markOnboardingDoneAwaited();
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
      body: SafeArea(
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
                            style: const TextStyle(
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
                child: _GradientButton(
                  label: isLast
                      ? (isFr ? "C'est parti !" : "Let's go!")
                      : (isFr ? 'Suivant' : 'Next'),
                  onPressed: isLast ? _complete : _next,
                ),
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// DATA MODEL
// ─────────────────────────────────────────────

class _PageData {
  final IconData icon;
  final Color accentColor;
  final Color iconBgColor;
  final String eyebrow;
  final String title;
  final String subtitle;
  final bool showDiagram;

  const _PageData({
    required this.icon,
    required this.accentColor,
    required this.iconBgColor,
    required this.eyebrow,
    required this.title,
    required this.subtitle,
    this.showDiagram = false,
  });
}

// ─────────────────────────────────────────────
// PAGE WIDGET
// Carte plate avec bordure fine, comme les _FeatureRow du paywall —
// pas de BackdropFilter/blur ici.
// ─────────────────────────────────────────────

class _OnboardingPage extends StatelessWidget {
  final _PageData data;

  const _OnboardingPage({required this.data});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 40),
          decoration: BoxDecoration(
            color: const Color(0xFF0A0E1F),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.06),
              width: 1,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Icon
              Container(
                width: 76,
                height: 76,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(22),
                  color: data.iconBgColor.withValues(alpha: 0.18),
                  boxShadow: [
                    BoxShadow(
                      color: data.iconBgColor.withValues(alpha: 0.30),
                      blurRadius: 24,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Icon(
                  data.icon,
                  size: 34,
                  color: data.accentColor,
                ),
              ),
              const SizedBox(height: 20),
              // Eyebrow
              Text(
                data.eyebrow,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.4,
                  color: data.accentColor,
                ),
              ),
              const SizedBox(height: 10),
              // Title
              Text(
                data.title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                  height: 1.25,
                ),
              ),
              const SizedBox(height: 10),
              // Subtitle
              Text(
                data.subtitle,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.white.withValues(alpha: 0.45),
                  height: 1.5,
                ),
              ),
              if (data.showDiagram) ...[
                const SizedBox(height: 20),
                _ShareSheetDiagram(
                  accentColor: data.accentColor,
                  iconBgColor: data.iconBgColor,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// MINI DIAGRAM (Partager → Plus → Activé)
// Utilisé sur la page "Tu ne vois pas Reelr ?"
// ─────────────────────────────────────────────

class _ShareSheetDiagram extends StatelessWidget {
  final Color accentColor;
  final Color iconBgColor;

  const _ShareSheetDiagram({
    required this.accentColor,
    required this.iconBgColor,
  });

  Widget _step(IconData icon, {bool filled = false}) {
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: iconBgColor.withValues(alpha: filled ? 0.30 : 0.18),
        borderRadius: BorderRadius.circular(9),
      ),
      child: Icon(icon, size: 16, color: accentColor),
    );
  }

  Widget _arrow() => Text(
        '→',
        style: TextStyle(
          color: Colors.white.withValues(alpha: 0.25),
          fontSize: 14,
        ),
      );

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.06),
          width: 0.5,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _step(Icons.ios_share_rounded),
          const SizedBox(width: 8),
          _arrow(),
          const SizedBox(width: 8),
          _step(Icons.more_horiz_rounded),
          const SizedBox(width: 8),
          _arrow(),
          const SizedBox(width: 8),
          _step(Icons.check_rounded, filled: true),
        ],
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
                : Colors.white.withValues(alpha: 0.25),
          ),
        );
      }),
    );
  }
}

// ─────────────────────────────────────────────
// GRADIENT BUTTON
// Style aligné sur le bouton "Passer à Premium" du paywall.
// ─────────────────────────────────────────────

class _GradientButton extends StatelessWidget {
  final String label;
  final VoidCallback onPressed;

  const _GradientButton({required this.label, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF7C3AED), Color(0xFFA855F7)],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: BorderRadius.circular(14),
      ),
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        child: Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
