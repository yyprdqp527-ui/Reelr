import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Loader circulaire "border beam" : un faisceau en dégradé (violet →
/// bleu → cyan, couleurs de marque) tourne en continu autour d'un anneau.
/// Réservé aux contextes où le loader est le point focal de l'écran
/// (ex: tuile en attente de classification) — pas les petits spinners
/// inline dans les boutons.
class ReelrLoader extends StatefulWidget {
  final double size;
  final double strokeWidth;

  const ReelrLoader({
    super.key,
    this.size = 32,
    this.strokeWidth = 3,
  });

  @override
  State<ReelrLoader> createState() => _ReelrLoaderState();
}

class _ReelrLoaderState extends State<ReelrLoader>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          return CustomPaint(
            painter: _BeamPainter(
              progress: _controller.value,
              strokeWidth: widget.strokeWidth,
            ),
          );
        },
      ),
    );
  }
}

class _BeamPainter extends CustomPainter {
  final double progress;
  final double strokeWidth;

  _BeamPainter({required this.progress, required this.strokeWidth});

  static const _colors = [
    Color(0xFF8B5CF6),
    Color(0xFF2563EB),
    Color(0xFF22D3EE),
    Color(0xFF8B5CF6),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = (size.shortestSide - strokeWidth) / 2;
    final rect = Rect.fromCircle(center: center, radius: radius);

    // Anneau de fond discret, pour garder une structure visible même
    // quand le faisceau est de l'autre côté du cercle.
    final basePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.12)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(rect, 0, 2 * math.pi, false, basePaint);

    // Faisceau en dégradé, tourne en continu.
    final sweepPaint = Paint()
      ..shader = SweepGradient(
        colors: _colors,
        stops: const [0.0, 0.4, 0.7, 1.0],
        transform: GradientRotation(2 * math.pi * progress),
      ).createShader(rect)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2);
    canvas.drawArc(rect, 0, 2 * math.pi, false, sweepPaint);
  }

  @override
  bool shouldRepaint(covariant _BeamPainter oldDelegate) =>
      oldDelegate.progress != progress;
}
