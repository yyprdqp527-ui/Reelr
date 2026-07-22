import 'package:flutter/cupertino.dart';

/// Association centralisée nom de catégorie → icône standardisée, utilisée
/// uniquement pour l'affichage des badges sur les cartes de l'écran
/// d'accueil. Purement visuel : ne touche ni aux données persistées
/// (ClipCategory.icon en base SQLite), ni à la logique de classification IA.
///
/// Toutes les icônes viennent de la même famille (CupertinoIcons, variantes
/// pleines) pour un poids visuel homogène quelle que soit la catégorie.
class CategoryVisuals {
  CategoryVisuals._();

  static const Map<String, IconData> _icons = {
    'Tout': CupertinoIcons.square_grid_2x2_fill,
    'All': CupertinoIcons.square_grid_2x2_fill,
    'Podcast': CupertinoIcons.mic_fill,
    'Bien-être': CupertinoIcons.heart_fill,
    'Wellness': CupertinoIcons.heart_fill,
    'Humour': CupertinoIcons.smiley_fill,
    'Humor': CupertinoIcons.smiley_fill,
    'Famille': CupertinoIcons.person_2_fill,
    'Family': CupertinoIcons.person_2_fill,
    'Actualités': CupertinoIcons.news_solid,
    'News': CupertinoIcons.news_solid,
    'Voyage': CupertinoIcons.airplane,
    'Travel': CupertinoIcons.airplane,
    'Beauté': CupertinoIcons.paintbrush_fill,
    'Beauty': CupertinoIcons.paintbrush_fill,
    'Cinéma & Séries': CupertinoIcons.film_fill,
    'Movies & Series': CupertinoIcons.film_fill,
    'Culture': CupertinoIcons.book_fill,
    'True Crime': CupertinoIcons.shield_lefthalf_fill,
    'Conduite': CupertinoIcons.car_detailed,
    'Auto & Moto': CupertinoIcons.car_detailed,
    'Sport': CupertinoIcons.sportscourt_fill,
    'Finance': CupertinoIcons.money_dollar_circle_fill,
    'Gaming': CupertinoIcons.game_controller_solid,
    'Musique': CupertinoIcons.music_note,
    'Music': CupertinoIcons.music_note,
    'DIY': CupertinoIcons.hammer_fill,
  };

  /// Icône standardisée pour [name] ; retombe sur [fallback] pour les
  /// catégories personnalisées non répertoriées (ex. créées librement par
  /// l'utilisateur), afin de ne jamais rien casser pour les cas existants.
  static IconData iconFor(String name, IconData fallback) =>
      _icons[name] ?? fallback;

  /// Calibre la saturation et la luminosité d'une couleur de catégorie pour
  /// un rendu franc et lisible sur les miniatures (claires ou sombres),
  /// tout en conservant sa teinte d'origine (même famille chromatique).
  /// Renforce légèrement la saturation (~+25 %, plafonnée pour éviter tout
  /// rendu néon) et vise une luminosité plus riche (0.42–0.60) plutôt que
  /// pâle, sans jamais assombrir une couleur déjà nette.
  static Color desaturate(Color color) {
    final hsl = HSLColor.fromColor(color);
    final targetSaturation = (hsl.saturation * 1.25).clamp(0.0, 0.90);
    final targetLightness = hsl.lightness.clamp(0.42, 0.60);
    return hsl
        .withSaturation(targetSaturation)
        .withLightness(targetLightness)
        .toColor();
  }
}
