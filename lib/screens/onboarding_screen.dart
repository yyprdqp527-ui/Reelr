import 'dart:async';

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
      icon: Icons.find_in_page_rounded,
      accentColor: const Color(0xFFA855F7),
      iconBgColor: const Color(0xFF7C3AED),
      eyebrow: isFr ? 'TU CONNAIS ÇA ?' : 'SOUND FAMILIAR?',
      title: isFr ? 'Tes vidéos, éparpillées partout' : 'Your videos, scattered everywhere',
      subtitle: isFr
          ? "Une sur TikTok, une sur Instagram, une sur YouTube... et impossible de remettre la main dessus. Reelr classe toutes tes vidéos préférées au même endroit, automatiquement."
          : "One on TikTok, one on Instagram, one on YouTube... and no way to find them again. Reelr keeps all your favorite videos in one place, automatically.",
      showScatteredLogos: true,
    ),
    _PageData(
      icon: Icons.ios_share_rounded,
      accentColor: const Color(0xFFA855F7),
      iconBgColor: const Color(0xFF7C3AED),
      eyebrow: isFr ? 'COMMENT PARTAGER' : 'HOW TO SHARE',
      title: isFr ? "Cherche l'icône de partage" : 'Find the share icon',
      subtitle: isFr
          ? "Tu es sur YouTube, TikTok, Instagram... (pas dans Reelr). Elle change de forme selon l'app."
          : "You're on YouTube, TikTok, Instagram... (not in Reelr). It looks different in every app.",
      showIconLegend: true,
    ),
    _PageData(
      icon: Icons.more_horiz_rounded,
      accentColor: const Color(0xFFA855F7),
      iconBgColor: const Color(0xFF7C3AED),
      eyebrow: isFr ? 'ASTUCE RAPIDE' : 'QUICK TIP',
      title: isFr ? 'Fixe Reelr tout en haut' : 'Pin Reelr to the top',
      subtitle: isFr
          ? "La 1ʳᵉ fois, Reelr est tout en bas de la liste. Appuie sur ··· Plus → Modifier, puis fais-la glisser en haut : elle y restera à chaque partage."
          : "The first time, Reelr sits at the bottom of the list. Tap ··· More → Edit, then drag it to the top — it'll stay there every time you share.",
      showDiagram: true,
    ),
  ];

  Future<void> _complete() async {
    if (!mounted) return;
    await ClipsApp.of(context)?.markOnboardingDoneAwaited();
    if (!mounted) return;
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }
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
  final bool showScatteredLogos;
  final bool showIconLegend;

  const _PageData({
    required this.icon,
    required this.accentColor,
    required this.iconBgColor,
    required this.eyebrow,
    required this.title,
    required this.subtitle,
    this.showDiagram = false,
    this.showScatteredLogos = false,
    this.showIconLegend = false,
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
                alignment: Alignment.center,
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
              if (data.showScatteredLogos) ...[
                const SizedBox(height: 20),
                const _ScatteredLogos(),
              ],
              if (data.showIconLegend) ...[
                const SizedBox(height: 20),
                const _ShareIconLegend(),
              ],
              if (data.showDiagram) ...[
                const SizedBox(height: 20),
                _PinAnimationDiagram(
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
// DIAGRAMME ANIMÉ (Partager → Plus → Modifier → épingler)
// Utilisé sur la page "Fixe Reelr tout en haut".
// Boucle en continu : pastille "Plus" qui pulse, puis la ligne
// Reelr qui glisse en haut de la liste "Modifier".
// ─────────────────────────────────────────────

class _PinAnimationDiagram extends StatefulWidget {
  final Color accentColor;
  final Color iconBgColor;

  const _PinAnimationDiagram({
    required this.accentColor,
    required this.iconBgColor,
  });

  @override
  State<_PinAnimationDiagram> createState() => _PinAnimationDiagramState();
}

class _PinAnimationDiagramState extends State<_PinAnimationDiagram>
    with TickerProviderStateMixin {
  static const double _rowHeight = 40;
  static const List<String> _order = ['reelr', 'w', 'm', 'n'];

  late final AnimationController _pulseController;
  Timer? _timer;
  bool _pinned = false;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _timer = Timer.periodic(const Duration(milliseconds: 2200), (_) {
      if (mounted) setState(() => _pinned = !_pinned);
    });
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _timer?.cancel();
    super.dispose();
  }

  Widget _shareDot(IconData icon, Color color) {
    return Container(
      width: 28,
      height: 28,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(8)),
      child: Icon(icon, size: 13, color: Colors.white),
    );
  }

  Widget _pulsingPlus() {
    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, child) {
        final t = _pulseController.value;
        return Container(
          width: 32,
          height: 32,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(9),
            border: const Border.fromBorderSide(
              BorderSide(color: Color(0xFF22D3EE), width: 1.5),
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF22D3EE).withValues(alpha: 0.45 * (1 - t)),
                spreadRadius: 7 * t,
              ),
            ],
          ),
          child: const Icon(Icons.more_horiz_rounded, size: 16, color: Color(0xFF22D3EE)),
        );
      },
    );
  }

  Widget _row(String id) {
    const labels = {'reelr': 'Reelr', 'w': 'WhatsApp', 'm': 'Messages', 'n': 'Notes'};
    const colors = {
      'w': Color(0xFF25D366),
      'm': Color(0xFF0C447C),
      'n': Color(0xFFFAC775),
    };
    final isReelr = id == 'reelr';
    return SizedBox(
      height: _rowHeight,
      child: Row(
        children: [
          if (isReelr) ...[
            const Icon(Icons.drag_indicator_rounded, size: 15, color: Color(0xFFA855F7)),
            const SizedBox(width: 4),
          ],
          Container(
            width: 20,
            height: 20,
            decoration: BoxDecoration(
              gradient: isReelr
                  ? const LinearGradient(colors: [Color(0xFF7C3AED), Color(0xFFA855F7)])
                  : null,
              color: isReelr ? null : colors[id],
              borderRadius: BorderRadius.circular(6),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            labels[id]!,
            style: TextStyle(
              color: isReelr ? Colors.white : Colors.white.withValues(alpha: 0.7),
              fontSize: 12,
              fontWeight: isReelr ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final order = _pinned ? _order : ['w', 'm', 'n', 'reelr'];
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.04),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withValues(alpha: 0.06), width: 0.5),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _shareDot(Icons.chat_bubble_outline_rounded, const Color(0xFF25D366)),
              const SizedBox(width: 10),
              _shareDot(Icons.mail_outline_rounded, const Color(0xFF0C447C)),
              const SizedBox(width: 10),
              _shareDot(Icons.description_outlined, const Color(0xFFFAC775)),
              const SizedBox(width: 10),
              _pulsingPlus(),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Text(
          '↓ Plus → Modifier',
          style: TextStyle(color: Colors.white.withValues(alpha: 0.25), fontSize: 11),
        ),
        const SizedBox(height: 8),
        Container(
          height: _order.length * _rowHeight,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.04),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withValues(alpha: 0.06), width: 0.5),
          ),
          child: Stack(
            children: [
              for (final id in _order)
                AnimatedPositioned(
                  duration: const Duration(milliseconds: 700),
                  curve: Curves.easeInOutCubic,
                  top: order.indexOf(id) * _rowHeight,
                  left: 0,
                  right: 0,
                  child: _row(id),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────
// LOGOS DISPERSÉS
// Utilisés sur la page "Tes vidéos, éparpillées partout" pour
// illustrer visuellement le message. Mêmes assets que la grille
// de plateformes et que l'écran d'accueil vide.
// ─────────────────────────────────────────────

class _ScatteredLogos extends StatelessWidget {
  const _ScatteredLogos();

  static const double _height = 124;

  // left/top exprimés en fraction de la largeur/hauteur disponible (0..1),
  // pour rester cohérent quelle que soit la taille de l'écran.
  static const List<Map<String, Object>> _items = [
    {'asset': 'assets/icons/youtube.png', 'left': 0.16, 'top': 0.10, 'size': 46.0, 'angle': -0.22},
    {'asset': 'assets/icons/tiktok.png', 'left': 0.80, 'top': 0.06, 'size': 40.0, 'angle': 0.18},
    {'asset': 'assets/icons/instagram.png', 'left': 0.48, 'top': 0.28, 'size': 54.0, 'angle': -0.10},
    {'asset': 'assets/icons/facebook.png', 'left': 0.20, 'top': 0.62, 'size': 34.0, 'angle': 0.16},
    {'asset': 'assets/icons/pinterest.png', 'left': 0.76, 'top': 0.60, 'size': 36.0, 'angle': -0.18},
  ];

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: _height,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final w = constraints.maxWidth;
          return Stack(
            children: [
              for (final item in _items)
                Positioned(
                  left: (item['left'] as double) * (w - (item['size'] as double)),
                  top: (item['top'] as double) * _height,
                  child: Transform.rotate(
                    angle: item['angle'] as double,
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular((item['size'] as double) * 0.28),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.35),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular((item['size'] as double) * 0.28),
                        child: Image.asset(
                          item['asset'] as String,
                          width: item['size'] as double,
                          height: item['size'] as double,
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────
// LÉGENDE DES ICÔNES DE PARTAGE
// Utilisée sur la page "Cherche l'icône de partage" : montre les
// 3 formes les plus courantes du bouton de partage selon les apps.
// ─────────────────────────────────────────────

class _ShareIconLegend extends StatelessWidget {
  const _ShareIconLegend();

  static const List<IconData> _icons = [
    Icons.ios_share_rounded,
    Icons.send_rounded,
    Icons.more_vert_rounded,
  ];

  static const List<Map<String, String>> _variants = [
    {'labelFr': 'Carré + flèche', 'labelEn': 'Square + arrow', 'sub': 'YouTube, Safari'},
    {'labelFr': 'Avion', 'labelEn': 'Plane', 'sub': 'Instagram, TikTok'},
    {'labelFr': '"Partager via"', 'labelEn': '"Share via"', 'sub': 'Android, menus ⋮'},
  ];

  @override
  Widget build(BuildContext context) {
    final isFr = Localizations.localeOf(context).languageCode == 'fr';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06), width: 0.5),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < _variants.length; i++)
            SizedBox(
              width: 84,
              child: Column(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: const Color(0xFF7C3AED).withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(_icons[i], size: 20, color: const Color(0xFFA855F7)),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    isFr ? _variants[i]['labelFr']! : _variants[i]['labelEn']!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _variants[i]['sub']!,
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 10),
                  ),
                ],
              ),
            ),
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
