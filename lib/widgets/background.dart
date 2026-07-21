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
          // Sombre : dégradé identité inchangé. Clair : fond uni — plus de
          // dégradé/voile coloré sur tout l'écran.
          color: isDark ? null : AppTheme.lightBackground,
          gradient: isDark
              ? const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [AppTheme.background, Color(0xFF1A0A2E)],
                )
              : null,
        ),
        child: Stack(
          children: isDark
              ? const [
                  Positioned(
                    top: -120,
                    right: -80,
                    child: Orb(
                      size: 360,
                      color: Color.fromRGBO(124, 58, 237, 0.18),
                    ),
                  ),
                  Positioned(
                    top: 220,
                    left: -120,
                    child: Orb(
                      size: 300,
                      color: Color.fromRGBO(37, 99, 235, 0.15),
                    ),
                  ),
                  Positioned(
                    bottom: 40,
                    right: -60,
                    child: Orb(
                      size: 280,
                      color: Color.fromRGBO(10, 10, 31, 0.4),
                    ),
                  ),
                ]
              // Un seul reflet, très discret, centré en haut autour de la
              // zone du logo — presque imperceptible, plus de voile violet
              // ni de halo rose sur le reste de l'écran.
              : [
                  Positioned(
                    top: -60,
                    left: 0,
                    right: 0,
                    child: Center(
                      child: Orb(
                        size: 200,
                        color: AppTheme.lightLavenderTint.withValues(alpha: 0.22),
                      ),
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
