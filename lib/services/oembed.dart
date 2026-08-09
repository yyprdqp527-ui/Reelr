import 'dart:convert';
import 'dart:io' show HttpClient;

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../config/secrets.dart';
import 'classifier.dart';

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
    'other': const SocialPlatform(
      id: 'other',
      name: 'Autre',
      icon: Icons.link_rounded,
      color: Color(0xFF9E9E9E),
    ),
  };
}

class OEmbedService {
  // ignore: unused_element
  static String get _ytApiKey => Secrets.youtubeApiKey;
  static String get _instagramAccessToken => Secrets.instagramAccessToken;
  static String get _twitchClientId => Secrets.twitchClientId;
  static String get _twitchAccessToken => Secrets.twitchAccessToken;

  static String? bestThumbnailUrl(String url, String? storedThumbUrl) {
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
    // Reddit et Pinterest: protections anti-hotlink cote CDN qui peuvent
    // bloquer un chargement direct depuis l'app. Le Worker proxy
    // retelecharge l'image avec des en-tetes (User-Agent, Referer)
    // adaptes, ce qui peut contourner une partie de ces blocages.
    if ((lower.contains('reddit.com') || lower.contains('pinterest.')) &&
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
  static String _proxiedThumbnailUrl(String rawUrl) {
    final proxyBase = Secrets.reelrProxyUrl.replaceAll('/v1/messages', '');
    return '$proxyBase/thumb?url=${Uri.encodeComponent(rawUrl)}';
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
        return fetchMetadata(realUrl);
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
      return _fetchOpenGraphMetadata(uri, platformId: SocialPlatform.detect(trimmed).id);
    }

    return VideoData(
      title: _filenameTitle(trimmed),
      platform: 'upload',
    );
  }

  static Future<VideoData?> _fetchYouTubeMetadata(Uri videoUri, String videoId) async {
    try {
      final oembedUrl = 'https://www.youtube.com/oembed?url=${Uri.encodeComponent(videoUri.toString())}&format=json';
      final response = await http
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
      final response = await http
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
    if (_instagramAccessToken.trim().isEmpty) {
      debugPrint('[oembed] instagram error: missing access token');
      return _fetchOpenGraphMetadata(videoUri, platformId: 'instagram');
    }

    final requestUri = Uri.https('graph.facebook.com', '/v18.0/instagram_oembed', {
      'url': videoUri.toString(),
      'access_token': _instagramAccessToken,
    });

    try {
      final response = await http
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

    if (_twitchClientId.trim().isEmpty || _twitchAccessToken.trim().isEmpty) {
      debugPrint('[oembed] twitch error: missing credentials');
      return _fetchOpenGraphMetadata(videoUri, platformId: 'twitch');
    }

    final requestUri = clipId != null
        ? Uri.https('api.twitch.tv', '/helix/clips', {'id': clipId})
        : Uri.https('api.twitch.tv', '/helix/videos', {'id': videoId!});

    try {
      final response = await http.get(
        requestUri,
        headers: {
          'Accept': 'application/json',
          'Client-Id': _twitchClientId,
          'Authorization': 'Bearer $_twitchAccessToken',
        },
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) {
        return _fetchOpenGraphMetadata(videoUri, platformId: 'twitch');
      }

      final payload = json.decode(response.body) as Map<String, dynamic>;
      final items = payload['data'] as List<dynamic>?;
      if (items == null || items.isEmpty) {
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
  static String? _tiktokVideoIdFromDownloadLink(Uri uri) {
    final host = uri.host.toLowerCase();
    if (host != 'tiktok.com' && !host.endsWith('.tiktok.com')) return null;
    if (!uri.pathSegments.contains('download-link')) return null;

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
    final host = uri.host.toLowerCase();
    final isPinterestShortLink = host == 'pin.it';
    final isRedditShareLink =
        host.endsWith('reddit.com') && uri.pathSegments.contains('s');
    final isGoogleShareLink =
        host == 'share.google' || host.endsWith('.share.google');
    final tiktokDownloadLinkId = _tiktokVideoIdFromDownloadLink(uri);
    if (!isPinterestShortLink &&
        !isRedditShareLink &&
        !isGoogleShareLink &&
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
        if ((scheme == 'http' || scheme == 'https') &&
            resolved.host.isNotEmpty) {
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
    'reddit',
    'pinterest',
    'video',
    'log in or sign up to view',
    'page not found',
    'content not available',
  };

  /// Vrai si [title] est vide ou n'est qu'un titre de coquille (cf.
  /// [_placeholderTitles]) : dans les deux cas, aucune information utile.
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
    if (segments.isEmpty) return !_hasContentQuery(uri);

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

  static Future<VideoData?> _fetchRedditMetadata(Uri videoUri) async {
    final resolvedUri = await _resolveRedditShareLink(videoUri);
    try {
      var path = resolvedUri.path;
      if (!path.endsWith('/')) path = '$path/';
      final jsonUri = Uri.https('www.reddit.com', '$path.json');
      final response = await http.get(
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

  static Future<VideoData?> _fetchOpenGraphMetadata(
    Uri uri, {
    required String platformId,
  }) async {
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
      final response = await http.get(
        uri,
        headers: needsRealisticHeaders
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
      final ogDescription = platformId == 'pinterest' ? rawDescription : null;
      final title = (ogDescription != null && ogDescription.trim().isNotEmpty)
          ? ogDescription
          : ogTitle;
      final thumb = _extractMetaContent(body, property: 'og:image') ??
          _extractMetaContent(body, property: 'og:image:url') ??
          _extractMetaContent(body, name: 'twitter:image') ??
          _extractMetaContent(body, name: 'twitter:image:src');
      final channel = _extractMetaContent(body, property: 'og:site_name');

      var cleanedTitle = (title ?? '').trim();
      final cleanedThumb = _sanitizeMediaUrl(thumb);
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

  static String? _extractMetaContent(
    String html, {
    String? property,
    String? name,
  }) {
    final key = property ?? name;
    if (key == null) return null;

    final escapedKey = RegExp.escape(key);
    final patternA = RegExp(
      '<meta[^>]+(?:property|name)=["\']$escapedKey["\'][^>]+content=["\']([^"\']+)["\']',
      caseSensitive: false,
    );
    final patternB = RegExp(
      '<meta[^>]+content=["\']([^"\']+)["\'][^>]+(?:property|name)=["\']$escapedKey["\']',
      caseSensitive: false,
    );

    final match = patternA.firstMatch(html) ?? patternB.firstMatch(html);
    if (match == null) return null;
    return _decodeHtmlEntities(match.group(1)?.trim() ?? '');
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

  static String _decodeHtmlEntities(String s) {
    return s
        .replaceAll('&amp;', '&')
        .replaceAll('&quot;', '"')
        .replaceAll('&apos;', "'")
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&nbsp;', '\u00a0')
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
