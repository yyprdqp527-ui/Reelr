import 'package:flutter/material.dart';

/// Badge pour l'icône d'une carte de catégorie sur l'écran d'accueil : même
/// taille et même poids visuel quelle que soit la miniature affichée en
/// dessous. Même direction artistique dans les deux thèmes : carré opaque
/// coloré + pictogramme contrasté — jamais une icône posée directement sans
/// fond, jamais de pastille translucide.
class CategoryIconBadge extends StatelessWidget {
  final IconData icon;
  /// Fond du carré (couleur de catégorie, ou couleur de substitution pour
  /// les catégories peu contrastées).
  final Color background;
  /// Pictogramme — toujours une teinte contrastée sur [background].
  final Color foreground;
  final double size;
  final double iconSize;

  const CategoryIconBadge({
    super.key,
    required this.icon,
    required this.background,
    required this.foreground,
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
        color: background.withValues(alpha: 0.96),
        borderRadius: BorderRadius.circular(size / 2.6),
      ),
      child: Icon(icon, size: iconSize, color: foreground),
    );
  }
}
