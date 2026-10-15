import 'package:flutter/material.dart';

import 'search_query_card.dart';

/// Visuel de secours UNIQUE pour toute vignette absente ou en echec.
///
/// Regle produit : jamais de case vide. Ordre de repli :
/// 1. recherche Google : la requete (carte pleine) ;
/// 2. logo du site sur pastille blanche (+ titre et domaine en carte
///    pleine) ;
/// 3. si le logo ne charge pas non plus : initiale du site sur pastille ;
/// 4. si l'adresse est inexploitable : icone de lien sur fond colore.
///
/// [compact] : petites cases (mosaique, tuile, carnet) : logo seul, centre,
/// dimensionne selon la place disponible.
class ThumbnailFallback extends StatelessWidget {
  final String url;
  final String title;
  final bool compact;

  const ThumbnailFallback({
    super.key,
    required this.url,
    this.title = '',
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final host = hostOf(url);
    if (host.isEmpty) {
      return Container(
        color: const Color(0xFF1E2A5A),
        alignment: Alignment.center,
        child: Icon(Icons.link_rounded,
            color: Colors.white.withValues(alpha: 0.7), size: 28),
      );
    }
    if (!compact) {
      final q = SearchQueryCard.queryFor(url);
      if (q != null) return SearchQueryCard(query: q);
    }
    return LinkFallbackCard(
      url: url,
      title: title,
      compact: compact,
      logoFallback: LetterBadge(host: host, size: compact ? 28 : 52),
    );
  }

  static String hostOf(String url) =>
      (Uri.tryParse(url.trim())?.host ?? '').replaceFirst('www.', '');
}

/// Initiale du site sur pastille blanche : dernier recours quand le logo
/// du site est introuvable.
class LetterBadge extends StatelessWidget {
  final String host;
  final double size;
  const LetterBadge({super.key, required this.host, required this.size});

  @override
  Widget build(BuildContext context) {
    final letter = host.isEmpty ? '?' : host[0].toUpperCase();
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(size * 0.2),
      ),
      child: Text(
        letter,
        style: TextStyle(
          color: const Color(0xFF1E2A5A),
          fontSize: size * 0.55,
          fontWeight: FontWeight.w800,
          height: 1,
        ),
      ),
    );
  }
}
