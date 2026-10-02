import 'dart:async';
import 'dart:convert';

import 'package:app_links/app_links.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter/services.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'services/purchase_service.dart';
import 'package:uuid/uuid.dart';

import 'core/l10n.dart';
import 'core/theme.dart';
import 'models/clip.dart';
import 'screens/onboarding_screen.dart';
import 'screens/playlist_import_screen.dart';
import 'services/thumbnail_cache.dart';
import 'services/thumbnail_store.dart';
import 'services/classifier.dart' show VideoData;
import 'services/link_preview.dart';
import 'services/oembed.dart';
import 'services/playlist_link.dart';
import 'screens/paywall_screen.dart';
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
  static const MethodChannel _silentShareInboxChannel = MethodChannel(
    'reelr/share_inbox',
  );
  ThemeMode _themeMode = ThemeMode.dark;
  Locale _locale = const Locale('en');
  bool _onboardingDone = false;
  bool _prefsLoaded = false;
  bool _isPremium = false;
  /// Compteur cumulatif du nombre de clips jamais ajoutés (ne diminue
  /// jamais, contrairement à totalClipsCount qui reflète la liste
  /// actuelle). Sert de garde-fou pour le paywall : sans ça, un
  /// utilisateur gratuit pourrait supprimer des clips pour repasser
  /// sous la limite de 50 et ne jamais être bloqué.
  int _lifetimeClipsAdded = 0;
  /// Dernière valeur de _lifetimeClipsAdded pour laquelle la bulle de
  /// countdown (3, 2, 1 vidéos restantes) a été affichée, pour ne jamais
  /// réafficher le même palier deux fois.
  int _lastCountdownWarningShownAt = 0;
  late final PurchaseService _purchaseService;
  bool _purchaseServiceReady = false;
  /// Route du paywall actuellement affiche, pour pouvoir la refermer depuis
  /// l'exterieur quand l'achat aboutit.
  Route<void>? _paywallRoute;
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();
  StreamSubscription<List<SharedMediaFile>>? _shareSub;
  StreamSubscription<Uri>? _deepLinkSub;

  ThemeMode get themeMode => _themeMode;
  Locale get locale => _locale;
  bool get isPremium => _isPremium;

  void setPremium(bool value) {
    setState(() => _isPremium = value);
    SharedPreferences.getInstance().then((p) => p.setBool('is_premium', value));
  }

  void setThemeMode(ThemeMode mode) {
    setState(() => _themeMode = mode);
    SharedPreferences.getInstance().then(
      (p) => p.setString('themeMode', mode.name),
    );
  }

  void setLocale(Locale locale) {
    setState(() => _locale = locale);
    SharedPreferences.getInstance().then(
      (p) => p.setString('locale', locale.languageCode),
    );
    _silentShareInboxChannel
        .invokeMethod('setSharedLocale', locale.languageCode)
        .catchError((_) {});
  }

  void markOnboardingDone() {
    setState(() => _onboardingDone = true);
    SharedPreferences.getInstance().then(
      (p) => p.setBool('onboarding_done', true),
    );
    _drainPendingShare();
    _drainPendingPlaylist();
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
    _drainPendingPlaylist();
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Devine la langue du téléphone immédiatement et de façon synchrone,
    // pour que le tout premier texte affiché (avant même la fin de la
    // lecture asynchrone des préférences) soit déjà dans la bonne langue.
    // _loadPrefs() pourra ensuite l'ajuster si l'utilisateur a choisi une
    // langue manuellement dans les Réglages.
    final deviceLang =
        WidgetsBinding.instance.platformDispatcher.locale.languageCode;
    _locale = Locale(['fr', 'en'].contains(deviceLang) ? deviceLang : 'en');
    final prefsFuture = _loadPrefs();
    // La boite de partage n'est videe qu'une fois les preferences lues :
    // avant, `_lifetimeClipsAdded` vaut 0 et `_isPremium` false. Les clips
    // ajoutes dans cette fenetre etaient ensuite effaces du compteur a vie
    // par `_loadPrefs`, qui ecrase la valeur en memoire.
    prefsFuture.then((_) {
      if (mounted) _drainSilentShareInbox();
    });
    _initShareIntent();
    _initDeepLinks();
    _purchaseService = PurchaseService(
      onPremiumUnlocked: () {
        setPremium(true);
        _dismissPaywallIfOpen();
      },
      // Retire l'accès Premium local si l'abonnement n'est plus retrouvé
      // côté store au démarrage (résilié, expiré, remboursé...) — avant cet
      // ajout, rien ne repassait jamais is_premium à false une fois activé.
      onPremiumExpired: () => setPremium(false),
      isFr: () => _locale.languageCode == 'fr',
      onError: (message) {
        final ctx = _navigatorKey.currentContext;
        if (ctx != null) {
          ScaffoldMessenger.of(
            ctx,
          ).showSnackBar(SnackBar(content: Text(message)));
        }
      },
    );
    final purchaseInitFuture = _purchaseService.init();
    purchaseInitFuture.then((_) {
      if (mounted) setState(() => _purchaseServiceReady = true);
    });
    // Une fois les prefs (dont le statut Premium local persisté) ET le
    // service d'achat prêts, on lance une resynchronisation silencieuse en
    // arrière-plan — aucune erreur affichée à l'utilisateur, ce n'est pas
    // une action qu'il a demandée.
    Future.wait([prefsFuture, purchaseInitFuture]).then((_) {
      if (!mounted) return;
      _purchaseService.silentlyReverifyEntitlement(
        currentlyPremium: _isPremium,
      );
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      debugPrint("[lifecycle] resumed");
      _drainSilentShareInbox();
      if (_prefsLoaded) _scheduleThumbnailRepair();
    }
  }

  Future<void> _loadPrefs() async {
    final p = await SharedPreferences.getInstance();
    final theme = p.getString('themeMode');
    final lang = p.getString('locale');
    if (!mounted) return;
    final onboarding = p.getBool('onboarding_done') ?? false;
    final premium = p.getBool('is_premium') ?? false;
    // Migration : si le compteur cumulatif n'existe pas encore (mise à
    // jour depuis une version antérieure à ce fix), on l'initialise avec
    // le nombre de clips actuellement présents, puis il ne fera plus
    // que croître.
    final storedLifetime = p.getInt('lifetime_clips_added');
    final lifetime = storedLifetime ?? widget.state.totalClipsCount;
    if (storedLifetime == null) {
      unawaited(p.setInt('lifetime_clips_added', lifetime));
    }
    final lastCountdownWarningShownAt =
        p.getInt('last_countdown_warning_shown_at') ?? 0;
    setState(() {
      _onboardingDone = onboarding;
      _isPremium = premium;
      _lifetimeClipsAdded = lifetime;
      _lastCountdownWarningShownAt = lastCountdownWarningShownAt;
      _prefsLoaded = true;
      if (theme != null) {
        _themeMode = ThemeMode.values.firstWhere(
          (m) => m.name == theme,
          orElse: () => ThemeMode.system,
        );
      }
      if (lang != null) {
        _locale = Locale(lang);
      } else {
        // Utilise la langue du téléphone, fr ou en uniquement
        final deviceLang =
            WidgetsBinding.instance.platformDispatcher.locale.languageCode;
        _locale = Locale(['fr', 'en'].contains(deviceLang) ? deviceLang : 'en');
      }
    });
    _drainPendingShare();
    _drainPendingPlaylist();
    _scheduleThumbnailRepair();
  }

  void _initDeepLinks() {
    if (kIsWeb) return;
    final appLinks = AppLinks();
    // Cold start : URI qui a lancé l'app
    appLinks.getInitialLink().then((uri) {
      debugPrint('[deeplink] getInitialLink: $uri');
      if (uri != null) _handleDeepLink(uri);
    });
    // App déjà en cours d'exécution
    _deepLinkSub = appLinks.uriLinkStream.listen((uri) {
      debugPrint('[deeplink] uriLinkStream: $uri');
      _handleDeepLink(uri);
    }, onError: (e) {
      debugPrint('[deeplink] uriLinkStream error: $e');
    });
  }

  Future<void> _handleDeepLink(Uri uri) async {
    debugPrint('[deeplink] _handleDeepLink scheme=${uri.scheme} host=${uri.host}');
    // Le lien de partage de playlist existe sous deux formes : le schéma
    // personnalisé reelr://playlist... et le lien https universel
    // (yyprdqp527-ui.github.io/reelr-support/playlist...) délivré
    // directement à l'app quand les Universal/App Links sont actifs — donc
    // testé avant le filtre "scheme == reelr" ci-dessous, qui ne concerne
    // que le reste des liens (ex. reelr://add). Le décodage peut nécessiter
    // un appel réseau (nouveau format court "code=..."), d'où l'attente ici.
    final isPlaylistLink = (uri.scheme == 'reelr' && uri.host == 'playlist') ||
        ((uri.scheme == 'https' || uri.scheme == 'http') &&
            uri.host == 'yyprdqp527-ui.github.io' &&
            uri.path.startsWith('/reelr-support/playlist'));
    if (isPlaylistLink) {
      final playlist = await PlaylistLink.tryDecodeAsync(uri);
      if (playlist != null) {
        debugPrint('[deeplink] playlist decode -> ${playlist.items.length} vidéos');
        _openPlaylistImportWhenReady(playlist);
      } else {
        debugPrint('[deeplink] playlist decode failed');
      }
      return;
    }
    if (uri.scheme != 'reelr') return;
    if (uri.host != 'add') return;
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
  PlaylistLink? _pendingPlaylist;
  final Set<String> _ingestingUrls = {};

  /// Met la playlist reçue en file d'attente et tente d'ouvrir l'écran
  /// d'aperçu/import si l'app est prête (mêmes garde-fous que pour un lien
  /// vidéo unique : prefs chargées + onboarding terminé).
  void _openPlaylistImportWhenReady(PlaylistLink playlist) {
    _pendingPlaylist = playlist;
    _drainPendingPlaylist();
  }

  void _drainPendingPlaylist() {
    debugPrint('[deeplink] _drainPendingPlaylist prefsLoaded=$_prefsLoaded onboardingDone=$_onboardingDone pending=${_pendingPlaylist != null}');
    if (!_prefsLoaded || !_onboardingDone) return;
    final playlist = _pendingPlaylist;
    if (playlist == null) return;
    _pendingPlaylist = null;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctx = _navigatorKey.currentContext;
      debugPrint('[deeplink] opening PlaylistImportScreen, ctx=${ctx != null}');
      if (ctx == null) {
        // Pas encore monté, on remet en file.
        _pendingPlaylist = playlist;
        return;
      }
      Navigator.of(ctx).push(MaterialPageRoute(
        builder: (_) => PlaylistImportScreen(
          state: widget.state,
          playlist: playlist,
          // Mode silencieux obligatoire : l'ecran importe en boucle.
          onImportUrl: (url) => _ingestSharedUrl(url, silent: true),
        ),
      ));
    });
  }

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
            content: Text(
              _locale.languageCode == 'fr'
                  ? (title != null && title.isNotEmpty
                        ? '"$title" est déjà dans votre liste.'
                        : 'Ce lien est déjà dans votre liste.')
                  : (title != null && title.isNotEmpty
                        ? '"$title" is already in your list.'
                        : 'This link is already in your list.'),
            ),
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
      _shareSub = ReceiveSharingIntent.instance.getMediaStream().listen((
        files,
      ) {
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

  static const int freeClipsLimit = 50;

  /// Enregistre un lien partagé. Renvoie `true` si un clip a été créé.
  ///
  /// [silent] supprime tout retour visuel — SnackBar d'URL sans contenu,
  /// écran Premium. Indispensable pour l'import de playlist, qui appelle
  /// cette méthode EN BOUCLE : sans lui, dix vidéos importées au-delà de
  /// la limite gratuite empilaient dix écrans Premium à fermer un par un,
  /// et chaque URL sans contenu ajoutait sa propre SnackBar. Signalé en
  /// test : « il faut valider plusieurs fois pour aller dans Reelr ».
  ///
  /// L'appelant en boucle est responsable d'afficher UN seul message à la
  /// fin, à partir du nombre de succès.
  Future<bool> _ingestSharedUrl(String url, {bool silent = false}) async {
    // Resout les liens courts connus (pin.it, Reddit /s/xxxx) vers leur
    // URL canonique avant la verification de doublon, pour que deux
    // liens courts differents pointant vers le meme contenu soient
    // reconnus comme le meme clip. L'URL d'origine `url` reste utilisee
    // partout ailleurs (stockage, plateforme, vignette) : seule la
    // verification de doublon utilise l'URL resolue.
    final parsedUrl = Uri.tryParse(url.trim());
    final dedupUrl = parsedUrl != null
        ? (await OEmbedService.resolveShortLinkForDedup(parsedUrl)).toString()
        : url;
    // Garde-fou : une URL sans contenu precis (page d'accueil, flux
    // « Pour toi », recherche...) ne doit ni creer de carte vide, ni
    // consommer une unite du quota gratuit a vie — ce compteur ne
    // redescend jamais, meme apres suppression du clip.
    if (OEmbedService.isContentlessUrl(dedupUrl)) {
      debugPrint('[ingest] URL sans contenu ignoree : $dedupUrl');
      if (!silent) _showContentlessUrlNotice();
      return false;
    }
    if (widget.state.isDuplicate(dedupUrl)) return false;
    if (!canAddClip(silent: silent)) return false;
    final normalized = ClipsState.normalizeUrlForDedup(dedupUrl);
    if (_ingestingUrls.contains(normalized)) return false;
    _ingestingUrls.add(normalized);
    try {
      final platform = SocialPlatform.detect(dedupUrl);
      final clip = Clip(
        id: const Uuid().v4(),
        url: dedupUrl,
        title: platform.name,
        platform: platform.id,
        categoryId: null,
        tags: const [],
        addedAt: DateTime.now(),
        thumbnailUrl: OEmbedService.bestThumbnailUrl(dedupUrl, null),
      );
      if (!await widget.state.addClip(clip)) return false;
      registerClipAdded();
      _enqueueHydration(clip);
      return true;
    } finally {
      _ingestingUrls.remove(normalized);
    }
  }

  /// Vrai si un clip supplémentaire peut être ajouté. Affiche le paywall
  /// et renvoie `false` sinon — sauf en mode [silent].
  ///
  /// Public et centralisé pour que TOUTES les voies d'ajout passent par
  /// là. Le formulaire manuel « + » ne le faisait pas : il appelait
  /// `addClip` directement, permettant de dépasser la limite gratuite.
  bool canAddClip({bool silent = false}) {
    if (_isPremium || _lifetimeClipsAdded < freeClipsLimit) return true;
    // En boucle (import de playlist), afficher le paywall a chaque
    // iteration empilerait autant d'ecrans que de videos refusees.
    if (!silent) showPaywall();
    return false;
  }

  /// Comptabilise un clip ajouté, quelle que soit la voie d'ajout, et
  /// affiche le countdown préventif.
  ///
  /// Countdown : à 3, 2 puis 1 vidéo(s) restante(s) avant la limite
  /// gratuite (47, 48, 49 sur 50), une fois par palier. Les vidéos
  /// supprimées comptent quand même (`_lifetimeClipsAdded` ne redescend
  /// jamais) — le message le précise pour éviter toute confusion avec le
  /// compteur visible.
  void registerClipAdded() {
    _lifetimeClipsAdded++;
    unawaited(
      SharedPreferences.getInstance()
          .then((p) => p.setInt('lifetime_clips_added', _lifetimeClipsAdded)),
    );
    if (_isPremium ||
        _lifetimeClipsAdded < freeClipsLimit - 3 ||
        _lifetimeClipsAdded >= freeClipsLimit ||
        _lifetimeClipsAdded <= _lastCountdownWarningShownAt) {
      return;
    }
    _lastCountdownWarningShownAt = _lifetimeClipsAdded;
    unawaited(
      SharedPreferences.getInstance().then(
        (p) => p.setInt(
          'last_countdown_warning_shown_at',
          _lastCountdownWarningShownAt,
        ),
      ),
    );
    final remaining = freeClipsLimit - _lifetimeClipsAdded;
    final ctx = _navigatorKey.currentContext;
    if (ctx == null || !ctx.mounted) return;
    ScaffoldMessenger.of(ctx).showSnackBar(
      SnackBar(
        content: Text(
          _locale.languageCode == 'fr'
              ? (remaining == 1
                  ? "Plus qu'une vidéo avant la limite gratuite (même les vidéos supprimées comptent) — passe à Premium pour continuer sans limite."
                  : 'Plus que $remaining vidéos avant la limite gratuite (même les vidéos supprimées comptent) — passe à Premium pour continuer sans limite.')
              : (remaining == 1
                  ? 'Only 1 video left before the free limit (deleted videos still count) — upgrade to Premium to keep going without limits.'
                  : 'Only $remaining videos left before the free limit (deleted videos still count) — upgrade to Premium to keep going without limits.'),
        ),
        duration: const Duration(seconds: 6),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  /// Explique pourquoi un partage n'a rien produit, plutôt que d'échouer
  /// en silence : sans message, l'utilisateur croit que l'app est cassée.
  void _showContentlessUrlNotice({int attempt = 0}) {
    final ctx = _navigatorKey.currentContext;
    if (ctx == null || !ctx.mounted) {
      // Au demarrage a froid, la file de partages est vidée avant que le
      // Navigator ne soit construit : sans ce report, le message ne
      // s'afficherait jamais et l'utilisateur croirait son partage perdu
      // sans savoir pourquoi. On retente brievement, puis on renonce.
      if (attempt >= 3) {
        debugPrint('[ingest] notice non affichable (pas de contexte)');
        return;
      }
      Future<void>.delayed(const Duration(milliseconds: 600), () {
        if (mounted) _showContentlessUrlNotice(attempt: attempt + 1);
      });
      return;
    }
    ScaffoldMessenger.of(ctx).showSnackBar(
      SnackBar(
        content: Text(
          _locale.languageCode == 'fr'
              ? "Ce lien ne pointe pas vers une vidéo précise — ouvre la vidéo, puis partage-la depuis son écran."
              : "This link doesn't point to a specific video — open the video first, then share it from there.",
        ),
        duration: const Duration(seconds: 5),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  /// Ouvre l'écran d'abonnement Premium. Accessible depuis le flux de
  /// limite gratuite (_ingestSharedUrl) et directement depuis les Réglages,
  /// pour que l'achat ne soit pas caché derrière la limite de 50 clips
  /// (cf. rejet Apple 2.1(b) — IAP introuvable par le reviewer).
  void showPaywall() {
    final navigator = _navigatorKey.currentState;
    if (navigator == null) return;
    // Un seul paywall a la fois : deux ecrans identiques empiles obligeaient
    // a fermer deux fois.
    final existing = _paywallRoute;
    if (existing != null && existing.isActive) return;

    final route = MaterialPageRoute<void>(
      builder: (_) => PaywallScreen(
        priceText: _purchaseService.premiumProduct?.price,
        isLoading:
            !_purchaseServiceReady || _purchaseService.premiumProduct == null,
        // On attend l'etat terminal cote StoreKit (achete, annule, erreur)
        // avant de rendre la main : le paywall garde son indicateur pendant
        // toute la preparation de la feuille de paiement, au lieu de rester
        // visuellement inerte.
        onUpgrade: () async {
          final started = await _purchaseService.buyPremium();
          if (started) {
            await _purchaseService.waitUntilSettled();
          }
        },
        onRestore: () async {
          await _purchaseService.restorePurchases();
          await _purchaseService.waitUntilSettled(
            timeout: const Duration(seconds: 10),
          );
          if (!mounted || _isPremium) return;
          final ctx = _navigatorKey.currentContext;
          // Le lint exige que le garde-fou porte sur le BuildContext
          // reellement utilise, pas sur le State qui l'a recupere.
          if (ctx == null || !ctx.mounted) return;
          ScaffoldMessenger.of(ctx).showSnackBar(
            SnackBar(
              content: Text(
                _locale.languageCode == 'fr'
                    ? 'Aucun abonnement à restaurer sur ce compte Apple.'
                    : 'No subscription to restore on this Apple account.',
              ),
            ),
          );
        },
        onClose: () => _navigatorKey.currentState?.pop(),
      ),
    );
    _paywallRoute = route;
    navigator.push(route).whenComplete(() {
      if (identical(_paywallRoute, route)) _paywallRoute = null;
    });
  }

  /// Retire le paywall des qu'un achat aboutit. Sans ca, l'utilisateur
  /// payait, la feuille App Store se fermait, et il retombait sur le meme
  /// ecran « Passer a Premium » inchange — donnant l'impression que rien ne
  /// s'etait passe, avec le risque d'un second achat.
  void _dismissPaywallIfOpen() {
    final route = _paywallRoute;
    if (route == null || !route.isActive) return;
    _paywallRoute = null;
    _navigatorKey.currentState?.removeRoute(route);
  }

  /// Expose l'achat premium pour les écrans (Paywall, Settings).
  Future<bool> buyPremium() => _purchaseService.buyPremium();

  /// Expose la restauration d'achats pour les écrans (Settings).
  Future<void> restorePurchases() => _purchaseService.restorePurchases();

  Future<void> _drainSilentShareInbox() async {
    try {
      debugPrint('[drain] calling drainPendingUrls...');
      final dynamic raw = await _silentShareInboxChannel.invokeMethod(
        'drainPendingUrls',
      );
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
    } catch (e) {
      debugPrint('[drain] error: $e');
    }
  }

  bool _isValidHttpUrl(String url) {
    final uri = Uri.tryParse(url.trim());
    return uri != null &&
        (uri.scheme == 'http' || uri.scheme == 'https') &&
        uri.host.isNotEmpty;
  }

  // ─────────────────────────────────────────────
  // FILE D'ATTENTE DES EXTRACTIONS
  // ─────────────────────────────────────────────

  /// Extractions simultanees au maximum.
  ///
  /// Un utilisateur qui partage quinze videos depuis TikTok sans ouvrir
  /// Reelr les retrouve toutes dans la boite de partage a la prochaine
  /// ouverture. Sans file, quinze extractions partaient en meme temps :
  /// TikTok et Instagram repondaient par des pages anti-bot, et les clips
  /// restaient sans vignette. Un partage isole n'attend pas : la file est
  /// vide, il demarre aussitot.
  static const int _maxConcurrentHydrations = 2;

  /// Pause apres chaque extraction, avant de liberer sa place.
  static const Duration _hydrationSpacing = Duration(milliseconds: 800);

  final List<Clip> _hydrationQueue = [];

  /// Clips dont l'extraction est en attente ou en cours (file ou
  /// reparation). La reparation les ignore pour ne pas les doubler.
  final Set<String> _hydratingClipIds = {};

  int _activeHydrations = 0;

  void _enqueueHydration(Clip clip) {
    if (!_hydratingClipIds.add(clip.id)) return;
    _hydrationQueue.add(clip);
    _pumpHydrationQueue();
  }

  void _pumpHydrationQueue() {
    while (_activeHydrations < _maxConcurrentHydrations &&
        _hydrationQueue.isNotEmpty) {
      final queued = _hydrationQueue.removeAt(0);
      _activeHydrations++;
      unawaited(_runQueuedHydration(queued));
    }
  }

  Future<void> _runQueuedHydration(Clip queued) async {
    try {
      // Relu dans l'etat : le clip a pu etre modifie ou supprime pendant
      // son attente dans la file.
      final current =
          widget.state.allClips.where((c) => c.id == queued.id).firstOrNull;
      // La place dans la file n'est tenue que pendant l'EXTRACTION
      // (requetes vers les plateformes, la ou la rafale declenche
      // l'anti-bot). La classification continue ensuite hors file : elle
      // a son propre limiteur (_ClassifyLimiter). Avant, chaque place
      // restait prise ~3,5 s de plus pendant l'appel a Claude, et le
      // lot suivant attendait pour rien.
      if (current != null && mounted) {
        final hydrated = Completer<void>();
        unawaited(
          _hydrateAndClassify(current, hydrated: hydrated)
              .catchError((Object e) {
            debugPrint('[hydrate] erreur (${current.id}): $e');
          }).whenComplete(() {
            if (!hydrated.isCompleted) hydrated.complete();
          }),
        );
        await hydrated.future;
      }
    } catch (e) {
      debugPrint('[hydrate] erreur dans la file (${queued.id}): $e');
    } finally {
      await Future<void>.delayed(_hydrationSpacing);
      _activeHydrations--;
      _hydratingClipIds.remove(queued.id);
      if (mounted) _pumpHydrationQueue();
    }
  }

  Future<void> _hydrateAndClassify(
    Clip clip, {
    Completer<void>? hydrated,
  }) async {
    final hasRealTitle = await _hydrateClip(clip);
    // Extraction terminee : la file d'attente peut lancer la suivante.
    if (hydrated != null && !hydrated.isCompleted) hydrated.complete();
    final updated =
        widget.state.allClips.where((c) => c.id == clip.id).firstOrNull ?? clip;
    // Ne pas payer un appel de classification pour rien : quand
    // l'extraction a echoue, le clip ne porte que le nom de la
    // plateforme (« TikTok »). Observe en production, le classifieur
    // repondait « À trier, confiance 5 » — resultat previsible, facture
    // reelle. Le clip reste simplement a trier manuellement.
    final hasDescription = updated.description?.trim().isNotEmpty ?? false;
    // Le createur est un signal a part entiere : `classifyClipInBackground`
    // commence par un `detectStrongMatch` local et gratuit qui reconnait
    // les medias d'actualite, influenceurs et marques connus a partir de
    // la chaine, et le prompt envoye a Claude contient « Chaîne: ... ».
    // La premiere version de ce garde-fou coupait les deux : une video
    // sans legende publiee par un media connu n'etait plus classee, alors
    // qu'une regle deterministe sans appel API l'aurait attrapee.
    //
    // On ecarte en revanche les faux createurs : hors TikTok, `channel`
    // vaut `og:site_name`, donc « Twitch », « Pinterest », « LinkedIn ».
    // `isPlaceholderTitle` les reconnait deja.
    final channel = updated.channel?.trim() ?? '';
    final hasUsableChannel =
        channel.isNotEmpty && !OEmbedService.isPlaceholderTitle(channel);
    if (!hasRealTitle && !hasDescription && !hasUsableChannel) {
      debugPrint(
        '[classify] ignore (aucun signal exploitable): "${updated.title}"',
      );
      return;
    }
    await widget.state.classifyClipInBackground(updated);
  }

  /// Catégorie ACTUELLE du clip, relue dans l'état plutôt que prise dans
  /// l'instantané reçu en paramètre.
  ///
  /// `_hydrateClip` réécrit le clip entier à la fin de son extraction, à
  /// partir de l'objet qu'on lui a passé. Si une classification s'est
  /// terminée entre-temps, cet objet est périmé et sa catégorie vide
  /// écrase celle qui vient d'être attribuée.
  ///
  /// Le cas se produit vraiment : la passe de réparation démarre 4 s
  /// après le lancement et traite les clips un par un avec des pauses,
  /// donc elle peut ré-extraire un clip pendant que Claude le classe.
  /// Observé en production — une catégorie « Luxe » créée, prédiction
  /// `cat_luxe` à 65 de confiance enregistrée dans le journal, et le clip
  /// resté sans catégorie.
  ///
  /// L'hydratation n'a de toute façon aucune raison de modifier la
  /// catégorie : elle ne s'occupe que du titre, de la vignette, de la
  /// chaîne et de la description.
  String? _currentCategoryIdOf(Clip clip) {
    for (final c in widget.state.allClips) {
      if (c.id == clip.id) return c.categoryId;
    }
    return clip.categoryId;
  }

  /// Renseigne titre, vignette, chaine et description d'un clip.
  ///
  /// Renvoie `true` si un VRAI titre a ete extrait. Un titre de repli
  /// (nom du createur, nom de plateforme) ne compte pas : c'est cette
  /// distinction qui permet a `_hydrateAndClassify` de ne pas payer une
  /// classification sur un signal qui n'en est pas un.
  /// Complete les metadonnees avec l'apercu de lien natif d'iOS
  /// (LinkPresentation, le moteur des apercus d'iMessage) quand
  /// l'extraction n'a trouve ni vignette ni vrai titre.
  ///
  /// Cas vises : Reddit (page anti-bot : titre « Reddit », aucune image)
  /// et les pages de vente / publicites dont l'image n'est pas lisible par
  /// une simple requete HTTP. L'image est ecrite directement dans le
  /// stockage permanent ; le clip recoit l'URL interne `reelr-local://<id>`.
  Future<VideoData?> _completeWithLinkPreview(
    Clip clip,
    VideoData? meta,
  ) async {
    final currentThumb = meta?.thumbnailUrl;
    final hasThumb = currentThumb != null && currentThumb.isNotEmpty;
    final metaTitle = meta?.title ?? '';
    final hasTitle = !OEmbedService.isPlaceholderTitle(metaTitle);
    if (hasThumb && hasTitle) return meta;

    final preview = await LinkPreviewService.fetch(clip.url);
    if (preview == null) return meta;

    var thumbnailUrl = currentThumb;
    final image = preview.image;
    if (!hasThumb && image != null) {
      // iOS : image deja telechargee, enregistree directement.
      if (await ThumbnailStore.instance.saveBytes(clip.id, image)) {
        thumbnailUrl = ThumbnailStore.localUrlFor(clip.id);
        debugPrint('[linkpreview] vignette enregistree: ${clip.url}');
      }
    } else if (!hasThumb && preview.imageUrl != null) {
      // Android : adresse de l'image ; le pre-cache de _hydrateClip la
      // telecharge et la copie dans le stockage permanent.
      thumbnailUrl = preview.imageUrl;
      debugPrint('[linkpreview] vignette trouvee: ${preview.imageUrl}');
    }
    final previewTitle = preview.title?.trim() ?? '';
    final String title;
    if (hasTitle) {
      title = metaTitle;
    } else if (!OEmbedService.isPlaceholderTitle(previewTitle)) {
      title = previewTitle;
    } else {
      title = metaTitle;
    }
    if (thumbnailUrl == currentThumb && title == metaTitle) {
      return meta;
    }
    return VideoData(
      title: title,
      channel: meta?.channel,
      description: meta?.description,
      tags: meta?.tags ?? const [],
      views: meta?.views,
      duration: meta?.duration,
      publishedAt: meta?.publishedAt,
      platform: meta?.platform ?? clip.platform,
      thumbnailUrl: thumbnailUrl,
      transcriptExcerpt: meta?.transcriptExcerpt,
    );
  }

  /// Dernier recours pour un lien web (plateforme 'other') reste sans
  /// vignette apres tous les essais : capture d'ecran de la page par le
  /// Worker. Les videos des plateformes connues ne sont pas concernees,
  /// ni les liens dont aucune metadonnee n'a pu etre lue (meta == null).
  VideoData? _completeWithScreenshot(Clip clip, VideoData? meta) {
    if (meta == null || clip.platform != 'other') return meta;
    final thumb = meta.thumbnailUrl;
    if (thumb != null && thumb.isNotEmpty) return meta;
    debugPrint('[screenshot] capture demandee pour: ${clip.url}');
    return VideoData(
      title: meta.title,
      channel: meta.channel,
      description: meta.description,
      tags: meta.tags,
      views: meta.views,
      duration: meta.duration,
      publishedAt: meta.publishedAt,
      platform: meta.platform,
      thumbnailUrl: OEmbedService.screenshotUrlFor(clip.url),
      transcriptExcerpt: meta.transcriptExcerpt,
    );
  }

  /// Page de resultats Google (google.fr/search?q=...) : le titre lu vaut
  /// « Google Search », sans la requete, et Claude classait au hasard
  /// (Yoann Gourcuff en Tech, « walibi » laisse a trier). Le titre
  /// devient la requete elle-meme.
  VideoData? _withSearchQueryTitle(Clip clip, VideoData? meta) {
    if (meta == null) return meta;
    final uri = Uri.tryParse(clip.url);
    if (uri == null || uri.path != '/search') return meta;
    final host = uri.host.toLowerCase();
    if (!RegExp(r'(^|\.)google\.[a-z.]+$').hasMatch(host)) return meta;
    final query = uri.queryParameters['q']?.trim() ?? '';
    if (query.isEmpty) return meta;
    debugPrint('[hydrate] recherche Google, titre = requete: $query');
    return VideoData(
      title: query,
      channel: meta.channel,
      description: meta.description,
      tags: meta.tags,
      views: meta.views,
      duration: meta.duration,
      publishedAt: meta.publishedAt,
      platform: meta.platform,
      thumbnailUrl: meta.thumbnailUrl,
      transcriptExcerpt: meta.transcriptExcerpt,
    );
  }

  /// Lien web dont la page n'a rien renvoye, meme a l'apercu natif (site
  /// anti-robot, ex. fiche produit Fnac) : le titre est tire de l'adresse.
  /// Le clip a alors un nom, Claude a de quoi le classer, et la capture
  /// d'ecran est tentee pour la vignette. Les videos des plateformes
  /// connues ne sont pas concernees.
  VideoData? _completeWithUrlTitle(Clip clip, VideoData? meta) {
    if (meta != null || clip.platform != 'other') return meta;
    final title = OEmbedService.titleFromUrlPath(clip.url);
    if (title == null) return null;
    debugPrint('[hydrate] aucune metadonnee, titre tire de l\'adresse : $title');
    return VideoData(title: title, platform: clip.platform);
  }

  Future<bool> _hydrateClip(Clip clip) async {
    debugPrint('[hydrate] ${DateTime.now()} starting for: ${clip.url}');
    final rawMeta = _completeWithScreenshot(
      clip,
      _completeWithUrlTitle(
        clip,
        await _completeWithLinkPreview(
          clip,
          await OEmbedService.fetchMetadata(clip.url),
        ),
      ),
    );
    final meta = _withSearchQueryTitle(clip, rawMeta);
    if (meta == null) {
      // Cette sortie etait muette : un `starting for` sans `done`, et rien
      // pour dire pourquoi. C'est ce silence qui rendait les diagnostics
      // interminables — impossible de distinguer une extraction qui a
      // echoue d'une extraction qui n'a jamais rendu la main.
      debugPrint('[hydrate] ECHEC TOTAL, aucune metadonnee : ${clip.url}');
      return false;
    }
    debugPrint('[hydrate] ${DateTime.now()} done url=${clip.url}');
    debugPrint(
      '[hydrate] title=${meta.title} thumb=${meta.thumbnailUrl ?? "NULL"}',
    );
    debugPrint('[hydrate] channel: ${meta.channel}');
    // Un titre de coquille JS (« TikTok - Make Your Day ») vaut un titre
    // absent : l'ecrire ecraserait le vrai titre du clip et declencherait
    // une classification sur une chaine sans contenu.
    final rawTitle = meta.title.trim();
    final title = OEmbedService.isPlaceholderTitle(rawTitle) ? '' : rawTitle;
    if (title.isEmpty && rawTitle.isNotEmpty) {
      debugPrint('[hydrate] titre de coquille ignore: "$rawTitle"');
    }
    // Titre de repli quand la video n'a pas de legende : le nom du
    // createur est bien plus parlant que « TikTok » sur une carte, et
    // c'est frequent (TikTok renvoie regulierement un titre vide avec
    // une vignette valide). On ne remplace jamais un vrai titre.
    final channel = (meta.channel ?? clip.channel)?.trim();
    final fallbackTitle =
        (channel != null &&
                channel.isNotEmpty &&
                OEmbedService.isPlaceholderTitle(clip.title))
            ? channel
            : clip.title;
    final thumbnailUrl = meta.thumbnailUrl;
    if (title.isEmpty && (thumbnailUrl == null || thumbnailUrl.isEmpty)) {
      if (clip.title.isNotEmpty) return false;
      final platform =
          clip.platform[0].toUpperCase() + clip.platform.substring(1);
      await widget.state.updateClip(
        Clip(
          id: clip.id,
          url: clip.url,
          title: platform,
          platform: clip.platform,
          categoryId: _currentCategoryIdOf(clip),
          tags: clip.tags,
          addedAt: clip.addedAt,
          thumbnailUrl: clip.thumbnailUrl,
          position: clip.position,
          channel: meta.channel ?? clip.channel,
          description: meta.description ?? clip.description,
        ),
      );
      return false;
    }
    final resolvedThumbnailUrl = (thumbnailUrl == null || thumbnailUrl.isEmpty)
        ? clip.thumbnailUrl
        : thumbnailUrl;
    // Le pre-cache doit viser EXACTEMENT l'URL que l'affichage
    // reclamera (cf. bestThumbnailUrl, qui proxifie Facebook / Reddit /
    // Pinterest). Pre-telecharger l'URL brute produirait une cle de
    // cache differente de celle lue a l'affichage : le fichier ne
    // serait jamais retrouve et le pre-cache serait inutile.
    final effectiveThumbnailUrl =
        OEmbedService.bestThumbnailUrl(clip.url, resolvedThumbnailUrl);
    if (effectiveThumbnailUrl != null && effectiveThumbnailUrl.isNotEmpty) {
      unawaited(_precacheThumbnail(effectiveThumbnailUrl, clipId: clip.id));
    }
    await widget.state.updateClip(
      Clip(
        id: clip.id,
        url: clip.url,
        title: title.isEmpty ? fallbackTitle : title,
        platform: clip.platform,
        categoryId: _currentCategoryIdOf(clip),
        tags: clip.tags,
        addedAt: clip.addedAt,
        thumbnailUrl: resolvedThumbnailUrl,
        position: clip.position,
        channel: meta.channel ?? clip.channel,
        description: meta.description ?? clip.description,
      ),
    );
    if (title.isEmpty && fallbackTitle != clip.title) {
      debugPrint('[hydrate] titre de repli = createur: "$fallbackTitle"');
    }
    return title.isNotEmpty;
  }

  /// Délais entre deux tentatives de pré-cache. La fenêtre totale (~10 s)
  /// est volontairement courte : les jetons CDN sont signés et il ne sert
  /// à rien d'insister longtemps sur une URL qui va expirer.
  static const List<Duration> _precacheRetryDelays = [
    Duration(seconds: 2),
    Duration(seconds: 8),
  ];

  /// Télécharge la vignette en arrière-plan pour la mettre en cache disque
  /// immédiatement après le partage, pendant que l'URL est encore fraîche
  /// (jetons CDN à courte durée de vie sur Facebook/Instagram/TikTok/etc.).
  ///
  /// Réessaie jusqu'à 3 fois : une seule tentative signifiait qu'une
  /// coupure réseau passagère au moment du partage condamnait la vignette
  /// définitivement. Passé ~24 h le jeton CDN est mort et plus aucune
  /// tentative ne peut aboutir — d'où la fenêtre courte.
  ///
  /// Échec final silencieux : ResilientThumbnail retentera au réseau à
  /// l'affichage, et retombera sur le logo de plateforme si besoin.
  ///
  /// Si [clipId] est fourni, l'image est aussi copiee dans le stockage
  /// permanent (ThumbnailStore) : c'est cette copie, et non le cache
  /// purgeable, qui garantit que la carte gardera sa miniature une fois
  /// l'URL signee expiree.
  ///
  /// Renvoie `true` si l'image a ete telechargee (et, avec [clipId],
  /// conservee dans le stockage permanent). [retry] a false pour un essai
  /// unique, utilise par la reparation qui sait re-extraire en cas d'echec.
  Future<bool> _precacheThumbnail(
    String url, {
    String? clipId,
    bool retry = true,
  }) async {
    // URL interne : l'image est deja (ou n'est plus) dans le stockage
    // permanent, il n'y a rien a telecharger.
    if (ThumbnailStore.isLocalUrl(url)) {
      return clipId != null && await ThumbnailStore.instance.has(clipId);
    }
    final host = Uri.tryParse(url)?.host ?? url;
    final delays = retry ? _precacheRetryDelays : const <Duration>[];
    for (var attempt = 0; ; attempt++) {
      try {
        final info = await ThumbnailCache.instance.downloadFile(
          url,
          authHeaders: ThumbnailCache.headersFor(url),
        );
        debugPrint('[precache] vignette mise en cache: $host');
        if (clipId != null) {
          final saved =
              await ThumbnailStore.instance.saveFromFile(clipId, info.file);
          debugPrint(
            '[precache] copie permanente ${saved ? "ok" : "refusee"}: $host',
          );
          return saved;
        }
        return true;
      } catch (e) {
        if (attempt >= delays.length) {
          debugPrint(
            '[precache] échec définitif ($host) après ${attempt + 1} '
            'tentative(s): $e',
          );
          return false;
        }
        debugPrint(
          '[precache] tentative ${attempt + 1} échouée ($host), '
          'nouvel essai dans ${delays[attempt].inSeconds}s: $e',
        );
        await Future<void>.delayed(delays[attempt]);
        if (!mounted) return false;
      }
    }
  }

  // ─────────────────────────────────────────────
  // REPARATION DES VIGNETTES MANQUANTES
  // ─────────────────────────────────────────────

  /// Clips traites au maximum par lancement.
  ///
  /// Historique, pour ne pas refaire le raisonnement a l'envers : ce
  /// plafond avait ete abaisse a 5 en soupconnant une limitation de debit
  /// cote TikTok, apres une passe ou 7 reparations enchainees avaient
  /// toutes echoue. C'etait un diagnostic errone. La vraie cause etait
  /// un bug local — `_fetchTikTokMetadata` jetait la vignette des que le
  /// titre etait vide. Corrige, la meme passe est passee a 5 succes sur
  /// 5. Le rythme n'a jamais ete en cause.
  static const int _thumbnailRepairBatchSize = 12;

  /// Plafond global de clips examines par passe. Plus large que celui des
  /// re-extractions : la plupart des reparations ne sont qu'un simple
  /// telechargement, rapide et sans risque anti-bot.
  static const int _thumbnailRepairMaxPerPass = 60;

  /// Pause entre deux reparations : simple politesse reseau, pas une
  /// protection contre une limitation de debit (cf. ci-dessus).
  static const Duration _thumbnailRepairSpacing = Duration(seconds: 2);

  /// Nombre de tentatives rapprochees (une par lancement). Au-dela, un
  /// clip n'est plus abandonne : il est retente de plus en plus rarement
  /// (cf. `_thumbnailRepairBackoff`). L'ancien plafond definitif
  /// condamnait a vie au logo generique un clip qui avait echoue trois
  /// fois de suite, par exemple pendant une coupure reseau ou un blocage
  /// passager de la plateforme.
  static const int _thumbnailRepairMaxAttempts = 3;

  /// Delai minimal entre deux tentatives une fois les tentatives
  /// rapprochees epuisees : 1 jour, puis 7 jours, puis 30 jours
  /// indefiniment. Au pire une extraction par mois et par clip
  /// inextricable (Reddit...), ce qui reste negligeable.
  static const List<Duration> _thumbnailRepairBackoff = [
    Duration(days: 1),
    Duration(days: 7),
    Duration(days: 30),
  ];

  static const String _thumbnailRepairPrefsKey = 'thumbnail_repair_attempts';

  /// Horodatage (ms) de la derniere tentative, par clip.
  static const String _thumbnailRepairLastPrefsKey = 'thumbnail_repair_last';

  bool _isRepairDue(
    String clipId,
    Map<String, int> attempts,
    Map<String, int> lastAttempts,
    DateTime now,
  ) {
    final count = attempts[clipId] ?? 0;
    if (count < _thumbnailRepairMaxAttempts) return true;
    final over = count - _thumbnailRepairMaxAttempts;
    final delay = over < _thumbnailRepairBackoff.length
        ? _thumbnailRepairBackoff[over]
        : _thumbnailRepairBackoff.last;
    // Clips deja au plafond avant cette version : pas d'horodatage, donc
    // epoch 0, donc immediatement eligibles. C'est voulu : ils avaient ete
    // abandonnes a tort.
    final last = DateTime.fromMillisecondsSinceEpoch(lastAttempts[clipId] ?? 0);
    return now.difference(last) >= delay;
  }

  /// Delai avant de lancer la passe : laisse le premier rendu et le
  /// chargement des clips se terminer sans concurrence reseau.
  static const Duration _thumbnailRepairStartDelay = Duration(seconds: 4);

  /// Intervalle minimal entre deux passes. La passe tournait une seule
  /// fois par demarrage a froid : une app simplement remise au premier
  /// plan (le cas le plus courant sur iPhone) ne reparait jamais rien.
  static const Duration _thumbnailRepairMinInterval = Duration(minutes: 15);

  bool _thumbnailRepairRunning = false;
  DateTime? _lastThumbnailRepairAt;

  /// Lance une passe au demarrage et a chaque retour au premier plan,
  /// au plus toutes les 15 minutes, jamais deux a la fois.
  void _scheduleThumbnailRepair() {
    if (_thumbnailRepairRunning) return;
    final last = _lastThumbnailRepairAt;
    final now = DateTime.now();
    if (last != null && now.difference(last) < _thumbnailRepairMinInterval) {
      return;
    }
    _thumbnailRepairRunning = true;
    _lastThumbnailRepairAt = now;
    Future<void>.delayed(_thumbnailRepairStartDelay, () async {
      try {
        if (!mounted) return;
        await _purgeContentlessClips();
        if (!mounted) return;
        await _repairMissingThumbnails();
      } catch (e) {
        debugPrint('[repair] passe interrompue: $e');
      } finally {
        _thumbnailRepairRunning = false;
      }
    });
  }

  static const String _contentlessPurgeDoneKey = 'contentless_clips_purged_v1';

  /// Migration unique : supprime les clips enregistres avant le garde-fou
  /// d'ingestion et qui ne pointent vers aucun contenu (`tiktok.com/foryou`,
  /// `tiktok.com/fr/`, pages d'accueil...), puis rend au compteur a vie les
  /// unites qu'ils avaient consommees.
  ///
  /// C'est le seul endroit ou `_lifetimeClipsAdded` diminue, et c'est
  /// justifie : ces clips n'auraient jamais du etre comptes. Le compteur
  /// est plancherne a zero, et on ne rend jamais plus que ce qui a ete
  /// effectivement supprime — un utilisateur ne peut donc pas s'en servir
  /// pour regagner du quota.
  ///
  /// Ne s'execute qu'une fois par installation.
  Future<void> _purgeContentlessClips() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(_contentlessPurgeDoneKey) ?? false) return;
    if (!mounted) return;

    final doomed = widget.state.allClips
        .where((c) => OEmbedService.isContentlessUrl(c.url))
        .toList();
    if (doomed.isEmpty) {
      await prefs.setBool(_contentlessPurgeDoneKey, true);
      return;
    }

    for (final clip in doomed) {
      debugPrint('[purge] carte vide supprimee : ${clip.url}');
      await widget.state.removeClip(clip.id);
      if (!mounted) return;
    }

    _lifetimeClipsAdded =
        (_lifetimeClipsAdded - doomed.length).clamp(0, _lifetimeClipsAdded);
    await prefs.setInt('lifetime_clips_added', _lifetimeClipsAdded);
    await prefs.setBool(_contentlessPurgeDoneKey, true);
    debugPrint(
      '[purge] ${doomed.length} carte(s) vide(s) supprimee(s), '
      'compteur a vie ramene a $_lifetimeClipsAdded',
    );
    if (mounted) setState(() {});
  }

  /// Retente l'extraction des clips enregistres sans vignette.
  ///
  /// `_hydrateClip` n'etait appele qu'au moment du partage : un clip
  /// ajoute pendant une coupure reseau, ou avant que la resolution des
  /// liens courts n'existe, restait sans vignette pour toujours. Cette
  /// passe repare l'existant.
  ///
  /// Deux precautions par rapport a une simple re-extraction :
  ///   - l'URL est d'abord re-resolue (pin.it, share.google, wrapper
  ///     TikTok...), sinon une URL non resolue echouerait exactement
  ///     comme la premiere fois ;
  ///   - chaque tentative est comptee et persistee AVANT d'etre jouee,
  ///     pour qu'un crash en cours de route ne produise pas une boucle
  ///     de re-tentatives a chaque lancement.
  Future<void> _repairMissingThumbnails() async {
    if (!_onboardingDone) return;
    final prefs = await SharedPreferences.getInstance();
    final attempts = _readRepairAttempts(prefs);
    final lastAttempts =
        _readRepairAttempts(prefs, key: _thumbnailRepairLastPrefsKey);

    // Menage du stockage permanent : fichiers de clips supprimes et
    // ecritures interrompues. Jamais sur une liste vide, qui peut
    // signifier une base pas (ou mal) chargee et non « aucun clip ».
    final liveIds = widget.state.allClips.map((c) => c.id).toSet();
    if (liveIds.isNotEmpty) {
      final removed = await ThumbnailStore.instance.pruneOrphans(liveIds);
      if (removed > 0) {
        debugPrint('[thumbstore] $removed fichier(s) orphelin(s) supprime(s)');
      }
    }
    if (!mounted) return;

    final needing = await _clipsNeedingRepair();
    if (!mounted) return;

    final now = DateTime.now();
    final candidates = needing
        .where((c) => _isRepairDue(c.id, attempts, lastAttempts, now))
        .toList()
      // Les clips les plus recents d'abord : ce sont ceux que
      // l'utilisateur regarde, et ceux dont les jetons CDN ont encore
      // une chance d'etre valides.
      ..sort((a, b) => b.addedAt.compareTo(a.addedAt));

    if (candidates.isEmpty) {
      // Rien a reparer : on purge les compteurs devenus inutiles.
      if (attempts.isNotEmpty) await _pruneRepairAttempts(prefs, attempts);
      return;
    }

    final batch = candidates.take(_thumbnailRepairMaxPerPass).toList();
    debugPrint(
      '[repair] ${candidates.length} clip(s) a reparer, '
      'jusqu\'a ${batch.length} examine(s) sur cette passe',
    );

    var extractions = 0;
    for (final clip in batch) {
      if (!mounted) return;
      if (extractions >= _thumbnailRepairBatchSize) break;
      if (_hydratingClipIds.contains(clip.id)) continue;
      attempts[clip.id] = (attempts[clip.id] ?? 0) + 1;
      lastAttempts[clip.id] = DateTime.now().millisecondsSinceEpoch;
      await prefs.setString(_thumbnailRepairPrefsKey, jsonEncode(attempts));
      await prefs.setString(
          _thumbnailRepairLastPrefsKey, jsonEncode(lastAttempts));
      var extracted = true;
      _hydratingClipIds.add(clip.id);
      try {
        extracted = await _repairOneThumbnail(clip);
      } catch (e) {
        debugPrint('[repair] echec ${clip.id}: $e');
      } finally {
        _hydratingClipIds.remove(clip.id);
      }
      if (!mounted) return;
      if (extracted) {
        extractions++;
        // Respiration entre deux extractions : evite la rafale de
        // requetes qui faisait basculer TikTok en mode anti-bot.
        await Future<void>.delayed(_thumbnailRepairSpacing);
      }
    }

    if (!mounted) return;
    await _pruneRepairAttempts(prefs, attempts);
  }

  /// Delai de grace avant de juger une vignette manquante. Court depuis
  /// que les extractions en cours sont suivies (`_hydratingClipIds`) et
  /// que la reparation commence par un simple telechargement : une heure
  /// laissait mourir l'URL des clips dont le pre-cache avait ete
  /// interrompu par une mise en arriere-plan.
  static const Duration _deadThumbnailGracePeriod = Duration(minutes: 2);

  /// Tous les clips qui meritent une re-extraction : ceux sans vignette,
  /// et ceux dont la vignette est morte.
  ///
  /// Les URLs sans contenu precis (tiktok.com/foryou, /fr/... enregistres
  /// avant le garde-fou d'ingestion) sont exclues : aucune extraction ne
  /// les reparera et elles gaspillaient des creneaux — observe en
  /// production, 3 sur 8 lors de la premiere passe.
  Future<List<Clip>> _clipsNeedingRepair() async {
    final seen = <String>{};
    final result = <Clip>[];
    final now = DateTime.now();
    void add(Clip c) {
      if (OEmbedService.isContentlessUrl(c.url)) return;
      // Extraction deja en cours (partage tout juste recu) : ne pas la
      // doubler ni consommer une tentative de reparation pour rien.
      if (_hydratingClipIds.contains(c.id)) return;
      if (now.difference(c.addedAt) < _deadThumbnailGracePeriod) return;
      if (seen.add(c.id)) result.add(c);
    }

    for (final c in widget.state.allClips) {
      if (c.thumbnailUrl == null || c.thumbnailUrl!.isEmpty) add(c);
    }
    for (final c in await _clipsWithDeadThumbnail()) {
      add(c);
    }
    return result;
  }

  /// Clips dont la vignette est morte : l'URL est signee (donc perissable)
  /// et aucun fichier local ne subsiste dans le cache disque.
  ///
  /// Ces clips echappaient entierement a la passe de reparation, qui ne
  /// regardait que `thumbnailUrl == null`. Or c'est exactement le symptome
  /// d'origine : « le logo generique remplace une miniature qui
  /// s'affichait la veille ». Une carte pouvait donc rester cassee a vie
  /// tout en ayant l'air pourvue d'une vignette.
  ///
  /// Le test du cache disque est local et sans reseau : c'est le meme
  /// signal que celui utilise par ResilientThumbnail a l'affichage, donc
  /// « pas de fichier en cache » veut bien dire « la carte montre le
  /// logo generique ».
  ///
  /// Depuis l'ajout de ThumbnailStore, cette passe sert aussi de
  /// migration : une miniature encore presente dans le cache disque est
  /// copiee dans le stockage permanent, et la carte est sauvee avant que
  /// le cache ne soit purge.
  Future<List<Clip>> _clipsWithDeadThumbnail() async {
    final now = DateTime.now();
    final dead = <Clip>[];
    var adopted = 0;
    for (final clip in widget.state.allClips) {
      final stored = clip.thumbnailUrl;
      if (stored == null || stored.isEmpty) continue;
      // Copie permanente presente : la carte s'affiche, rien a faire.
      if (await ThumbnailStore.instance.has(clip.id)) continue;
      final displayed = OEmbedService.bestThumbnailUrl(clip.url, stored);
      if (displayed == null || displayed.isEmpty) continue;
      try {
        final file = await ThumbnailCache.instance.getFileFromCache(displayed);
        if (file != null) {
          if (await ThumbnailStore.instance.saveFromFile(clip.id, file.file)) {
            adopted++;
          }
          continue;
        }
      } catch (_) {
        // Cache illisible : on s'abstient plutot que de tout retenter.
        continue;
      }
      if (now.difference(clip.addedAt) < _deadThumbnailGracePeriod) continue;
      // Toutes les URLs sont retenues, signees ou non : la reparation
      // commence par un simple telechargement et ne re-extrait qu'en cas
      // d'echec. Une URL non signee jamais affichee obtient ainsi sa
      // copie permanente sans attendre que l'utilisateur fasse defiler.
      dead.add(clip);
    }
    if (adopted > 0) {
      debugPrint('[thumbstore] $adopted miniature(s) copiee(s) depuis le cache');
    }
    if (dead.isNotEmpty) {
      debugPrint('[repair] ${dead.length} vignette(s) morte(s) detectee(s)');
    }
    return dead;
  }

  /// Repare un clip : re-resolution de l'URL puis re-extraction.
  ///
  /// Renvoie `true` si une re-extraction a eu lieu (couteuse, a espacer),
  /// `false` si un simple telechargement a suffi.
  Future<bool> _repairOneThumbnail(Clip clip) async {
    // 0. L'URL connue est peut-etre encore valide : c'est le cas des clips
    //    dont le pre-cache a ete interrompu (app mise en arriere-plan
    //    juste apres l'ouverture). Un telechargement suffit alors.
    final stored = clip.thumbnailUrl;
    if (stored != null && stored.isNotEmpty) {
      final displayed = OEmbedService.bestThumbnailUrl(clip.url, stored);
      if (displayed != null &&
          displayed.isNotEmpty &&
          await _precacheThumbnail(displayed, clipId: clip.id, retry: false)) {
        debugPrint('[repair] vignette recuperee sans extraction: ${clip.id}');
        return false;
      }
      if (!mounted) return false;
    }

    var target = clip;

    // 1. Re-resoudre l'URL si c'est un lien court connu. `dedupUrl`
    //    devient l'URL stockee, comme a l'ingestion.
    final parsed = Uri.tryParse(clip.url.trim());
    if (parsed != null) {
      final resolved =
          (await OEmbedService.resolveShortLinkForDedup(parsed)).toString();
      if (resolved != clip.url && !widget.state.isDuplicate(resolved)) {
        debugPrint('[repair] URL re-resolue: ${clip.url} -> $resolved');
        target = Clip(
          id: clip.id,
          url: resolved,
          title: clip.title,
          platform: SocialPlatform.detect(resolved).id,
          // Relu, jamais repris de l'instantané : la classification peut
          // s'être terminée depuis (cf. `_currentCategoryIdOf`).
          categoryId: _currentCategoryIdOf(clip),
          tags: clip.tags,
          addedAt: clip.addedAt,
          thumbnailUrl: clip.thumbnailUrl,
          position: clip.position,
          channel: clip.channel,
          description: clip.description,
        );
        await widget.state.updateClip(target);
      }
    }

    // 2. Re-extraire les metadonnees. `_hydrateClip` se charge de la mise
    //    a jour du clip et du pre-cache de la vignette.
    if (!mounted) return true;
    await _hydrateClip(target);
    return true;
  }

  Map<String, int> _readRepairAttempts(
    SharedPreferences prefs, {
    String key = _thumbnailRepairPrefsKey,
  }) {
    final raw = prefs.getString(key);
    if (raw == null || raw.isEmpty) return <String, int>{};
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return <String, int>{};
      return decoded.map(
        (k, v) => MapEntry('$k', v is int ? v : int.tryParse('$v') ?? 0),
      );
    } catch (_) {
      return <String, int>{};
    }
  }

  /// Oublie les compteurs des clips supprimes ou desormais reparés, pour
  /// que la preference ne grossisse pas indefiniment et qu'un clip repare
  /// redevienne eligible s'il reperd un jour sa vignette.
  ///
  /// L'eligibilite est recalculee et non deduite de `thumbnailUrl` :
  /// une vignette morte a une URL non vide, et la deduire aurait efface
  /// son compteur a chaque passage — donc retente sans fin, malgre le
  /// plafond de 3 tentatives.
  Future<void> _pruneRepairAttempts(
    SharedPreferences prefs,
    Map<String, int> attempts,
  ) async {
    final stillNeeding =
        (await _clipsNeedingRepair()).map((c) => c.id).toSet();
    if (!mounted) return;
    attempts.removeWhere((id, _) => !stillNeeding.contains(id));
    if (attempts.isEmpty) {
      await prefs.remove(_thumbnailRepairPrefsKey);
    } else {
      await prefs.setString(_thumbnailRepairPrefsKey, jsonEncode(attempts));
    }
    final lastAttempts =
        _readRepairAttempts(prefs, key: _thumbnailRepairLastPrefsKey)
          ..removeWhere((id, _) => !stillNeeding.contains(id));
    if (lastAttempts.isEmpty) {
      await prefs.remove(_thumbnailRepairLastPrefsKey);
    } else {
      await prefs.setString(
          _thumbnailRepairLastPrefsKey, jsonEncode(lastAttempts));
    }
  }

  @override
  void dispose() {
    _shareSub?.cancel();
    _deepLinkSub?.cancel();
    _purchaseService.dispose();
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
            ? MainShell(state: widget.state, onPasteUrl: _ingestSharedUrl)
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
                ? MainShell(state: widget.state, onPasteUrl: _ingestSharedUrl)
                : OnboardingScreen(state: widget.state),
          );
        },
        onUnknownRoute: (settings) => MaterialPageRoute(
          builder: (_) => !_prefsLoaded
              ? const Scaffold(backgroundColor: Color(0xFF0A0E1F))
              : _onboardingDone
              ? MainShell(state: widget.state, onPasteUrl: _ingestSharedUrl)
              : OnboardingScreen(state: widget.state),
        ),
      ),
    );
  }
}
