import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'thumbnail_cache.dart';

/// Stockage PERMANENT des miniatures, une image par clip.
///
/// Pourquoi ce stockage en plus de `ThumbnailCache` :
///
/// Pour TikTok, Instagram et Facebook, la base ne conserve qu'une URL
/// signee qui expire (x-expires, oe=...). Jusqu'ici la seule copie de
/// l'image vivait dans le cache de flutter_cache_manager, qui :
///   - est range dans le dossier Caches d'iOS, vide par le systeme des
///     que l'appareil manque de place (typiquement les telephones pleins
///     des utilisateurs, jamais celui du developpeur) ;
///   - repart de zero apres une reinstallation ;
///   - est plafonne (3000 objets) ;
///   - est indexe par l'URL COMPLETE : un changement de domaine du proxy
///     ou de format d'URL rendait toutes les miniatures introuvables.
/// Une fois le fichier de cache perdu et l'URL expiree, la carte
/// retombait sur le logo generique.
///
/// Ici, l'image appartient a l'app :
///   - dossier Application Support/thumbnails, jamais purge par iOS
///     (et inclus dans la sauvegarde iCloud : un nouveau telephone
///     restaure retrouve ses miniatures) ;
///   - fichier nomme d'apres l'id du clip, donc independant de l'URL ;
///   - ecriture atomique (fichier temporaire puis renommage) ;
///   - contenu verifie : seules de vraies images sont conservees, pas une
///     page HTML ou une reponse JSON d'erreur.
///
/// Indisponible sur le web (pas de systeme de fichiers) : toutes les
/// methodes y renvoient null/false et l'app se comporte comme avant.
class ThumbnailStore {
  ThumbnailStore._();

  static final ThumbnailStore instance = ThumbnailStore._();

  Future<Directory?>? _dirFuture;

  /// Index en memoire : nom de fichier (id du clip nettoye) -> fichier.
  /// Permet une reponse SYNCHRONE a « ce clip a-t-il une vignette ? ».
  final Map<String, File> _known = {};

  /// Construit l'index en lisant le dossier une fois. A appeler au
  /// demarrage, avant le premier affichage. Sans lui, tout fonctionne
  /// quand meme : l'index se remplit au fil des lectures.
  Future<void> warmUp() async {
    final dir = await _directory();
    if (dir == null) return;
    try {
      await for (final entity in dir.list()) {
        if (entity is! File) continue;
        final base = p.basename(entity.path);
        if (!base.endsWith(_extension)) continue;
        _known[base.substring(0, base.length - _extension.length)] = entity;
      }
      debugPrint('[thumbstore] index: ${_known.length} miniature(s)');
    } catch (e) {
      debugPrint('[thumbstore] index impossible: $e');
    }
  }

  /// Fichier de la miniature de [clipId] si l'index le connait. Synchrone,
  /// sans acces disque : utilisable dans `initState`.
  File? knownFileFor(String clipId) => _known[_safeName(clipId)];

  Future<Directory?> _directory() {
    if (kIsWeb) return Future<Directory?>.value(null);
    return _dirFuture ??= _initDirectory();
  }

  Future<Directory?> _initDirectory() async {
    try {
      final base = await getApplicationSupportDirectory();
      final dir = Directory(p.join(base.path, 'thumbnails'));
      if (!await dir.exists()) await dir.create(recursive: true);
      return dir;
    } catch (e) {
      debugPrint('[thumbstore] dossier indisponible: $e');
      // Permettre un nouvel essai plus tard plutot que de rester bloque.
      _dirFuture = null;
      return null;
    }
  }

  /// Schema de l'URL interne donnee aux clips dont la vignette n'existe
  /// QUE dans ce stockage (obtenue par l'apercu de lien iOS, sans URL
  /// distante). Elle sert de marqueur « une vignette existe » partout ou
  /// le code attend une URL non vide.
  static const String localScheme = 'reelr-local';

  static String localUrlFor(String clipId) => '$localScheme://$clipId';

  static bool isLocalUrl(String url) => url.startsWith('$localScheme://');

  static String _safeName(String clipId) =>
      clipId.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '_');

  static const String _extension = '.img';

  /// Fichier de la miniature de [clipId], ou null s'il n'existe pas.
  Future<File?> fileFor(String clipId) async {
    final dir = await _directory();
    if (dir == null) return null;
    final name = _safeName(clipId);
    final file = File(p.join(dir.path, '$name$_extension'));
    try {
      if (await file.exists() && await file.length() > 0) {
        _known[name] = file;
        return file;
      }
    } catch (_) {}
    _known.remove(name);
    return null;
  }

  Future<bool> has(String clipId) async => (await fileFor(clipId)) != null;

  /// Enregistre [bytes] comme miniature de [clipId], si ce sont bien les
  /// octets d'une image. Ecrase une miniature existante.
  Future<bool> saveBytes(String clipId, Uint8List bytes) async {
    if (!looksLikeImage(bytes)) {
      debugPrint('[thumbstore] contenu refuse (pas une image) clip=$clipId');
      return false;
    }
    final dir = await _directory();
    if (dir == null) return false;
    final name = _safeName(clipId);
    final tmp = File(p.join(
      dir.path,
      '$name.${DateTime.now().microsecondsSinceEpoch}.tmp',
    ));
    try {
      await tmp.writeAsBytes(bytes, flush: true);
      final saved = await tmp.rename(p.join(dir.path, '$name$_extension'));
      _known[name] = saved;
      return true;
    } catch (e) {
      debugPrint('[thumbstore] ecriture impossible clip=$clipId: $e');
      try {
        if (await tmp.exists()) await tmp.delete();
      } catch (_) {}
      return false;
    }
  }

  /// Copie [source] (typiquement un fichier du cache) comme miniature.
  Future<bool> saveFromFile(String clipId, File source) async {
    try {
      final bytes = await source.readAsBytes();
      return saveBytes(clipId, bytes);
    } catch (e) {
      debugPrint('[thumbstore] lecture source impossible clip=$clipId: $e');
      return false;
    }
  }

  /// Copie la miniature de [url] depuis le cache disque, si elle y est.
  /// Aucun acces reseau.
  Future<bool> saveFromCache(String clipId, String url) async {
    try {
      final info = await ThumbnailCache.instance.getFileFromCache(url);
      if (info == null) return false;
      return saveFromFile(clipId, info.file);
    } catch (_) {
      return false;
    }
  }

  /// Supprime la miniature de [clipId] (clip supprime, ou fichier
  /// illisible qu'il faut laisser a la passe de reparation).
  Future<void> delete(String clipId) async {
    final file = await fileFor(clipId);
    _known.remove(_safeName(clipId));
    if (file == null) return;
    try {
      await file.delete();
    } catch (_) {}
  }

  /// Supprime les fichiers qui n'appartiennent a aucun clip connu, ainsi
  /// que les fichiers temporaires laisses par une ecriture interrompue.
  Future<int> pruneOrphans(Set<String> liveClipIds) async {
    final dir = await _directory();
    if (dir == null) return 0;
    final live = liveClipIds.map(_safeName).toSet();
    var removed = 0;
    try {
      await for (final entity in dir.list()) {
        if (entity is! File) continue;
        final base = p.basename(entity.path);
        final keep = base.endsWith(_extension) &&
            live.contains(base.substring(0, base.length - _extension.length));
        if (keep) continue;
        if (base.endsWith(_extension)) {
          _known.remove(base.substring(0, base.length - _extension.length));
        }
        try {
          await entity.delete();
          removed++;
        } catch (_) {}
      }
    } catch (e) {
      debugPrint('[thumbstore] nettoyage impossible: $e');
    }
    return removed;
  }

  /// Vrai si [bytes] commencent par la signature d'un format d'image
  /// connu (JPEG, PNG, GIF, WebP, HEIC/AVIF).
  ///
  /// Les tout petits fichiers sont refuses : ce sont des pixels de suivi
  /// ou des images vides, jamais une vraie miniature de video.
  @visibleForTesting
  static bool looksLikeImage(Uint8List b) {
    if (b.length < 100) return false;
    // JPEG
    if (b[0] == 0xFF && b[1] == 0xD8 && b[2] == 0xFF) return true;
    // PNG
    if (b[0] == 0x89 && b[1] == 0x50 && b[2] == 0x4E && b[3] == 0x47) {
      return true;
    }
    // GIF
    if (b[0] == 0x47 && b[1] == 0x49 && b[2] == 0x46 && b[3] == 0x38) {
      return true;
    }
    // WebP : "RIFF" .... "WEBP"
    if (b[0] == 0x52 && b[1] == 0x49 && b[2] == 0x46 && b[3] == 0x46 &&
        b[8] == 0x57 && b[9] == 0x45 && b[10] == 0x42 && b[11] == 0x50) {
      return true;
    }
    // HEIC / AVIF : boite "ftyp" a l'octet 4
    if (b[4] == 0x66 && b[5] == 0x74 && b[6] == 0x79 && b[7] == 0x70) {
      return true;
    }
    return false;
  }
}
