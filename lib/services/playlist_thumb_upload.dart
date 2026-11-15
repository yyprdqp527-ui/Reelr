import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:http/http.dart' as http;

import '../config/secrets.dart';
import '../models/clip.dart';
import 'thumbnail_store.dart';

/// Envoie au Worker la copie permanente des vignettes d'une playlist
/// partagée. Les adresses d'origine (Facebook, Instagram...) expirent vite :
/// l'ami verrait le logo de la plateforme au lieu de la vignette.
///
/// Toute erreur est silencieuse : la vignette retombe sur l'adresse
/// d'origine, comme avant.
class PlaylistThumbUpload {
  static const int _maxBytes = 300 * 1024;
  static const int _parallel = 4;

  static String get _base =>
      Secrets.reelrProxyUrl.replaceAll('/v1/messages', '');

  /// id du clip -> adresse publique de sa vignette.
  static Future<Map<String, String>> uploadFor(List<Clip> clips) async {
    final result = <String, String>{};
    final queue = clips.where(_needsUpload).toList();
    Future<void> worker() async {
      while (queue.isNotEmpty) {
        final clip = queue.removeLast();
        final url = await _uploadOne(clip);
        if (url != null) result[clip.id] = url;
      }
    }

    try {
      await Future.wait(List.generate(_parallel, (_) => worker()))
          .timeout(const Duration(seconds: 20));
    } catch (_) {}
    return Map<String, String>.from(result);
  }

  /// YouTube et Pinterest ont des adresses stables : inutile de les copier.
  static bool _needsUpload(Clip c) {
    final u = c.url.toLowerCase();
    if (u.contains('youtube.com') || u.contains('youtu.be')) return false;
    final th = (c.thumbnailUrl ?? '').toLowerCase();
    if (th.contains('pinimg.com')) return false;
    return true;
  }

  static Future<String?> _uploadOne(Clip clip) async {
    try {
      final file = await ThumbnailStore.instance.fileFor(clip.id);
      if (file == null) return null;
      var bytes = await file.readAsBytes();
      // Les vignettes locales font souvent 300 Ko a 1 Mo : on les reduit.
      if (bytes.length > _maxBytes) {
        final small = await _shrink(bytes);
        if (small == null) return null;
        bytes = small;
      }
      if (bytes.isEmpty) return null;
      final type = _imageType(bytes);
      if (type == null) return null;
      final response = await http
          .post(
            Uri.parse('$_base/playlist-thumb'),
            headers: {
              'x-reelr-secret': Secrets.appSharedSecret,
              'content-type': type,
            },
            body: bytes,
          )
          .timeout(const Duration(seconds: 8));
      if (response.statusCode != 200) return null;
      final id = (jsonDecode(response.body) as Map<String, dynamic>)['id'];
      if (id is! String || id.isEmpty) return null;
      return '$_base/pt/$id';
    } catch (_) {
      return null;
    }
  }

  /// Reduit en PNG, de la plus grande largeur a la plus petite, jusqu'a
  /// passer sous la limite du Worker.
  static Future<Uint8List?> _shrink(Uint8List bytes) async {
    for (final w in const [480, 384, 288, 224]) {
      try {
        final codec = await ui.instantiateImageCodec(bytes, targetWidth: w);
        final frame = await codec.getNextFrame();
        final data =
            await frame.image.toByteData(format: ui.ImageByteFormat.png);
        frame.image.dispose();
        if (data == null) return null;
        final out = data.buffer.asUint8List();
        if (out.length <= _maxBytes) return out;
      } catch (_) {
        return null;
      }
    }
    return null;
  }

  static String? _imageType(Uint8List b) {
    if (b.length > 3 && b[0] == 0xFF && b[1] == 0xD8) return 'image/jpeg';
    if (b.length > 3 && b[0] == 0x89 && b[1] == 0x50) return 'image/png';
    if (b.length > 11 && b[0] == 0x52 && b[1] == 0x49 && b[8] == 0x57) {
      return 'image/webp';
    }
    if (b.length > 3 && b[0] == 0x47 && b[1] == 0x49) return 'image/gif';
    return null;
  }
}
