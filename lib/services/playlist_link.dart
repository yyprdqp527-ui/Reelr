import 'dart:convert';

import '../models/clip.dart';
import 'oembed.dart';

/// Encodage/décodage du lien de partage de playlist (Part 6 — étape 1).
///
/// Une playlist est entièrement encodée dans l'URL elle-même (pas de
/// backend) : `reelr://playlist?name=<nom>&items=<payload>` où `items` est
/// un JSON compact ([{"t": titre, "u": url}, ...]) encodé en base64url.
///
/// Cette classe ne fait que construire/lire l'URL — elle ne partage rien,
/// n'affiche rien et n'importe rien : voir `_CategoryDetailScreenState`
/// (génération du lien) et le futur écran d'aperçu (étape 2, réception).
class PlaylistLinkItem {
  final String title;
  final String url;
  // Miniature déjà connue de l'appareil qui partage — encodée directement
  // dans le lien pour que le destinataire l'affiche sans requête réseau
  // supplémentaire à l'ouverture.
  final String? thumbnailUrl;

  const PlaylistLinkItem({
    required this.title,
    required this.url,
    this.thumbnailUrl,
  });

  Map<String, dynamic> toJson() => {
        't': title,
        'u': url,
        if (thumbnailUrl != null && thumbnailUrl!.isNotEmpty) 'th': thumbnailUrl,
      };

  factory PlaylistLinkItem.fromJson(Map<String, dynamic> json) =>
      PlaylistLinkItem(
        title: (json['t'] as String?) ?? '',
        url: (json['u'] as String?) ?? '',
        thumbnailUrl: json['th'] as String?,
      );
}

class PlaylistLink {
  final String name;
  final List<PlaylistLinkItem> items;

  const PlaylistLink({required this.name, required this.items});

  factory PlaylistLink.fromClips(String name, List<Clip> clips) =>
      PlaylistLink(
        name: name,
        items: clips
            .map((c) => PlaylistLinkItem(
                  title: c.title,
                  url: c.url,
                  thumbnailUrl: OEmbedService.bestThumbnailUrl(c.url, c.thumbnailUrl),
                ))
            .toList(),
      );

  String _encodedPayload() {
    final jsonList = items.map((i) => i.toJson()).toList();
    return base64Url.encode(utf8.encode(json.encode(jsonList)));
  }

  /// Expose le payload encodé (même valeur que le paramètre `items` de
  /// [toWebUri]/[toAppUri]) pour que [PlaylistLinkShortener] puisse envoyer
  /// exactement les mêmes données au Worker de raccourcissement.
  String encodedItemsForSharing() => _encodedPayload();

  /// Lien à schéma personnalisé (ouvre directement l'app si installée).
  /// Même mécanisme que le `reelr://add?url=...` déjà utilisé pour
  /// l'ajout d'un lien unique.
  Uri toAppUri() => Uri(
        scheme: 'reelr',
        host: 'playlist',
        queryParameters: {
          'name': name,
          'items': _encodedPayload(),
        },
      );

  /// Lien web (https, hébergé sur la page support GitHub Pages) utilisé
  /// pour le partage. Contrairement à [toAppUri], celui-ci génère un vrai
  /// lien cliquable avec aperçu dans les apps de messagerie, et permet un
  /// fallback vers l'App Store / Play Store si le destinataire n'a pas
  /// Reelr installée (voir playlist.html).
  Uri toWebUri() => Uri.https(
        'yyprdqp527-ui.github.io',
        '/reelr-support/playlist.html',
        {
          'name': name,
          'items': _encodedPayload(),
        },
      );

  static PlaylistLink? tryDecode(Uri uri) {
    if (uri.scheme != 'reelr' || uri.host != 'playlist') return null;
    final name = uri.queryParameters['name'];
    final encoded = uri.queryParameters['items'];
    if (name == null || encoded == null) return null;
    try {
      final decoded = utf8.decode(base64Url.decode(encoded));
      final list = json.decode(decoded) as List<dynamic>;
      final items = list
          .whereType<Map<String, dynamic>>()
          .map(PlaylistLinkItem.fromJson)
          .where((i) => i.url.isNotEmpty)
          .toList();
      if (items.isEmpty) return null;
      return PlaylistLink(name: name, items: items);
    } catch (_) {
      return null;
    }
  }
}
