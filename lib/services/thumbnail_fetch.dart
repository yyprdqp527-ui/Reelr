import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'oembed.dart';
import 'thumbnail_cache.dart';
import 'thumbnail_resolver.dart';

const int _maxImageBytes = 8 * 1024 * 1024;

const String _safariUserAgent =
    'Mozilla/5.0 (iPhone; CPU iPhone OS 18_0 like Mac OS X) '
    'AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.0 '
    'Mobile/15E148 Safari/604.1';

/// Telecharge [url] avec l'identite [who] et renvoie les octets, ou null.
///
/// Garde-fous communs a tous les sites : seul un statut 200 compte, une
/// reponse annoncee comme video, son, texte ou JSON est abandonnee sans
/// etre lue, et rien au-dela de 8 Mo n'est telecharge (la « vignette »
/// d'Oh My Resto etait une video de 10 Mo).
Future<Uint8List?> fetchImageBytes(String url, FetchIdentity who) async {
  final target = who == FetchIdentity.proxy
      ? OEmbedService.proxiedThumbnailUrl(url)
      : url;
  final uri = Uri.tryParse(target);
  if (uri == null || !(uri.scheme == 'http' || uri.scheme == 'https')) {
    return null;
  }
  final client = HttpClient()
    ..connectionTimeout = const Duration(seconds: 6);
  try {
    final req = await client.getUrl(uri);
    req.followRedirects = true;
    req.maxRedirects = 5;
    final extra = ThumbnailCache.headersFor(target);
    if (extra != null) {
      for (final e in extra.entries) {
        req.headers.set(e.key, e.value);
      }
    }
    if (who == FetchIdentity.browser) {
      req.headers.set(HttpHeaders.userAgentHeader, _safariUserAgent);
      req.headers.set('Referer', '${uri.scheme}://${uri.host}/');
    } else if (who == FetchIdentity.previewBot) {
      req.headers.set(HttpHeaders.userAgentHeader, 'facebookexternalhit/1.1');
    }
    final resp = await req.close().timeout(const Duration(seconds: 8));
    if (resp.statusCode != 200) {
      await resp.drain<void>();
      return null;
    }
    final type = resp.headers.contentType;
    if (type != null) {
      final primary = type.primaryType;
      if (primary == 'video' ||
          primary == 'audio' ||
          primary == 'text' ||
          type.subType == 'json') {
        await resp.drain<void>();
        return null;
      }
    }
    if (resp.contentLength > _maxImageBytes) {
      await resp.drain<void>();
      return null;
    }
    final builder = BytesBuilder(copy: false);
    await for (final chunk in resp) {
      builder.add(chunk);
      if (builder.length > _maxImageBytes) return null;
    }
    return builder.takeBytes();
  } catch (_) {
    return null;
  } finally {
    client.close(force: true);
  }
}
