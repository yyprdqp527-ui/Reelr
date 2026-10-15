import 'package:flutter/material.dart';

import 'site_logo.dart';
import 'thumbnail_fallback.dart' show LetterBadge;

/// Vignette d'une recherche Google : la page ne fournit que le logo « G »
/// de Google, identique pour toutes les recherches. On affiche donc la
/// requete elle-meme, ce qui distingue chaque clip d'un coup d'oeil.
class SearchQueryCard extends StatelessWidget {
  final String query;
  const SearchQueryCard({super.key, required this.query});

  /// Requete (q=) si [url] est une recherche Google, sinon null.
  static String? queryFor(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null || uri.path != '/search') return null;
    if (!RegExp(r'(^|\.)google\.[a-z.]+$').hasMatch(uri.host.toLowerCase())) {
      return null;
    }
    final q = uri.queryParameters['q']?.trim() ?? '';
    return q.isEmpty ? null : q;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1E2A5A), Color(0xFF3B2A7A)],
        ),
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search_rounded,
              color: Colors.white.withValues(alpha: 0.7), size: 28),
          const SizedBox(height: 8),
          Flexible(
            child: Text(
              query,
              textAlign: TextAlign.center,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w700,
                height: 1.2,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Vignette de secours d'un lien web dont la capture est impossible
/// (site anti-robot, erreur 502) : logo du site, titre et domaine sur un
/// fond colore stable pour chaque site. Remplace le fond gris vide.
class LinkFallbackCard extends StatelessWidget {
  final String url;
  final String title;
  final Widget logoFallback;

  /// Petite case : logo seul, centre, sans titre ni domaine.
  final bool compact;
  const LinkFallbackCard({
    super.key,
    required this.url,
    required this.title,
    required this.logoFallback,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final host = (Uri.tryParse(url)?.host ?? '').replaceFirst('www.', '');
    final hue = (host.codeUnits.fold<int>(0, (a, b) => (a * 31 + b) & 0xFFFF) % 360)
        .toDouble();
    final c1 = HSLColor.fromAHSL(1, hue, 0.45, 0.22).toColor();
    final c2 = HSLColor.fromAHSL(1, (hue + 40) % 360, 0.45, 0.30).toColor();
    if (compact) {
      return LayoutBuilder(builder: (context, box) {
        final side = box.biggest.shortestSide;
        final size = side.isFinite ? (side * 0.5).clamp(20.0, 52.0) : 36.0;
        return Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [c1, c2],
            ),
          ),
          alignment: Alignment.center,
          child: SiteLogo(
            url: url,
            size: size,
            fallback: LetterBadge(host: host, size: size),
          ),
        );
      });
    }
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [c1, c2],
        ),
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SiteLogo(url: url, size: 52, fallback: logoFallback),
          const SizedBox(height: 10),
          Flexible(
            child: Text(
              title,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w700,
                height: 1.2,
              ),
            ),
          ),
          if (host.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              host,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.65),
                fontSize: 11,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
