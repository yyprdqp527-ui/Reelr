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
  // Le lien partage passe par la route /s/ du Worker reelr-proxy : elle
  // genere l'apercu (Messages, WhatsApp) puis redirige vers la page.
  static const String _shortBase = 'https://s.myreelr.app';

  static Future<Uri> shorten(PlaylistLink link) async {
    // Une seconde tentative avant le lien long de secours.
    final first = await _tryShorten(link);
    if (first != null) return first;
    return await _tryShorten(link) ?? link.toWebUri();
  }

  static Future<Uri?> _tryShorten(PlaylistLink link) async {
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
          .timeout(const Duration(seconds: 6));

      if (response.statusCode != 200) return null;

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final code = data['code'] as String?;
      if (code == null || code.isEmpty) return null;

      return Uri.parse('$_shortBase/$code');
    } catch (_) {
      return null;
    }
  }
}
