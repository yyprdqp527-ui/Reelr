import 'package:flutter/material.dart';

/// Badge uniforme pour l'icône d'une carte de catégorie sur l'écran
/// d'accueil : même taille, même fond, même poids visuel quelle que soit
/// la miniature affichée en dessous ou le thème clair/sombre.
class CategoryIconBadge extends StatelessWidget {
  final IconData icon;
  final Color color;
  final double size;
  final double iconSize;

  const CategoryIconBadge({
    super.key,
    required this.icon,
    required this.color,
    this.size = 36,
    this.iconSize = 23,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: const Color(0xFF000000).withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(size / 2.6),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.10),
          width: 0.8,
        ),
      ),
      child: Icon(icon, size: iconSize, color: color),
    );
  }
}
