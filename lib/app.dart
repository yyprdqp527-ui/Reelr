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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _drainSilentShareInbox();
    });
    _initShareIntent();
    _initDeepLinks();
    _purchaseService = PurchaseService(
      onPremiumUnlocked: () => setPremium(true),
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
          onImportUrl: _ingestSharedUrl,
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

  Future<void> _ingestSharedUrl(String url) async {
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
      _showContentlessUrlNotice();
      return;
    }
    if (widget.state.isDuplicate(dedupUrl)) return;
    if (!_isPremium && _lifetimeClipsAdded >= freeClipsLimit) {
      showPaywall();
      return;
    }
    final normalized = ClipsState.normalizeUrlForDedup(dedupUrl);
    if (_ingestingUrls.contains(normalized)) return;
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
      await widget.state.addClip(clip);
      _lifetimeClipsAdded++;
      unawaited(
        SharedPreferences.getInstance()
            .then((p) => p.setInt('lifetime_clips_added', _lifetimeClipsAdded)),
      );
      // Countdown préventif : à 3, 2 puis 1 vidéo(s) restante(s) avant la
      // limite gratuite (47, 48, 49 sur 50), une fois par palier. Les
      // vidéos supprimées comptent quand même (_lifetimeClipsAdded ne
      // redescend jamais) — le message le précise pour éviter toute
      // confusion avec le compteur visible.
      if (!_isPremium &&
          _lifetimeClipsAdded >= freeClipsLimit - 3 &&
          _lifetimeClipsAdded < freeClipsLimit &&
          _lifetimeClipsAdded > _lastCountdownWarningShownAt) {
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
        if (ctx != null && ctx.mounted) {
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
      }
      unawaited(_hydrateAndClassify(clip));
    } finally {
      _ingestingUrls.remove(normalized);
    }
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
    _navigatorKey.currentState?.push(
      MaterialPageRoute(
        builder: (_) => PaywallScreen(
          priceText: _purchaseService.premiumProduct?.price,
          isLoading:
              !_purchaseServiceReady || _purchaseService.premiumProduct == null,
          onUpgrade: () {
            _purchaseService.buyPremium();
          },
          onClose: () => _navigatorKey.currentState?.pop(),
        ),
      ),
    );
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

  Future<void> _hydrateAndClassify(Clip clip) async {
    final hasRealTitle = await _hydrateClip(clip);
    final updated =
        widget.state.allClips.where((c) => c.id == clip.id).firstOrNull ?? clip;
    // Ne pas payer un appel de classification pour rien : quand
    // l'extraction a echoue, le clip ne porte que le nom de la
    // plateforme (« TikTok »). Observe en production, le classifieur
    // repondait « À trier, confiance 5 » — resultat previsible, facture
    // reelle. Le clip reste simplement a trier manuellement.
    final hasDescription = updated.description?.trim().isNotEmpty ?? false;
    if (!hasRealTitle && !hasDescription) {
      debugPrint(
        '[classify] ignore (aucun signal exploitable): "${updated.title}"',
      );
      return;
    }
    await widget.state.classifyClipInBackground(updated);
  }

  /// Renseigne titre, vignette, chaine et description d'un clip.
  ///
  /// Renvoie `true` si un VRAI titre a ete extrait. Un titre de repli
  /// (nom du createur, nom de plateforme) ne compte pas : c'est cette
  /// distinction qui permet a `_hydrateAndClassify` de ne pas payer une
  /// classification sur un signal qui n'en est pas un.
  Future<bool> _hydrateClip(Clip clip) async {
    debugPrint('[hydrate] ${DateTime.now()} starting for: ${clip.url}');
    final meta = await OEmbedService.fetchMetadata(clip.url);
    if (meta == null) return false;
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
          categoryId: clip.categoryId,
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
      unawaited(_precacheThumbnail(effectiveThumbnailUrl));
    }
    await widget.state.updateClip(
      Clip(
        id: clip.id,
        url: clip.url,
        title: title.isEmpty ? fallbackTitle : title,
        platform: clip.platform,
        categoryId: clip.categoryId,
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
  Future<void> _precacheThumbnail(String url) async {
    final host = Uri.tryParse(url)?.host ?? url;
    for (var attempt = 0; ; attempt++) {
      try {
        await ThumbnailCache.instance.downloadFile(
          url,
          authHeaders: ThumbnailCache.headersFor(url),
        );
        debugPrint('[precache] vignette mise en cache: $host');
        return;
      } catch (e) {
        if (attempt >= _precacheRetryDelays.length) {
          debugPrint(
            '[precache] échec définitif ($host) après ${attempt + 1} '
            'tentative(s): $e',
          );
          return;
        }
        debugPrint(
          '[precache] tentative ${attempt + 1} échouée ($host), '
          'nouvel essai dans ${_precacheRetryDelays[attempt].inSeconds}s: $e',
        );
        await Future<void>.delayed(_precacheRetryDelays[attempt]);
        if (!mounted) return;
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

  /// Pause entre deux reparations : simple politesse reseau, pas une
  /// protection contre une limitation de debit (cf. ci-dessus).
  static const Duration _thumbnailRepairSpacing = Duration(seconds: 2);

  /// Au-dela de ce nombre d'echecs, un clip n'est plus retente. Sans ce
  /// plafond, les clips definitivement inextricables (Reddit, Facebook
  /// Reels) relanceraient une extraction inutile a chaque ouverture.
  static const int _thumbnailRepairMaxAttempts = 3;

  static const String _thumbnailRepairPrefsKey = 'thumbnail_repair_attempts';

  /// Delai avant de lancer la passe : laisse le premier rendu et le
  /// chargement des clips se terminer sans concurrence reseau.
  static const Duration _thumbnailRepairStartDelay = Duration(seconds: 4);

  /// Une seule passe par session, meme si _loadPrefs est rappele.
  bool _thumbnailRepairStarted = false;

  void _scheduleThumbnailRepair() {
    if (_thumbnailRepairStarted) return;
    _thumbnailRepairStarted = true;
    Future<void>.delayed(_thumbnailRepairStartDelay, () {
      if (!mounted) return;
      unawaited(_repairMissingThumbnails());
    });
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

    final candidates = widget.state.allClips
        .where((c) => c.thumbnailUrl == null || c.thumbnailUrl!.isEmpty)
        // Les clips enregistres avant le garde-fou d'ingestion pointent
        // parfois vers une page sans contenu (tiktok.com/foryou, /fr/).
        // Aucune extraction ne les reparera : les inclure gaspillait des
        // creneaux de la passe — observe en production, 3 sur 8.
        .where((c) => !OEmbedService.isContentlessUrl(c.url))
        .where((c) =>
            (attempts[c.id] ?? 0) < _thumbnailRepairMaxAttempts)
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

    final batch = candidates.take(_thumbnailRepairBatchSize).toList();
    debugPrint(
      '[repair] ${candidates.length} clip(s) sans vignette, '
      '${batch.length} traite(s) sur cette session',
    );

    for (final clip in batch) {
      if (!mounted) return;
      attempts[clip.id] = (attempts[clip.id] ?? 0) + 1;
      await prefs.setString(_thumbnailRepairPrefsKey, jsonEncode(attempts));
      try {
        await _repairOneThumbnail(clip);
      } catch (e) {
        debugPrint('[repair] echec ${clip.id}: $e');
      }
      if (!mounted) return;
      // Respiration entre deux clips : evite la rafale de requetes qui
      // faisait basculer TikTok en mode anti-bot.
      await Future<void>.delayed(_thumbnailRepairSpacing);
    }

    if (!mounted) return;
    await _pruneRepairAttempts(prefs, attempts);
  }

  /// Repare un clip : re-resolution de l'URL puis re-extraction.
  Future<void> _repairOneThumbnail(Clip clip) async {
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
          categoryId: clip.categoryId,
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
    if (!mounted) return;
    await _hydrateClip(target);
  }

  Map<String, int> _readRepairAttempts(SharedPreferences prefs) {
    final raw = prefs.getString(_thumbnailRepairPrefsKey);
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

  /// Oublie les compteurs des clips supprimes ou desormais pourvus d'une
  /// vignette, pour que la preference ne grossisse pas indefiniment et
  /// qu'un clip repare redevienne eligible s'il reperd sa vignette.
  Future<void> _pruneRepairAttempts(
    SharedPreferences prefs,
    Map<String, int> attempts,
  ) async {
    final stillMissing = widget.state.allClips
        .where((c) => c.thumbnailUrl == null || c.thumbnailUrl!.isEmpty)
        .map((c) => c.id)
        .toSet();
    attempts.removeWhere((id, _) => !stillMissing.contains(id));
    if (attempts.isEmpty) {
      await prefs.remove(_thumbnailRepairPrefsKey);
    } else {
      await prefs.setString(_thumbnailRepairPrefsKey, jsonEncode(attempts));
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
