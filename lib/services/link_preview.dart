import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Apercu de lien natif : LinkPresentation sur iOS, WebView invisible sur
/// Android (MainActivity.kt).
///
/// C'est le moteur des apercus de liens d'iMessage : il charge la page
/// comme Safari (WebKit, cookies, JavaScript, redirections), la ou nos
/// requetes HTTP recoivent une page anti-bot (Reddit) ou ne trouvent pas
/// l'image (pages de vente, publicites, balises og:image relatives...).
///
/// Utilise en secours quand l'extraction classique n'a trouve ni vignette
/// ni vrai titre. L'image est renvoyee sous forme d'octets (JPEG, 720 px
/// max), a enregistrer directement dans le stockage permanent.
///
/// iOS renvoie l'image en octets (`image`) ; Android renvoie son adresse
/// (`imageUrl`), que l'app telecharge comme n'importe quelle vignette.
/// Renvoie null sur le web ou si rien n'a ete trouve.
class LinkPreviewService {
  LinkPreviewService._();

  static const MethodChannel _channel = MethodChannel('reelr/link_preview');

  static Future<({String? title, Uint8List? image, String? imageUrl})?> fetch(
    String url,
  ) async {
    if (kIsWeb || !(Platform.isIOS || Platform.isAndroid)) return null;
    try {
      final raw = await _channel
          .invokeMethod<Map<Object?, Object?>>('fetch', url)
          .timeout(const Duration(seconds: 20));
      if (raw == null) {
        debugPrint('[linkpreview] rien trouve: $url');
        return null;
      }
      final title = raw['title'] as String?;
      final image = raw['image'] as Uint8List?;
      final imageUrl = raw['imageUrl'] as String?;
      debugPrint(
        '[linkpreview] title=${title ?? "NULL"} '
        'image=${image == null ? "NULL" : "${image.length} octets"} '
        'imageUrl=${imageUrl ?? "NULL"}',
      );
      return (title: title, image: image, imageUrl: imageUrl);
    } catch (e) {
      debugPrint('[linkpreview] erreur ($url): $e');
      return null;
    }
  }
}
