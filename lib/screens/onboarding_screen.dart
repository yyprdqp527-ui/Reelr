import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../app.dart';
import '../state/clips_state.dart';

// ─────────────────────────────────────────────
// ONBOARDING — version oct. 2026
// 5 écrans : accueil animé (le bazar → Reelr → rangé), 3 écrans
// "comment enregistrer" (Partager → Plus / défiler → choisir Reelr),
// un dernier écran "Essaie" avec les raccourcis vers les applis.
// Tailles et espaces proportionnels à la hauteur d'écran (_sc).
// L'écran 3 change selon la plateforme : "Plus" sur iPhone, "défiler"
// sur Android. Textes FR/EN validés le 05/10/2026.
// DA : fond nuit violet de l'accueil, halos violets, cadres néon lilas,
// mots-clés au dégradé du logo, bouton dégradé violet.
// ─────────────────────────────────────────────

const Color _bg = Color(0xFF0B0820);
const Color _violet = Color(0xFF7C3AED);
const Color _violetLight = Color(0xFFA855F7);
const Color _lilac = Color(0xFFA78BFA);
const Color _panelColor = Color(0xD914182B);

/// Dégradé exact du titre "Reelr" de l'écran d'accueil (home_screen).
const LinearGradient _logoGradient = LinearGradient(
  colors: [Color(0xFF8B5CF6), Color(0xFF2563EB), Color(0xFF22D3EE)],
  stops: [0.0, 0.6, 1.0],
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
);

const String _nbsp = ' ';

// ─────────────────────────────────────────────
// TEXTES FR / EN
// ─────────────────────────────────────────────

class _T {
  final bool fr;
  const _T(this.fr);

  String get skip => fr ? 'Passer' : 'Skip';
  String get next => fr ? 'Continuer' : 'Continue';
  String get gotIt => fr ? "J’ai compris, j’y vais$_nbsp!" : "Got it, I'm on it!";
  String get replay => fr ? 'Revoir le tutoriel' : 'Show me again';

  // Accueil
  String get q1 => fr ? 'Tu enregistres plein de contenus$_nbsp?' : 'Always saving videos and links?';
  String get q2 => fr ? 'Tu passes des heures à les retrouver$_nbsp?' : 'Then spend ages finding them?';
  String get putAll => fr ? 'Mets tout dans Reelr.' : 'Drop it all in Reelr.';
  String get sorts => fr ? 'Il les classe automatiquement.' : 'It sorts them automatically.';
  String get findFast => fr
      ? 'Retrouve tes liens et vidéos\nen deux secondes.'
      : 'Find your links and videos\nin seconds.';
  List<String> get cats => fr
      ? const ['Recettes', 'Voyage', 'Tricot']
      : const ['Recipes', 'Travel', 'Knitting'];

  // Écran 1 — Partager
  String get s1Top => fr ? 'Un contenu' : 'See something';
  String get s1Accent => fr ? 'te plaît$_nbsp?' : 'you like?';
  String get s1Sub => fr ? 'Appuie sur Partager.' : 'Tap Share.';
  String get s1Foot => fr
      ? 'Depuis une vidéo ou un lien,\nouvre le menu de partage.'
      : 'On any video or link,\nopen the share menu.';

  // Écran 2 — Plus (iPhone) / défiler (Android)
  String get s2Top => fr ? 'Tu ne vois pas' : "Don't see";
  String get s2Accent => fr ? 'Reelr$_nbsp?' : 'Reelr?';
  String get s2SubIos => fr ? 'Appuie sur «$_nbsp$more$_nbsp».' : 'Tap More.';
  String get s2FootIos => fr
      ? 'Les trois petits points ouvrent\nla liste des applications.'
      : 'The three dots open\nyour full app list.';
  String get s2SubAndroid => fr ? 'Fais défiler.' : 'Scroll down.';
  String get s2FootAndroid => fr
      ? 'La liste des applications\ncontinue vers le bas.'
      : 'There are more apps below.';
  String get worthSaving => fr ? 'Un contenu à garder' : 'Worth saving';
  String get more => fr ? 'Plus' : 'More';
  String get copy => fr ? 'Copier' : 'Copy';
  String get bookmark => fr ? 'Ajouter un signet' : 'Add Bookmark';

  // Écran 3 — Choisir Reelr
  String get s3Lead => fr ? 'Dans la liste des applications,' : 'In the app list,';
  String get s3Verb => fr ? 'choisis ' : 'tap ';
  String get s3Foot => fr
      ? 'Astuce : touche Modifier puis +\npour mettre Reelr en favori.'
      : 'Tip: tap Edit, then +,\nto make Reelr a favorite.';
  // Écran « Essaie »
  String get tryTop => fr ? 'Essaie avec' : 'Try it with';
  String get tryAccent => fr ? 'ton premier contenu' : 'your first save';
  String get tryFoot => fr
      ? 'Choisis un lien que tu veux garder,\npuis partage-le vers Reelr.'
      : 'Pick a link you want to keep,\nthen share it to Reelr.';

  String get tryApps => fr ? 'Ouvre une appli ou un site et choisis un contenu' : 'Open an app or a site and pick something';

  String get apps => 'Apps';
  String get edit => fr ? 'Modifier' : 'Edit';

  // Noms d'apps génériques (aucun logo de marque)
  String get aMessages => 'Messages';
  String get aMail => 'Mail';
  String get aNotes => 'Notes';
  String get aFiles => fr ? 'Fichiers' : 'Files';
  String get aReminders => fr ? 'Rappels' : 'Reminders';
  String get aCalendar => fr ? 'Agenda' : 'Calendar';
  String get aContacts => 'Contacts';
  String get aPrint => fr ? 'Imprimer' : 'Print';
  String get aCloud => 'Cloud';
  String get aChat => fr ? 'Discussion' : 'Chat';
  String get aLists => fr ? 'Listes' : 'Lists';
  String get aPhotos => 'Photos';
  String get aGallery => fr ? 'Galerie' : 'Gallery';
  String get aDocs => 'Docs';
  String get aMoreApps => fr ? 'Plus d’apps' : 'More apps';
}

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
  static const int _pageCount = 5;

  final PageController _controller = PageController();
  int _currentPage = 0;

  bool get _isLast => _currentPage == _pageCount - 1;

  Future<void> _complete() async {
    if (!mounted) return;
    await ClipsApp.of(context)?.markOnboardingDoneAwaited();
    if (!mounted) return;
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }
  }

  void _next() {
    _controller.nextPage(
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeInOut,
    );
  }

  void _replay() {
    _controller.animateToPage(
      0,
      duration: const Duration(milliseconds: 450),
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
    final t = _T(Localizations.localeOf(context).languageCode == 'fr');
    final isAndroid = defaultTargetPlatform == TargetPlatform.android;
    final sc = _sc(context);

    return Scaffold(
      backgroundColor: _bg,
      body: Stack(
        children: [
          const Positioned.fill(child: _GlowBackground()),
          SafeArea(
            child: Center(
             child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: Column(
              children: [
                // "Passer" (masqué sur le dernier écran)
                SizedBox(
                  height: sc < 0.9 ? 40 : 48,
                  child: _isLast
                      ? const SizedBox.shrink()
                      : Align(
                          alignment: Alignment.centerRight,
                          child: Padding(
                            padding: const EdgeInsets.only(right: 12),
                            child: TextButton(
                              onPressed: _complete,
                              child: Text(
                                t.skip,
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.6),
                                  fontSize: 15,
                                ),
                              ),
                            ),
                          ),
                        ),
                ),
                Expanded(
                  child: PageView(
                    controller: _controller,
                    onPageChanged: (i) => setState(() => _currentPage = i),
                    children: [
                      _WelcomePage(t: t),
                      _SharePage(t: t),
                      isAndroid ? _ScrollPage(t: t) : _MorePage(t: t),
                      _PickPage(t: t),
                      _TryPage(t: t, onLeave: _complete),
                    ],
                  ),
                ),
                SizedBox(height: 14 * sc),
                // Bouton : même format et même place sur tous les écrans.
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: _GradientButton(
                    label: _isLast ? t.gotIt : t.next,
                    onPressed: _isLast ? _complete : _next,
                  ),
                ),
                // Emplacement réservé sous le bouton : vide sauf sur le
                // dernier écran, pour que le bouton ne bouge jamais.
                SizedBox(
                  height: sc < 0.9 ? 36 : 44,
                  child: _isLast
                      ? Center(
                          child: TextButton.icon(
                            onPressed: _replay,
                            icon: const Icon(Icons.replay_rounded,
                                size: 16, color: _violetLight),
                            label: Text(
                              t.replay,
                              style: const TextStyle(
                                color: _violetLight,
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        )
                      : null,
                ),
                const SizedBox(height: 8),
              ],
            ),
            ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// ÉLÉMENTS COMMUNS
// ─────────────────────────────────────────────

/// Halos violets fixes, en dégradés radiaux (pas de blur : plus léger).
class _GlowBackground extends StatelessWidget {
  const _GlowBackground();

  Widget _halo(Color c, double size, double alpha) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [c.withValues(alpha: alpha), c.withValues(alpha: 0)],
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Stack(
        clipBehavior: Clip.hardEdge,
        children: [
          Positioned(top: -160, right: -180, child: _halo(const Color(0xFF6D28D9), 460, 0.45)),
          Positioned(top: 240, left: -230, child: _halo(const Color(0xFF312E81), 420, 0.6)),
          Positioned(top: 420, right: -220, child: _halo(_lilac, 360, 0.22)),
          Positioned(bottom: -230, left: -40, child: _halo(const Color(0xFF4C1D95), 480, 0.5)),
        ],
      ),
    );
  }
}

class _GradientText extends StatelessWidget {
  final String text;
  final TextStyle style;

  const _GradientText(this.text, {required this.style});

  @override
  Widget build(BuildContext context) {
    return ShaderMask(
      blendMode: BlendMode.srcIn,
      shaderCallback: (bounds) => _logoGradient.createShader(bounds),
      child: Text(text, textAlign: TextAlign.center, style: style.copyWith(color: Colors.white)),
    );
  }
}

class _GradientButton extends StatelessWidget {
  final String label;
  final VoidCallback onPressed;

  const _GradientButton({required this.label, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(18);
    return Container(
      width: double.infinity,
      height: 54,
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [_violet, _violetLight]),
        borderRadius: radius,
        boxShadow: [
          BoxShadow(
            color: _violet.withValues(alpha: 0.45),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: radius,
          onTap: onPressed,
          child: Center(
            child: Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 17,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

BoxDecoration _neon(double radius) => BoxDecoration(
      color: const Color(0x591E1446),
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: _lilac, width: 2.5),
      boxShadow: [
        BoxShadow(color: const Color(0xFF8B5CF6).withValues(alpha: 0.8), blurRadius: 18),
        BoxShadow(color: const Color(0xFF2563EB).withValues(alpha: 0.45), blurRadius: 50),
      ],
    );

BoxDecoration _panel(double radius) => BoxDecoration(
      color: _panelColor,
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
    );

double _seg(double t, double a, double b) => ((t - a) / (b - a)).clamp(0.0, 1.0);

/// Doigt qui arrive, appuie, puis disparaît. Posé par-dessus [child].
class _TapDot extends StatelessWidget {
  final double t;
  final double start;
  final double arrive;
  final double press;
  final double end;
  final Widget child;
  final Alignment alignment;

  const _TapDot({
    required this.t,
    required this.start,
    required this.arrive,
    required this.press,
    required this.end,
    required this.child,
    this.alignment = Alignment.center,
  });

  @override
  Widget build(BuildContext context) {
    double opacity = 0;
    double scale = 1;
    Offset offset = Offset.zero;
    if (t >= start && t < arrive) {
      final p = Curves.easeOut.transform(_seg(t, start, arrive));
      opacity = p;
      offset = Offset(30 * (1 - p), 50 * (1 - p));
    } else if (t >= arrive && t < press) {
      opacity = 1;
    } else if (t >= press && t < press + 0.07) {
      opacity = 1;
      scale = 1 - 0.3 * _seg(t, press, press + 0.07);
    } else if (t >= press + 0.07 && t < end) {
      final p = _seg(t, press + 0.07, end);
      opacity = 1 - p;
      scale = 0.7 + 0.9 * p;
    }
    return Stack(
      clipBehavior: Clip.none,
      alignment: alignment,
      children: [
        child,
        IgnorePointer(
          child: Transform.translate(
            offset: offset,
            child: Opacity(
              opacity: opacity,
              child: Transform.scale(
                scale: scale,
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: 0.35),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.8), width: 2),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Mise en page commune des écrans « comment enregistrer ».
/// Espacements identiques partout (proportionnels à la hauteur d'écran).
class _TutoPage extends StatelessWidget {
  final String? counter;
  final List<Widget> heading;
  final Widget visual;
  final List<Widget> foot;

  const _TutoPage({
    this.counter,
    required this.heading,
    required this.visual,
    required this.foot,
  });

  @override
  Widget build(BuildContext context) {
    final sc = _sc(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 22),
      child: Column(
        children: [
          SizedBox(
            height: 20 * sc,
            child: counter == null
                ? null
                : Text(
                    counter!,
                    style: TextStyle(
                      color: _lilac,
                      fontSize: 16 * sc,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 2,
                    ),
                  ),
          ),
          SizedBox(height: 12 * sc),
          ...heading,
          SizedBox(height: 16 * sc),
          Expanded(
            child: Center(
              child: FittedBox(
                fit: BoxFit.contain,
                child: SizedBox(width: 320, height: 340, child: visual),
              ),
            ),
          ),
          SizedBox(height: 18 * sc),
          ...foot,
          SizedBox(height: 28 * sc),
        ],
      ),
    );
  }
}

Widget _fit(Widget child) => FittedBox(fit: BoxFit.scaleDown, child: child);

/// Facteur d'échelle selon la hauteur de l'écran (1.0 dès 800 pt, jusqu'à 0.78
/// sur les petits téléphones) : l'onboarding s'adapte à tous les écrans.
double _sc(BuildContext c) => (MediaQuery.sizeOf(c).height / 800).clamp(0.78, 1.0).toDouble();

TextStyle _h1(BuildContext c) => TextStyle(
      color: Colors.white,
      fontSize: 36 * _sc(c),
      fontWeight: FontWeight.w800,
      letterSpacing: -1,
      height: 1.08,
    );
TextStyle _h2(BuildContext c) => TextStyle(
      color: Colors.white,
      fontSize: 25 * _sc(c),
      fontWeight: FontWeight.w700,
      letterSpacing: -0.4,
    );
TextStyle _foot(BuildContext c) => TextStyle(
      color: Colors.white.withValues(alpha: 0.9),
      fontSize: 17 * _sc(c),
      height: 1.35,
    );

/// Mixin : contrôleur d'animation en boucle infinie.
mixin _LoopAnim<W extends StatefulWidget> on State<W>, SingleTickerProviderStateMixin<W> {
  late final AnimationController loop;
  Duration get loopDuration;

  @override
  void initState() {
    super.initState();
    loop = AnimationController(vsync: this, duration: loopDuration)..repeat();
  }

  @override
  void dispose() {
    loop.dispose();
    super.dispose();
  }
}

/// Tuile d'app générique (pas de logo de marque).
class _AppIcon extends StatelessWidget {
  final Color color;
  final IconData icon;
  final double size;
  final bool round;

  const _AppIcon(this.color, this.icon, {this.size = 49, this.round = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color,
        shape: round ? BoxShape.circle : BoxShape.rectangle,
        borderRadius: round ? null : BorderRadius.circular(size * 0.25),
      ),
      child: Icon(icon, color: Colors.white, size: size * 0.53),
    );
  }
}

class _ReelrIcon extends StatelessWidget {
  final double size;
  final bool round;

  const _ReelrIcon({this.size = 49, this.round = false});

  @override
  Widget build(BuildContext context) {
    final radius = round ? size / 2 : size * 0.25;
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: Image.asset('assets/icon/icon.png', width: size, height: size, fit: BoxFit.cover),
    );
  }
}

// ─────────────────────────────────────────────
// ÉCRAN 0 — ACCUEIL : le bazar → Reelr aspire tout → c'est rangé
// ─────────────────────────────────────────────

class _WelcomePage extends StatefulWidget {
  final _T t;

  const _WelcomePage({required this.t});

  @override
  State<_WelcomePage> createState() => _WelcomePageState();
}

class _WelcomePageState extends State<_WelcomePage> with SingleTickerProviderStateMixin {
  static const _items = <(IconData, Color, int)>[
    (Icons.play_arrow_rounded, Color(0xFFFF4D4D), 0),
    (Icons.image_outlined, Color(0xFFF472B6), 1),
    (Icons.music_note_rounded, Color(0xFF22D3EE), 2),
    (Icons.link_rounded, Color(0xFFFBBF24), 0),
    (Icons.shopping_bag_outlined, Color(0xFFFB923C), 1),
    (Icons.bookmark_border_rounded, Color(0xFFA78BFA), 2),
    (Icons.play_arrow_rounded, Color(0xFFFF4D4D), 0),
    (Icons.image_outlined, Color(0xFFF472B6), 2),
    (Icons.link_rounded, Color(0xFFFBBF24), 1),
  ];
  static const _catColors = [Color(0xFFFB923C), Color(0xFF22D3EE), Color(0xFFF472B6)];

  late final AnimationController _c;
  final math.Random _rnd = math.Random();
  late List<(double, double, double)> _scatter;

  void _shuffle() {
    _scatter = List.generate(
      _items.length,
      (_) => (_rnd.nextDouble() * 2 - 1, _rnd.nextDouble() * 2 - 1, (_rnd.nextDouble() * 2 - 1) * 0.5),
    );
  }

  @override
  void initState() {
    super.initState();
    _shuffle();
    _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 6500))
      ..addStatusListener((s) {
        if (s == AnimationStatus.completed) {
          _shuffle();
          _c.forward(from: 0);
        }
      })
      ..forward();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  Widget _stage() {
    return LayoutBuilder(builder: (context, box) {
      final w = box.maxWidth;
      final h = box.maxHeight;
      final colX = [-w / 3, 0.0, w / 3];
      final tile = math.min(64.0, h / 4.3);
      final labelW = math.min(96.0, w / 3 - 12);
      return AnimatedBuilder(
        animation: _c,
        builder: (context, _) {
          final t = _c.value;
          final hubIn = t >= 0.32 && t < 0.64;
          final hubScale = hubIn
              ? Curves.elasticOut.transform(_seg(t, 0.32, 0.44)) *
                  (1 + 0.15 * math.sin(math.pi * _seg(t, 0.48, 0.6) * 2).abs())
              : 0.0;
          final labelsOpacity = _seg(t, 0.62, 0.7);
          final counts = [0, 0, 0];
          final children = <Widget>[];

          // Étiquettes de catégories
          for (var i = 0; i < 3; i++) {
            children.add(Positioned(
              top: 4,
              left: w / 2 + colX[i] - labelW / 2,
              width: labelW,
              child: Opacity(
                opacity: labelsOpacity,
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  decoration: BoxDecoration(
                    color: _catColors[i].withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: _catColors[i].withValues(alpha: 0.55)),
                  ),
                  child: Text(
                    widget.t.cats[i],
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: _catColors[i], fontSize: 13, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ));
          }

          // Logo Reelr au centre
          children.add(Positioned(
            left: w / 2 - 46,
            top: h / 2 - 46,
            child: Transform.scale(
              scale: hubScale,
              child: Container(
                width: 92,
                height: 92,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(26),
                  border: Border.all(color: const Color(0xFF8B5CF6), width: 1.5),
                  boxShadow: [
                    BoxShadow(color: const Color(0xFF8B5CF6).withValues(alpha: 0.75), blurRadius: 50),
                    BoxShadow(color: const Color(0xFF2563EB).withValues(alpha: 0.5), blurRadius: 90),
                  ],
                ),
                child: const _ReelrIcon(size: 92),
              ),
            ),
          ));

          // Tuiles de contenu
          for (var i = 0; i < _items.length; i++) {
            final (icon, color, cat) = _items[i];
            final n = counts[cat]++;
            final (sx, sy, sr) = _scatter[i];
            final scatter = Offset(sx * (w / 2 - tile * 0.7), sy * (h / 2 - tile * 0.8));
            final sorted = Offset(colX[cat], -h / 2 + 40 + tile / 2 + n * (tile + 6));

            Offset pos;
            double scale;
            double rot;
            double opacity = 1;
            if (t < 0.34) {
              pos = scatter;
              scale = 1;
              rot = sr + 0.1 * math.sin(t * 60 + i);
            } else if (t < 0.48) {
              final p = Curves.easeIn.transform(_seg(t, 0.34 + i * 0.008, 0.46 + i * 0.002));
              pos = Offset.lerp(scatter, Offset.zero, p)!;
              scale = 1 - 0.8 * p;
              rot = sr * (1 - p);
              opacity = p > 0.95 ? 0 : 1;
            } else if (t < 0.62 + i * 0.012) {
              pos = Offset.zero;
              scale = 0.2;
              rot = 0;
              opacity = 0;
            } else {
              final p = Curves.elasticOut.transform(_seg(t, 0.62 + i * 0.012, 0.8 + i * 0.012));
              pos = Offset.lerp(Offset.zero, sorted, p)!;
              scale = 0.2 + 0.65 * p;
              rot = 0;
            }

            children.add(Positioned(
              left: w / 2 - tile / 2 + pos.dx,
              top: h / 2 - tile / 2 + pos.dy,
              child: Opacity(
                opacity: opacity,
                child: Transform.rotate(
                  angle: rot,
                  child: Transform.scale(
                    scale: scale,
                    child: Container(
                      width: tile,
                      height: tile,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(tile * 0.27),
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Colors.white.withValues(alpha: 0.22),
                            Colors.white.withValues(alpha: 0.05),
                          ],
                        ),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
                      ),
                      child: Icon(icon, color: color, size: tile * 0.46),
                    ),
                  ),
                ),
              ),
            ));
          }
          return Stack(clipBehavior: Clip.none, children: children);
        },
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.t;
    final sc = _sc(context);
    // Tout le bloc est centré : l'animation n'est plus loin du texte.
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _fit(Text(
            '${t.q1}\n${t.q2}',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.92),
              fontSize: 21 * sc,
              fontWeight: FontWeight.w700,
              height: 1.35,
            ),
          )),
          SizedBox(height: 18 * sc),
          Flexible(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxHeight: 250 * sc),
              child: _stage(),
            ),
          ),
          SizedBox(height: 20 * sc),
          _fit(_GradientText(
            t.putAll,
            style: TextStyle(fontSize: 32 * sc, fontWeight: FontWeight.w800, letterSpacing: -0.6),
          )),
          SizedBox(height: 4 * sc),
          _fit(Text(
            t.sorts,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.85),
              fontSize: 20 * sc,
              fontWeight: FontWeight.w600,
            ),
          )),
          SizedBox(height: 20 * sc),
          // Le bénéfice principal de l'appli : le plus gros texte.
          _fit(Text(
            t.findFast,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white,
              fontSize: 25 * sc,
              fontWeight: FontWeight.w800,
              height: 1.25,
              letterSpacing: -0.4,
            ),
          )),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// ÉCRAN 1 — APPUIE SUR PARTAGER
// ─────────────────────────────────────────────

class _SharePage extends StatefulWidget {
  final _T t;

  const _SharePage({required this.t});

  @override
  State<_SharePage> createState() => _SharePageState();
}

class _SharePageState extends State<_SharePage>
    with SingleTickerProviderStateMixin, _LoopAnim<_SharePage> {
  @override
  Duration get loopDuration => const Duration(milliseconds: 2400);

  double _ringScale(double t) {
    if (t < 0.55) return 1;
    if (t < 0.62) return 1 - 0.15 * _seg(t, 0.55, 0.62);
    if (t < 0.72) return 0.85 + 0.27 * _seg(t, 0.62, 0.72);
    return 1.12 - 0.12 * _seg(t, 0.72, 0.85);
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.t;
    return _TutoPage(
      counter: '1 / 3',
      heading: [
        _fit(Text(t.s1Top, style: _h1(context))),
        _fit(_GradientText(t.s1Accent, style: _h1(context))),
        const SizedBox(height: 6),
        _fit(Text(t.s1Sub, style: _h2(context))),
      ],
      visual: AnimatedBuilder(
        animation: loop,
        builder: (context, _) {
          final v = loop.value;
          return Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned(
                left: 50,
                top: 8,
                child: Container(
                  width: 220,
                  height: 322,
                  padding: const EdgeInsets.fromLTRB(12, 22, 12, 12),
                  decoration: _neon(34),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: Stack(
                      children: [
                        const Positioned.fill(child: CustomPaint(painter: _LandscapePainter())),
                        Positioned(
                          right: 10,
                          bottom: 56,
                          child: Column(
                            children: [
                              const Icon(Icons.favorite_border_rounded, color: Colors.white, size: 26),
                              const SizedBox(height: 14),
                              const Icon(Icons.chat_bubble_outline_rounded, color: Colors.white, size: 24),
                              const SizedBox(height: 14),
                              _TapDot(
                                t: v,
                                start: 0,
                                arrive: 0.35,
                                press: 0.55,
                                end: 0.75,
                                child: Transform.scale(
                                  scale: _ringScale(v),
                                  child: Container(
                                    width: 46,
                                    height: 46,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      border: Border.all(color: _lilac, width: 3),
                                      boxShadow: [
                                        BoxShadow(color: _lilac.withValues(alpha: 0.8), blurRadius: 14),
                                      ],
                                    ),
                                    child: Transform.rotate(
                                      angle: -math.pi / 6,
                                      child: const Icon(Icons.send_rounded, color: Colors.white, size: 22),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Positioned(
                          left: 10,
                          bottom: 14,
                          child: Row(
                            children: [
                              CircleAvatar(radius: 11, backgroundColor: Colors.white.withValues(alpha: 0.35)),
                              const SizedBox(width: 6),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _bar(70),
                                  const SizedBox(height: 5),
                                  _bar(100),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Positioned(
                left: 160 - 30,
                top: 15,
                child: Container(
                  width: 60,
                  height: 5,
                  decoration: BoxDecoration(
                    color: _lilac.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
              // Flèche qui pointe le bouton
              Positioned(
                left: 268,
                top: 192,
                child: Transform.translate(
                  offset: Offset(-6 * math.sin(v * 2 * math.pi * 2).abs(), 6 * math.sin(v * 2 * math.pi * 2).abs()),
                  child: const CustomPaint(size: Size(46, 46), painter: _ArrowPainter()),
                ),
              ),
            ],
          );
        },
      ),
      foot: [Text(t.s1Foot, textAlign: TextAlign.center, style: _foot(context))],
    );
  }

  Widget _bar(double w) => Container(
        width: w,
        height: 6,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(3),
        ),
      );
}

/// Paysage de montagne générique (aucune photo).
class _LandscapePainter extends CustomPainter {
  const _LandscapePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final sx = size.width / 200;
    final sy = size.height / 290;
    Offset p(double x, double y) => Offset(x * sx, y * sy);
    Path poly(List<Offset> pts) => Path()..addPolygon(pts, true);

    final rect = Offset.zero & size;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF3B82F6), Color(0xFFBAE6FD)],
        ).createShader(rect),
    );
    canvas.drawPath(
      poly([p(0, 140), p(40, 80), p(70, 115), p(110, 55), p(150, 105), p(175, 85), p(200, 110), p(200, 160), p(0, 160)]),
      Paint()..color = const Color(0xFF64748B),
    );
    final snow = Paint()..color = const Color(0xFFF1F5F9);
    canvas.drawPath(poly([p(110, 55), p(122, 72), p(100, 72)]), snow);
    canvas.drawPath(poly([p(40, 80), p(50, 93), p(31, 93)]), snow);
    canvas.drawPath(
      poly([p(0, 150), p(60, 120), p(120, 140), p(200, 125), p(200, 165), p(0, 165)]),
      Paint()..color = const Color(0xFF166534),
    );
    final lake = Rect.fromLTWH(0, 160 * sy, size.width, 130 * sy);
    canvas.drawRect(
      lake,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF60A5FA), Color(0xFF1E3A8A)],
        ).createShader(lake),
    );
    final tree = Paint()..color = const Color(0xFF14532D);
    for (final tr in const [(10.0, 230.0, 170.0), (28.0, 245.0, 180.0), (0.0, 260.0, 200.0), (50.0, 265.0, 210.0)]) {
      final (x, bottom, top) = tr;
      canvas.drawPath(poly([p(x, bottom), p(x + 12, top), p(x + 24, bottom)]), tree);
    }
    canvas.drawRect(
      Rect.fromLTWH(0, 262 * sy, size.width, 28 * sy),
      Paint()..color = const Color(0x8C0B0820),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _ArrowPainter extends CustomPainter {
  const _ArrowPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 56;
    final paint = Paint()
      ..color = _lilac
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final curve = Path()
      ..moveTo(46 * s, 6 * s)
      ..cubicTo(48 * s, 26 * s, 36 * s, 38 * s, 16 * s, 40 * s);
    final head = Path()
      ..moveTo(24 * s, 30 * s)
      ..lineTo(16 * s, 40 * s)
      ..lineTo(27 * s, 46 * s);
    canvas.drawPath(curve, paint);
    canvas.drawPath(head, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// En-tête commun des feuilles de partage simulées.
Widget _sheetHeader(_T t) => Container(
      padding: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.white.withValues(alpha: 0.1))),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: SizedBox(
              width: 46,
              height: 46,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  const CustomPaint(painter: _LandscapePainter()),
                  Center(
                    child: Icon(
                      Icons.play_arrow_rounded,
                      color: Colors.white,
                      size: 26,
                      shadows: const [Shadow(color: Color(0x73000000), blurRadius: 6)],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              t.worthSaving,
              style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );

Widget _appLabel(String s) => Padding(
      padding: const EdgeInsets.only(top: 5),
      child: Text(
        s,
        maxLines: 1,
        overflow: TextOverflow.clip,
        softWrap: false,
        style: TextStyle(color: Colors.white.withValues(alpha: 0.9), fontSize: 10.5),
      ),
    );

// ─────────────────────────────────────────────
// ÉCRAN 2 (iPhone) — APPUIE SUR « PLUS »
// ─────────────────────────────────────────────

class _MorePage extends StatefulWidget {
  final _T t;

  const _MorePage({required this.t});

  @override
  State<_MorePage> createState() => _MorePageState();
}

class _MorePageState extends State<_MorePage>
    with SingleTickerProviderStateMixin, _LoopAnim<_MorePage> {
  @override
  Duration get loopDuration => const Duration(milliseconds: 4000);

  double _press(double t) {
    if (t < 0.74) return 1;
    if (t < 0.8) return 1 - 0.15 * _seg(t, 0.74, 0.8);
    if (t < 0.88) return 0.85 + 0.2 * _seg(t, 0.8, 0.88);
    return 1.05 - 0.05 * _seg(t, 0.88, 0.95);
  }

  Widget _app(Color c, IconData i, String label) => SizedBox(
        width: 49,
        child: Column(children: [_AppIcon(c, i), _appLabel(label)]),
      );

  @override
  Widget build(BuildContext context) {
    final t = widget.t;
    return _TutoPage(
      counter: '2 / 3',
      heading: [
        _fit(Text(t.s2Top, style: _h1(context))),
        _fit(_GradientText(t.s2Accent, style: _h1(context))),
        const SizedBox(height: 6),
        _fit(Text(t.s2SubIos, style: _h2(context))),
      ],
      visual: Center(
        child: Container(
          width: 300,
          padding: const EdgeInsets.all(16),
          decoration: _neon(34),
          child: Container(
            padding: const EdgeInsets.fromLTRB(12, 14, 12, 14),
            decoration: _panel(22),
            child: AnimatedBuilder(
              animation: loop,
              builder: (context, _) {
                final v = loop.value;
                final swipe = Curves.easeInOut.transform(_seg(v, 0.2, 0.45));
                final ring = _seg(v, 0.48, 0.58);
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _sheetHeader(t),
                    Container(
                      height: 92,
                      decoration: BoxDecoration(
                        border: Border(bottom: BorderSide(color: Colors.white.withValues(alpha: 0.1))),
                      ),
                      child: ClipRect(
                        child: OverflowBox(
                          alignment: Alignment.centerLeft,
                          maxWidth: double.infinity,
                          child: Transform.translate(
                            offset: Offset(-118 * swipe, 0),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                _app(const Color(0xFF34C759), Icons.chat_bubble_rounded, t.aMessages),
                                const SizedBox(width: 10),
                                _app(const Color(0xFF3B82F6), Icons.mail_outline_rounded, t.aMail),
                                const SizedBox(width: 10),
                                _app(const Color(0xFFFACC15), Icons.notes_rounded, t.aNotes),
                                const SizedBox(width: 10),
                                _app(const Color(0xFFF97316), Icons.folder_outlined, t.aFiles),
                                const SizedBox(width: 10),
                                _app(const Color(0xFFA855F7), Icons.schedule_rounded, t.aReminders),
                                const SizedBox(width: 10),
                                SizedBox(
                                  width: 49,
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      _TapDot(
                                        t: v,
                                        start: 0.55,
                                        arrive: 0.72,
                                        press: 0.73,
                                        end: 0.92,
                                        child: Transform.scale(
                                          scale: _press(v),
                                          child: Stack(
                                            clipBehavior: Clip.none,
                                            alignment: Alignment.center,
                                            children: [
                                              const _AppIcon(Color(0xFF8E8E93), Icons.more_horiz_rounded),
                                              Opacity(
                                                opacity: ring,
                                                child: Transform.scale(
                                                  scale: 0.6 + 0.4 * ring,
                                                  child: Container(
                                                    width: 63,
                                                    height: 63,
                                                    decoration: BoxDecoration(
                                                      shape: BoxShape.circle,
                                                      border: Border.all(color: _lilac, width: 3),
                                                      boxShadow: [
                                                        BoxShadow(color: _lilac.withValues(alpha: 0.7), blurRadius: 12),
                                                      ],
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                      _appLabel(t.more),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 12),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _action(Icons.copy_rounded, t.copy),
                        const SizedBox(width: 40),
                        _action(Icons.bookmark_border_rounded, t.bookmark),
                      ],
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
      foot: [Text(t.s2FootIos, textAlign: TextAlign.center, style: _foot(context))],
    );
  }

  Widget _action(IconData i, String label) => Column(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withValues(alpha: 0.1)),
            child: Icon(i, color: Colors.white, size: 22),
          ),
          const SizedBox(height: 6),
          Text(label, style: const TextStyle(color: Colors.white, fontSize: 12)),
        ],
      );
}

// ─────────────────────────────────────────────
// ÉCRAN 2 (Android) — FAIS DÉFILER
// ─────────────────────────────────────────────

class _ScrollPage extends StatefulWidget {
  final _T t;

  const _ScrollPage({required this.t});

  @override
  State<_ScrollPage> createState() => _ScrollPageState();
}

class _ScrollPageState extends State<_ScrollPage>
    with SingleTickerProviderStateMixin, _LoopAnim<_ScrollPage> {
  @override
  Duration get loopDuration => const Duration(milliseconds: 4500);

  static const double _rowStep = 81;

  Widget _cell(Widget icon, String label) => Expanded(
        child: SizedBox(
          height: _rowStep,
          child: Column(children: [icon, _appLabel(label)]),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final t = widget.t;
    return _TutoPage(
      counter: '2 / 3',
      heading: [
        _fit(Text(t.s2Top, style: _h1(context))),
        _fit(_GradientText(t.s2Accent, style: _h1(context))),
        const SizedBox(height: 6),
        _fit(Text(t.s2SubAndroid, style: _h2(context))),
      ],
      visual: Center(
        child: Container(
          width: 300,
          padding: const EdgeInsets.all(16),
          decoration: _neon(34),
          child: Container(
            padding: const EdgeInsets.fromLTRB(12, 14, 12, 14),
            decoration: _panel(22),
            child: AnimatedBuilder(
              animation: loop,
              builder: (context, _) {
                final v = loop.value;
                final scroll = Curves.easeInOut.transform(_seg(v, 0.15, 0.45));
                final ring = _seg(v, 0.48, 0.56);
                double press = 1;
                if (v >= 0.75 && v < 0.8) press = 1 - 0.15 * _seg(v, 0.75, 0.8);
                if (v >= 0.8 && v < 0.88) press = 0.85 + 0.2 * _seg(v, 0.8, 0.88);
                if (v >= 0.88) press = 1.05 - 0.05 * _seg(v, 0.88, 0.95);

                Widget appIconRound(Color c, IconData i) => _AppIcon(c, i, round: true);

                final reelr = _TapDot(
                  t: v,
                  start: 0.55,
                  arrive: 0.72,
                  press: 0.73,
                  end: 0.92,
                  child: Transform.scale(
                    scale: press,
                    child: Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        boxShadow: ring > 0
                            ? [
                                BoxShadow(color: _lilac.withValues(alpha: ring), spreadRadius: 3),
                                BoxShadow(color: _lilac.withValues(alpha: 0.8 * ring), blurRadius: 16),
                              ]
                            : null,
                      ),
                      child: const _ReelrIcon(round: true),
                    ),
                  ),
                );

                final rows = <List<Widget>>[
                  [
                    _cell(appIconRound(const Color(0xFF34C759), Icons.chat_bubble_rounded), t.aMessages),
                    _cell(appIconRound(const Color(0xFF3B82F6), Icons.mail_outline_rounded), t.aMail),
                    _cell(appIconRound(const Color(0xFFFACC15), Icons.notes_rounded), t.aNotes),
                    _cell(appIconRound(const Color(0xFFF97316), Icons.folder_outlined), t.aFiles),
                  ],
                  [
                    _cell(appIconRound(const Color(0xFFA855F7), Icons.schedule_rounded), t.aReminders),
                    _cell(appIconRound(const Color(0xFFEF4444), Icons.calendar_today_outlined), t.aCalendar),
                    _cell(appIconRound(const Color(0xFF14B8A6), Icons.person_outline_rounded), t.aContacts),
                    _cell(appIconRound(const Color(0xFF64748B), Icons.print_outlined), t.aPrint),
                  ],
                  [
                    _cell(appIconRound(const Color(0xFF0EA5E9), Icons.cloud_outlined), t.aCloud),
                    _cell(reelr, 'Reelr'),
                    _cell(appIconRound(const Color(0xFFEC4899), Icons.chat_bubble_rounded), t.aChat),
                    _cell(appIconRound(const Color(0xFF22C55E), Icons.checklist_rounded), t.aLists),
                  ],
                  [
                    _cell(appIconRound(const Color(0xFF6366F1), Icons.photo_outlined), t.aPhotos),
                    _cell(appIconRound(const Color(0xFFF59E0B), Icons.collections_outlined), t.aGallery),
                    _cell(appIconRound(const Color(0xFF10B981), Icons.description_outlined), t.aDocs),
                    _cell(appIconRound(const Color(0xFF8B5CF6), Icons.add_rounded), t.aMoreApps),
                  ],
                ];

                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _sheetHeader(t),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 206,
                      child: ShaderMask(
                        blendMode: BlendMode.dstIn,
                        shaderCallback: (r) => const LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Colors.white, Colors.white, Colors.transparent],
                          stops: [0, 0.8, 1],
                        ).createShader(r),
                        child: ClipRect(
                          child: OverflowBox(
                            alignment: Alignment.topCenter,
                            maxHeight: double.infinity,
                            child: Transform.translate(
                              offset: Offset(0, 4 - _rowStep * scroll),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [for (final r in rows) Row(children: r)],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
      foot: [Text(t.s2FootAndroid, textAlign: TextAlign.center, style: _foot(context))],
    );
  }
}

// ─────────────────────────────────────────────
// ÉCRAN 3 — CHOISIS REELR
// ─────────────────────────────────────────────

class _PickPage extends StatefulWidget {
  final _T t;

  const _PickPage({required this.t});

  @override
  State<_PickPage> createState() => _PickPageState();
}

class _PickPageState extends State<_PickPage>
    with SingleTickerProviderStateMixin, _LoopAnim<_PickPage> {
  @override
  Duration get loopDuration => const Duration(milliseconds: 5000);

  Widget _row(Widget icon, String label, {double highlight = 0}) {
    final row = Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: _lilac.withValues(alpha: 0.1 * highlight),
        border: Border.all(color: _lilac.withValues(alpha: highlight), width: 2.5),
        boxShadow: highlight > 0
            ? [BoxShadow(color: _lilac.withValues(alpha: 0.8 * highlight), blurRadius: 16)]
            : null,
      ),
      child: Row(
        children: [
          icon,
          const SizedBox(width: 12),
          Expanded(child: Text(label, style: const TextStyle(color: Colors.white, fontSize: 16))),
          Text('›', style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 20)),
        ],
      ),
    );
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(height: 1, color: Colors.white.withValues(alpha: 0.08)),
        row,
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.t;
    return _TutoPage(
      counter: '3 / 3',
      heading: [
        _fit(Text(t.s3Lead, style: const TextStyle(color: Colors.white, fontSize: 21, fontWeight: FontWeight.w700))),
        const SizedBox(height: 4),
        _fit(Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(t.s3Verb, style: _h1(context)),
            _GradientText('Reelr.', style: _h1(context)),
          ],
        )),
      ],
      visual: Center(
        child: Container(
          width: 300,
          padding: const EdgeInsets.all(16),
          decoration: _neon(34),
          child: Container(
            padding: const EdgeInsets.fromLTRB(10, 6, 10, 14),
            decoration: _panel(22),
            child: AnimatedBuilder(
              animation: loop,
              builder: (context, _) {
                final v = loop.value;
                final hl = _seg(v, 0.15, 0.25);
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      height: 40,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Text(t.apps,
                              style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
                          Align(
                            alignment: Alignment.centerRight,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Text(t.edit,
                                  style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500)),
                            ),
                          ),
                        ],
                      ),
                    ),
                    _row(const _AppIcon(Color(0xFF34C759), Icons.chat_bubble_rounded, size: 38), t.aMessages),
                    _row(const _AppIcon(Color(0xFF3B82F6), Icons.mail_outline_rounded, size: 38), t.aMail),
                    _row(const _AppIcon(Color(0xFFFACC15), Icons.notes_rounded, size: 38), t.aNotes),
                    _TapDot(
                      t: v,
                      start: 0.10,
                      arrive: 0.25,
                      press: 0.26,
                      end: 0.43,
                      alignment: const Alignment(0.3, 0),
                      child: _row(const _ReelrIcon(size: 38), 'Reelr', highlight: hl),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
      foot: [Text(t.s3Foot, textAlign: TextAlign.center, style: _foot(context))],
    );
  }
}

// ─────────────────────────────────────────────
// ÉCRAN « ESSAIE » — à part, avec son propre bouton
// ─────────────────────────────────────────────

class _TryPage extends StatefulWidget {
  final _T t;

  /// Termine l'onboarding. Appelé avant d'ouvrir une appli : sinon le lien
  /// partagé reste en attente (l'app ne le traite qu'une fois l'onboarding
  /// fini) et on retombait sur l'onboarding au retour.
  final Future<void> Function() onLeave;

  const _TryPage({required this.t, required this.onLeave});

  @override
  State<_TryPage> createState() => _TryPageState();
}

class _TryPageState extends State<_TryPage>
    with SingleTickerProviderStateMixin, _LoopAnim<_TryPage> {
  @override
  Duration get loopDuration => const Duration(milliseconds: 1800);

  @override
  Widget build(BuildContext context) {
    final t = widget.t;
    return _TutoPage(
      heading: [
        _fit(Text(t.tryTop, style: _h1(context))),
        _fit(_GradientText(t.tryAccent, style: _h1(context))),
      ],
      visual: FittedBox(
        fit: BoxFit.scaleDown,
        child: SizedBox(
          width: 320,
          child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedBuilder(
            animation: loop,
            builder: (context, _) {
              final p = 0.5 + 0.5 * math.sin(loop.value * 2 * math.pi);
              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 96,
                    height: 96,
                    padding: const EdgeInsets.all(5),
                    decoration: _neon(24),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(18),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          const CustomPaint(painter: _LandscapePainter()),
                          const Center(
                            child: Icon(Icons.play_arrow_rounded, color: Colors.white, size: 40),
                          ),
                        ],
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 52,
                    child: Transform.translate(
                      offset: Offset(8 * p - 4, 0),
                      child: const Icon(Icons.arrow_forward_rounded, color: _lilac, size: 34),
                    ),
                  ),
                  Container(
                    width: 96,
                    height: 96,
                    padding: const EdgeInsets.all(5),
                    decoration: _neon(24),
                    child: const _ReelrIcon(size: 86),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 26),
          Text(
            t.tryApps,
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white.withValues(alpha: 0.75), fontSize: 15, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 14,
            runSpacing: 14,
            children: [
              _AppLink('assets/icons/youtube.png', 'YouTube', 'https://www.youtube.com', ['youtube', 'vnd.youtube'], onBefore: widget.onLeave),
              _AppLink('assets/icons/tiktok.png', 'TikTok', 'https://www.tiktok.com', ['tiktok', 'snssdk1233'], onBefore: widget.onLeave),
              _AppLink('assets/icons/instagram.png', 'Instagram', 'https://www.instagram.com', ['instagram'], onBefore: widget.onLeave),
              _AppLink('assets/icons/facebook.png', 'Facebook', 'https://www.facebook.com', ['fb'], onBefore: widget.onLeave),
              _AppLink('assets/icons/pinterest.png', 'Pinterest', 'https://www.pinterest.com', ['pinterest'], onBefore: widget.onLeave),
              _AppLink('assets/icons/twitch.png', 'Twitch', 'https://www.twitch.tv', ['twitch'], onBefore: widget.onLeave),
              _AppLink('assets/icons/linkedin.png', 'LinkedIn', 'https://www.linkedin.com', ['linkedin'], onBefore: widget.onLeave),
              _AppLink(null, null, 'https://www.google.com', [], onBefore: widget.onLeave),
            ],
          ),
        ],
      ),
        ),
      ),
      foot: [Text(t.tryFoot, textAlign: TextAlign.center, style: _foot(context))],
    );
  }
}

/// Raccourci vers une appli — même fonctionnement que la grille de l'accueil :
/// un appui ouvre un petit encadré (« Direction YouTube… » + « Compris,
/// j'y vais »), puis on termine l'onboarding et on ouvre l'appli native
/// (ou le site si elle n'est pas installée).
class _AppLink extends StatelessWidget {
  /// Logo de l'appli ; null = tuile « site web ».
  final String? asset;
  final String? label;
  final String url;
  final List<String> schemes;
  final Future<void> Function()? onBefore;

  const _AppLink(this.asset, this.label, this.url, this.schemes, {this.onBefore});

  Future<void> _open() async {
    for (final scheme in schemes) {
      final uri = Uri.parse('$scheme://');
      try {
        if (await canLaunchUrl(uri) && await launchUrl(uri, mode: LaunchMode.externalApplication)) {
          return;
        }
      } catch (_) {}
    }
    try {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } catch (_) {}
  }

  Future<void> _tap(BuildContext context, String name) async {
    final fr = Localizations.localeOf(context).languageCode == 'fr';
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF14182B),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                fr ? 'Direction $name' : 'Heading to $name',
                style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 10),
              Text(
                fr
                    ? 'Choisis une vidéo, appuie sur ↑ Partager, puis cherche Reelr.\nTu ne le vois pas ? Appuie sur ··· Plus et active-le.'
                    : "Pick a video, tap ↑ Share, then look for Reelr.\nDon't see it? Tap ··· More and turn it on.",
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 14, height: 1.5),
              ),
              const SizedBox(height: 20),
              _GradientButton(
                label: fr ? 'Compris, j’y vais' : "Got it, let's go",
                onPressed: () => Navigator.of(sheetContext).pop(),
              ),
            ],
          ),
        ),
      ),
    );
    // Terminer l'onboarding AVANT de partir : sinon le lien partagé reste
    // en attente et on retombe sur l'onboarding au retour.
    await onBefore?.call();
    await _open();
  }

  @override
  Widget build(BuildContext context) {
    final fr = Localizations.localeOf(context).languageCode == 'fr';
    final name = label ?? (fr ? 'Site web' : 'Website');
    return GestureDetector(
      onTap: () => _tap(context, name),
      child: SizedBox(
        width: 64,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(15),
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.35), blurRadius: 10, offset: const Offset(0, 4))],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(15),
                child: asset != null
                    ? Image.asset(asset!, width: 54, height: 54, cacheWidth: 162, fit: BoxFit.cover)
                    : Container(
                        width: 54,
                        height: 54,
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [Color(0xFF7C3AED), Color(0xFF2563EB)],
                          ),
                        ),
                        child: const Icon(Icons.language_rounded, color: Colors.white, size: 30),
                      ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.clip,
              softWrap: false,
              style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 11, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }
}
