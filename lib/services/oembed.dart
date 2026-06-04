import 'dart:convert';

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
    if (lower.contains('youtube.com') || lower.contains('youtu.be')) {
      return _platforms['youtube']!;
    } else if (lower.contains('tiktok.com') || lower.contains('vm.tiktok.com')) {
      return _platforms['tiktok']!;
    } else if (lower.contains('instagram.com')) {
      return _platforms['instagram']!;
    } else if (lower.contains('twitter.com') || lower.contains('x.com')) {
      return _platforms['x']!;
    } else if (lower.contains('facebook.com') || lower.contains('fb.watch')) {
      return _platforms['facebook']!;
    } else if (lower.contains('twitch.tv')) {
      return _platforms['twitch']!;
    } else if (lower.contains('vimeo.com')) {
      return _platforms['vimeo']!;
    } else if (lower.contains('reddit.com')) {
      return _platforms['reddit']!;
    } else if (lower.contains('pinterest.com')) {
      return _platforms['pinterest']!;
    } else if (lower.contains('linkedin.com')) {
      return _platforms['linkedin']!;
    }
    return _platforms['other']!;
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
    return storedThumbUrl;
  }

  static Future<VideoData?> fetchMetadata(String url) async {
    final trimmed = url.trim();
    final lower = trimmed.toLowerCase();
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
      final oembedUrl = 'https://www.youtube.com/oembed?url=' + Uri.encodeComponent(videoUri.toString()) + '&format=json';
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

  static Future<VideoData?> _fetchTikTokMetadata(Uri videoUri) async {
    final requestUri = Uri.https('www.tiktok.com', '/oembed', {
      'url': videoUri.toString(),
    });

    try {
      final response = await http
          .get(requestUri, headers: {'Accept': 'application/json'})
          .timeout(const Duration(seconds: 10));
      if (response.statusCode != 200) return null;

      final payload = json.decode(response.body) as Map<String, dynamic>;
      final title = (payload['title'] as String?)?.trim();
      if (title == null || title.isEmpty) return null;

      return VideoData(
        title: title,
        channel: (payload['author_name'] as String?)?.trim(),
        platform: 'tiktok',
        thumbnailUrl: _sanitizeMediaUrl(payload['thumbnail_url'] as String?),
      );
    } catch (e) {
      debugPrint('[oembed] tiktok error: $e');
      return null;
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
      if (title == null || title.isEmpty) return null;

      return VideoData(
        title: title,
        channel: (payload['author_name'] as String?)?.trim(),
        platform: 'instagram',
        thumbnailUrl: _sanitizeMediaUrl(payload['thumbnail_url'] as String?),
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
      if (title == null || title.isEmpty) {
        return _fetchOpenGraphMetadata(videoUri, platformId: 'twitch');
      }

      final thumbnailTemplate = item['thumbnail_url'] as String?;
      final thumbnailUrl = _sanitizeMediaUrl(
        thumbnailTemplate?.replaceAll('{width}x{height}', '480x270'),
      );

      return VideoData(
        title: title,
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

  static Future<VideoData?> _fetchOpenGraphMetadata(
    Uri uri, {
    required String platformId,
  }) async {
    try {
      final response = await http.get(
        uri,
        headers: {
          'User-Agent': 'Mozilla/5.0 (compatible; Reelr/1.0)',
          'Accept': 'text/html,application/xhtml+xml',
        },
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) return null;

      final body = response.body;
      final title = _extractMetaContent(body, property: 'og:title') ??
          _extractMetaContent(body, name: 'twitter:title') ??
          _extractHtmlTitle(body);
      final thumb = _extractMetaContent(body, property: 'og:image') ??
          _extractMetaContent(body, property: 'og:image:url') ??
          _extractMetaContent(body, name: 'twitter:image') ??
          _extractMetaContent(body, name: 'twitter:image:src');
      final channel = _extractMetaContent(body, property: 'og:site_name');

      final cleanedTitle = (title ?? '').trim();
      final cleanedThumb = _sanitizeMediaUrl(thumb);

      if (cleanedTitle.isEmpty && cleanedThumb == null && (channel ?? '').trim().isEmpty) {
        return null;
      }

      return VideoData(
        title: cleanedTitle.isEmpty ? SocialPlatform.detect(uri.toString()).name : cleanedTitle,
        channel: (channel ?? '').trim().isEmpty ? null : channel!.trim(),
        platform: platformId,
        thumbnailUrl: cleanedThumb,
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
