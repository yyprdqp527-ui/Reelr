import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../config/secrets.dart';
import '../services/thumbnail_cache.dart';

/// Favicon du site d'origine d'un lien, utilise pour les plateformes qui n'ont
/// pas de logo PNG dedie dans assets/icons/ (sites inconnus, X, Vimeo,
/// Spotify, Apple Music...).
///
/// Si le favicon ne peut pas etre charge (hors ligne, site sans icone, URL non
/// analysable), affiche [fallback] — l'icone Material actuelle — pour ne
/// jamais regresser par rapport a l'affichage precedent.
class SiteLogo extends StatelessWidget {
  final String url;
  final double size;
  final Widget fallback;

  const SiteLogo({
    super.key,
    required this.url,
    required this.size,
    required this.fallback,
  });

  /// URL du favicon pour le domaine de [url], ou null si l'URL n'a pas de
  /// nom d'hote exploitable. Seul le nom de domaine est transmis.
  static String? faviconUrlFor(String url) {
    final host = Uri.tryParse(url.trim())?.host ?? '';
    if (host.isEmpty) return null;
    // Route /favicon du Worker Cloudflare : Google, puis les icones
    // declarees par la page, puis /favicon.ico, avec cache par site.
    // Aucun tiers ne voit l'adresse IP de l'utilisateur.
    final proxyBase = Secrets.reelrProxyUrl.replaceAll('/v1/messages', '');
    return '$proxyBase/favicon?url=${Uri.encodeComponent(url.trim())}';
  }

  @override
  Widget build(BuildContext context) {
    final faviconUrl = faviconUrlFor(url);
    if (faviconUrl == null) return fallback;
    return ClipRRect(
      borderRadius: BorderRadius.circular(size * 0.2),
      child: CachedNetworkImage(
        imageUrl: faviconUrl,
        cacheManager: ThumbnailCache.instance,
        httpHeaders: ThumbnailCache.headersFor(faviconUrl),
        width: size,
        height: size,
        fit: BoxFit.contain,
        fadeInDuration: Duration.zero,
        // Pastille blanche : un logo sombre sur fond transparent reste
        // lisible sur les cartes sombres.
        imageBuilder: (context, provider) => Container(
          width: size,
          height: size,
          color: Colors.white,
          padding: EdgeInsets.all(size * 0.12),
          child: Image(image: provider, fit: BoxFit.contain),
        ),
        placeholder: (context, url) => fallback,
        errorWidget: (context, url, error) => fallback,
      ),
    );
  }
}
