import 'dart:ui';

import 'package:flutter/material.dart';

import '../core/theme.dart';

class GlassCard extends StatelessWidget {
  final Widget child;
  final double borderRadius;
  final EdgeInsetsGeometry? padding;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final double blur;

  const GlassCard({
    super.key,
    required this.child,
    this.borderRadius = 24,
    this.padding,
    this.onTap,
    this.onLongPress,
    this.blur = 40,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
          child: Container(
            decoration: BoxDecoration(
              // Reflet lumineux RadialGradient haut gauche + fond glass —
              // teinté avec les surfaces centralisées (au lieu d'un blanc
              // uni) pour bien se distinguer du fond sombre uni.
              gradient: isDark
                  ? RadialGradient(
                      center: const Alignment(-0.8, -0.8),
                      radius: 1.5,
                      colors: [
                        AppTheme.surfaceElevated.withValues(alpha: 0.70),
                        AppTheme.surface.withValues(alpha: 0.55),
                      ],
                    )
                  // Surface blanche translucide (0.70–0.90) : se détache
                  // clairement du fond clair sobre, au lieu de se fondre
                  // dans une teinte lavande proche du fond.
                  : LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        AppTheme.lightSurface(alpha: 0.88),
                        AppTheme.lightSurface(alpha: 0.74),
                      ],
                    ),
              borderRadius: BorderRadius.circular(borderRadius),
              // Bordure cristal
              border: Border.all(
                color: isDark ? AppTheme.darkBorder : AppTheme.lightBorder,
                width: 1,
              ),
              boxShadow: [
                // Ombre portée — allégée en sombre (fine bordure + faible
                // élévation plutôt qu'une ombre noire lourde) ; inchangée
                // en clair.
                BoxShadow(
                  color: isDark
                      ? Colors.black.withValues(alpha: 0.22)
                      : const Color.fromRGBO(0, 0, 20, 0.4),
                  blurRadius: isDark ? 16 : 40,
                  offset: Offset(0, isDark ? 4 : 8),
                ),
                // Lumière interne (reflet bas)
                BoxShadow(
                  color: Colors.white.withValues(alpha: 0.10),
                  blurRadius: 1,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
            padding: padding ?? const EdgeInsets.all(16),
            child: child,
          ),
        ),
      ),
    );
  }
}
