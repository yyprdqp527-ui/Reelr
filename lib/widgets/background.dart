import 'package:flutter/material.dart';

import '../core/theme.dart';

class GradientBackground extends StatelessWidget {
  final bool isDark;

  const GradientBackground({super.key, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isDark
                ? const [
                    Color(0xFF0A0A0F),
                    Color(0xFF1A0A2E),
                  ]
                : const [
                    Color(0xFFF3EEFF),
                    Color(0xFFEEF2FF),
                    Color(0xFFFFF0F5),
                  ],
          ),
        ),
        child: Stack(
          children: [
            Positioned(
              top: -120,
              right: -80,
              child: Orb(
                size: 360,
                color: Color.fromRGBO(124, 58, 237, isDark ? 0.18 : 0.25),
              ),
            ),
            Positioned(
              top: 220,
              left: -120,
              child: Orb(
                size: 300,
                color: Color.fromRGBO(37, 99, 235, isDark ? 0.15 : 0.20),
              ),
            ),
            Positioned(
              bottom: 40,
              right: -60,
              child: Orb(
                size: 280,
                color: AppTheme.darkGreen
                    .withValues(alpha: isDark ? 0.4 : 0.15),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class Orb extends StatelessWidget {
  final double size;
  final Color color;

  const Orb({super.key, required this.size, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(colors: [color, Colors.transparent]),
      ),
    );
  }
}
