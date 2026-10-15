import 'dart:async';
import 'dart:typed_data';

/// REGLE GENERALE DES VIGNETTES (decision d'Anne, 2026-10-14)
///
/// Un clip a toujours une vignette, et elle ne depend jamais du reseau a
/// l'affichage. A l'enregistrement, on essaie des sources dans le MEME
/// ordre pour tous les liens, sans cas particulier par site :
///
///   1. l'image annoncee par la page, avec trois identites tour a tour :
///      navigateur, robot d'apercu de liens, puis serveur Cloudflare
///      (un meme site repond autrement selon qui demande : c'est le cas
///      de Booking, de Facebook, de Reddit...) ;
///   2. les autres images de la page ;
///   3. l'apercu natif du telephone ;
///   4. une capture d'ecran de la page ;
///   5. une carte dessinee par l'app (initiale ou logo, titre, site).
///
/// Chaque essai est valide en DECODANT vraiment l'image : une video, de
/// l'AVIF illisible ou une page d'erreur comptent comme un echec. La
/// premiere image valide est gardee. Seule la carte (5) est sure de
/// reussir ; elle est marquee « dessinee », et la reparation retentera
/// les etapes 1 a 4 plus tard.
enum FetchIdentity { browser, previewBot, proxy }

typedef ImageFetch = Future<Uint8List?> Function(
    String url, FetchIdentity who);
typedef ImageValidator = Future<bool> Function(Uint8List bytes);

class ResolvedThumbnail {
  const ResolvedThumbnail({
    required this.bytes,
    required this.source,
    required this.attempts,
    this.generated = false,
  });

  final Uint8List bytes;

  /// « image », « autre image », « apercu natif », « capture » ou « carte ».
  final String source;

  /// Vrai pour la carte dessinee par l'app (pas une vraie photo).
  final bool generated;

  /// Journal lisible de chaque essai, dans l'ordre.
  final List<String> attempts;
}

class ThumbnailResolver {
  ThumbnailResolver({
    required this.fetch,
    required this.isUsable,
    this.nativePreview,
    this.screenshot,
    this.renderCard,
    this.stepTimeout = const Duration(seconds: 8),
    this.maxAlternatives = 3,
  });

  final ImageFetch fetch;
  final ImageValidator isUsable;
  final Future<Uint8List?> Function()? nativePreview;
  final Future<Uint8List?> Function()? screenshot;
  final Future<Uint8List> Function()? renderCard;
  final Duration stepTimeout;
  final int maxAlternatives;

  /// Renvoie la premiere image valide, ou null si rien n'a marche et
  /// qu'aucune carte n'est disponible (liens video : l'affichage garde
  /// alors le logo de la plateforme).
  Future<ResolvedThumbnail?> resolve({
    String? imageUrl,
    List<String> alternatives = const [],
  }) async {
    final attempts = <String>[];

    Future<Uint8List?> attempt(
        String label, Future<Uint8List?> Function() run) async {
      try {
        final bytes = await run().timeout(stepTimeout);
        if (bytes == null || bytes.isEmpty) {
          attempts.add('$label : rien');
          return null;
        }
        if (!await isUsable(bytes)) {
          attempts.add('$label : illisible');
          return null;
        }
        attempts.add('$label : ok');
        return bytes;
      } on TimeoutException {
        attempts.add('$label : trop lent');
        return null;
      } catch (_) {
        attempts.add('$label : erreur');
        return null;
      }
    }

    final urls = <String>[];
    if (imageUrl != null && imageUrl.isNotEmpty) urls.add(imageUrl);
    for (final alt in alternatives) {
      if (alt.isEmpty || urls.contains(alt)) continue;
      if (urls.length >= 1 + maxAlternatives) break;
      urls.add(alt);
    }

    for (var i = 0; i < urls.length; i++) {
      final url = urls[i];
      final label = i == 0 ? 'image' : 'autre image';
      final identities = i == 0
          ? FetchIdentity.values
          : const [FetchIdentity.browser, FetchIdentity.proxy];
      for (final who in identities) {
        final bytes = await attempt('$label/${who.name}', () => fetch(url, who));
        if (bytes != null) {
          return ResolvedThumbnail(
              bytes: bytes, source: label, attempts: attempts);
        }
      }
    }

    final native = nativePreview;
    if (native != null) {
      final bytes = await attempt('apercu natif', native);
      if (bytes != null) {
        return ResolvedThumbnail(
            bytes: bytes, source: 'apercu natif', attempts: attempts);
      }
    }

    final shot = screenshot;
    if (shot != null) {
      final bytes = await attempt('capture', shot);
      if (bytes != null) {
        return ResolvedThumbnail(
            bytes: bytes, source: 'capture', attempts: attempts);
      }
    }

    final card = renderCard;
    if (card != null) {
      try {
        final bytes = await card();
        attempts.add('carte : ok');
        return ResolvedThumbnail(
            bytes: bytes,
            source: 'carte',
            attempts: attempts,
            generated: true);
      } catch (_) {
        attempts.add('carte : erreur');
      }
    }
    return null;
  }
}
