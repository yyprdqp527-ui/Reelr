import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/secrets.dart';
import 'playlist_link.dart';

/// Raccourcit le lien d'une playlist via le Worker reelr-link-shortener.
///
/// En cas d'échec réseau (Worker injoignable, timeout, erreur serveur),
/// retombe silencieusement sur le lien web long existant
/// ([PlaylistLink.toWebUri]) : le partage continue de fonctionner, avec
/// un lien plus long dans ce cas de repli plutôt qu'un blocage total.
class PlaylistLinkShortener {
  static const String _shortenUrl =
      'https://reelr-link-shortener.myreelr.workers.dev/shorten';
  static const String _shortDomain =
      'https://reelr-link-shortener.myreelr.workers.dev';

  static Future<Uri> shorten(PlaylistLink link) async {
    final fallback = link.toWebUri();
    try {
      final response = await http
          .post(
            Uri.parse(_shortenUrl),
            headers: {
              'x-reelr-secret': Secrets.appSharedSecret,
              'content-type': 'application/json',
            },
            body: jsonEncode({
              'name': link.name,
              'items': link.encodedItemsForSharing(),
            }),
          )
          .timeout(const Duration(seconds: 5));

      if (response.statusCode != 200) return fallback;

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final code = data['code'] as String?;
      if (code == null || code.isEmpty) return fallback;

      return Uri.parse('$_shortDomain/$code');
    } catch (_) {
      return fallback;
    }
  }
}
