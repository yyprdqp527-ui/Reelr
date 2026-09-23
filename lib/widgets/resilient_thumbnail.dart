import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import '../services/thumbnail_cache.dart';
import '../services/thumbnail_store.dart';

/// Widget de miniature "résilient" utilisé pour Instagram, TikTok, Facebook
/// (et toute autre plateforme utilisant des URLs de miniature à durée de vie
/// limitée, ex. tokens signés).
///
/// Problème corrigé : une URL de miniature valide, déjà affichée avec succès
/// ne doit jamais être remplacée par le visuel générique de la plateforme
/// simplement parce que l'URL distante a expiré (403/404/redirection HTML).
///
/// Stratégie, par ordre de priorité :
/// 0. Si [persistId] est fourni (id du clip), on cherche d'abord la copie
///    PERMANENTE de la miniature dans `ThumbnailStore`. Elle ne dépend ni
///    de l'URL, ni du cache (purgeable par iOS), ni du réseau.
/// 1. Sinon, on vérifie le cache disque (flutter_cache_manager). Si le
///    fichier y est, on l'affiche sans réseau — et on en fait au passage
///    une copie permanente.
/// 2. Sinon, on tente le réseau via CachedNetworkImage. En cas de succès,
///    l'image est copiée dans le stockage permanent. En cas d'échec
///    (403/404/HTML/expiration), on affiche le fallback générique fourni
///    par l'appelant — UNIQUEMENT dans ce cas.
/// 3. Un compteur de génération protège contre les races : si le widget est
///    recyclé (ListView/GridView) pour un autre clip pendant une lecture
///    asynchrone, le résultat obsolète est ignoré.
///
/// Aucune modification visuelle : les callbacks fallbackBuilder /
/// loadingBuilder fournis par l'appelant sont rendus à l'identique.
class ResilientThumbnail extends StatefulWidget {
  final String? url;
  final String cacheKeyId;
  final String platformId;
  final BoxFit fit;
  final WidgetBuilder fallbackBuilder;
  final WidgetBuilder? loadingBuilder;

  /// Id du clip dont c'est la miniature. Active le stockage permanent.
  /// Laisser null pour une image qui n'appartient pas (encore) à un clip
  /// enregistré, par exemple l'aperçu d'un import de playlist.
  final String? persistId;

  const ResilientThumbnail({
    super.key,
    required this.url,
    required this.cacheKeyId,
    required this.platformId,
    required this.fallbackBuilder,
    this.loadingBuilder,
    this.fit = BoxFit.cover,
    this.persistId,
  });

  @override
  State<ResilientThumbnail> createState() => _ResilientThumbnailState();
}

class _ResilientThumbnailState extends State<ResilientThumbnail> {
  File? _storedFile;
  FileInfo? _cachedFile;
  bool _checkingCache = true;
  bool _persistScheduled = false;
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
        oldWidget.cacheKeyId != widget.cacheKeyId ||
        oldWidget.persistId != widget.persistId) {
      _storedFile = null;
      _cachedFile = null;
      _checkingCache = true;
      _persistScheduled = false;
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

  bool _isStale(int gen, String requestClipId) =>
      !mounted || gen != _generation || widget.cacheKeyId != requestClipId;

  Future<void> _checkCache() async {
    final url = widget.url;
    final persistId = widget.persistId;
    final requestClipId = widget.cacheKeyId;
    final gen = ++_generation;

    // Priorité 0 : copie permanente, indépendante de l'URL.
    if (persistId != null) {
      final stored = await ThumbnailStore.instance.fileFor(persistId);
      if (_isStale(gen, requestClipId)) return;
      if (stored != null) {
        setState(() {
          _storedFile = stored;
          _checkingCache = false;
        });
        _log('miniature permanente trouvée -> affichage local');
        return;
      }
    }

    if (url == null || url.isEmpty) {
      _log('aucune URL disponible -> fallback');
      if (!_isStale(gen, requestClipId)) {
        setState(() => _checkingCache = false);
      }
      return;
    }

    FileInfo? info;
    try {
      info = await ThumbnailCache.instance.getFileFromCache(url);
    } catch (e) {
      _log('erreur lecture cache disque (${_sanitizeForLog(url)}): $e');
    }

    if (_isStale(gen, requestClipId)) return;

    setState(() {
      _cachedFile = info;
      _checkingCache = false;
    });
    if (info != null) {
      _log('miniature trouvée dans le cache disque -> affichage local');
      // Le cache est purgeable : on en garde une copie permanente.
      if (persistId != null) {
        _persistScheduled = true;
        ThumbnailStore.instance.saveFromFile(persistId, info.file);
      }
    } else {
      _log('aucune miniature en cache -> tentative réseau (${_sanitizeForLog(url)})');
    }
  }

  /// Appelé quand CachedNetworkImage a réussi : le fichier vient d'être
  /// écrit dans le cache, on le recopie dans le stockage permanent.
  void _persistAfterNetworkSuccess(String url) {
    final persistId = widget.persistId;
    if (persistId == null || _persistScheduled) return;
    _persistScheduled = true;
    Future<void>(() async {
      var ok = await ThumbnailStore.instance.saveFromCache(persistId, url);
      if (!ok) {
        // L'écriture dans le cache peut suivre de peu l'affichage.
        await Future<void>.delayed(const Duration(seconds: 1));
        ok = await ThumbnailStore.instance.saveFromCache(persistId, url);
      }
      _log(ok
          ? 'miniature réseau copiée dans le stockage permanent'
          : 'copie permanente impossible après chargement réseau');
    });
  }

  @override
  Widget build(BuildContext context) {
    final url = widget.url;

    if (_storedFile != null) {
      final file = _storedFile!;
      return Image.file(
        file,
        fit: widget.fit,
        errorBuilder: (_, _, _) {
          // Fichier corrompu : on le supprime pour que la passe de
          // réparation puisse le remplacer au prochain lancement.
          _log('miniature permanente illisible -> suppression + fallback');
          final persistId = widget.persistId;
          if (persistId != null) {
            FileImage(file).evict();
            ThumbnailStore.instance.delete(persistId);
          }
          return widget.fallbackBuilder(context);
        },
      );
    }

    if (_checkingCache) {
      return widget.loadingBuilder?.call(context) ?? const SizedBox.shrink();
    }

    if (url == null || url.isEmpty) {
      return widget.fallbackBuilder(context);
    }

    // Priorité 1 : une miniature déjà présente dans le cache disque est
    // affichée depuis le disque, jamais depuis le réseau.
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

    // Priorité 2 : aucune miniature locale -> tentative réseau.
    // Le fallback générique n'est utilisé que si cette tentative échoue
    // réellement (403/404/HTML/expiration/timeout).
    return CachedNetworkImage(
      imageUrl: url,
      cacheManager: ThumbnailCache.instance,
      fit: widget.fit,
      httpHeaders: ThumbnailCache.headersFor(url),
      placeholder: widget.loadingBuilder != null
          ? (ctx, _) => widget.loadingBuilder!(ctx)
          : null,
      imageBuilder: (ctx, imageProvider) {
        _persistAfterNetworkSuccess(url);
        return Image(image: imageProvider, fit: widget.fit);
      },
      errorWidget: (_, _, error) {
        _log('échec réseau (${_sanitizeForLog(url)}): $error -> fallback');
        return widget.fallbackBuilder(context);
      },
    );
  }
}
