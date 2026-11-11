import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../app.dart';
import '../state/clips_state.dart';

// ─────────────────────────────────────────────
// ONBOARDING — version nov. 2026
//
// Parcours de départ (iPhone) : Bienvenue (vidéo des tuiles) → « Un contenu
// te plaît ? » → « Tu ne vois pas Reelr quand tu partages ? » → page des
// applis. Android : même chose sans l'écran des trois points.
//
// Parcours de secours : proposé quand le client revient d'une appli sans
// avoir partagé (voir ClipsApp._maybeOfferOnboardingRescue), ou depuis le
// lien « Je ne trouve pas Reelr ». iPhone : activer Reelr dans la liste
// d'applis. Android : faire défiler la ligne d'applis et épingler Reelr.
//
// Les téléphones animés sont des WebP (assets/onboarding), un par langue.
// Titres, boutons, liens des applis et textes restent en Flutter (FR/EN).
// DA du site myreelr.app : fond #1A1651, lueurs bleues, Figtree 900,
// un mot en jaune par titre, boutons jaune pâle.
// ─────────────────────────────────────────────

const Color _bg = Color(0xFF1A1651);
const Color _blue = Color(0xFF2B43F4);
const Color _teal = Color(0xFF12C2DA);
const Color _blueSoft = Color(0xFF6F82FF);
const Color _cyan = Color(0xFF6FF1FA);
const Color _sun = Color(0xFFE6E98A);
const String _font = 'Figtree';
const String _nbsp = ' ';
const String _dir = 'assets/onboarding';

/// Clé des préférences : un lien partagé est attendu après l'ouverture
/// d'une appli depuis l'onboarding.
const String kOnbRescuePending = 'onb_rescue_pending';
const String kOnbRescueBase = 'onb_rescue_base';
const String kOnbRescueAt = 'onb_rescue_at';

// ─────────────────────────────────────────────
// TEXTES FR / EN
// ─────────────────────────────────────────────

class _T {
  final bool fr;
  const _T(this.fr);

  String get lang => fr ? 'fr' : 'en';

  String get skip => fr ? 'Passer' : 'Skip';
  String get next => fr ? 'Continuer' : 'Continue';
  String get start => fr ? 'Commencer' : 'Get started';
  String get go => fr ? 'J’y vais$_nbsp!' : "Let's go!";
  String get cantFind => fr ? 'Je ne trouve pas Reelr' : "I can't find Reelr";
  String get showMe => fr ? 'Montre-moi' : 'Show me';
  String get imFine => fr ? 'Non, ça va' : "No, I'm good";

  // Intro du secours (iPhone)
  String get introBody => fr
      ? 'Pas de panique, ça arrive$_nbsp!\nIl suffit de l’activer dans ta liste d’applis.'
      : 'No worries, it happens!\nJust turn it on in your app list.';
  String get introShow => fr ? 'On te montre.' : "We'll show you.";

  // Page des applis
  String get appsHint => fr
      ? 'Clique sur ton appli préférée\net choisis une vidéo'
      : 'Tap your favorite app\nand pick a video';
  String browser(bool android) => android ? 'Chrome' : 'Safari';
}

// ─────────────────────────────────────────────
// ÉCRAN
// ─────────────────────────────────────────────

enum _Kind { welcome, share, dots, apps, intro, modifier, toggle, androidRescue }

class OnboardingScreen extends StatefulWidget {
  final ClipsState state;

  /// Vrai quand l'écran est ouvert depuis l'accueil après un retour sans
  /// partage : on montre seulement le parcours de secours, puis on ferme.
  final bool rescueOnly;

  const OnboardingScreen({super.key, required this.state, this.rescueOnly = false});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen>
    with WidgetsBindingObserver {
  final PageController _controller = PageController();
  int _page = 0;
  bool _rescue = false;

  /// Moment ou le client a quitte l'appli depuis les dernieres pages.
  DateTime? _leftAt;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  /// Le client est alle chercher un lien dans une autre appli depuis les
  /// dernieres pages : a son retour, on le laisse dans Reelr (accueil) au
  /// lieu de le laisser bloque sur l'onboarding.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (widget.rescueOnly || !mounted) return;
    if (state == AppLifecycleState.paused) {
      _leftAt = (_kind == _Kind.dots || _kind == _Kind.apps)
          ? DateTime.now()
          : null;
    } else if (state == AppLifecycleState.resumed) {
      final left = _leftAt;
      _leftAt = null;
      if (left != null &&
          DateTime.now().difference(left) > const Duration(seconds: 3)) {
        _complete();
      }
    }
  }

  bool get _isAndroid => defaultTargetPlatform == TargetPlatform.android;
  bool get _inRescue => _rescue || widget.rescueOnly;

  List<_Kind> get _kinds {
    if (_inRescue) {
      return _isAndroid
          ? const [_Kind.androidRescue, _Kind.apps]
          : const [_Kind.intro, _Kind.dots, _Kind.modifier, _Kind.toggle, _Kind.apps];
    }
    return [
      _Kind.welcome,
      _Kind.share,
      if (!_isAndroid) _Kind.dots,
      _Kind.apps,
    ];
  }

  _Kind get _kind => _kinds[math.min(_page, _kinds.length - 1)];
  bool get _hasWelcome => _kinds.first == _Kind.welcome;

  Future<void> _complete() async {
    if (!mounted) return;
    if (widget.rescueOnly) {
      Navigator.of(context).pop();
      return;
    }
    await ClipsApp.of(context)?.markOnboardingDoneAwaited();
    if (!mounted) return;
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }
  }

  /// Avant d'ouvrir une appli : on note qu'un lien est attendu. Au retour,
  /// si rien n'est arrivé, l'accueil proposera l'aide.
  Future<void> _leaveForApp() async {
    // Lu AVANT tout await : on ne touche pas au BuildContext apres.
    final app = ClipsApp.of(context);
    if (!_inRescue) {
      try {
        final base = app?.lifetimeClipsAdded ?? 0;
        final p = await SharedPreferences.getInstance();
        await p.setInt(kOnbRescueBase, base);
        await p.setInt(kOnbRescueAt, DateTime.now().millisecondsSinceEpoch);
        await p.setBool(kOnbRescuePending, true);
      } catch (_) {}
    }
    // Terminer l'onboarding AVANT de partir : sinon on retombe dessus au
    // retour. L'accueil affiche alors le spinner « Reelr range ton lien… »
    // (et non l'ecran vide) jusqu'au retour du client.
    app?.holdArrivalForLeave();
    await _complete();
  }

  Future<void> _afterApp() async {}

  void _back() {
    _controller.previousPage(
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeInOut,
    );
  }

  void _next() {
    _controller.nextPage(
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeInOut,
    );
  }

  void _startRescue() {
    setState(() {
      _rescue = true;
      _page = 0;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_controller.hasClients) _controller.jumpToPage(0);
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller.dispose();
    super.dispose();
  }

  String _primaryLabel(_T t) {
    switch (_kind) {
      case _Kind.welcome:
        return t.start;
      case _Kind.apps:
        return t.go;
      case _Kind.intro:
        return t.showMe;
      default:
        return t.next;
    }
  }

  VoidCallback _primaryAction() {
    return _kind == _Kind.apps ? _complete : _next;
  }

  String? _secondaryLabel(_T t) {
    switch (_kind) {
      case _Kind.apps:
        return _inRescue ? null : t.cantFind;
      case _Kind.intro:
      case _Kind.androidRescue:
        return t.imFine;
      default:
        return null;
    }
  }

  VoidCallback? _secondaryAction() {
    switch (_kind) {
      case _Kind.apps:
        return _startRescue;
      case _Kind.intro:
      case _Kind.androidRescue:
        return _complete;
      default:
        return null;
    }
  }

  Widget _progress() {
    final total = _kinds.where((k) => k != _Kind.welcome).length;
    final index = _page - (_hasWelcome ? 1 : 0);
    if (_kind == _Kind.welcome) return const SizedBox.shrink();
    return Row(
      children: List.generate(total, (i) {
        return Container(
          width: 22,
          height: 3,
          margin: const EdgeInsets.only(right: 4),
          decoration: BoxDecoration(
            color: i <= index ? _sun : Colors.white.withValues(alpha: 0.18),
            borderRadius: BorderRadius.circular(2),
          ),
        );
      }),
    );
  }

  Widget _buildPage(_Kind kind, _T t) {
    switch (kind) {
      case _Kind.welcome:
        return _Page(
          title: _title(context, [
            _s(t.fr ? 'Bienvenue dans\n' : 'Welcome to\n'),
            _s('Reelr', wordmark: true),
          ]),
          phone: (h) => _PhoneFrame(
            height: h,
            child: Image.asset(
              '$_dir/tuiles11-fluide.webp',
              fit: BoxFit.cover,
              gaplessPlayback: true,
            ),
          ),
        );
      case _Kind.share:
        return _Page(
          title: _title(context, t.fr
              ? [_s('Un contenu\n'), _s('te plaît', y: true), _s('$_nbsp?')]
              : [_s('See something\nyou '), _s('like', y: true), _s('?')]),
          phone: (h) => _PhoneAnim(asset: '$_dir/onb_share_${t.lang}.webp', height: h),
        );
      case _Kind.dots:
        return _Page(
          title: _title(context, t.fr
              ? [_s('Tu ne vois pas Reelr\nquand tu '), _s('partages', y: true), _s('$_nbsp?')]
              : [_s("Don't see Reelr\nwhen you "), _s('share', y: true), _s('?')]),
          phone: (h) => _PhoneAnim(asset: '$_dir/onb_dots_${t.lang}.webp', height: h),
        );
      case _Kind.modifier:
        return _Page(
          title: _title(context, t.fr
              ? [_s('Tu vas tomber sur\nla liste des '), _s('applis', y: true)]
              : [_s("You'll land on\nthe "), _s('app', y: true), _s(' list')]),
          phone: (h) => _PhoneAnim(asset: '$_dir/onb_modifier_${t.lang}.webp', height: h),
        );
      case _Kind.toggle:
        return _Page(
          title: _title(context, t.fr
              ? [_s('Scrolle,\nReelr est tout en '), _s('bas', y: true), _s('$_nbsp!')]
              : [_s('Scroll,\nReelr is at the '), _s('bottom', y: true), _s('!')]),
          phone: (h) => _PhoneAnim(asset: '$_dir/onb_toggle_${t.lang}.webp', height: h),
        );
      case _Kind.androidRescue:
        return _Page(
          title: _title(context, t.fr
              ? [_s('Tu ne trouves pas\n'), _s('Reelr', wordmark: true), _s('$_nbsp?')]
              : [_s("Can't find\n"), _s('Reelr', wordmark: true), _s('?')]),
          phone: (h) => _PhoneAnim(asset: '$_dir/onb_android_${t.lang}.webp', height: h),
        );
      case _Kind.intro:
        return _Page(
          title: _title(context, t.fr
              ? [_s('Tu n’as pas trouvé\n'), _s('Reelr', wordmark: true), _s('$_nbsp?')]
              : [_s("Can't find\n"), _s('Reelr', wordmark: true), _s('?')]),
          phone: (h) => _PhoneFrame(height: h, child: _IntroScreen(t: t, height: h)),
        );
      case _Kind.apps:
        return _Page(
          title: _title(context, t.fr
              ? [_s('Maintenant, trouve\nun contenu à '), _s('garder', y: true)]
              : [_s('Now find\nsomething to '), _s('save', y: true)]),
          phone: (h) => _PhoneFrame(
            height: h,
            child: _AppsScreen(t: t, height: h, android: _isAndroid, onBefore: _leaveForApp, onAfter: _afterApp),
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = _T(Localizations.localeOf(context).languageCode == 'fr');
    final kinds = _kinds;
    final secondary = _secondaryLabel(t);

    return Scaffold(
      backgroundColor: _bg,
      body: Stack(
        children: [
          const Positioned.fill(child: IgnorePointer(child: _Glow())),
          SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 560),
                child: Column(
                  children: [
                    SizedBox(
                      height: 44,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: Row(
                          children: [
                            _progress(),
                            const Spacer(),
                            if (_kind != _Kind.welcome)
                              TextButton(
                                onPressed: _complete,
                                child: Text(
                                  t.skip,
                                  style: TextStyle(
                                    fontFamily: _font,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.white.withValues(alpha: 0.6),
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                    Expanded(
                      child: PageView(
                        controller: _controller,
                        clipBehavior: Clip.none,
                        physics: const NeverScrollableScrollPhysics(),
                        onPageChanged: (i) => setState(() => _page = i),
                        children: [for (final k in kinds) _buildPage(k, t)],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _ArrowButton(
                          icon: Icons.chevron_left_rounded,
                          visible: _page > 0 && _kind != _Kind.welcome,
                          onPressed: _back,
                        ),
                        const SizedBox(width: 12),
                        AnimatedOpacity(
                          duration: const Duration(milliseconds: 250),
                          opacity: _kind == _Kind.apps ? 0 : 1,
                          child: IgnorePointer(
                            ignoring: _kind == _Kind.apps,
                            child: _PillButton(label: _primaryLabel(t), onPressed: _primaryAction()),
                          ),
                        ),
                        const SizedBox(width: 12),
                        _ArrowButton(
                          icon: Icons.chevron_right_rounded,
                          visible: _kind != _Kind.welcome && _kind != _Kind.apps,
                          onPressed: _next,
                        ),
                      ],
                    ),
                    SizedBox(
                      height: 44,
                      child: secondary == null
                          ? null
                          : Center(
                              child: TextButton(
                                onPressed: _secondaryAction(),
                                child: Text(
                                  secondary,
                                  style: TextStyle(
                                    fontFamily: _font,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.white.withValues(alpha: 0.65),
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                            ),
                    ),
                    const SizedBox(height: 6),
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

/// Lueurs floues du site : bleu en haut à gauche, turquoise à droite,
/// bleu en bas.
class _Glow extends StatelessWidget {
  const _Glow();

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
    return Stack(
      clipBehavior: Clip.hardEdge,
      children: [
        Positioned(top: -140, left: -160, child: _halo(_blue, 440, 0.55)),
        Positioned(top: 260, right: -220, child: _halo(_teal, 380, 0.28)),
        Positioned(bottom: -180, left: -100, child: _halo(_blue, 460, 0.38)),
      ],
    );
  }
}

/// Un morceau de titre : blanc, jaune (le mot important) ou dégradé du logo.
TextSpan _s(String text, {bool y = false, bool wordmark = false}) {
  if (wordmark) {
    return TextSpan(
      text: text,
      style: TextStyle(
        foreground: Paint()
          ..shader = const LinearGradient(colors: [_blueSoft, _cyan])
              .createShader(const Rect.fromLTWH(0, 0, 120, 36)),
      ),
    );
  }
  return TextSpan(text: text, style: TextStyle(color: y ? _sun : Colors.white));
}

Widget _title(BuildContext context, List<TextSpan> spans) {
  final h = MediaQuery.of(context).size.height;
  final size = (h / 800).clamp(0.82, 1.1) * 28.0;
  return Padding(
    padding: const EdgeInsets.fromLTRB(26, 6, 26, 0),
    child: Align(
      alignment: Alignment.centerLeft,
      child: Text.rich(
        TextSpan(
          style: TextStyle(
            fontFamily: _font,
            fontWeight: FontWeight.w900,
            fontSize: size,
            height: 1.08,
            letterSpacing: -1.1,
          ),
          children: spans,
        ),
      ),
    ),
  );
}

/// Titre en haut, téléphone centré dans la place restante.
class _Page extends StatelessWidget {
  final Widget title;
  final Widget Function(double height) phone;

  const _Page({required this.title, required this.phone});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        title,
        Expanded(
          child: LayoutBuilder(
            builder: (context, c) {
              final h = math.min(c.maxHeight - 28, 660.0);
              return Center(
                child: Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: phone(math.max(h, 200)),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

/// Faux iPhone (mêmes proportions que dans la maquette : 194 × 420).
class _PhoneFrame extends StatelessWidget {
  final Widget child;
  final double height;

  const _PhoneFrame({required this.child, required this.height});

  @override
  Widget build(BuildContext context) {
    final s = height / 420;
    final w = height * 194 / 420;
    final r = 34 * s;
    final bezel = math.max(3.0, 4 * s);
    return Container(
      width: w,
      height: height,
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(r),
        border: Border.all(color: const Color(0xFF1C1B26), width: bezel),
        boxShadow: [
          BoxShadow(color: Colors.white.withValues(alpha: 0.19), spreadRadius: 1.5),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.55),
            blurRadius: 28 * s,
            offset: Offset(0, 16 * s),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(math.max(0, r - bezel)),
        child: Stack(
          fit: StackFit.expand,
          children: [
            child,
            Positioned(
              top: 8 * s,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  width: 60 * s,
                  height: 17 * s,
                  decoration: BoxDecoration(
                    color: Colors.black,
                    borderRadius: BorderRadius.circular(9 * s),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Téléphone animé : WebP déjà dessiné avec son cadre (206 × 432).
class _PhoneAnim extends StatelessWidget {
  final String asset;
  final double height;

  const _PhoneAnim({required this.asset, required this.height});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      width: height * 206 / 432,
      child: Image.asset(
        asset,
        fit: BoxFit.contain,
        gaplessPlayback: true,
        filterQuality: FilterQuality.medium,
      ),
    );
  }
}

/// Flèche ronde pour revenir en arrière / avancer. Invisible mais gardée
/// dans la mise en page quand elle ne sert pas, pour que le bouton jaune
/// ne bouge jamais.
class _ArrowButton extends StatelessWidget {
  final IconData icon;
  final bool visible;
  final VoidCallback onPressed;

  const _ArrowButton({
    required this.icon,
    required this.visible,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 250),
      opacity: visible ? 1 : 0,
      child: IgnorePointer(
        ignoring: !visible,
        child: Material(
          color: Colors.white.withValues(alpha: 0.12),
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onPressed,
            child: SizedBox(
              width: 46,
              height: 46,
              child: Icon(icon, color: Colors.white, size: 30),
            ),
          ),
        ),
      ),
    );
  }
}

/// Bouton jaune pâle du site, texte bleu marine.
class _PillButton extends StatelessWidget {
  final String label;
  final VoidCallback onPressed;

  const _PillButton({required this.label, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: _sun,
      borderRadius: BorderRadius.circular(26),
      child: InkWell(
        borderRadius: BorderRadius.circular(26),
        onTap: onPressed,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 44, vertical: 15),
          child: Text(
            label,
            style: const TextStyle(
              fontFamily: _font,
              fontWeight: FontWeight.w800,
              fontSize: 16,
              color: _bg,
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// ÉCRANS DESSINÉS EN FLUTTER (dans le faux téléphone)
// ─────────────────────────────────────────────

/// Écran d'intro du secours (iPhone) : logo, point d'interrogation, texte.
class _IntroScreen extends StatelessWidget {
  final _T t;
  final double height;

  const _IntroScreen({required this.t, required this.height});

  @override
  Widget build(BuildContext context) {
    final s = height / 420;
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF221D68), Color(0xFF17134A)],
        ),
      ),
      padding: EdgeInsets.symmetric(horizontal: 18 * s),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(18 * s),
                child: Image.asset(
                  'assets/icon/icon.png',
                  width: 72 * s,
                  height: 72 * s,
                  fit: BoxFit.cover,
                ),
              ),
              Positioned(
                right: -10 * s,
                top: -10 * s,
                child: Container(
                  width: 30 * s,
                  height: 30 * s,
                  decoration: const BoxDecoration(color: _sun, shape: BoxShape.circle),
                  alignment: Alignment.center,
                  child: Text(
                    '?',
                    style: TextStyle(
                      fontFamily: _font,
                      fontWeight: FontWeight.w900,
                      fontSize: 19 * s,
                      color: _bg,
                    ),
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 22 * s),
          Text(
            t.introBody,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.85),
              fontSize: 13 * s,
              height: 1.45,
            ),
          ),
          SizedBox(height: 6 * s),
          Text(
            t.introShow,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white,
              fontSize: 13 * s,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

/// Page des applis, animée : un contenu vole vers Reelr, puis les applis
/// apparaissent une à une. Un appui sur une appli l'ouvre.
class _AppsScreen extends StatefulWidget {
  final _T t;
  final double height;
  final bool android;
  final Future<void> Function() onBefore;
  final Future<void> Function() onAfter;

  const _AppsScreen({
    required this.t,
    required this.height,
    required this.android,
    required this.onBefore,
    required this.onAfter,
  });

  @override
  State<_AppsScreen> createState() => _AppsScreenState();
}

class _AppsScreenState extends State<_AppsScreen> with TickerProviderStateMixin {
  /// Boucle du contenu qui part vers Reelr.
  late final AnimationController _loop = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 3200),
  )..repeat();

  /// Apparition des applis (une seule fois).
  late final AnimationController _pop = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  )..forward();

  /// Une lueur jaune passe d'une appli à l'autre : ça invite à appuyer.
  late final AnimationController _wave = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 12600),
  )..repeat();

  @override
  void dispose() {
    _wave.dispose();
    _loop.dispose();
    _pop.dispose();
    super.dispose();
  }

  Widget _top(double s) {
    return AnimatedBuilder(
      animation: _loop,
      builder: (context, _) {
        final p = _loop.value;
        final double fly;
        if (p < 0.5) {
          fly = Curves.easeInOut.transform(((p - 0.1) / 0.4).clamp(0.0, 1.0));
        } else {
          fly = p < 0.85 ? 1.0 : 0.0;
        }
        double photoOpacity = 1;
        if (p >= 0.5 && p < 0.55) photoOpacity = 1 - (p - 0.5) / 0.05;
        if (p >= 0.55 && p < 0.85) photoOpacity = 0;
        if (p >= 0.85) photoOpacity = (p - 0.85) / 0.15;
        final pulse = (p >= 0.48 && p <= 0.72)
            ? math.sin((p - 0.48) / 0.24 * math.pi)
            : 0.0;
        return SizedBox(
          height: 56 * s,
          child: Stack(
            alignment: Alignment.center,
            clipBehavior: Clip.none,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(width: 62 * s),
                  SizedBox(width: 8 * s),
                  Icon(Icons.arrow_forward_rounded, color: _sun, size: 22 * s),
                  SizedBox(width: 8 * s),
                  Transform.scale(
                    scale: 1 + 0.16 * pulse,
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(14 * s),
                        border: Border.all(
                          color: _sun.withValues(alpha: pulse),
                          width: 2.2 * s,
                        ),
                      ),
                      padding: EdgeInsets.all(2 * s),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12 * s),
                        child: Image.asset(
                          'assets/icon/icon.png',
                          width: 44 * s,
                          height: 44 * s,
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              // La photo : elle part vers Reelr, rétrécit et disparaît.
              Positioned(
                left: 0,
                right: 0,
                top: 0,
                bottom: 0,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Opacity(
                      opacity: photoOpacity.clamp(0.0, 1.0),
                      child: Transform.translate(
                        offset: Offset(95 * s * fly, 0),
                        child: Transform.scale(
                          scale: 1 - 0.35 * fly,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(11 * s),
                            child: Image.asset(
                              '$_dir/photo.jpg',
                              width: 62 * s,
                              height: 44 * s,
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                      ),
                    ),
                    SizedBox(width: (8 + 22 + 8 + 52.4) * s),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  /// Une appli qui apparaît en rebondissant, avec un petit décalage.
  Widget _tile(int i, double s, Widget icon, String label, String url,
      List<String> schemes) {
    final size = 30 * s;
    final start = (i * 0.07).clamp(0.0, 0.6);
    final anim = CurvedAnimation(
      parent: _pop,
      curve: Interval(start, math.min(1.0, start + 0.35), curve: Curves.easeOutBack),
    );
    return AnimatedBuilder(
      animation: anim,
      builder: (context, child) => Opacity(
        opacity: anim.value.clamp(0.0, 1.0),
        child: Transform.scale(scale: 0.5 + 0.5 * anim.value, child: child),
      ),
      child: AnimatedBuilder(
        animation: _wave,
        builder: (context, child) {
          // Un doigt « clique » sur une appli à la fois, lentement :
          // ça montre qu'il faut appuyer dessus.
          var d = (_wave.value * 9 - i) % 9;
          if (d < 0) d += 9;
          final g = d < 1.6 ? math.sin(d / 1.6 * math.pi) : 0.0;
          final r = 13 * s;
          return Transform.scale(
            scale: 1 - 0.05 * g,
            child: Stack(
              alignment: Alignment.topCenter,
              clipBehavior: Clip.none,
              children: [
                child!,
                Positioned(
                  top: 6 * s + size / 2 - r + 8 * s * (1 - g),
                  child: IgnorePointer(
                    child: Container(
                      width: 2 * r,
                      height: 2 * r,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withValues(alpha: 0.42 * g),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.7 * g),
                          width: 1.2 * s,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
        child: _AppLink(
          icon: icon,
          label: label,
          url: url,
          schemes: schemes,
          s: s,
          onBefore: widget.onBefore,
          onAfter: widget.onAfter,
        ),
      ),
    );
  }

  Widget _logo(String asset, double size) => Image.asset(
        asset,
        width: size,
        height: size,
        cacheWidth: 162,
        fit: BoxFit.cover,
      );

  Widget _row(List<Widget> tiles) => Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: tiles,
      );

  @override
  Widget build(BuildContext context) {
    final t = widget.t;
    final s = widget.height / 420;
    final size = 30 * s;
    final browser = Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF5CB8FF), Color(0xFF0A60F0)],
        ),
      ),
      child: Icon(Icons.explore_rounded, color: Colors.white, size: 26 * s),
    );
    final google = Container(
      width: size,
      height: size,
      color: Colors.white,
      alignment: Alignment.center,
      child: Text(
        'G',
        style: TextStyle(
          fontFamily: _font,
          fontWeight: FontWeight.w900,
          fontSize: 24 * s,
          color: const Color(0xFF4285F4),
        ),
      ),
    );
    const web = 'https://www.google.com';
    Widget gap() => SizedBox(height: 10 * s);
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF221D68), Color(0xFF17134A)],
        ),
      ),
      padding: EdgeInsets.fromLTRB(8 * s, 40 * s, 8 * s, 28 * s),
      child: Column(
        children: [
          _top(s),
          SizedBox(height: 12 * s),
          Text(
            t.appsHint,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: _font,
              fontWeight: FontWeight.w800,
              fontSize: 11.5 * s,
              height: 1.25,
              color: _sun,
            ),
          ),
          // Les applis occupent la place restante, centrées.
          Expanded(
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _row([
                    _tile(0, s, _logo('assets/icons/youtube.png', size), 'YouTube', 'https://www.youtube.com', const ['youtube', 'vnd.youtube']),
                    _tile(1, s, _logo('assets/icons/tiktok.png', size), 'TikTok', 'https://www.tiktok.com', const ['tiktok', 'snssdk1233']),
                    _tile(2, s, _logo('assets/icons/instagram.png', size), 'Instagram', 'https://www.instagram.com', const ['instagram']),
                  ]),
                  gap(),
                  _row([
                    _tile(3, s, _logo('assets/icons/facebook.png', size), 'Facebook', 'https://www.facebook.com', const ['fb']),
                    _tile(4, s, _logo('assets/icons/pinterest.png', size), 'Pinterest', 'https://www.pinterest.com', const ['pinterest']),
                    _tile(5, s, _logo('assets/icons/twitch.png', size), 'Twitch', 'https://www.twitch.tv', const ['twitch']),
                  ]),
                  gap(),
                  _row([
                    _tile(6, s, _logo('assets/icons/linkedin.png', size), 'LinkedIn', 'https://www.linkedin.com', const ['linkedin']),
                    _tile(7, s, browser, t.browser(widget.android), web, const []),
                    _tile(8, s, google, 'Google', web, const []),
                  ]),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Raccourci vers une appli : un appui note qu'un lien est attendu,
/// termine l'onboarding, puis ouvre l'appli (ou le site si elle n'est pas
/// installée).
class _AppLink extends StatelessWidget {
  final Widget icon;
  final String label;
  final String url;
  final List<String> schemes;
  final double s;
  final Future<void> Function() onBefore;
  final Future<void> Function() onAfter;

  const _AppLink({
    required this.icon,
    required this.label,
    required this.url,
    required this.schemes,
    required this.s,
    required this.onBefore,
    required this.onAfter,
  });

  Future<void> _open() async {
    for (final scheme in schemes) {
      final uri = Uri.parse('$scheme://');
      try {
        if (await canLaunchUrl(uri) &&
            await launchUrl(uri, mode: LaunchMode.externalApplication)) {
          return;
        }
      } catch (_) {}
    }
    try {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } catch (_) {}
  }

  Future<void> _tap() async {
    await onBefore();
    await _open();
    await onAfter();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _tap,
      child: Container(
        width: 50 * s,
        padding: EdgeInsets.fromLTRB(2 * s, 6 * s, 2 * s, 5 * s),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(14 * s),
          border: Border.all(color: Colors.white.withValues(alpha: 0.14), width: 1),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(9 * s),
              child: icon,
            ),
            SizedBox(height: 3 * s),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.clip,
              softWrap: false,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.85),
                fontSize: 8.5 * s,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
