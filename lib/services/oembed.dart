import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

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
    } else if (lower.contains('tiktok.com')) {
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
  /// Retourne la meilleure URL de miniature pour un clip.
  /// Pour YouTube : construction directe (gratuit, sans clé API).
  /// Pour les autres : on utilise l'URL stockée via oEmbed.
  static String? bestThumbnailUrl(String url, String? storedThumbUrl) {
    final lower = url.toLowerCase();
    if (lower.contains('youtube.com') || lower.contains('youtu.be')) {
      final id = _youtubeVideoId(url);
      if (id != null) {
        return 'https://img.youtube.com/vi/$id/mqdefault.jpg';
      }
    }
    return storedThumbUrl;
  }

  static String? _youtubeVideoId(String url) {
    try {
      final uri = Uri.parse(url);
      if (uri.host.contains('youtu.be')) {
        return uri.pathSegments.isNotEmpty ? uri.pathSegments.first : null;
      }
      return uri.queryParameters['v'];
    } catch (_) {
      return null;
    }
  }

  static Future<Map<String, String?>> fetchMetadata(String url) async {
    try {
      final lower = url.toLowerCase();
      String? oembedUrl;
      if (lower.contains('youtube.com') || lower.contains('youtu.be')) {
        oembedUrl =
            'https://www.youtube.com/oembed?url=${Uri.encodeComponent(url)}&format=json';
      } else if (lower.contains('vimeo.com')) {
        oembedUrl =
            'https://vimeo.com/api/oembed.json?url=${Uri.encodeComponent(url)}';
      } else if (lower.contains('tiktok.com')) {
        oembedUrl =
            'https://www.tiktok.com/oembed?url=${Uri.encodeComponent(url)}';
      }
      if (oembedUrl != null) {
        final response = await http.get(Uri.parse(oembedUrl),
            headers: {'Accept': 'application/json'}).timeout(
          const Duration(seconds: 6),
        );
        if (response.statusCode == 200) {
          final data = json.decode(response.body) as Map<String, dynamic>;
          return {
            'title': data['title'] as String?,
            'thumbnailUrl': data['thumbnail_url'] as String?,
          };
        }
      }
    } catch (_) {}
    return {'title': null, 'thumbnailUrl': null};
  }
}
