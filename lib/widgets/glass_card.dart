import 'dart:ui';

import 'package:flutter/material.dart';

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
              // Reflet lumineux RadialGradient haut gauche + fond glass
              gradient: isDark
                  ? const RadialGradient(
                      center: Alignment(-0.8, -0.8),
                      radius: 1.5,
                      colors: [
                        Color.fromRGBO(255, 255, 255, 0.14),
                        Color.fromRGBO(255, 255, 255, 0.06),
                      ],
                    )
                  : LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        const Color.fromRGBO(245, 240, 255, 0.92),
                        const Color.fromRGBO(238, 232, 255, 0.75),
                      ],
                    ),
              borderRadius: BorderRadius.circular(borderRadius),
              // Bordüre cristal
              border: Border.all(
                color: const Color.fromRGBO(255, 255, 255, 0.12),
                width: 1,
              ),
              boxShadow: [
                // Ombre portée
                const BoxShadow(
                  color: Color.fromRGBO(0, 0, 20, 0.4),
                  blurRadius: 40,
                  offset: Offset(0, 8),
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
