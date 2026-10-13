import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/clip.dart';
import 'oembed.dart';
import 'thumbnail_store.dart';

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

  /// Vignette à enregistrer sur le clip du destinataire : l'adresse
  /// d'origine, sans le passage par le proxy /thumb (l'app le rajoute
  /// elle-même à l'affichage), et rien pour une vignette locale.
  String? get rawThumbnailUrl {
    final th = thumbnailUrl?.trim();
    if (th == null || th.isEmpty || ThumbnailStore.isLocalUrl(th)) return null;
    final uri = Uri.tryParse(th);
    if (uri != null && uri.path.endsWith('/thumb')) {
      final inner = uri.queryParameters['url'];
      if (inner != null && inner.isNotEmpty) return inner;
    }
    return th;
  }

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
                  thumbnailUrl: _shareableThumbnail(
                      OEmbedService.bestThumbnailUrl(c.url, c.thumbnailUrl)),
                ))
            .toList(),
      );

  /// Une vignette locale (reelr-local://) n'existe que sur cet appareil :
  /// inutile, et trompeuse, pour le destinataire.
  static String? _shareableThumbnail(String? url) =>
      (url == null || ThumbnailStore.isLocalUrl(url)) ? null : url;

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

  static const String _dataEndpoint =
      'https://reelr-link-shortener.myreelr.workers.dev/data/';

  static PlaylistLink? _decodeItemsPayload(String name, String encoded) {
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

  /// Récupère la playlist stockée par le Worker pour ce code.
  /// Renvoie null en cas d'échec (réseau, délai, code inconnu, données
  /// illisibles) : l'appelant tente alors le décodage local.
  static Future<PlaylistLink?> _fetchFromWorker(String code) async {
    try {
      final response = await http
          .get(Uri.parse('$_dataEndpoint$code'))
          .timeout(const Duration(seconds: 8));
      if (response.statusCode != 200) return null;
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final name = data['name'] as String?;
      final encoded = data['items'] as String?;
      if (name == null || encoded == null) return null;
      return _decodeItemsPayload(name, encoded);
    } catch (_) {
      return null;
    }
  }

  /// Décode un lien de playlist reçu. Le format récent (`code=...`)
  /// nécessite un appel réseau vers le Worker pour récupérer les vraies
  /// données ; l'ancien format (`name=...&items=...`, gardé pour les liens
  /// déjà partagés avant ce changement, ou le mode de repli [toWebUri] en
  /// cas de Worker injoignable au moment du partage) se décode entièrement
  /// en local.
  static Future<PlaylistLink?> tryDecodeAsync(Uri uri) async {
    // Accepte à la fois le lien à schéma personnalisé (reelr://playlist...)
    // et le lien https (yyprdqp527-ui.github.io/reelr-support/playlist...)
    // : ce dernier est délivré directement à l'app quand les Universal
    // Links / App Links sont actifs, sans jamais passer par le navigateur.
    final isAppScheme = uri.scheme == 'reelr' && uri.host == 'playlist';
    final isWebLink = (uri.scheme == 'https' || uri.scheme == 'http') &&
        uri.host == 'yyprdqp527-ui.github.io' &&
        uri.path.startsWith('/reelr-support/playlist');
    if (!isAppScheme && !isWebLink) return null;

    final code = uri.queryParameters['code'];
    if (code != null && code.isNotEmpty) {
      final fromWorker = await _fetchFromWorker(code);
      if (fromWorker != null) return fromWorker;
      // Worker injoignable ou code inconnu : on ne s'arrête pas là.
      // playlist.html ajoute aussi name + items au lien reelr://, donc
      // les vidéos sont souvent déjà là — on tente le décodage local.
    }

    // Ancien format, tout dans l'URL — décodage local, sans réseau.
    // Sert aussi de repli quand le Worker n'a pas répondu (voir plus haut).
    final name = uri.queryParameters['name'];
    final encoded = uri.queryParameters['items'];
    if (name == null || encoded == null) return null;
    return _decodeItemsPayload(name, encoded);
  }
}
