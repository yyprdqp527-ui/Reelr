import 'dart:convert';
import 'dart:io' show HttpClient;

import 'package:flutter/material.dart';
import 'net.dart';

import '../config/secrets.dart';
import 'classifier.dart';
import 'thumbnail_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SocialPlatform {
  final String id;
  final String name;
  final IconData icon;
  final Color color;

  const SocialPlatform({
    required this.id,
    required this.name,
    required this.icon,
    required this.color,
  });

  static SocialPlatform detect(String url) {
    final lower = url.toLowerCase();
    final host = _hostOf(lower);
    if (_hostMatches(host, lower, const ['youtube.com', 'youtu.be'])) {
      return _platforms['youtube']!;
    } else if (_hostMatches(host, lower, const ['tiktok.com'])) {
      return _platforms['tiktok']!;
    } else if (_hostMatches(host, lower, const ['instagram.com', 'instagr.am'])) {
      return _platforms['instagram']!;
    } else if (_hostMatches(host, lower, const ['twitter.com', 'x.com'])) {
      return _platforms['x']!;
    } else if (_hostMatches(host, lower, const ['facebook.com', 'fb.watch'])) {
      return _platforms['facebook']!;
    } else if (_hostMatches(host, lower, const ['twitch.tv'])) {
      return _platforms['twitch']!;
    } else if (_hostMatches(host, lower, const ['vimeo.com'])) {
      return _platforms['vimeo']!;
    } else if (_hostMatches(host, lower, const ['reddit.com'])) {
      return _platforms['reddit']!;
    } else if (_hostMatches(host, lower, const ['pinterest.com', 'pin.it'])) {
      return _platforms['pinterest']!;
    } else if (_hostMatches(host, lower, const ['linkedin.com'])) {
      return _platforms['linkedin']!;
    } else if (_hostMatches(host, lower,
        const ['music.apple.com', 'itunes.apple.com', 'apple.co'])) {
      // apple.co : lien court genere par l'app Musique lors d'un partage.
      return _platforms['applemusic']!;
    } else if (_hostMatches(
        host, lower, const ['open.spotify.com', 'spotify.link'])) {
      return _platforms['spotify']!;
    }
    return _platforms['other']!;
  }

  /// Nom d'hôte d'une URL (ex. "www.x.com" à partir de
  /// "https://www.x.com/foo"), ou chaîne vide si l'URL n'a pas pu être
  /// analysée (ex. lien sans schéma http(s)://).
  static String _hostOf(String lowerUrl) {
    try {
      return Uri.parse(lowerUrl.trim()).host;
    } catch (_) {
      return '';
    }
  }

  /// Vrai si [host] est exactement l'un des [domains], ou un sous-domaine de
  /// l'un d'eux (ex. "www.x.com"/"mobile.x.com" matchent "x.com", mais —
  /// contrairement à l'ancien `.contains('x.com')` — "netflix.com" ou
  /// "xbox.com" ne matchent plus jamais "x.com").
  ///
  /// Si [host] est vide (URL non analysable), on retombe sur l'ancienne
  /// recherche de sous-chaîne dans l'URL complète, pour ne jamais régresser
  /// sur ces cas rares.
  static bool _hostMatches(String host, String fullUrlLower, List<String> domains) {
    for (final domain in domains) {
      if (host == domain || host.endsWith('.$domain')) return true;
    }
    if (host.isEmpty) {
      for (final domain in domains) {
        if (fullUrlLower.contains(domain)) return true;
      }
    }
    return false;
  }

  static final Map<String, SocialPlatform> _platforms = {
    'youtube': const SocialPlatform(
      id: 'youtube',
      name: 'YouTube',
      icon: Icons.smart_display_rounded,
      color: Color(0xFFFF0000),
    ),
    'tiktok': const SocialPlatform(
      id: 'tiktok',
      name: 'TikTok',
      icon: Icons.music_note_rounded,
      color: Color(0xFF69C9D0),
    ),
    'instagram': const SocialPlatform(
      id: 'instagram',
      name: 'Instagram',
      icon: Icons.camera_alt_rounded,
      color: Color(0xFFE1306C),
    ),
    'x': const SocialPlatform(
      id: 'x',
      name: 'X / Twitter',
      icon: Icons.alternate_email_rounded,
      color: Color(0xFF1DA1F2),
    ),
    'facebook': const SocialPlatform(
      id: 'facebook',
      name: 'Facebook',
      icon: Icons.facebook_rounded,
      color: Color(0xFF1877F2),
    ),
    'twitch': const SocialPlatform(
      id: 'twitch',
      name: 'Twitch',
      icon: Icons.live_tv_rounded,
      color: Color(0xFF9146FF),
    ),
    'vimeo': const SocialPlatform(
      id: 'vimeo',
      name: 'Vimeo',
      icon: Icons.videocam_rounded,
      color: Color(0xFF1AB7EA),
    ),
    'reddit': const SocialPlatform(
      id: 'reddit',
      name: 'Reddit',
      icon: Icons.forum_rounded,
      color: Color(0xFFFF4500),
    ),
    'pinterest': const SocialPlatform(
      id: 'pinterest',
      name: 'Pinterest',
      icon: Icons.push_pin_rounded,
      color: Color(0xFFE60023),
    ),
    'linkedin': const SocialPlatform(
      id: 'linkedin',
      name: 'LinkedIn',
      icon: Icons.work_rounded,
      color: Color(0xFF0A66C2),
    ),
    'applemusic': const SocialPlatform(
      id: 'applemusic',
      name: 'Apple Music',
      icon: Icons.library_music_rounded,
      color: Color(0xFFFA243C),
    ),
    'spotify': const SocialPlatform(
      id: 'spotify',
      name: 'Spotify',
      icon: Icons.graphic_eq_rounded,
      color: Color(0xFF1DB954),
    ),
    'other': const SocialPlatform(
      id: 'other',
      name: 'Autre',
      icon: Icons.link_rounded,
      color: Color(0xFF9E9E9E),
    ),
  };
}

class OEmbedService {
  // `_ytApiKey` retire : l'extraction YouTube passe par l'oEmbed public,
  // qui ne demande aucune cle. La cle voyageait dans le binaire sans
  // jamais etre appelee.
  static String get _instagramAccessToken => Secrets.instagramAccessToken;
  static String get _twitchClientId => Secrets.twitchClientId;
  static String get _twitchAccessToken => Secrets.twitchAccessToken;

  /// Vrai si une clé a réellement été renseignée.
  ///
  /// Le fichier d'exemple livre des valeurs du type
  /// `YOUR_TWITCH_ACCESS_TOKEN`. Copiées telles quelles, elles ne sont
  /// pas vides : le code les envoyait donc comme identifiants, et Twitch
  /// répondait `401 Invalid OAuth token` à chaque partage. Un
  /// aller-retour réseau perdu d'avance avant de retomber sur OpenGraph.
  ///
  /// Diagnostiqué à tort comme un jeton expiré : il n'a jamais existé.
  static bool _isConfigured(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return false;
    final upper = trimmed.toUpperCase();
    return !upper.startsWith('YOUR') &&
        !upper.contains('VOTRE') &&
        !upper.contains('...');
  }

  static String? bestThumbnailUrl(String url, String? storedThumbUrl) {
    // Vignette qui n'existe que dans le stockage permanent : ni proxy ni
    // reconstruction, l'URL interne est lue telle quelle.
    if (storedThumbUrl != null && ThumbnailStore.isLocalUrl(storedThumbUrl)) {
      return storedThumbUrl;
    }
    final lower = url.toLowerCase();
    if (lower.contains('youtube.com') || lower.contains('youtu.be')) {
      final id = _youtubeVideoIdFromUrl(url);
      if (id != null) {
        return 'https://img.youtube.com/vi/$id/mqdefault.jpg';
      }
    }
    // Facebook: les URLs de vignette (fbcdn.net) contiennent des tokens
    // signes a courte duree de vie (oh=/oe=) qui expirent souvent avant
    // que l'image ne soit chargee. On fait passer l'URL par le Worker
    // proxy, qui retelecharge l'image cote serveur a la demande -- le
    // token n'a alors jamais le temps d'expirer.
    if (lower.contains('facebook.com') &&
        storedThumbUrl != null &&
        storedThumbUrl.isNotEmpty) {
      return _proxiedThumbnailUrl(storedThumbUrl);
    }
    // Reddit : protections anti-hotlink cote CDN qui peuvent bloquer un
    // chargement direct depuis l'app. Le Worker proxy retelecharge l'image
    // avec des en-tetes (User-Agent, Referer) adaptes.
    //
    // Pinterest n'y passe plus : les images i.pinimg.com sont publiques,
    // sans jeton ni expiration, et se chargent directement. Le proxy ne
    // faisait qu'ajouter un point de panne — le Worker deploye sur
    // room79 ne connait pas la route /thumb et repondait 405, si bien
    // qu'AUCUNE vignette Pinterest ne s'affichait.
    if (lower.contains('reddit.com') &&
        storedThumbUrl != null &&
        storedThumbUrl.isNotEmpty) {
      return _proxiedThumbnailUrl(storedThumbUrl);
    }
    return storedThumbUrl;
  }

  /// Fait passer une URL de vignette par la route /thumb du Worker
  /// Cloudflare, qui la retelecharge cote serveur avec des en-tetes
  /// realistes et la retransmet -- utile pour contourner les tokens CDN
  /// expires et les protections anti-hotlink de certaines plateformes.
  /// Capture d'ecran de [pageUrl] par la route /screenshot du Worker :
  /// dernier recours pour un lien web qui n'a fourni aucune image. Le
  /// Worker refuse (502) les pages bloquees ou en erreur ; l'affichage
  /// retombe alors sur le logo.
  static String screenshotUrlFor(String pageUrl) {
    final proxyBase = Secrets.reelrProxyUrl.replaceAll('/v1/messages', '');
    return '$proxyBase/screenshot?url=${Uri.encodeComponent(pageUrl)}';
  }

  static String _proxiedThumbnailUrl(String rawUrl) {
    final proxyBase = Secrets.reelrProxyUrl.replaceAll('/v1/messages', '');
    return '$proxyBase/thumb?url=${Uri.encodeComponent(rawUrl)}';
  }

  /// Vrai seulement si [url] repond 404 ou 410 (image supprimee). Delai
  /// maximal 2 s ; toute autre issue renvoie false.
  static Future<bool> _imageIsGone(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return false;
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 2);
    try {
      final request = await client.headUrl(uri).timeout(const Duration(seconds: 2));
      final response = await request.close().timeout(const Duration(seconds: 2));
      await response.drain<void>();
      return response.statusCode == 404 || response.statusCode == 410;
    } catch (_) {
      return false;
    } finally {
      client.close(force: true);
    }
  }

  /// Lien partage depuis l'appli Booking : domaine nu, aucun chemin, numero
  /// d'hotel en parametre.
  static bool _isBookingAppLink(Uri uri) {
    final host = uri.host.toLowerCase();
    if (host != 'booking.com' && !host.endsWith('.booking.com')) return false;
    if (uri.path.isNotEmpty && uri.path != '/') return false;
    final id = uri.queryParameters['app_hotel_id'] ??
        uri.queryParameters['hotel_id'] ??
        '';
    return RegExp(r'^\d+$').hasMatch(id);
  }

  /// Essaie quelques adresses Booking qui redirigent un numero d'hotel vers
  /// sa fiche. Une adresse n'est retenue que si, apres redirection, elle
  /// mene a un chemin /hotel/ (jamais la page d'accueil). Delai : 6 s par
  /// essai. Renvoie l'adresse de la fiche (sans parametres), ou null.
  static Future<String?> _resolveBookingAppLink(Uri uri) async {
    final id = uri.queryParameters['app_hotel_id'] ??
        uri.queryParameters['hotel_id'] ??
        '';
    final candidates = <String>[
      'https://www.booking.com/hotel/index.html?hotel_id=$id',
      'https://www.booking.com/hotel.html?hotel_id=$id',
      'https://www.booking.com/hotel/redirect.html?hotel_id=$id',
    ];
    for (final candidate in candidates) {
      try {
        final response = await Net.client.get(
          Uri.parse(candidate),
          headers: const {
            'User-Agent': 'facebookexternalhit/1.1',
            'Accept': 'text/html,application/xhtml+xml',
          },
        ).timeout(const Duration(seconds: 6));
        final finalUri = response.request?.url;
        if (response.statusCode == 200 &&
            finalUri != null &&
            finalUri.path.contains('/hotel/') &&
            !finalUri.path.endsWith('/index.html')) {
          return finalUri.replace(query: '').toString().replaceAll('?', '');
        }
      } catch (e) {
        debugPrint('[oembed] Booking app link essai echoue: $e');
      }
    }
    return null;
  }

  /// Lien court partage depuis l'appli Booking : booking.com/Share-xxxx.
  static bool _isBookingShareLink(Uri uri) {
    final host = uri.host.toLowerCase();
    if (host != 'booking.com' && !host.endsWith('.booking.com')) return false;
    return uri.pathSegments.length == 1 &&
        RegExp(r'^Share-[A-Za-z0-9]+$').hasMatch(uri.pathSegments.first);
  }

  /// Suit la redirection d'un lien Share-xxxx avec l'identite d'un robot
  /// d'apercu. Renvoie l'adresse de la fiche (sans parametres), ou null si
  /// la redirection ne mene pas a un chemin /hotel/.
  static Future<String?> _resolveBookingShareLink(Uri uri) async {
    HttpClient? client;
    try {
      client = HttpClient()..userAgent = 'facebookexternalhit/1.1';
      final request =
          await client.getUrl(uri).timeout(const Duration(seconds: 10));
      request.headers.set('Accept', 'text/html,application/xhtml+xml');
      final response =
          await request.close().timeout(const Duration(seconds: 10));
      await response.drain<void>();
      if (response.statusCode == 200 && response.redirects.isNotEmpty) {
        final finalUri = response.redirects.last.location;
        if (finalUri.host.isNotEmpty &&
            finalUri.path.contains('/hotel/') &&
            !finalUri.path.endsWith('/index.html')) {
          return Uri(
            scheme: finalUri.scheme,
            host: finalUri.host,
            path: finalUri.path,
          ).toString();
        }
      }
      debugPrint('[oembed] Booking Share : redirection inexploitable '
          '(code ${response.statusCode}, ${response.redirects.length} saut(s))');
    } catch (e) {
      debugPrint('[oembed] Booking Share echoue: $e');
    } finally {
      client?.close(force: true);
    }
    return null;
  }

  static Future<VideoData?> fetchMetadata(String url) async {
    final trimmed = url.trim();
    final lower = trimmed.toLowerCase();

    // Liens de redirection Google Images (ex: partagés depuis l'app Google
    // ou Google Images) : l'URL réelle du contenu est cachée dans le
    // paramètre imgrefurl (page d'origine) — on la résout avant d'extraire
    // les métadonnées, sinon on récupère le titre générique de la page de
    // résultats Google au lieu du vrai contenu.
    if (lower.contains('google.') && lower.contains('/imgres')) {
      final googleUri = Uri.tryParse(trimmed);
      final realUrl = googleUri?.queryParameters['imgrefurl'];
      if (realUrl != null && realUrl.isNotEmpty && realUrl != trimmed) {
        final meta = await fetchMetadata(realUrl);
        // L'image touchee dans Google Images (imgurl) est celle que
        // l'utilisateur a vue : elle passe avant l'og:image de la page,
        // parfois generique (Le Parisien : placeholder_ogimage.png).
        final imageUrl = googleUri?.queryParameters['imgurl'] ?? '';
        if (meta == null || !imageUrl.startsWith('http')) return meta;
        // lookaside.instagram.com est un point d'acces reserve au robot
        // Google : l'appli n'y recoit pas une image. Si la page d'origine
        // a donne sa propre image (og:image), on la garde.
        // Idem pour tiktok.com/api/img : refuse (403) a l'app comme au
        // Worker ; la page TikTok donne une vignette lisible.
        final imageUri = Uri.tryParse(imageUrl);
        final imageHost = imageUri?.host ?? '';
        final unreadableImage = imageHost == 'lookaside.instagram.com' ||
            (imageHost.endsWith('tiktok.com') &&
                (imageUri?.path ?? '').startsWith('/api/img'));
        if (unreadableImage &&
            (meta.thumbnailUrl?.startsWith('http') ?? false)) {
          debugPrint('[oembed] Google Images : imgurl lookaside ignore, '
              'og:image de la page d\'origine conservee');
          return meta;
        }
        // Image supprimee depuis par la boutique (404 / 410) : la page,
        // elle, existe encore, on prend son og:image. Les autres reponses
        // (refus, delai depasse, HEAD non gere) ne prouvent rien : on garde
        // l'image de Google.
        // Meme sans og:image sur la page : une image morte ne vaut rien,
        // mieux vaut pas de vignette (apercu Safari, capture ensuite).
        if (await _imageIsGone(imageUrl)) {
          debugPrint('[oembed] Google Images : imgurl disparue (404), '
              'vignette de la page d\'origine (ou aucune)');
          return meta;
        }
        debugPrint('[oembed] Google Images : vignette = imgurl $imageUrl');
        return VideoData(
          title: meta.title,
          channel: meta.channel,
          description: meta.description,
          tags: meta.tags,
          views: meta.views,
          duration: meta.duration,
          publishedAt: meta.publishedAt,
          platform: meta.platform,
          thumbnailUrl: imageUrl,
          transcriptExcerpt: meta.transcriptExcerpt,
        );
      }
    }

    // Liens de redirection Facebook (ex: partage d'un lien externe posté
    // sur Facebook, enveloppé par Facebook via l.facebook.com/l.php?u=...)
    // : l'URL réelle est dans le paramètre u= — on la résout avant
    // d'extraire les métadonnées, sinon on récupère la page de redirection
    // Facebook elle-même plutôt que le vrai contenu partagé.
    if (lower.contains('facebook.com/l.php') || lower.contains('l.facebook.com')) {
      final fbUri = Uri.tryParse(trimmed);
      final realUrl = fbUri?.queryParameters['u'];
      if (realUrl != null && realUrl.isNotEmpty && realUrl != trimmed) {
        return fetchMetadata(realUrl);
      }
    }

    final uri = _parseHttpUri(trimmed);

    // Lien court de l'appli Booking (booking.com/Share-xxxx) : il redirige
    // vers la fiche de l'hotel, mais seulement pour un robot d'apercu (un
    // navigateur recoit une page de verification, code 202, sans photo).
    // On retrouve la fiche, puis on lit ses metadonnees comme celles d'un
    // lien partage depuis Safari.
    if (uri != null && _isBookingShareLink(uri)) {
      final hotelUrl = await _resolveBookingShareLink(uri);
      if (hotelUrl != null && hotelUrl != trimmed) {
        debugPrint('[oembed] Booking Share -> $hotelUrl');
        return fetchMetadata(hotelUrl);
      }
      debugPrint('[oembed] Booking Share : fiche introuvable');
    }

    // Lien de l'appli Booking (booking.com?...&app_hotel_id=123) : la page
    // d'accueil, l'hotel n'est qu'un numero. On tente de retrouver la fiche.
    if (uri != null && _isBookingAppLink(uri)) {
      final hotelUrl = await _resolveBookingAppLink(uri);
      if (hotelUrl != null && hotelUrl != trimmed) {
        debugPrint('[oembed] Booking app link -> $hotelUrl');
        return fetchMetadata(hotelUrl);
      }
      debugPrint('[oembed] Booking app link : fiche introuvable');
    }

    if (lower.contains('youtube.com') || lower.contains('youtu.be')) {
      if (uri == null) return null;
      final videoId = _youtubeVideoIdFromUri(uri);
      if (videoId == null || videoId.isEmpty) return null;
      return _fetchYouTubeMetadata(uri, videoId);
    }

    if (lower.contains('tiktok.com') || lower.contains('vm.tiktok.com')) {
      if (uri == null) return null;
      return _fetchTikTokMetadata(uri);
    }

    if (lower.contains('instagram.com')) {
      if (uri == null) return null;
      return _fetchInstagramMetadata(uri);
    }

    if (lower.contains('twitch.tv') || lower.contains('clips.twitch.tv')) {
      if (uri == null) return null;
      return _fetchTwitchMetadata(uri);
    }
    if (lower.contains('reddit.com')) {
      if (uri == null) return null;
      return _fetchRedditMetadata(uri);
    }

    // Plateformes HTTP non couvertes (ex: Facebook): fallback OpenGraph.
    if (uri != null) {
      final platformId = SocialPlatform.detect(trimmed).id;
      final og = await _fetchOpenGraphMetadata(uri, platformId: platformId);
      // Site quelconque sans image, ou qui bloque la requete (fiches hotel
      // Booking) : second essai en se presentant comme un robot d'apercu
      // de liens, que ces sites laissent passer pour les vignettes des
      // messageries. Verifie a la main sur Booking le 2026-10-02.
      // Les plateformes connues ne sont pas concernees.
      if (platformId == 'other' && (og == null || og.thumbnailUrl == null)) {
        final retry = await _fetchOpenGraphMetadata(uri,
            platformId: platformId, previewBotUserAgent: true);
        if (retry != null && (og == null || retry.thumbnailUrl != null)) {
          debugPrint('[oembed] robot d\'apercu : metadonnees recuperees pour ${uri.host}');
          return retry;
        }
      }
      return og;
    }

    return VideoData(
      title: _filenameTitle(trimmed),
      platform: 'upload',
    );
  }

  /// Duree ISO 8601 (PT1H2M3S) -> « 1:02:03 ».
  static String? _youtubeDuration(String? iso) {
    if (iso == null) return null;
    final m = RegExp(r'^PT(?:(\d+)H)?(?:(\d+)M)?(?:(\d+)S)?$').firstMatch(iso);
    if (m == null) return null;
    final h = int.tryParse(m.group(1) ?? '') ?? 0;
    final mi = int.tryParse(m.group(2) ?? '') ?? 0;
    final s = int.tryParse(m.group(3) ?? '') ?? 0;
    final ss = s.toString().padLeft(2, '0');
    if (h > 0) return '$h:${mi.toString().padLeft(2, '0')}:$ss';
    return '$mi:$ss';
  }

  static Future<VideoData?> _fetchYouTubeViaProxy(
      Uri videoUri, String videoId) async {
    try {
      final proxyBase = Secrets.reelrProxyUrl.replaceAll('/v1/messages', '');
      final response = await Net.client.get(
        Uri.parse('$proxyBase/youtube?id=${Uri.encodeComponent(videoId)}'),
        headers: {'x-reelr-secret': Secrets.appSharedSecret},
      ).timeout(const Duration(seconds: 8));
      if (response.statusCode != 200) return null;
      final p = json.decode(utf8.decode(response.bodyBytes))
          as Map<String, dynamic>;
      final title = (p['title'] as String?)?.trim() ?? '';
      if (title.isEmpty) return null;
      final channel = (p['channel'] as String?)?.trim();
      final description = (p['description'] as String?)?.trim();
      return VideoData(
        title: title,
        channel: (channel == null || channel.isEmpty) ? null : channel,
        description:
            (description == null || description.isEmpty) ? null : description,
        tags: ((p['tags'] as List?) ?? const []).whereType<String>().toList(),
        views: (p['views'] as num?)?.toInt(),
        duration: _youtubeDuration(p['duration'] as String?),
        publishedAt: p['publishedAt'] as String?,
        platform: 'youtube',
        thumbnailUrl: bestThumbnailUrl(videoUri.toString(), null),
      );
    } catch (e) {
      debugPrint('[oembed] youtube proxy: $e');
      return null;
    }
  }

  static Future<VideoData?> _fetchYouTubeMetadata(Uri videoUri, String videoId) async {
    try {
      // Metadonnees riches via le proxy (cle YouTube cote Cloudflare). Toute
      // erreur : on retombe sur l'oEmbed ci-dessous, comme avant.
      final rich = await _fetchYouTubeViaProxy(videoUri, videoId);
      if (rich != null) return rich;
      final oembedUrl = 'https://www.youtube.com/oembed?url=${Uri.encodeComponent(videoUri.toString())}&format=json';
      final response = await Net.client
          .get(Uri.parse(oembedUrl), headers: {'Accept': 'application/json'})
          .timeout(const Duration(seconds: 10));
      if (response.statusCode != 200) {
        return VideoData(
          title: videoUri.toString(),
          platform: 'youtube',
          thumbnailUrl: bestThumbnailUrl(videoUri.toString(), null),
        );
      }
      final payload = json.decode(response.body) as Map<String, dynamic>;
      final title = (payload['title'] as String?)?.trim() ?? '';
      final author = (payload['author_name'] as String?)?.trim();
      final thumbUrl = bestThumbnailUrl(videoUri.toString(), payload['thumbnail_url'] as String?);
      return VideoData(
        title: title.isNotEmpty ? title : videoUri.toString(),
        channel: author,
        platform: 'youtube',
        thumbnailUrl: thumbUrl,
      );
    } catch (e) {
      debugPrint('[oembed] youtube error: $e');
      return null;
    }
  }

  /// Pseudo de l'auteur, lu dans le chemin de l'URL (`/@pseudo/video/123`).
  /// Deterministe, sans reseau. Sert au repli : `og:site_name` ne renvoie que
  /// « TikTok », un nom generique qui n'apprend rien et encombre le prompt.
  static String? _tiktokHandleFromUri(Uri uri) {
    for (final seg in uri.pathSegments) {
      if (seg.startsWith('@') && seg.length > 1) return seg.substring(1);
    }
    return null;
  }

  /// Second canal pour TikTok : la page elle-meme, via OpenGraph.
  ///
  /// TikTok etait la seule plateforme sans repli -- Instagram retombe ici
  /// quand son oEmbed echoue, Facebook et Pinterest y passent d'office. Une
  /// reponse partielle reste precieuse : la miniature seule suffit souvent,
  /// TikTok faisant partie des plateformes classees en multimodal.
  static Future<VideoData?> _fetchTikTokMetadataViaPage(Uri videoUri) async {
    final og = await _fetchOpenGraphMetadata(videoUri, platformId: 'tiktok');
    if (og == null) {
      debugPrint('[oembed] tiktok: repli OpenGraph infructueux lui aussi');
      return null;
    }
    final handle = _tiktokHandleFromUri(videoUri);
    debugPrint('[oembed] tiktok: repli OpenGraph -> titre="${og.title}" '
        'thumb=${og.thumbnailUrl != null} description=${og.description != null}');
    return VideoData(
      title: og.title,
      channel: (handle != null && handle.isNotEmpty) ? handle : og.channel,
      platform: 'tiktok',
      thumbnailUrl: og.thumbnailUrl,
      description: og.description,
    );
  }

  static Future<VideoData?> _fetchTikTokMetadata(Uri videoUri) async {
    final requestUri = Uri.https('www.tiktok.com', '/oembed', {
      'url': videoUri.toString(),
    });

    try {
      final response = await Net.client
          .get(requestUri, headers: {'Accept': 'application/json'})
          .timeout(const Duration(seconds: 10));
      // Ces trois sorties etaient muettes : un 403 ou un 429 de TikTok
      // passait totalement inapercu, et `_hydrateClip` abandonnait sans
      // laisser la moindre trace dans la console.
      if (response.statusCode != 200) {
        final peek = response.body.length > 200
            ? response.body.substring(0, 200)
            : response.body;
        debugPrint('[oembed] tiktok: oEmbed statut ${response.statusCode} '
            '-- debut du corps: $peek');
        return _fetchTikTokMetadataViaPage(videoUri);
      }

      final payload = json.decode(response.body) as Map<String, dynamic>;
      final title = (payload['title'] as String?)?.trim();
      final thumbnail = _sanitizeMediaUrl(payload['thumbnail_url'] as String?);
      if (title == null || title.isEmpty) {
        // Un titre vide ne justifie PAS de jeter la vignette. L'ancien
        // code repartait sur le scraping OpenGraph, qui ne ramene que la
        // coquille JS de TikTok : une image valide etait perdue alors
        // qu'elle est exactement ce qu'on cherche.
        if (thumbnail != null && thumbnail.isNotEmpty) {
          debugPrint(
            '[oembed] tiktok: oEmbed 200 sans titre MAIS vignette presente '
            '-- vignette conservee',
          );
          return VideoData(
            title: '',
            channel: (payload['author_name'] as String?)?.trim(),
            platform: 'tiktok',
            thumbnailUrl: thumbnail,
          );
        }
        debugPrint(
          '[oembed] tiktok: oEmbed 200 sans titre NI vignette '
          '-- video probablement supprimee, privee ou restreinte',
        );
        return _fetchTikTokMetadataViaPage(videoUri);
      }

      return VideoData(
        title: title,
        channel: (payload['author_name'] as String?)?.trim(),
        platform: 'tiktok',
        thumbnailUrl: thumbnail,
      );
    } catch (e) {
      debugPrint('[oembed] tiktok error: $e');
      return _fetchTikTokMetadataViaPage(videoUri);
    }
  }

  static Future<VideoData?> _fetchInstagramMetadata(Uri videoUri) async {
    if (!_isConfigured(_instagramAccessToken)) {
      debugPrint('[oembed] instagram: jeton absent ou non remplace '
          '-- repli OpenGraph direct');
      return _fetchOpenGraphMetadata(videoUri, platformId: 'instagram');
    }

    final requestUri = Uri.https('graph.facebook.com', '/v18.0/instagram_oembed', {
      'url': videoUri.toString(),
      'access_token': _instagramAccessToken,
    });

    try {
      final response = await Net.client
          .get(requestUri, headers: {'Accept': 'application/json'})
          .timeout(const Duration(seconds: 10));
      if (response.statusCode != 200) return null;

      final payload = json.decode(response.body) as Map<String, dynamic>;
      final title = (payload['title'] as String?)?.trim();
      final thumbnail = _sanitizeMediaUrl(payload['thumbnail_url'] as String?);
      // Meme raisonnement que pour TikTok : un titre vide ne doit pas
      // faire perdre une vignette valide (les Reels sans legende sont
      // frequents et renvoient precisement ce profil).
      if (title == null || title.isEmpty) {
        if (thumbnail == null || thumbnail.isEmpty) return null;
        debugPrint(
          '[oembed] instagram: titre vide mais vignette presente -- conservee',
        );
      }

      return VideoData(
        title: title ?? '',
        channel: (payload['author_name'] as String?)?.trim(),
        platform: 'instagram',
        thumbnailUrl: thumbnail,
      );
    } catch (e) {
      debugPrint('[oembed] instagram error: $e');
      return _fetchOpenGraphMetadata(videoUri, platformId: 'instagram');
    }
  }

  static Future<VideoData?> _fetchTwitchMetadata(Uri videoUri) async {
    final clipId = _twitchClipIdFromUri(videoUri);
    final videoId = clipId == null ? _twitchVideoIdFromUri(videoUri) : null;

    if (clipId == null && videoId == null) {
      return _fetchOpenGraphMetadata(videoUri, platformId: 'twitch');
    }

    if (!_isConfigured(_twitchClientId) || !_isConfigured(_twitchAccessToken)) {
      debugPrint('[oembed] twitch: identifiants absents ou non remplaces '
          '-- repli OpenGraph direct, sans appel API');
      return _fetchOpenGraphMetadata(videoUri, platformId: 'twitch');
    }

    final requestUri = clipId != null
        ? Uri.https('api.twitch.tv', '/helix/clips', {'id': clipId})
        : Uri.https('api.twitch.tv', '/helix/videos', {'id': videoId!});

    try {
      final response = await Net.client.get(
        requestUri,
        headers: {
          'Accept': 'application/json',
          'Client-Id': _twitchClientId,
          'Authorization': 'Bearer $_twitchAccessToken',
        },
      ).timeout(const Duration(seconds: 10));

      // Branche muette jusqu'ici : un jeton d'application expire (ils
      // durent ~60 jours) faisait silencieusement retomber TOUS les clips
      // et VOD Twitch sur le repli OpenGraph, lequel ne renvoie que le
      // logo Twitch en guise de miniature. Rien dans la console ne
      // permettait de faire la difference avec un identifiant invalide.
      if (response.statusCode != 200) {
        final peek = response.body.length > 200
            ? response.body.substring(0, 200)
            : response.body;
        debugPrint('[oembed] twitch: API statut ${response.statusCode} '
            '${response.statusCode == 401 ? "(jeton expire ou invalide ?) " : ""}'
            '-- debut du corps: $peek');
        return _fetchOpenGraphMetadata(videoUri, platformId: 'twitch');
      }

      final payload = json.decode(response.body) as Map<String, dynamic>;
      final items = payload['data'] as List<dynamic>?;
      if (items == null || items.isEmpty) {
        debugPrint('[oembed] twitch: API 200 mais aucun element '
            '-- identifiant introuvable ou contenu supprime');
        return _fetchOpenGraphMetadata(videoUri, platformId: 'twitch');
      }

      final item = items.first as Map<String, dynamic>;
      final title = (item['title'] as String?)?.trim();

      final thumbnailTemplate = item['thumbnail_url'] as String?;
      final thumbnailUrl = _sanitizeMediaUrl(
        thumbnailTemplate?.replaceAll('{width}x{height}', '480x270'),
      );

      // Meme correction que pour TikTok : un titre vide ne doit pas faire
      // jeter une vignette valide deja recue. On ne repart sur le repli
      // OpenGraph que si l'API n'a vraiment rien donne d'exploitable.
      if ((title == null || title.isEmpty) &&
          (thumbnailUrl == null || thumbnailUrl.isEmpty)) {
        return _fetchOpenGraphMetadata(videoUri, platformId: 'twitch');
      }

      return VideoData(
        title: title ?? '',
        channel: (item['broadcaster_name'] as String?)?.trim(),
        description: (item['game_name'] as String?)?.trim(),
        views: item['view_count'] is int
            ? item['view_count'] as int
            : int.tryParse('${item['view_count'] ?? ''}'),
        duration: (item['duration'] as String?)?.trim(),
        platform: 'twitch',
        thumbnailUrl: thumbnailUrl,
      );
    } catch (e) {
      debugPrint('[oembed] twitch error: $e');
      return _fetchOpenGraphMetadata(videoUri, platformId: 'twitch');
    }
  }

  static const String _redditBrowserUserAgent =
      'Mozilla/5.0 (iPhone; CPU iPhone OS 17_5 like Mac OS X) '
      'AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.5 '
      'Mobile/15E148 Safari/604.1';

  /// Resout un lien court de partage Reddit (ex:
  /// reddit.com/r/xxx/s/pZnn3jOTh8) vers son URL canonique
  /// (reddit.com/r/xxx/comments/id/titre/) en suivant la redirection
  /// HTTP. Reddit sert une page HTML interstitielle sur ces liens courts,
  /// donc construire ".json" dessus directement echoue toujours. Si
  /// l'URI n'est pas un lien court, ou si la resolution echoue, on
  /// retombe sur l'URI d'origine (comportement inchange).
  static Future<Uri> _resolveRedditShareLink(Uri uri) async {
    if (!uri.pathSegments.contains('s')) return uri;
    HttpClient? client;
    try {
      client = HttpClient();
      client.userAgent = _redditBrowserUserAgent;
      final request = await client.getUrl(uri).timeout(const Duration(seconds: 10));
      final response = await request.close().timeout(const Duration(seconds: 10));
      await response.drain<void>();
      if (response.redirects.isNotEmpty) {
        return response.redirects.last.location;
      }
      return uri;
    } catch (e) {
      debugPrint('[oembed] reddit share-link resolve error: $e');
      return uri;
    } finally {
      client?.close(force: true);
    }
  }

  /// Extrait l'identifiant de video d'un lien TikTok « download-link ».
  ///
  /// TikTok enveloppe une partie de ses partages dans un lien AppsFlyer :
  ///
  ///     https://www.tiktok.com/download-link/ol/bIdt?domain_source=tiktok
  ///         &af_dp=snssdk1233%3A%2F%2Faweme%2Fdetail%2F7669434753547947272
  ///         &deep_link_value=snssdk1233%3A%2F%2Faweme%2Fdetail%2F76694347
  ///
  /// L'oEmbed refuse cette URL (non-200) et `_fetchTikTokMetadata` renvoie
  /// null : le clip reste sans titre, sans auteur et sans miniature, et le
  /// classifieur ne recoit que le mot « TikTok ». Observe en production.
  ///
  /// L'identifiant se trouve dans `af_dp` et `deep_link_value`, sous la
  /// forme `aweme/detail/{id}`. La query brute est balayee en dernier
  /// recours, au cas ou les noms de parametres changeraient.
  ///
  /// Renvoie null si [uri] n'est pas un lien de ce type.
  static bool _isTikTokDownloadLink(Uri uri) {
    final host = uri.host.toLowerCase();
    if (host != 'tiktok.com' && !host.endsWith('.tiktok.com')) return false;
    return uri.pathSegments.contains('download-link');
  }

  /// NE PAS utiliser `canonical` ni `c=video_{id}` ici.
  ///
  /// Ces wrappers portent DEUX identifiants, et il est tentant de croire
  /// que `canonical` designe la video partagee. C'est faux, et verifie
  /// aupres de l'utilisatrice :
  ///
  ///   - `canonical` et `c=video_{id}` designent la PAGE WEB depuis
  ///     laquelle le lien a ete genere ;
  ///   - `click=` et `deep_link_value=snssdk1233://aweme/detail/{id}`
  ///     designent la video sur laquelle l'utilisateur a reellement
  ///     appuye.
  ///
  /// Sur un partage depuis une liste (`action=list_video`,
  /// `tap_target=hot_video`), les deux different : on consulte la page
  /// d'une video, on en partage une autre vue dans la liste. Preferer
  /// `canonical` enregistrerait alors la mauvaise video.
  ///
  /// Ce commentaire existe parce que l'inversion a ete tentee puis
  /// annulee : ne la refaites pas.
  static String? _tiktokVideoIdFromDownloadLink(Uri uri) {
    if (!_isTikTokDownloadLink(uri)) return null;

    final pattern = RegExp(r'aweme/detail/(\d+)');
    final candidates = <String?>[
      uri.queryParameters['af_dp'],
      uri.queryParameters['deep_link_value'],
      uri.query,
    ];

    for (final candidate in candidates) {
      if (candidate == null || candidate.isEmpty) continue;
      // `queryParameters` decode une fois, `query` pas du tout, et
      // certains partages sont doublement encodes : on essaie les
      // differentes formes.
      for (final value in _decodeVariants(candidate)) {
        final match = pattern.firstMatch(value);
        if (match != null) return match.group(1);
      }
    }
    return null;
  }

  /// [raw] accompagne de ses versions decodees, quand le decodage est
  /// possible. Un pourcentage isole ou une sequence invalide fait lever
  /// `Uri.decode*` : dans ce cas on se contente des formes obtenues.
  static Set<String> _decodeVariants(String raw) {
    final variants = <String>{raw};
    try {
      variants.add(Uri.decodeComponent(raw));
    } catch (_) {}
    try {
      variants.add(Uri.decodeFull(raw));
    } catch (_) {}
    return variants;
  }

  /// Resout les liens courts connus vers leur URL canonique, en suivant
  /// la redirection HTTP :
  ///
  ///   - pin.it                     (Pinterest)
  ///   - reddit.com/r/x/s/          (liens de partage Reddit)
  ///   - share.google               (raccourcisseur de partage Google)
  ///   - tiktok.com/download-link/  (wrapper AppsFlyer TikTok)
  ///   - vm./vt.tiktok.com          (liens courts TikTok)
  ///   - tiktok.com/t/xxx           (idem, forme par chemin)
  ///   - lnkd.in                    (liens courts LinkedIn)
  ///
  /// Le resultat sert a la deduplication (isDuplicate), mais aussi —
  /// et c'est essentiel — d'URL stockee pour le clip : dans
  /// `_ingestSharedUrl`, `dedupUrl` alimente `clip.url` ET
  /// `SocialPlatform.detect`. Un lien non resolu se traduit donc par une
  /// plateforme mal detectee et une extraction de metadonnees a cote.
  ///
  /// share.google : observe en production sur des partages TikTok. Non
  /// resolu, le clip etait enregistre en plateforme `other`, le scraping
  /// OpenGraph generique ne ramenait que le <title> de la coquille JS
  /// (« TikTok - Make Your Day ») sans og:image, et le classifieur ne
  /// disposait d'aucun signal exploitable.
  ///
  /// Retombe sur l'URI d'origine si ce n'est pas un lien court connu, ou
  /// si la resolution echoue.
  static Future<Uri> resolveShortLinkForDedup(Uri uri) async {
    // Booking Share (dedup) : chaque partage d'un meme hotel cree un nouveau
    // code Share-xxxx. On le resout vers la fiche, dont la normalisation
    // (clips_state) ignore la langue et les parametres. En cas d'echec, le
    // lien est conserve tel quel.
    if (_isBookingShareLink(uri)) {
      final hotelUrl = await _resolveBookingShareLink(uri);
      return hotelUrl != null ? Uri.parse(hotelUrl) : uri;
    }
    final host = uri.host.toLowerCase();
    final isPinterestShortLink = host == 'pin.it';
    final isRedditShareLink =
        host.endsWith('reddit.com') && uri.pathSegments.contains('s');
    final isGoogleShareLink =
        host == 'share.google' || host.endsWith('.share.google');
    // Lien court LinkedIn : chaque partage genere une URL lnkd.in
    // differente pour la meme video (code de tracking unique par
    // partage). Non resolu, deux partages du meme contenu produisaient
    // deux clips distincts malgre le controle anti-doublon — signale en
    // production par l'utilisatrice.
    final isLinkedInShortLink = host == 'lnkd.in';
    // Liens de partage Facebook et Instagram : code aleatoire a chaque
    // partage (/share/r/.., /share/v/.., /share/reel/.., fb.watch/..).
    // Non resolus, deux partages de la meme video creaient deux clips.
    final firstSegment =
        uri.pathSegments.isNotEmpty ? uri.pathSegments.first : '';
    final isMetaShareLink = host == 'fb.watch' ||
        ((host.endsWith('facebook.com') || host.endsWith('instagram.com')) &&
            firstSegment == 'share');
    // Liens courts TikTok : vm./vt.tiktok.com et tiktok.com/t/xxx.
    // Non resolus, ils cassaient le dedoublonnage : `_tiktokVideoId`
    // cherche un segment `video` dans le chemin, absent de ces formes.
    // La meme video partagee une fois en lien court et une fois en lien
    // complet creait donc deux clips.
    final isTikTokShortLink = host == 'vm.tiktok.com' ||
        host == 'vt.tiktok.com' ||
        (host.endsWith('tiktok.com') &&
            uri.pathSegments.isNotEmpty &&
            uri.pathSegments.first == 't');
    final tiktokDownloadLinkId = _tiktokVideoIdFromDownloadLink(uri);
    if (!isPinterestShortLink &&
        !isRedditShareLink &&
        !isGoogleShareLink &&
        !isTikTokShortLink &&
        !isLinkedInShortLink &&
        !isMetaShareLink &&
        tiktokDownloadLinkId == null) {
      return uri;
    }

    // Cas particulier du wrapper TikTok : l'URL a suivre n'est PAS
    // celle qui a ete partagee. Le lien download-link mene a une page
    // de telechargement de l'application, jamais a la video. On
    // reconstruit donc une URL resolvable a partir de l'identifiant
    // extrait, et c'est elle dont on suit la redirection.
    final Uri target;
    if (tiktokDownloadLinkId != null) {
      target = Uri.parse('https://m.tiktok.com/v/$tiktokDownloadLinkId.html');
      debugPrint(
        '[shortlink] wrapper TikTok deballe : id=$tiktokDownloadLinkId',
      );
    } else {
      target = uri;
    }

    HttpClient? client;
    try {
      client = HttpClient();
      client.userAgent = _redditBrowserUserAgent;
      final request =
          await client.getUrl(target).timeout(const Duration(seconds: 10));
      final response = await request.close().timeout(const Duration(seconds: 10));
      await response.drain<void>();
      if (response.redirects.isNotEmpty) {
        final resolved = response.redirects.last.location;
        // Garde-fou : certaines redirections pointent vers un schema
        // d'application (snssdk1233://aweme/detail/...) ou vers une
        // cible sans hote. Remplacer l'URL d'origine par ce genre de
        // valeur casserait la detection de plateforme et l'ouverture du
        // lien : on prefere conserver l'URL d'origine.
        final scheme = resolved.scheme.toLowerCase();
        // Page de connexion (Facebook, Instagram sans session) : ce n'est
        // pas le contenu, on garde l'URL partagee.
        final landsOnLogin = resolved.pathSegments.any((s) =>
            s == 'login' || s == 'login.php' || s == 'checkpoint');
        if (landsOnLogin) {
          debugPrint('[shortlink] ${uri.host} -> page de connexion, '
              'URL partagee conservee');
          return uri;
        }
        if ((scheme == 'http' || scheme == 'https') &&
            resolved.host.isNotEmpty) {
          final canonical = _canonicalPinterestPinUrl(resolved);
          if (canonical != null) {
            debugPrint('[shortlink] ${uri.host} -> $canonical (epingle canonique)');
            return canonical;
          }
          debugPrint('[shortlink] ${uri.host} -> $resolved');
          return resolved;
        }
        debugPrint(
          '[shortlink] ${uri.host} -> cible inexploitable ($resolved)',
        );
      }
      if (tiktokDownloadLinkId != null) {
        debugPrint(
          '[shortlink] wrapper TikTok non resolu '
          '(id=$tiktokDownloadLinkId) -- URL partagee conservee',
        );
      }
      return uri;
    } catch (e) {
      debugPrint('[oembed] short-link dedup resolve error: $e');
      return uri;
    } finally {
      client?.close(force: true);
    }
  }

  /// Titres renvoyes par la coquille JavaScript d'une plateforme quand le
  /// contenu n'a pas pu etre rendu : video supprimee, privee, bloquee
  /// geographiquement, ou simple refus anti-bot.
  ///
  /// Ils DOIVENT etre traites comme un titre absent. Sinon l'hydratation
  /// ecrase le titre existant du clip par « TikTok - Make Your Day », puis
  /// lance une classification sur cette chaine vide de sens — observe en
  /// production : `cat_humour, confiance 25`.
  static const Set<String> _placeholderTitles = {
    'tiktok - make your day',
    'tiktok',
    'instagram',
    'instagram video',
    'facebook',
    'facebook watch',
    'watch',
    'reddit - dive into anything',
    'reddit - the heart of the internet',
    'log into facebook', 'log in to facebook', 'instagram - login',
    'reddit',
    'pinterest',
    'video',
    'log in or sign up to view',
    'page not found',
    'content not available',
    // Ajoutes apres coup : quand l'API Helix echoue, l'og:title de Twitch
    // vaut litteralement « Twitch ». Le classifieur etait quand meme
    // appele et repondait « cat_gaming, confiance 95 » sur ce seul mot.
    // Les autres noms de plateformes sont ajoutes par symetrie, le meme
    // scenario pouvant se produire partout.
    'twitch', 'vimeo', 'youtube', 'linkedin', 'twitter',
    'apple music', 'spotify',
    // Nom de plateforme par defaut d'un lien web sans titre : sans cela il
    // passait pour un vrai titre et l'apercu Safari n'etait jamais tente.
    'autre', 'other',
  };

  /// Images generiques servies par une plateforme quand elle n'a pas de
  /// visuel a proposer : logo maison, image par defaut.
  ///
  /// Les retenir comme miniature est pire que de n'en avoir aucune : la
  /// carte parait remplie, le pre-cache les stocke, et la passe de
  /// reparation ne les reprend jamais puisque `thumbnailUrl` n'est pas
  /// vide. Observe sur Twitch : `ttv-static-metadata/twitch_logo3.jpg`.
  static const List<String> _genericImageMarkers = [
    'ttv-static-metadata/twitch_logo',
    '/twitch_logo',
    // LinkedIn sert son logo de marque quand la page ne rend pas le
    // contenu du post. Les vraies images viennent de `media.licdn.com`
    // (photos) et `dms.licdn.com` (miniatures video) ; `static.licdn.com`
    // n'heberge que les elements d'interface du site.
    //
    // Mesure sur un export reel : 5 clips LinkedIn sur 11 portaient une
    // image `static.licdn.com`, affichee comme un logo a la place de la
    // video. Ecartee, la vignette redevient vide — donc le clip redevient
    // eligible a la passe de reparation, qui retentera l'extraction.
    'static.licdn.com',
  ];

  /// Sites reconnus comme boutiques (page produit : og:type produit, prix,
  /// JSON-LD Product). Retenus d'une session a l'autre.
  static final Set<String> _shopHosts = <String>{};
  static Future<void>? _shopHostsLoading;
  static const String _shopHostsKey = 'shop_hosts';

  static String _shopKey(String host) {
    var h = host.toLowerCase();
    if (h.startsWith('www.')) h = h.substring(4);
    return h;
  }

  static Future<void> loadShopHosts() => _shopHostsLoading ??= _doLoadShopHosts();

  static Future<void> _doLoadShopHosts() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _shopHosts.addAll(prefs.getStringList(_shopHostsKey) ?? const <String>[]);
    } catch (_) {}
  }

  static Future<void> markShopHost(String host) async {
    await loadShopHosts();
    final key = _shopKey(host);
    if (key.isEmpty || !_shopHosts.add(key)) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_shopHostsKey, _shopHosts.toList());
    } catch (_) {}
  }

  static bool isShopHost(String host) => _shopHosts.contains(_shopKey(host));

  static bool _isGenericPlatformImage(String url) {
    final lower = url.toLowerCase();
    // Un logo (logo_casino.png, auchan-logo-desktop.svg) n'est pas la photo
    // du contenu : mieux vaut aucune vignette (apercu, capture ensuite).
    if (RegExp(r'(^|[/_.-])logo([/_.-]|$)')
        .hasMatch(Uri.tryParse(lower)?.path ?? lower)) {
      return true;
    }
    // Un .svg est un logo ou une icone, jamais une photo : l'app ne sait
    // pas l'afficher comme miniature (observe sur auchan.fr).
    final path = Uri.tryParse(lower)?.path ?? lower;
    if (path.endsWith('.svg')) return true;
    return _genericImageMarkers.any(lower.contains);
  }

  /// Vrai si [title] est vide ou n'est qu'un titre de coquille (cf.
  /// [_placeholderTitles]) : dans les deux cas, aucune information utile.
  /// Titre lisible tire du chemin de [url], ou null. Dernier recours pour
  /// un lien web dont la page n'a rien renvoye (anti-robot) :
  /// fnac.com/a23256587/Rebecca-Yarros-Fourth-wing-titre-a-venir donne
  /// « Rebecca Yarros Fourth wing titre a venir ». Le segment retenu est
  /// celui qui porte le plus de mots ; les identifiants (a23256587,
  /// 26Q62X45A1CD) et les nombres sont ignores. Au moins deux mots exiges.
  static String? titleFromUrlPath(String url) {
    final uri = Uri.tryParse(url.trim());
    if (uri == null) return null;
    List<String> best = const [];
    for (final raw in uri.pathSegments) {
      var segment = raw;
      try {
        segment = Uri.decodeComponent(segment);
      } catch (_) {}
      segment = segment.replaceFirst(
          RegExp(r'\.(html?|php|aspx?|jsp)$', caseSensitive: false), '');
      final words = segment
          .split(RegExp(r'[-_+.\s]+'))
          .where((w) =>
              w.isNotEmpty &&
              RegExp(r'[A-Za-zÀ-ÿ]').hasMatch(w) &&
              !RegExp(r'\d').hasMatch(w))
          .toList();
      if (words.length > best.length) best = words;
    }
    if (best.length < 2) return null;
    final title = best.join(' ');
    return title[0].toUpperCase() + title.substring(1);
  }

  static bool isPlaceholderTitle(String? title) {
    final t = title?.trim().toLowerCase();
    if (t == null || t.isEmpty) return true;
    return _placeholderTitles.contains(t);
  }

  /// Segments de langue/region que certaines plateformes inserent en tete
  /// de chemin : tiktok.com/fr/, tiktok.com/en/@user/video/123.
  static const Set<String> _localePathSegments = {
    'fr', 'en', 'es', 'de', 'it', 'pt', 'nl', 'pl', 'ru', 'tr', 'ja', 'ko',
    'zh', 'ar', 'sv', 'da', 'no', 'fi', 'cs', 'el', 'he', 'hi', 'id', 'th',
    'vi', 'uk', 'ro', 'hu',
    'fr-fr', 'en-us', 'en-gb', 'es-es', 'es-mx', 'pt-br', 'pt-pt', 'de-de',
    'it-it', 'nl-nl', 'zh-cn', 'zh-tw', 'ja-jp', 'ko-kr',
  };

  /// Premiers segments de chemin qui designent une page de navigation (flux,
  /// recherche, reglages) et jamais un contenu precis, par domaine.
  ///
  /// Liste volontairement courte : on n'y met que des segments dont on est
  /// certain qu'ils ne peuvent pas mener a une video.
  static const Map<String, Set<String>> _navigationFirstSegments = {
    'tiktok.com': {
      'foryou', 'following', 'friends', 'explore', 'upload', 'messages',
      'search', 'discover', 'live', 'activity', 'setting', 'coin',
    },
    'instagram.com': {'explore', 'accounts', 'direct', 'your_activity'},
    'youtube.com': {'feed', 'results', 'account', 'playlists'},
    'facebook.com': {'watch', 'marketplace', 'notifications', 'friends'},
    'reddit.com': {'popular', 'all', 'search', 'submit', 'settings'},
    'pinterest.com': {'search', 'today', 'ideas'},
    'x.com': {'home', 'explore', 'notifications', 'messages', 'search'},
    'twitter.com': {'home', 'explore', 'notifications', 'messages', 'search'},
    'linkedin.com': {'feed', 'mynetwork', 'jobs', 'messaging'},
  };

  /// Segments qui, presents plus loin dans le chemin, prouvent qu'une URL
  /// designe malgre tout un contenu precis (ex. instagram.com/explore/reels/ABC/).
  static const Set<String> _contentPathMarkers = {
    'video', 'reel', 'reels', 'p', 'tv', 'shorts', 'watch', 'comments',
    'status', 'clip', 'clips', 'pin', 'v', 't', 'photo', 'embed',
    // `update` : LinkedIn publie ses posts sous
    // linkedin.com/feed/update/urn:li:activity:... — c'est exactement le
    // lien que donne « copier le lien du post ». Sans ce marqueur, le
    // segment `feed` faisait rejeter un partage parfaitement legitime.
    'update', 'posts', 'live',
  };

  /// Parametres de requete qui portent un identifiant de contenu.
  ///
  /// Distinguer ceux-la des autres est indispensable : la premiere version
  /// considerait que TOUT parametre rendait une URL exploitable, ce qui
  /// laissait passer `tiktok.com/foryou?lang=fr` — observe en production.
  /// Or TikTok ajoute `?is_from_webapp=1&sender_device=pc` a chacun de ses
  /// partages : sans cette distinction, le garde-fou etait contournable
  /// par n'importe quel lien de flux partage depuis l'application.
  static const Set<String> _contentQueryKeys = {
    'v', 'id', 'vid', 'video_id', 'story_fbid', 'fbid', 'photo_id', 'clip',
  };

  static bool _hasContentQuery(Uri uri) => uri.queryParameters.keys
      .any((k) => _contentQueryKeys.contains(k.toLowerCase()));

  /// Parametres qui signent une URL de miniature et lui donnent une duree
  /// de vie limitee. Passe ce delai, l'URL renvoie 403 et l'image est
  /// definitivement perdue si elle n'a pas ete mise en cache localement.
  ///
  ///   - x-expires / x-signature : TikTok (~24 h)
  ///   - oe= / _nc_ohc          : Instagram et Facebook (fbcdn, cdninstagram)
  ///   - expires / token        : forme generique
  static const Set<String> _expiringQueryKeys = {
    'x-expires',
    'x-signature',
    '_nc_ohc',
    'oe',
    'oh',
    'expires',
    'token',
  };

  /// Vrai si [url] est une miniature signee, donc perissable.
  ///
  /// Sert a reperer les clips dont la vignette est morte : ils ont un
  /// `thumbnailUrl` non vide — donc echappaient a la passe de reparation —
  /// mais l'URL ne repond plus et aucun fichier local ne subsiste.
  ///
  /// On inspecte les CLES de requete plutot que des sous-chaines, pour
  /// deux raisons :
  ///   - une recherche de « oe= » dans l'URL brute produirait des faux
  ///     positifs ;
  ///   - surtout, `bestThumbnailUrl` proxifie Facebook, Reddit et
  ///     Pinterest : l'URL d'origine y est encodee dans le parametre
  ///     `url`, ou « oe= » devient « oe%3D ». Une recherche textuelle
  ///     n'aurait jamais rien detecte sur ces trois plateformes.
  static bool isExpiringThumbnailUrl(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null) return false;
    if (_hasExpiringKey(uri)) return true;
    // Cas proxifie : on regarde l'URL d'origine, que Uri decode seul.
    final inner = uri.queryParameters['url'];
    if (inner == null || inner.isEmpty) return false;
    final innerUri = Uri.tryParse(inner);
    return innerUri != null && _hasExpiringKey(innerUri);
  }

  static bool _hasExpiringKey(Uri uri) => uri.queryParameters.keys
      .any((k) => _expiringQueryKeys.contains(k.toLowerCase()));

  /// Vrai si [url] ne peut designer aucun contenu precis : URL non
  /// analysable, page d'accueil d'une plateforme, ou page de navigation
  /// (« Pour toi », recherche, explorer, messagerie...).
  ///
  /// Sert de garde-fou a l'ingestion : ces URLs creaient jusqu'ici une
  /// carte vide ET consommaient une unite du quota gratuit a vie, que
  /// l'utilisateur ne pouvait pas recuperer.
  ///
  /// Volontairement conservateur : en cas de doute, renvoie `false` et
  /// l'URL est acceptee. Un faux positif empecherait d'enregistrer une
  /// video legitime — bien pire qu'une carte vide occasionnelle.
  static bool isContentlessUrl(String url) {
    final uri = _parseHttpUri(url.trim());
    if (uri == null) return true;

    var segments =
        uri.pathSegments.where((s) => s.trim().isNotEmpty).toList();
    if (segments.isNotEmpty &&
        _localePathSegments.contains(segments.first.toLowerCase())) {
      segments = segments.sublist(1);
    }

    // Page d'accueil : aucun segment utile, et aucun parametre portant un
    // identifiant de contenu (youtube.com/?v=abc reste exploitable).
    if (segments.isEmpty) {
      // Site quelconque (hors plateformes connues) : sa page d'accueil est
      // un lien legitime (journal, boutique, restaurant...). La regle ne
      // vaut que pour les reseaux sociaux, ou l'accueil n'est qu'un flux.
      if (SocialPlatform.detect(url).id == 'other') return false;
      return !_hasContentQuery(uri);
    }

    final host = uri.host.toLowerCase();
    final first = segments.first.toLowerCase();

    // Cas particulier Reddit : les flux globaux ont le segment de
    // navigation en deuxieme position (/r/popular, /r/all). Un vrai post
    // porte toujours /comments/ ensuite, d'ou la restriction a 2 segments.
    if ((host == 'reddit.com' || host.endsWith('.reddit.com')) &&
        first == 'r' &&
        segments.length == 2 &&
        const {'popular', 'all'}.contains(segments[1].toLowerCase())) {
      return true;
    }

    for (final entry in _navigationFirstSegments.entries) {
      final domain = entry.key;
      if (host != domain && !host.endsWith('.$domain')) continue;
      if (!entry.value.contains(first)) continue;
      // Un marqueur de contenu plus loin dans le chemin rend la page
      // exploitable malgre un premier segment de navigation.
      final rest = segments.skip(1).map((s) => s.toLowerCase());
      if (rest.any(_contentPathMarkers.contains)) return false;
      // Idem si l'identifiant est passe en query (facebook.com/watch/?v=).
      // Un `?lang=fr` ou `?is_from_webapp=1` ne compte pas.
      if (_hasContentQuery(uri)) return false;
      return true;
    }
    return false;
  }

  /// Ramene une URL Pinterest a la page canonique de l'epingle.
  ///
  /// `pin.it` ne redirige pas vers l'epingle mais vers une page
  /// d'invitation personnalisee :
  ///   `fr.pinterest.com/pin/<id>/sent/?invite_code=...&sender=<compte>`
  ///
  /// Deux consequences mesurees en production :
  ///   - cette page ne porte pas d'`og:description`, donc l'extraction
  ///     retombe sur l'`og:title` generique et localise (« Decouvrez cette
  ///     Epingle de `<prenom>` »). Le classifieur repondait 25 a 35 de
  ///     confiance et les epingles restaient a trier ;
  ///   - l'identifiant du compte Pinterest de l'utilisateur (`sender`)
  ///     etait stocke en base et repris dans les exports CSV.
  ///
  /// Le dedoublonnage, lui, n'etait pas affecte : `_canonicalVideoUrl`
  /// extrait deja `pinterest:<id>` du chemin.
  ///
  /// Renvoie `null` si [uri] n'est pas une epingle Pinterest, auquel cas
  /// l'appelant conserve l'URL telle quelle.
  static Uri? _canonicalPinterestPinUrl(Uri uri) {
    final host = uri.host.toLowerCase();
    if (host != 'pinterest.com' && !host.endsWith('.pinterest.com')) {
      return null;
    }
    final segments = uri.pathSegments.where((s) => s.isNotEmpty).toList();
    final pinIndex = segments.indexOf('pin');
    if (pinIndex == -1 || pinIndex + 1 >= segments.length) return null;
    final pinId = segments[pinIndex + 1];
    if (pinId.isEmpty || int.tryParse(pinId) == null) return null;
    // Deja canonique : ne rien changer, et surtout ne pas signaler un
    // changement qui n'en est pas un.
    if (segments.length == pinIndex + 2 && uri.query.isEmpty) return null;
    return Uri(scheme: uri.scheme, host: uri.host, path: '/pin/$pinId/');
  }

  static Future<VideoData?> _fetchRedditMetadata(Uri videoUri) async {
    final resolvedUri = await _resolveRedditShareLink(videoUri);
    try {
      var path = resolvedUri.path;
      if (!path.endsWith('/')) path = '$path/';
      final jsonUri = Uri.https('www.reddit.com', '$path.json');
      final response = await Net.client.get(
        jsonUri,
        headers: {
          'User-Agent': _redditBrowserUserAgent,
          'Accept': 'application/json',
        },
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) {
        return _fetchOpenGraphMetadata(resolvedUri, platformId: 'reddit');
      }

      final decoded = json.decode(response.body);
      if (decoded is! List || decoded.isEmpty) {
        return _fetchOpenGraphMetadata(resolvedUri, platformId: 'reddit');
      }
      final listing = decoded[0] as Map<String, dynamic>;
      final children = listing['data']?['children'] as List<dynamic>?;
      if (children == null || children.isEmpty) {
        return _fetchOpenGraphMetadata(resolvedUri, platformId: 'reddit');
      }
      final postData = (children.first as Map<String, dynamic>)['data'] as Map<String, dynamic>?;
      if (postData == null) {
        return _fetchOpenGraphMetadata(resolvedUri, platformId: 'reddit');
      }

      final title = (postData['title'] as String?)?.trim();
      if (title == null || title.isEmpty) {
        return _fetchOpenGraphMetadata(resolvedUri, platformId: 'reddit');
      }
      final subreddit = (postData['subreddit'] as String?)?.trim();

      String? thumb;
      try {
        final preview = postData['preview'] as Map<String, dynamic>?;
        final images = preview?['images'] as List<dynamic>?;
        if (images != null && images.isNotEmpty) {
          final source = (images.first as Map<String, dynamic>)['source'] as Map<String, dynamic>?;
          thumb = source?['url'] as String?;
        }
      } catch (_) {}
      if (thumb == null) {
        final rawThumb = postData['thumbnail'] as String?;
        if (rawThumb != null && rawThumb.startsWith('http')) {
          thumb = rawThumb;
        }
      }

      return VideoData(
        title: title,
        channel: (subreddit != null && subreddit.isNotEmpty) ? 'r/$subreddit' : null,
        description: (subreddit != null && subreddit.isNotEmpty) ? 'Subreddit: r/$subreddit' : null,
        platform: 'reddit',
        thumbnailUrl: _sanitizeMediaUrl(thumb),
      );
    } catch (e) {
      debugPrint('[oembed] reddit error: $e');
      return _fetchOpenGraphMetadata(resolvedUri, platformId: 'reddit');
    }
  }

  /// Prefixes de sous-domaine mobile qui servent une coquille JavaScript
  /// au lieu des balises OpenGraph.
  ///
  /// Observe en production sur `m.facebook.com` : un Reel y renvoie le
  /// titre « Facebook » et aucun `og:image`, alors que le meme contenu sur
  /// `www.facebook.com` renvoie titre complet et vignette.
  ///
  /// Seuls `m.` et `mobile.` sont concernes. Les sous-domaines de langue
  /// (`fr.pinterest.com`...) servent des metadonnees correctes et ne
  /// doivent surtout pas etre reecrits.
  static const List<String> _mobileHostPrefixes = ['m.', 'mobile.'];

  /// Variante « bureau » d'une URL, pour la REQUETE d'extraction seulement.
  ///
  /// L'URL stockee reste celle partagee par l'utilisateur : la carte doit
  /// continuer d'ouvrir la version mobile sur telephone.
  static Uri _desktopVariantForScraping(Uri uri) {
    final host = uri.host.toLowerCase();
    for (final prefix in _mobileHostPrefixes) {
      if (!host.startsWith(prefix)) continue;
      final rest = host.substring(prefix.length);
      // Garde-fou : `m.me` (liens Messenger) donnerait « www.me ».
      // On n'accepte que ce qui reste un nom de domaine complet.
      if (!rest.contains('.')) continue;
      return uri.replace(host: 'www.$rest');
    }
    return uri;
  }

  static Future<VideoData?> _fetchOpenGraphMetadata(
    Uri originalUri, {
    required String platformId,
    bool previewBotUserAgent = false,
  }) async {
    final uri = _desktopVariantForScraping(originalUri);
    if (uri != originalUri) {
      debugPrint('[oembed] scraping sur ${uri.host} au lieu de ${originalUri.host}');
    }
    try {
      // Pinterest et Reddit renvoient des erreurs / pages anti-bot avec
      // l'en-tete User-Agent generique utilise pour les autres
      // plateformes (probablement un blocage anti-bot ou un plantage de
      // rendu cote serveur quand la requete ne ressemble pas assez a un
      // vrai navigateur). En-tetes plus complets pour ces deux
      // plateformes, sans toucher aux autres.
      // TikTok ajoute a la liste : son oEmbed etrangle les rafales non
      // authentifiees, et la page repond mal a une requete qui ne ressemble
      // pas a un vrai navigateur. Meme raison que Pinterest et Reddit.
      final needsRealisticHeaders = platformId == 'pinterest' ||
          platformId == 'reddit' ||
          platformId == 'tiktok';
      final response = await Net.client.get(
        uri,
        headers: previewBotUserAgent
            ? const {
                'User-Agent': 'facebookexternalhit/1.1',
                'Accept': 'text/html,application/xhtml+xml',
              }
            : needsRealisticHeaders
            ? {
                'User-Agent':
                    'Mozilla/5.0 (iPhone; CPU iPhone OS 17_5 like Mac OS X) '
                    'AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.5 '
                    'Mobile/15E148 Safari/604.1',
                'Accept':
                    'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
                'Accept-Language': 'fr-FR,fr;q=0.9,en;q=0.8',
              }
            : {
                'User-Agent': 'Mozilla/5.0 (compatible; Reelr/1.0)',
                'Accept': 'text/html,application/xhtml+xml',
              },
      ).timeout(const Duration(seconds: 10));
      if (response.statusCode != 200) {
        return null;
      }

      final body = utf8.decode(response.bodyBytes, allowMalformed: true);
      final ogTitle = _extractMetaContent(body, property: 'og:title') ??
          _extractMetaContent(body, name: 'twitter:title') ??
          _extractHtmlTitle(body);
      // Pinterest sert un og:title generique et localise ("Decouvrez
      // cette Epingle de <auteur>") qui ne decrit jamais le contenu
      // reel du pin. Le vrai texte (legende de l'auteur) est dans
      // og:description, quand elle existe.
      final rawDescription = _extractMetaContent(body, property: 'og:description') ??
          _extractMetaContent(body, name: 'twitter:description') ??
          _extractMetaContent(body, name: 'description');
      // Pinterest prefixe desormais sa description d'une date de
      // publication (« Aug 29, 2026 — … », « 6 jul 2026 — … ») : sans
      // interet sur une carte, et du bruit pour le classement.
      final ogDescription = platformId == 'pinterest' && rawDescription != null
          ? rawDescription.replaceFirst(_leadingDatePrefix, '')
          : null;
      final title = (ogDescription != null && ogDescription.trim().isNotEmpty)
          ? ogDescription
          : ogTitle;
      final thumb = _extractMetaContent(body, property: 'og:image') ??
          _extractMetaContent(body, property: 'og:image:url') ??
          _extractMetaContent(body, name: 'twitter:image') ??
          _extractMetaContent(body, name: 'twitter:image:src') ??
          (platformId == 'other' ? _extractFallbackImage(body) : null);
      final channel = _extractMetaContent(body, property: 'og:site_name');
      // Page produit (boutique) : og:type produit, prix en balise meta ou
      // JSON-LD Product. Le site est retenu comme boutique.
      if (platformId == 'other') {
        final ogType =
            (_extractMetaContent(body, property: 'og:type') ?? '').toLowerCase();
        final isProductPage = ogType.contains('product') ||
            ogType.contains('produit') ||
            _extractMetaContent(body, property: 'product:price:amount') != null ||
            _extractMetaContent(body, property: 'og:price:amount') != null ||
            RegExp(r'"@type"\s*:\s*\[?\s*"Product"').hasMatch(body);
        if (isProductPage) {
          debugPrint('[oembed] page produit -> boutique ${uri.host}');
          markShopHost(uri.host).ignore();
        }
      }

      var cleanedTitle = (title ?? '').trim();
      // og:image relative (« //cdn.shopify.com/... », « /files/x.jpg ») :
      // frequent sur les pages de vente. Resolue contre l'URL de la page
      // au lieu d'etre rejetee faute de schema.
      String? absoluteThumb = thumb;
      if (thumb != null) {
        final t = _decodeHtmlEntities(thumb.trim());
        if (t.isNotEmpty && !t.toLowerCase().startsWith('http')) {
          try {
            absoluteThumb = uri.resolve(t).toString();
          } catch (_) {}
        }
      }
      var cleanedThumb = _sanitizeMediaUrl(absoluteThumb);
      // Un logo de plateforme n'est pas une miniature (cf.
      // _genericImageMarkers) : mieux vaut aucune vignette, le clip reste
      // alors eligible a la passe de reparation.
      if (cleanedThumb != null && _isGenericPlatformImage(cleanedThumb)) {
        debugPrint('[oembed] image generique ignoree: $cleanedThumb');
        cleanedThumb = null;
      }
      final lowerTitle = cleanedTitle.toLowerCase();
      if (lowerTitle.contains('please wait') ||
          lowerTitle.contains('verification') ||
          lowerTitle.contains('prove your humanity') ||
          lowerTitle.contains('just a moment')) {
        cleanedTitle = '';
      }

      if (cleanedTitle.isEmpty && cleanedThumb == null && (channel ?? '').trim().isEmpty) {
        return null;
      }

      // Le corps HTML est deja telecharge : recuperer la description ne coute
      // aucune requete supplementaire. Garde-fou Pinterest : og:description y
      // sert deja de titre (voir plus haut), on ne la renvoie pas deux fois.
      final cleanedDescription = (rawDescription ?? '').trim();
      final usableDescription =
          cleanedDescription.isEmpty || cleanedDescription == cleanedTitle
              ? null
              : cleanedDescription;

      return VideoData(
        title: cleanedTitle.isEmpty ? SocialPlatform.detect(uri.toString()).name : cleanedTitle,
        channel: (channel ?? '').trim().isEmpty ? null : channel!.trim(),
        platform: platformId,
        thumbnailUrl: cleanedThumb,
        description: usableDescription,
      );
    } catch (e) {
      debugPrint('[oembed] og error: $e');
      return null;
    }
  }

  /// Date en tete de texte suivie d'un tiret : « 29 Jul 2026 — »,
  /// « Aug 29, 2026 — », « 6 jul. 2026 - ».
  static final RegExp _leadingDatePrefix = RegExp(
    r'^\s*(?:\d{1,2}\s+\p{L}+\.?\s+\d{4}|\p{L}+\.?\s+\d{1,2},?\s+\d{4})\s*[—–-]\s*',
    unicode: true,
  );

  static String? _extractMetaContent(
    String html, {
    String? property,
    String? name,
  }) {
    final key = property ?? name;
    if (key == null) return null;

    final escapedKey = RegExp.escape(key);
    final patternA = RegExp(
      '<meta[^>]+(?:property|name)=["\']$escapedKey["\'][^>]+content=(["\'])((?:(?!\\1)[\\s\\S])+)\\1',
      caseSensitive: false,
    );
    final patternB = RegExp(
      '<meta[^>]+content=(["\'])((?:(?!\\1)[\\s\\S])+)\\1[^>]+(?:property|name)=["\']$escapedKey["\']',
      caseSensitive: false,
    );

    final match = patternA.firstMatch(html) ?? patternB.firstMatch(html);
    if (match == null) return null;
    return _decodeHtmlEntities(match.group(2)?.trim() ?? '');
  }

  /// Image de secours pour un site quelconque sans og:image ni
  /// twitter:image. Cherche dans l'ordre : <link rel="image_src">,
  /// <meta itemprop="image">, puis le champ "image" des donnees structurees
  /// JSON-LD (fiches produit, recettes, articles). Renvoie null si rien.
  static String? _extractFallbackImage(String html) {
    final linkSrc = RegExp(
      r'<link[^>]+rel=["\x27]image_src["\x27][^>]+href=["\x27]([^"\x27]+)["\x27]',
      caseSensitive: false,
    ).firstMatch(html)?.group(1)?.trim();
    if (linkSrc != null && linkSrc.isNotEmpty) {
      return _decodeHtmlEntities(linkSrc);
    }
    final itemprop = RegExp(
      r'<meta[^>]+itemprop=["\x27]image["\x27][^>]+content=["\x27]([^"\x27]+)["\x27]',
      caseSensitive: false,
    ).firstMatch(html)?.group(1)?.trim();
    if (itemprop != null && itemprop.isNotEmpty) {
      return _decodeHtmlEntities(itemprop);
    }
    final ldBlocks = RegExp(
      r'<script[^>]+type=["\x27]application/ld\+json["\x27][^>]*>([\s\S]*?)</script>',
      caseSensitive: false,
    ).allMatches(html);
    final imageField = RegExp(
      r'"image"\s*:\s*(?:\[\s*)?(?:\{[^}]*?"url"\s*:\s*)?"(https?:[^"]+)"',
    );
    for (final block in ldBlocks) {
      final m = imageField.firstMatch(block.group(1) ?? '');
      if (m != null) return m.group(1)!.replaceAll(r'\/', '/');
    }
    return null;
  }

  static String? _extractHtmlTitle(String html) {
    final match = RegExp(
      r'<title[^>]*>([^<]+)</title>',
      caseSensitive: false,
    ).firstMatch(html);
    if (match == null) return null;
    return _decodeHtmlEntities(match.group(1)?.trim() ?? '');
  }

  static Uri? _parseHttpUri(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null || !uri.hasScheme) return null;
    final scheme = uri.scheme.toLowerCase();
    if (scheme != 'http' && scheme != 'https') return null;
    if (uri.host.isEmpty) return null;
    return uri;
  }

  static String? _youtubeVideoIdFromUrl(String url) {
    final uri = _parseHttpUri(url);
    if (uri == null) return null;
    return _youtubeVideoIdFromUri(uri);
  }

  static String? _youtubeVideoIdFromUri(Uri uri) {
    final host = uri.host.toLowerCase();
    if (host.contains('youtu.be')) {
      return uri.pathSegments.isNotEmpty ? uri.pathSegments.first : null;
    }

    final segments = uri.pathSegments;
    if (segments.contains('live')) {
      final index = segments.indexOf('live');
      if (index + 1 < segments.length) return segments[index + 1];
    }
    if (segments.contains('shorts')) {
      final index = segments.indexOf('shorts');
      if (index + 1 < segments.length) return segments[index + 1];
    }
    if (segments.contains('embed')) {
      final index = segments.indexOf('embed');
      if (index + 1 < segments.length) return segments[index + 1];
    }

    final videoId = uri.queryParameters['v'];
    if (videoId != null && videoId.isNotEmpty) return videoId;
    return null;
  }

  static String? _twitchVideoIdFromUri(Uri uri) {
    final host = uri.host.toLowerCase();
    if (!host.contains('twitch.tv')) return null;

    final segments = uri.pathSegments.where((segment) => segment.isNotEmpty).toList();
    if (segments.length >= 2 && segments.first == 'videos') {
      return segments[1].trim().isEmpty ? null : segments[1].trim();
    }
    return null;
  }

  static String? _twitchClipIdFromUri(Uri uri) {
    final host = uri.host.toLowerCase();
    final segments = uri.pathSegments.where((segment) => segment.isNotEmpty).toList();

    if (host == 'clips.twitch.tv') {
      if (segments.isEmpty) return null;
      final clipId = segments.first.trim();
      return clipId.isEmpty ? null : clipId;
    }

    if (host.contains('twitch.tv')) {
      final clipIndex = segments.indexOf('clip');
      if (clipIndex != -1 && clipIndex + 1 < segments.length) {
        final clipId = segments[clipIndex + 1].trim();
        return clipId.isEmpty ? null : clipId;
      }
    }

    return null;
  }

  static String _filenameTitle(String raw) {
    final uri = Uri.tryParse(raw);
    final source = (uri?.pathSegments.isNotEmpty ?? false)
        ? uri!.pathSegments.last
        : raw.split(RegExp(r'[\\/]')).last;
    final decoded = Uri.decodeComponent(source);
    final withoutExtension = decoded.replaceFirst(RegExp(r'\.[^.]+$'), '');
    final normalized = withoutExtension
        .replaceAll(RegExp(r'[_-]+'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    return normalized.isEmpty ? 'Upload' : normalized;
  }

  static String? _sanitizeMediaUrl(String? raw) {
    if (raw == null) return null;
    final cleaned = _decodeHtmlEntities(raw.trim());
    final uri = Uri.tryParse(cleaned);
    if (uri == null || !uri.hasScheme) return null;
    final scheme = uri.scheme.toLowerCase();
    if (scheme != 'http' && scheme != 'https') return null;
    if (uri.host.isEmpty) return null;
    return cleaned;
  }

  /// Décode les entités HTML, en repassant tant que le texte change.
  ///
  /// Un seul passage ne suffit pas : LinkedIn sert des titres DOUBLEMENT
  /// encodés. « & » y arrive sous la forme `&amp;amp;`, qu'un décodage
  /// unique transforme en `&amp;` — visible tel quel par l'utilisateur.
  /// Observé sur « INA mediapro &amp; mediaclip ».
  ///
  /// Trois passages au maximum : au-delà, on est soit sur du texte qui
  /// contient légitimement « &amp; », soit sur une chaîne construite pour
  /// boucler. Dans les deux cas, mieux vaut s'arrêter.
  static String _decodeHtmlEntities(String s) {
    var out = s;
    for (var i = 0; i < 3; i++) {
      final next = _decodeHtmlEntitiesOnce(out);
      if (next == out) break;
      out = next;
    }
    return out;
  }

  /// Entites HTML nommees courantes (accents, guillemets, symboles).
  /// Une entite inconnue est laissee telle quelle.
  static const Map<String, String> _namedHtmlEntities = {
    'eacute': 'é', 'egrave': 'è', 'ecirc': 'ê', 'euml': 'ë',
    'agrave': 'à', 'aacute': 'á', 'acirc': 'â', 'auml': 'ä',
    'atilde': 'ã', 'aring': 'å', 'ccedil': 'ç', 'icirc': 'î',
    'iuml': 'ï', 'iacute': 'í', 'igrave': 'ì', 'ocirc': 'ô',
    'ouml': 'ö', 'oacute': 'ó', 'ograve': 'ò', 'otilde': 'õ',
    'ucirc': 'û', 'ugrave': 'ù', 'uuml': 'ü', 'uacute': 'ú',
    'yuml': 'ÿ', 'ntilde': 'ñ', 'oelig': 'œ', 'aelig': 'æ',
    'szlig': 'ß', 'Eacute': 'É', 'Egrave': 'È', 'Ecirc': 'Ê',
    'Euml': 'Ë', 'Agrave': 'À', 'Aacute': 'Á', 'Acirc': 'Â',
    'Auml': 'Ä', 'Ccedil': 'Ç', 'Icirc': 'Î', 'Iuml': 'Ï',
    'Ocirc': 'Ô', 'Ouml': 'Ö', 'Ucirc': 'Û', 'Ugrave': 'Ù',
    'Uuml': 'Ü', 'Ntilde': 'Ñ', 'OElig': 'Œ', 'AElig': 'Æ',
    'rsquo': '’', 'lsquo': '‘', 'rdquo': '”', 'ldquo': '“',
    'laquo': '«', 'raquo': '»', 'hellip': '…', 'ndash': '–',
    'mdash': '—', 'euro': '€', 'copy': '©', 'reg': '®',
    'trade': '™', 'deg': '°', 'middot': '·', 'bull': '•',
    'times': '×',
  };

  static String _decodeHtmlEntitiesOnce(String s) {
    return s
        .replaceAll('&amp;', '&')
        .replaceAll('&quot;', '"')
        .replaceAll('&apos;', "'")
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&nbsp;', '\u00a0')
        .replaceAllMapped(
          RegExp(r'&([a-zA-Z]+);'),
          (m) => _namedHtmlEntities[m.group(1)!] ?? m.group(0)!,
        )
        .replaceAllMapped(
          RegExp(r'&#x([0-9a-fA-F]+);'),
          (m) => String.fromCharCode(int.parse(m.group(1)!, radix: 16)),
        )
        .replaceAllMapped(
          RegExp(r'&#([0-9]+);'),
          (m) => String.fromCharCode(int.parse(m.group(1)!)),
        );
  }
}
