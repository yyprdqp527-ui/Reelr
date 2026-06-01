import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/l10n.dart';
import 'core/theme.dart';
import 'screens/home_screen.dart';
import 'screens/onboarding_screen.dart';
import 'widgets/main_shell.dart';
import 'state/clips_state.dart';

// ─────────────────────────────────────────────
// APP ROOT
// ─────────────────────────────────────────────

class ClipsApp extends StatefulWidget {
  final ClipsState state;

  const ClipsApp({super.key, required this.state});

    static ClipsAppState? of(BuildContext context) =>
      context.findAncestorStateOfType<ClipsAppState>();

  @override
  State<ClipsApp> createState() => ClipsAppState();
}

class ClipsAppState extends State<ClipsApp> {
  ThemeMode _themeMode = ThemeMode.dark;
  Locale _locale = const Locale('fr');
  bool _onboardingDone = false;
  bool _prefsLoaded = false;
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();
  StreamSubscription<List<SharedMediaFile>>? _shareSub;
  StreamSubscription<Uri>? _deepLinkSub;

  ThemeMode get themeMode => _themeMode;
  Locale get locale => _locale;

  void setThemeMode(ThemeMode mode) {
    setState(() => _themeMode = mode);
    SharedPreferences.getInstance()
        .then((p) => p.setString('themeMode', mode.name));
  }

  void setLocale(Locale locale) {
    setState(() => _locale = locale);
    SharedPreferences.getInstance()
        .then((p) => p.setString('locale', locale.languageCode));
  }

  void markOnboardingDone() {
    setState(() => _onboardingDone = true);
    SharedPreferences.getInstance()
        .then((p) => p.setBool('onboarding_done', true));
  }

  @override
  void initState() {
    super.initState();
    _loadPrefs();
    _initShareIntent();
    _initDeepLinks();
  }

  Future<void> _loadPrefs() async {
    final p = await SharedPreferences.getInstance();
    final theme = p.getString('themeMode');
    final lang = p.getString('locale');
    if (!mounted) return;
    final onboarding = p.getBool('onboarding_done') ?? false;
    setState(() {
      _onboardingDone = onboarding;
      _prefsLoaded = true;
      if (theme != null) {
        _themeMode = ThemeMode.values.firstWhere(
          (m) => m.name == theme,
          orElse: () => ThemeMode.system,
        );
      }
      if (lang != null) {
        _locale = Locale(lang);
      }
    });
  }

  void _initDeepLinks() {
    if (kIsWeb) return;
    final appLinks = AppLinks();
    // Cold start : URI qui a lancé l'app
    appLinks.getInitialLink().then((uri) {
      if (uri != null) _handleDeepLink(uri);
    });
    // App déjà en cours d'exécution
    _deepLinkSub = appLinks.uriLinkStream.listen(_handleDeepLink);
  }

  void _handleDeepLink(Uri uri) {
    if (uri.scheme != 'reelr' || uri.host != 'add') return;
    final encoded = uri.queryParameters['url'];
    if (encoded == null || encoded.isEmpty) return;
    final url = Uri.decodeComponent(encoded);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctx = _navigatorKey.currentContext;
      if (ctx == null) return;
      showModalBottomSheet(
        context: ctx,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => AddClipSheet(state: widget.state, initialUrl: url),
      );
    });
  }

  void _initShareIntent() {
    if (kIsWeb) return;
    try {
      // Cold start (app opened via share)
      ReceiveSharingIntent.instance.getInitialMedia().then((files) {
        _handleSharedFiles(files);
        ReceiveSharingIntent.instance.reset();
      });
      // Warm shares (app already running)
      _shareSub =
          ReceiveSharingIntent.instance.getMediaStream().listen((files) {
        _handleSharedFiles(files);
      });
    } catch (e) {
      debugPrint('Share intent unsupported on this platform: $e');
    }
  }

  void _handleSharedFiles(List<SharedMediaFile> files) {
    if (files.isEmpty) return;
    // Look for the first text/URL among shared items.
    String? url;
    for (final f in files) {
      final v = f.path.trim();
      if (v.startsWith('http')) {
        url = v;
        break;
      }
    }
    if (url == null) return;
    // Wait for the navigator to be mounted, then open the sheet.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctx = _navigatorKey.currentContext;
      if (ctx == null) return;
      showModalBottomSheet(
        context: ctx,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) =>
            AddClipSheet(state: widget.state, initialUrl: url),
      );
    });
  }

  @override
  void dispose() {
    _shareSub?.cancel();
    _deepLinkSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.state,
      builder: (context, _) => MaterialApp(
        title: 'Reelr',
        debugShowCheckedModeBanner: false,
        navigatorKey: _navigatorKey,
        theme: AppTheme.light(),
        darkTheme: AppTheme.dark(),
        themeMode: _themeMode,
        locale: _locale,
        supportedLocales: const [Locale('fr'), Locale('en')],
        localizationsDelegates: const [
          AppL10n.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: !_prefsLoaded
            ? const Scaffold(backgroundColor: Color(0xFF0A0E1F))
            : _onboardingDone
                ? MainShell(state: widget.state)
                : OnboardingScreen(state: widget.state),
      ),
    );
  }
}
