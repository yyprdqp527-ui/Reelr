import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';

/// Carte de vignette dessinee par l'app quand aucune vraie image n'a pu
/// etre obtenue : logo du site (ou initiale), titre, nom du site, sur un
/// fond degrade propre a chaque site. C'est la derniere etape de la regle
/// generale des vignettes : elle ne depend d'aucun reseau et ne peut pas
/// echouer.
Future<Uint8List> renderThumbnailCard({
  required String title,
  required String host,
  Uint8List? logo,
}) async {
  const w = 640.0;
  const h = 480.0;
  final cleanHost = host.toLowerCase().startsWith('www.') ? host.substring(4) : host;
  final recorder = ui.PictureRecorder();
  final canvas = ui.Canvas(recorder, const ui.Rect.fromLTWH(0, 0, w, h));

  final hue = (cleanHost.hashCode.abs() % 360).toDouble();
  final c1 = HSLColor.fromAHSL(1, hue, 0.45, 0.20).toColor();
  final c2 = HSLColor.fromAHSL(1, (hue + 40) % 360, 0.45, 0.34).toColor();
  canvas.drawRect(
    const ui.Rect.fromLTWH(0, 0, w, h),
    ui.Paint()
      ..shader = ui.Gradient.linear(
          const ui.Offset(0, 0), const ui.Offset(w, h), [c1, c2]),
  );

  // Pastille blanche : logo du site, sinon initiale.
  const badge = 120.0;
  final badgeRect = ui.RRect.fromRectAndRadius(
    const ui.Rect.fromLTWH((w - badge) / 2, 70, badge, badge),
    const ui.Radius.circular(26),
  );
  canvas.drawRRect(badgeRect, ui.Paint()..color = const ui.Color(0xFFFFFFFF));
  var drewLogo = false;
  if (logo != null) {
    try {
      final codec = await ui.instantiateImageCodec(logo);
      final frame = await codec.getNextFrame();
      final img = frame.image;
      canvas.drawImageRect(
        img,
        ui.Rect.fromLTWH(0, 0, img.width.toDouble(), img.height.toDouble()),
        const ui.Rect.fromLTWH((w - badge) / 2 + 18, 88, badge - 36, badge - 36),
        ui.Paint()..filterQuality = ui.FilterQuality.high,
      );
      img.dispose();
      codec.dispose();
      drewLogo = true;
    } catch (_) {}
  }
  if (!drewLogo) {
    final letter = cleanHost.isEmpty ? '?' : cleanHost[0].toUpperCase();
    final tp = TextPainter(
      text: TextSpan(
        text: letter,
        style: TextStyle(
            color: c1, fontSize: 64, fontWeight: ui.FontWeight.w800),
      ),
      textDirection: ui.TextDirection.ltr,
    )..layout();
    tp.paint(canvas,
        ui.Offset((w - tp.width) / 2, 70 + (badge - tp.height) / 2));
  }

  final shortTitle = title.length > 120 ? '${title.substring(0, 117)}...' : title;
  if (shortTitle.trim().isNotEmpty) {
    final tp = TextPainter(
      text: TextSpan(
        text: shortTitle,
        style: const TextStyle(
            color: ui.Color(0xFFFFFFFF),
            fontSize: 34,
            fontWeight: ui.FontWeight.w700,
            height: 1.2),
      ),
      textAlign: ui.TextAlign.center,
      textDirection: ui.TextDirection.ltr,
      maxLines: 3,
      ellipsis: '...',
    )..layout(maxWidth: w - 80);
    tp.paint(canvas, ui.Offset(40, 225));
  }
  if (cleanHost.isNotEmpty) {
    final tp = TextPainter(
      text: TextSpan(
        text: cleanHost,
        style: const TextStyle(color: ui.Color(0xB3FFFFFF), fontSize: 24),
      ),
      textDirection: ui.TextDirection.ltr,
    )..layout(maxWidth: w - 80);
    tp.paint(canvas, ui.Offset((w - tp.width) / 2, h - 60));
  }

  final picture = recorder.endRecording();
  final image = await picture.toImage(w.toInt(), h.toInt());
  final data = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  return data!.buffer.asUint8List();
}
