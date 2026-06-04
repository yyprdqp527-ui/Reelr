import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter/services.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import 'core/l10n.dart';
import 'core/theme.dart';
import 'models/clip.dart';
import 'screens/onboarding_screen.dart';
import 'services/oembed.dart';
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

class ClipsAppState extends State<ClipsApp> with WidgetsBindingObserver {
  static const MethodChannel _silentShareInboxChannel =
      MethodChannel('reelr/share_inbox');
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
    _drainPendingShare();
  }

  /// Variante qui attend la persistance avant de rendre la main.
  /// À utiliser depuis l'onboarding pour éviter qu'un kill immédiat
  /// de l'app ne perde la pref.
  Future<void> markOnboardingDoneAwaited() async {
    final p = await SharedPreferences.getInstance();
    await p.setBool('onboarding_done', true);
    if (!mounted) return;
    setState(() => _onboardingDone = true);
    _drainPendingShare();
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadPrefs();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _drainSilentShareInbox();
    });
    _initShareIntent();
    _initDeepLinks();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      debugPrint("[lifecycle] resumed");
      _drainSilentShareInbox();
    }
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
    _drainPendingShare();
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
    // Déduplication globale (15s).
    final now = DateTime.now();
    if (url == _lastSharedUrl &&
        _lastSharedAt != null &&
        now.difference(_lastSharedAt!).inSeconds < 15) {
      return;
    }
    _lastSharedUrl = url;
    _lastSharedAt = now;
    _openShareSheetWhenReady(url);
  }

  String? _lastSharedUrl;
  DateTime? _lastSharedAt;
  String? _pendingSharedUrl;

  /// Met l'URL en file d'attente et tente de l'ouvrir si l'app est prête.
  void _openShareSheetWhenReady(String url) {
    _pendingSharedUrl = url;
    _drainPendingShare();
  }

  /// Ouvre la sheet de partage UNIQUEMENT si les prefs sont chargées
  /// et l'onboarding terminé. Sinon attend.
  void _drainPendingShare() {
    if (!_prefsLoaded || !_onboardingDone) return;
    final url = _pendingSharedUrl;
    if (url == null) return;
    _pendingSharedUrl = null;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctx = _navigatorKey.currentContext;
      if (ctx == null) {
        // Pas encore monté, on remet en file.
        _pendingSharedUrl = url;
        return;
      }
      // Doublon ? Affiche un SnackBar discret sans ouvrir la sheet.
      if (widget.state.isDuplicate(url)) {
        final existing = widget.state.findDuplicate(url);
        final title = existing?.title;
        ScaffoldMessenger.of(ctx).showSnackBar(
          SnackBar(
            content: Text(_locale.languageCode == 'fr'
                ? (title != null && title.isNotEmpty
                    ? '"$title" est déjà dans votre liste.'
                    : 'Ce lien est déjà dans votre liste.')
                : (title != null && title.isNotEmpty
                    ? '"$title" is already in your list.'
                    : 'This link is already in your list.')),
            duration: const Duration(seconds: 3),
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }
      unawaited(_ingestSharedUrl(url));
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
    // Déduplication : ignore si même URL déjà traitée dans les 15 dernières secondes.
    final now = DateTime.now();
    if (url == _lastSharedUrl &&
        _lastSharedAt != null &&
        now.difference(_lastSharedAt!).inSeconds < 15) {
      return;
    }
    _lastSharedUrl = url;
    _lastSharedAt = now;
    unawaited(_ingestSharedUrl(url));
  }

  Future<void> _ingestSharedUrl(String url) async {
    if (widget.state.isDuplicate(url)) return;
    final platform = SocialPlatform.detect(url);
    final clip = Clip(
      id: const Uuid().v4(),
      url: url,
      title: platform.name,
      platform: platform.id,
      categoryId: null,
      tags: const [],
      addedAt: DateTime.now(),
      thumbnailUrl: OEmbedService.bestThumbnailUrl(url, null),
    );
    await widget.state.addClip(clip);
    unawaited(_hydrateAndClassify(clip));
  }

  Future<void> _drainSilentShareInbox() async {
    try {
      debugPrint('[drain] calling drainPendingUrls...');
      final dynamic raw = await _silentShareInboxChannel
          .invokeMethod('drainPendingUrls');
      debugPrint('[drain] raw result: $raw');
      final urls = (raw is List)
          ? raw.whereType<String>().map((u) => u.trim()).toList()
          : <String>[];
      debugPrint('[drain] found ${urls.length} urls');
      for (final url in urls) {
        if (!_isValidHttpUrl(url)) continue;
        if (widget.state.isDuplicate(url)) continue;
        await _ingestSharedUrl(url);
      }
    } catch (e) { debugPrint('[drain] error: $e'); }
  }

  bool _isValidHttpUrl(String url) {
    final uri = Uri.tryParse(url.trim());
    return uri != null &&
        (uri.scheme == 'http' || uri.scheme == 'https') &&
        uri.host.isNotEmpty;
  }

  Future<void> _hydrateAndClassify(Clip clip) async {
    await _hydrateClip(clip);
    final updated = widget.state.allClips.where((c) => c.id == clip.id).firstOrNull ?? clip;
    await widget.state.classifyClipInBackground(updated);
  }

  Future<void> _hydrateClip(Clip clip) async {
    debugPrint('[hydrate] starting for: \${clip.url}');
    final meta = await OEmbedService.fetchMetadata(clip.url);
    debugPrint('[hydrate] url=' + clip.url);
    debugPrint('[hydrate] title=' + (meta?.title ?? 'NULL') + ' thumb=' + (meta?.thumbnailUrl ?? 'NULL'));
    if (meta == null) return;
    final title = (meta.title ?? '').trim();
    final thumbnailUrl = meta.thumbnailUrl;
    if (title.isEmpty && (thumbnailUrl == null || thumbnailUrl.isEmpty)) {
      return;
    }
    await widget.state.updateClip(
      Clip(
        id: clip.id,
        url: clip.url,
        title: title.isEmpty ? clip.title : title,
        platform: clip.platform,
        categoryId: clip.categoryId,
        tags: clip.tags,
        addedAt: clip.addedAt,
        thumbnailUrl: (thumbnailUrl == null || thumbnailUrl.isEmpty)
            ? clip.thumbnailUrl
            : thumbnailUrl,
        position: clip.position,
      ),
    );
  }

  @override
  void dispose() {
    _shareSub?.cancel();
    _deepLinkSub?.cancel();
    WidgetsBinding.instance.removeObserver(this);
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
        onGenerateRoute: (settings) {
          // Gère le partage iOS via route "/?url=https://..." en mettant
          // simplement l'URL en file d'attente — sans bypasser le gating
          // _prefsLoaded / _onboardingDone.
          final name = settings.name ?? '';
          if (name.startsWith('/?url=')) {
            final encoded = name.substring('/?url='.length);
            final url = Uri.decodeComponent(encoded);
            if (url.startsWith('http')) {
              final now = DateTime.now();
              if (!(url == _lastSharedUrl &&
                  _lastSharedAt != null &&
                  now.difference(_lastSharedAt!).inSeconds < 15)) {
                _lastSharedUrl = url;
                _lastSharedAt = now;
                _openShareSheetWhenReady(url);
              }
            }
          }
          return MaterialPageRoute(
            builder: (_) => !_prefsLoaded
                ? const Scaffold(backgroundColor: Color(0xFF0A0E1F))
                : _onboardingDone
                    ? MainShell(state: widget.state)
                    : OnboardingScreen(state: widget.state),
          );
        },
        onUnknownRoute: (settings) => MaterialPageRoute(
          builder: (_) => !_prefsLoaded
              ? const Scaffold(backgroundColor: Color(0xFF0A0E1F))
              : _onboardingDone
                  ? MainShell(state: widget.state)
                  : OnboardingScreen(state: widget.state),
        ),
      ),
    );
  }
}
