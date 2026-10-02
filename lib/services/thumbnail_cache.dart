import 'package:flutter_cache_manager/flutter_cache_manager.dart';

import '../config/secrets.dart';

/// Gestionnaire de cache disque dedie aux miniatures de clips.
///
/// Reprend volontairement la MEME cle de cache que `DefaultCacheManager`
/// (`libCachedImageData`) : la base SQLite du cache et les fichiers deja
/// presents sur l'appareil sont donc reutilises tels quels. La mise a jour
/// ne fait perdre aucune miniature deja telechargee.
///
/// Seule la configuration change, et c'est tout l'objet de cette classe :
///
/// - `maxNrOfCacheObjects` : 200 (defaut) -> 3000.
///   Le defaut de flutter_cache_manager evincait les miniatures les plus
///   anciennes des le 201e objet mis en cache. Comme `ResilientThumbnail`
///   s'appuie sur ce cache pour sa strategie "last known good thumbnail",
///   l'eviction faisait retomber le widget sur une requete reseau, laquelle
///   echouait sur les plateformes a URL signee (TikTok, Instagram,
///   Facebook...) dont le jeton avait expire depuis longtemps. Resultat
///   visible : le logo generique remplacait une miniature qui s'affichait
///   correctement la veille.
///
/// - `stalePeriod` : 30 jours (defaut) -> 365 jours.
///   Meme raisonnement : une miniature perimee mais lisible sur le disque
///   vaut infiniment mieux qu'un logo generique.
///
/// Ordre de grandeur : 3000 miniatures ~ 30-60 Mo sur disque, ce qui reste
/// negligeable et reste purgeable par le systeme.
class ThumbnailCache {
  ThumbnailCache._();

  /// Cle identique a celle de `DefaultCacheManager` : indispensable pour
  /// reprendre le cache existant au lieu d'en creer un nouveau, vide.
  static const String cacheKey = 'libCachedImageData';

  static final CacheManager instance = CacheManager(
    Config(
      cacheKey,
      stalePeriod: const Duration(days: 365),
      maxNrOfCacheObjects: 3000,
    ),
  );

  /// En-tetes HTTP a joindre pour telecharger [url].
  ///
  /// La route /thumb du Worker Cloudflare exige le secret partage :
  /// sans cet en-tete elle repond 401 et la miniature n'arrive jamais.
  /// Les URLs qui ne passent pas par le proxy ne recoivent aucun
  /// en-tete supplementaire.
  ///
  /// Centralise ici pour que l'affichage (CachedNetworkImage) et le
  /// pre-cache (downloadFile) ne puissent pas diverger.
  static Map<String, String>? headersFor(String url) {
    if (!url.contains('workers.dev/thumb') &&
        !url.contains('workers.dev/screenshot') &&
        !url.contains('workers.dev/favicon')) {
      return null;
    }
    return {'x-reelr-secret': Secrets.appSharedSecret};
  }
}
