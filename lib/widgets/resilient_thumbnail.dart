import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';

/// Widget de miniature "résilient" utilisé pour Instagram, TikTok, Facebook
/// (et toute autre plateforme utilisant des URLs de miniature à durée de vie
/// limitée, ex. tokens signés).
///
/// Problème corrigé : une URL de miniature valide, déjà affichée avec succès
/// et déjà présente dans le cache disque, ne doit jamais être remplacée par
/// le visuel générique de la plateforme simplement parce que l'URL distante
/// a expiré (403/404/redirection HTML) lors d'une revalidation réseau.
///
/// Stratégie ("last known good thumbnail") :
/// 1. Avant toute requête réseau, on vérifie si le cache disque
///    (flutter_cache_manager, déjà utilisé en interne par CachedNetworkImage)
///    contient déjà un fichier valide pour cette URL. Si oui, on l'affiche
///    directement depuis le disque — sans jamais retenter le réseau — donc
///    une éventuelle expiration du token côté plateforme n'a aucun effet.
/// 2. Si rien n'est en cache, on tente le réseau via CachedNetworkImage.
///    En cas d'échec (403/404/HTML/expiration), on affiche le fallback
///    générique fourni par l'appelant — UNIQUEMENT dans ce cas, puisqu'aucune
///    miniature valide n'a jamais existé.
/// 3. Un identifiant de requête (cacheKeyId, généralement l'id du clip) et un
///    compteur de génération protègent contre les races : si le widget est
///    recyclé (ListView/GridView) pour un autre clip pendant la vérification
///    du cache, le résultat obsolète est ignoré.
///
/// Aucune modification visuelle : les callbacks fallbackBuilder /
/// loadingBuilder fournis par l'appelant sont rendus à l'identique de ce qui
/// existait avant (mêmes couleurs, mêmes icônes, même mise en page).
class ResilientThumbnail extends StatefulWidget {
  final String? url;
  final String cacheKeyId;
  final String platformId;
  final BoxFit fit;
  final WidgetBuilder fallbackBuilder;
  final WidgetBuilder? loadingBuilder;

  const ResilientThumbnail({
    super.key,
    required this.url,
    required this.cacheKeyId,
    required this.platformId,
    required this.fallbackBuilder,
    this.loadingBuilder,
    this.fit = BoxFit.cover,
  });

  @override
  State<ResilientThumbnail> createState() => _ResilientThumbnailState();
}

class _ResilientThumbnailState extends State<ResilientThumbnail> {
  FileInfo? _cachedFile;
  bool _checkingCache = true;
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    _checkCache();
  }

  @override
  void didUpdateWidget(covariant ResilientThumbnail oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url ||
        oldWidget.cacheKeyId != widget.cacheKeyId) {
      _cachedFile = null;
      _checkingCache = true;
      _checkCache();
    }
  }

  static String _sanitizeForLog(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null) return '(url invalide)';
    return '${uri.host}${uri.path}';
  }

  void _log(String message) {
    if (kDebugMode) {
      debugPrint(
        '[thumbnail] clip=${widget.cacheKeyId} platform=${widget.platformId} $message',
      );
    }
  }

  Future<void> _checkCache() async {
    final url = widget.url;
    final requestClipId = widget.cacheKeyId;
    final gen = ++_generation;

    if (url == null || url.isEmpty) {
      _log('aucune URL disponible -> fallback');
      if (mounted && gen == _generation) {
        setState(() => _checkingCache = false);
      }
      return;
    }

    FileInfo? info;
    try {
      info = await DefaultCacheManager().getFileFromCache(url);
    } catch (e) {
      _log('erreur lecture cache disque (${_sanitizeForLog(url)}): $e');
    }

    // Garde anti-race : le widget a pu être recyclé pour un autre clip
    // (scroll / reconstruction de liste) pendant l'attente asynchrone.
    if (!mounted || gen != _generation || widget.cacheKeyId != requestClipId) {
      return;
    }

    setState(() {
      _cachedFile = info;
      _checkingCache = false;
    });
    _log(info != null
        ? 'miniature trouvée dans le cache disque -> affichage local'
        : 'aucune miniature en cache -> tentative réseau (${_sanitizeForLog(url)})');
  }

  @override
  Widget build(BuildContext context) {
    final url = widget.url;

    if (url == null || url.isEmpty) {
      return widget.fallbackBuilder(context);
    }

    if (_checkingCache) {
      return widget.loadingBuilder?.call(context) ?? const SizedBox.shrink();
    }

    // Priorité 1 : une miniature déjà présente et valide dans le cache
    // disque est toujours affichée depuis le disque, jamais depuis le
    // réseau — donc une expiration du lien distant ne peut plus jamais
    // faire disparaître une miniature déjà chargée avec succès.
    if (_cachedFile != null) {
      return Image.file(
        _cachedFile!.file,
        fit: widget.fit,
        errorBuilder: (_, _, _) {
          _log('fichier en cache illisible -> fallback');
          return widget.fallbackBuilder(context);
        },
      );
    }

    // Priorité 2 : aucune miniature en cache -> nouvelle tentative réseau.
    // Le fallback générique n'est utilisé que si cette tentative échoue
    // réellement (403/404/HTML/expiration/timeout).
    return CachedNetworkImage(
      imageUrl: url,
      fit: widget.fit,
      placeholder: widget.loadingBuilder != null
          ? (ctx, _) => widget.loadingBuilder!(ctx)
          : null,
      errorWidget: (_, _, error) {
        _log('échec réseau (${_sanitizeForLog(url)}): $error -> fallback');
        return widget.fallbackBuilder(context);
      },
    );
  }
}
