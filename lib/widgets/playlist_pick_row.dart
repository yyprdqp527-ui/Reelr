import 'package:flutter/material.dart';

import '../core/theme.dart';
import '../services/oembed.dart';
import 'glass_card.dart';
import 'resilient_thumbnail.dart';
import 'site_logo.dart';

/// Carte d'un lien dans les écrans de playlist : choix avant l'envoi
/// (PlaylistShareSelectScreen) et import chez l'ami (PlaylistImportScreen).
/// Une seule carte pour les deux, pour qu'ils restent identiques.
class PlaylistPickRow extends StatelessWidget {
  /// Taille de la vignette, commune aux deux écrans.
  static const double thumbSize = 104;

  final String url;
  final String title;
  final String? thumbnailUrl;
  final String cacheKeyId;
  final String? persistId;
  final String? subtitle;
  final bool selected;
  final VoidCallback onTap;

  const PlaylistPickRow({
    super.key,
    required this.url,
    required this.title,
    required this.thumbnailUrl,
    required this.cacheKeyId,
    required this.selected,
    required this.onTap,
    this.persistId,
    this.subtitle,
  });

  /// Nom du site sans « www. », ou nom de la plateforme pour un réseau.
  static String sourceLabel(String url) {
    final platform = SocialPlatform.detect(url);
    if (platform.id != 'other') return platform.name;
    final host = Uri.tryParse(url.trim())?.host ?? '';
    return host.replaceFirst(RegExp(r'^www\.', caseSensitive: false), '');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final platform = SocialPlatform.detect(url);
    final fallbackIcon = Icon(platform.icon, color: platform.color, size: 36);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: AnimatedOpacity(
        opacity: selected ? 1 : 0.45,
        duration: const Duration(milliseconds: 150),
        child: GlassCard(
          borderRadius: 18,
          padding: const EdgeInsets.fromLTRB(8, 8, 14, 8),
          onTap: onTap,
          child: Row(
            children: [
              SizedBox(
                width: thumbSize,
                height: thumbSize,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: ResilientThumbnail(
                    url: thumbnailUrl,
                    cacheKeyId: cacheKeyId,
                    persistId: persistId,
                    platformId: platform.id,
                    fit: BoxFit.cover,
                    // Jamais de case vide : logo du site, sinon icône.
                    fallbackBuilder: (_) => Container(
                      color: platform.color.withValues(alpha: 0.12),
                      child: Center(
                        child: platform.id == 'other'
                            ? SiteLogo(url: url, size: 44, fallback: fallbackIcon)
                            : fallbackIcon,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title.isEmpty ? url : title,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium,
                    ),
                    if (subtitle != null && subtitle!.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        subtitle!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyMedium,
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 10),
              _CheckDot(selected: selected),
            ],
          ),
        ),
      ),
    );
  }
}

class _CheckDot extends StatelessWidget {
  final bool selected;
  const _CheckDot({required this.selected});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: 26,
      height: 26,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: selected
            ? const LinearGradient(
                colors: [AppTheme.violet, Color(0xFFA855F7)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              )
            : null,
        border: selected
            ? null
            : Border.all(
                color: (isDark ? Colors.white : Colors.black)
                    .withValues(alpha: 0.28),
                width: 2,
              ),
      ),
      child: selected
          ? const Icon(Icons.check_rounded, color: Colors.white, size: 18)
          : null,
    );
  }
}
