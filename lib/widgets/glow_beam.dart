import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

/// Horloge partagee du faisceau lumineux (meme tour que la barre de
/// recherche : 1,6 s). UN SEUL ticker pour toutes les tuiles qui brillent, et
/// il ne tourne que s'il y en a au moins une (batterie).
class BeamClock {
  BeamClock._();
  static final BeamClock instance = BeamClock._();

  static const int _periodMs = 1600;

  final ValueNotifier<double> progress = ValueNotifier<double>(0);
  Ticker? _ticker;
  int _users = 0;

  void acquire() {
    _users++;
    _ticker ??= Ticker(_onTick)..start();
  }

  void release() {
    _users--;
    if (_users <= 0) {
      _users = 0;
      _ticker?.dispose();
      _ticker = null;
    }
  }

  void _onTick(Duration elapsed) {
    progress.value = (elapsed.inMilliseconds % _periodMs) / _periodMs;
  }
}

/// Contour lumineux anime (bleu -> cyan, comme la barre de recherche), a
/// poser en `foregroundDecoration` d'une tuile ou d'une puce.
class BeamDecoration extends Decoration {
  final double radius;
  final double strokeWidth;
  const BeamDecoration({required this.radius, this.strokeWidth = 2.2});

  @override
  BoxPainter createBoxPainter([VoidCallback? onChanged]) =>
      _BeamBoxPainter(this, onChanged);

  @override
  bool operator ==(Object other) =>
      other is BeamDecoration &&
      other.radius == radius &&
      other.strokeWidth == strokeWidth;

  @override
  int get hashCode => Object.hash(radius, strokeWidth);
}

class _BeamBoxPainter extends BoxPainter {
  final BeamDecoration decoration;
  _BeamBoxPainter(this.decoration, VoidCallback? onChanged)
      : super(onChanged) {
    BeamClock.instance.acquire();
    BeamClock.instance.progress.addListener(_tick);
  }

  void _tick() => onChanged?.call();

  static const _colors = [
    Color(0xFF2563EB),
    Color(0xFF22D3EE),
    Color(0xFF2563EB),
  ];

  @override
  void paint(Canvas canvas, Offset offset, ImageConfiguration configuration) {
    final size = configuration.size;
    if (size == null) return;
    final sw = decoration.strokeWidth;
    final rect = (offset & size).deflate(sw / 2);
    final rrect =
        RRect.fromRectAndRadius(rect, Radius.circular(decoration.radius));
    final shader = SweepGradient(
      colors: _colors,
      stops: const [0.0, 0.5, 1.0],
      transform:
          GradientRotation(2 * math.pi * BeamClock.instance.progress.value),
    ).createShader(rect);
    // Halo doux puis trait net : c'est ce qui donne l'effet « lumineux ».
    canvas.saveLayer(rect.inflate(sw * 3),
        Paint()..color = const Color.fromRGBO(0, 0, 0, 0.4));
    canvas.drawRRect(
      rrect,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = sw * 2.5
        ..shader = shader
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
    );
    canvas.restore();
    canvas.drawRRect(
      rrect,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = sw
        ..shader = shader,
    );
  }

  @override
  void dispose() {
    BeamClock.instance.progress.removeListener(_tick);
    BeamClock.instance.release();
    super.dispose();
  }
}
