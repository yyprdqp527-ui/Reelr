import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:reelr/services/thumbnail_store.dart';

Uint8List _withHeader(List<int> header, {int size = 200}) {
  final b = Uint8List(size);
  b.setRange(0, header.length, header);
  return b;
}

void main() {
  group('ThumbnailStore.looksLikeImage', () {
    test('accepte JPEG, PNG, GIF, WebP, HEIC', () {
      expect(ThumbnailStore.looksLikeImage(_withHeader([0xFF, 0xD8, 0xFF])), isTrue);
      expect(ThumbnailStore.looksLikeImage(_withHeader([0x89, 0x50, 0x4E, 0x47])), isTrue);
      expect(ThumbnailStore.looksLikeImage(_withHeader([0x47, 0x49, 0x46, 0x38])), isTrue);
      expect(
        ThumbnailStore.looksLikeImage(_withHeader(
            [0x52, 0x49, 0x46, 0x46, 0, 0, 0, 0, 0x57, 0x45, 0x42, 0x50])),
        isTrue,
      );
      expect(
        ThumbnailStore.looksLikeImage(
            _withHeader([0, 0, 0, 0x18, 0x66, 0x74, 0x79, 0x70])),
        isTrue,
      );
    });

    test('refuse une video MP4 (meme boite ftyp que HEIC/AVIF)', () {
      // Cas reel : la « vignette » d'Oh My Resto etait une video de 10 Mo.
      final mp4 = _withHeader(
          [0, 0, 0, 0x20, 0x66, 0x74, 0x79, 0x70, 0x69, 0x73, 0x6f, 0x6d]);
      expect(ThumbnailStore.looksLikeImage(mp4), isFalse);
      final qt = _withHeader(
          [0, 0, 0, 0x14, 0x66, 0x74, 0x79, 0x70, 0x71, 0x74, 0x20, 0x20]);
      expect(ThumbnailStore.looksLikeImage(qt), isFalse);
    });

    test('accepte HEIC', () {
      final heic = _withHeader(
          [0, 0, 0, 0x18, 0x66, 0x74, 0x79, 0x70, 0x68, 0x65, 0x69, 0x63]);
      expect(ThumbnailStore.looksLikeImage(heic), isTrue);
    });

    test('refuse HTML, JSON et fichiers minuscules', () {
      expect(
        ThumbnailStore.looksLikeImage(
            _withHeader('<!DOCTYPE html>'.codeUnits)),
        isFalse,
      );
      expect(
        ThumbnailStore.looksLikeImage(_withHeader('{"error":"x"}'.codeUnits)),
        isFalse,
      );
      expect(
        ThumbnailStore.looksLikeImage(_withHeader([0xFF, 0xD8, 0xFF], size: 43)),
        isFalse,
      );
    });
  });
}
