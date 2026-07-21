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
          // Sombre : dégradé identité inchangé. Clair : dégradé vertical
          // pastel plus affirmé (lavande lumineuse en haut → lavande
          // principal au centre → bleu pastel en bas) — plus vivant que la
          // version précédente, mais toujours pastel, jamais saturé.
          gradient: isDark
              ? const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [AppTheme.background, Color(0xFF1A0A2E)],
                )
              : const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    AppTheme.lightBackgroundSecondary,
                    AppTheme.lightBackground,
                    AppTheme.lightBackgroundDeep,
                  ],
                  stops: [0.0, 0.5, 1.0],
                ),
        ),
        // Sombre : orbes identité inchangés. Clair : aucun halo/cercle —
        // la présence violet/bleu vient uniquement du dégradé de fond
        // ci-dessus, pour un logo net et propre, sans effet de glow.
        child: isDark
            ? const Stack(
                children: [
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
                ],
              )
            : null,
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
