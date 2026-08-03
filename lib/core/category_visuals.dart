import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show Icons;

/// Association centralisée nom de catégorie → icône standardisée, utilisée
/// uniquement pour l'affichage des badges sur les cartes de l'écran
/// d'accueil et sur les lignes de la page Catégories. Purement visuel : ne
/// touche ni aux données persistées (ClipCategory.icon en base SQLite), ni
/// à la logique de classification IA.
///
/// Couvre l'intégralité des ~53 catégories standard (cat_xxx) définies dans
/// `ClipsState`, avec les mêmes icônes que la donnée source (`Icons.*`,
/// garantissant que chaque titre affiche bien le pictogramme qui correspond
/// à son thème — ex. Food → icône restaurant, jamais une icône dossier
/// générique). Les toutes premières entrées (Cupertino, "pleines") sont
/// conservées telles quelles pour compatibilité visuelle ; les nouvelles
/// entrées ajoutées ci-dessous reprennent les icônes Material d'origine.
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
    'Cinéma': CupertinoIcons.film_fill,
    'Films': CupertinoIcons.film_fill,
    'Movies & Series': CupertinoIcons.film_fill,
    'Culture': CupertinoIcons.book_fill,
    'True Crime': CupertinoIcons.shield_lefthalf_fill,
    'Conduite': CupertinoIcons.car_detailed,
    'Auto': CupertinoIcons.car_detailed,
    'Cars': CupertinoIcons.car_detailed,
    'Moto': Icons.two_wheeler_rounded,
    'Bikes': Icons.two_wheeler_rounded,
    'Sport': CupertinoIcons.sportscourt_fill,
    'Finance': CupertinoIcons.money_dollar_circle_fill,
    'Gaming': CupertinoIcons.game_controller_solid,
    'Musique': CupertinoIcons.music_note,
    'Music': CupertinoIcons.music_note,
    'DIY': CupertinoIcons.hammer_fill,

    // ── Reste du catalogue standard — icônes Material identiques à celles
    // de `ClipsState._catIcons`, pour garantir la correspondance titre ↔
    // pictogramme quelle que soit l'icône réellement persistée en base.
    'Food': Icons.restaurant_rounded,
    'Fitness': Icons.fitness_center_rounded,
    'Mode': Icons.style_rounded,
    'Fashion': Icons.style_rounded,
    'Business': Icons.business_center_rounded,
    'Société': Icons.people_rounded,
    'Society': Icons.people_rounded,
    'Déco': Icons.home_rounded,
    'Decor': Icons.home_rounded,
    'Dév. Personnel': Icons.rocket_launch_rounded,
    'Self Growth': Icons.rocket_launch_rounded,
    'Animaux': Icons.pets_rounded,
    'Pets': Icons.pets_rounded,
    'Nature': Icons.park_rounded,
    'Astrologie': Icons.auto_awesome_rounded,
    'Astrology': Icons.auto_awesome_rounded,
    'Santé': Icons.favorite_rounded,
    'Health': Icons.favorite_rounded,
    'Science': Icons.science_rounded,
    'Bébé': Icons.child_care_rounded,
    'Baby': Icons.child_care_rounded,
    'Couture': Icons.content_cut_rounded,
    'Sewing': Icons.content_cut_rounded,
    'Tricot': Icons.checkroom_outlined,
    'Knitting': Icons.checkroom_outlined,
    'Crochet': Icons.gesture_rounded,
    'Documentaire': Icons.video_library_rounded,
    'Documentary': Icons.video_library_rounded,
    'Religion': Icons.church_rounded,
    'Immobilier': Icons.apartment_rounded,
    'Real Estate': Icons.apartment_rounded,
    'Anime & Manga': Icons.auto_stories_rounded,
    'Politique': Icons.account_balance_rounded,
    'Politics': Icons.account_balance_rounded,
    'Crypto': Icons.currency_bitcoin_rounded,
    'Langues': Icons.translate_rounded,
    'Languages': Icons.translate_rounded,
    'Histoire': Icons.history_edu_rounded,
    'History': Icons.history_edu_rounded,
    'Art': Icons.palette_rounded,
    'Photo': Icons.camera_alt_rounded,
    'Outdoor': Icons.terrain_rounded,
    'Psychologie': Icons.psychology_rounded,
    'Psychology': Icons.psychology_rounded,
    'Luxe': Icons.diamond_rounded,
    'Luxury': Icons.diamond_rounded,
    'Entrepreneuriat': Icons.rocket_rounded,
    'Entrepreneurship': Icons.rocket_rounded,
    'Éducation': Icons.school_rounded,
    'Education': Icons.school_rounded,
    'Cosplay': Icons.star_rounded,
    'Danse': Icons.music_note_rounded,
    'Dance': Icons.music_note_rounded,
    'Stand-up': Icons.sentiment_very_satisfied_rounded,
    'Jardinage': Icons.yard_rounded,
    'Gardening': Icons.yard_rounded,
    'Extrême': Icons.downhill_skiing_rounded,
    'Extreme': Icons.downhill_skiing_rounded,
    'Nutrition': Icons.local_dining_rounded,
    'Vintage': Icons.watch_rounded,
    'Fails': Icons.videocam_rounded,
  };

  /// Icône standardisée pour [name] ; retombe sur [fallback] pour les
  /// catégories personnalisées non répertoriées (ex. créées librement par
  /// l'utilisateur), afin de ne jamais rien casser pour les cas existants.
  static IconData iconFor(String name, IconData fallback) =>
      _icons[name] ?? fallback;

  /// Fond de badge dédié au mode clair, pour l'ensemble du catalogue de
  /// catégories standard. Objectifs : (1) rester lisible sur le fond bleu
  /// pastel clair — certaines couleurs pensées pour le mode sombre (jaune
  /// pâle, gris, vert clair...) y perdent tout contraste — et (2) garantir
  /// un maximum de couleurs différentes d'une catégorie à l'autre, pour que
  /// deux catégories voisines (ex. Gaming / Société / Food) ne se
  /// confondent jamais visuellement. Clé = nom localisé (FR/EN), comme
  /// `_icons` ci-dessus. Ne s'applique qu'en mode clair ; le mode sombre
  /// continue d'utiliser la couleur persistée.
  static const Map<String, Color> _lightBadgeBackground = {
    'Bien-être': Color(0xFF8EDFC4),
    'Wellness': Color(0xFF8EDFC4),
    'Musique': Color(0xFFFF8A91),
    'Music': Color(0xFFFF8A91),
    'Religion': Color(0xFFB9A1E8),
    'Gaming': Color(0xFFA77BEF),
    'Actualités': Color(0xFFA8B7C8),
    'News': Color(0xFFA8B7C8),
    'Food': Color(0xFFFFB088),
    'Histoire': Color(0xFF9EDDA7),
    'History': Color(0xFF9EDDA7),
    'Société': Color(0xFF9DAFC2),
    'Society': Color(0xFF9DAFC2),
    'Culture': Color(0xFFD68AD0),
    'Couture': Color(0xFFE095D6),
    'Sewing': Color(0xFFE095D6),
    'Tricot': Color(0xFFD4A5D9),
    'Knitting': Color(0xFFD4A5D9),
    'Crochet': Color(0xFFC08FD0),
    'Stand-up': Color(0xFFF2C74E),

    'Fitness': Color(0xFFFF9E9E),
    'Beauté': Color(0xFFF2A0C7),
    'Beauty': Color(0xFFF2A0C7),
    'Mode': Color(0xFFE0A26E),
    'Fashion': Color(0xFFE0A26E),
    'Voyage': Color(0xFFAFC9E8),
    'Travel': Color(0xFFAFC9E8),
    'Humour': Color(0xFFFFD37A),
    'Humor': Color(0xFFFFD37A),
    'Podcast': Color(0xFFC7BEB0),
    'Famille': Color(0xFFF2A98E),
    'Family': Color(0xFFF2A98E),
    'Finance': Color(0xFFA9DDB0),
    'Business': Color(0xFFF0C77E),
    'DIY': Color(0xFFC8DE8E),
    'Déco': Color(0xFFE0C9A6),
    'Decor': Color(0xFFE0C9A6),
    'Auto': Color(0xFF9BB8E8),
    'Cars': Color(0xFF9BB8E8),
    'Moto': Color(0xFF7FA0D8),
    'Bikes': Color(0xFF7FA0D8),
    'Conduite': Color(0xFF9BB8E8),
    'Cinéma': Color(0xFFF5B8A8),
    'Films': Color(0xFFF5B8A8),
    'Movies & Series': Color(0xFFF5B8A8),
    'Dév. Personnel': Color(0xFF7FD8C0),
    'Self Growth': Color(0xFF7FD8C0),
    'Animaux': Color(0xFFC0E29A),
    'Pets': Color(0xFFC0E29A),
    'Nature': Color(0xFF82D9C6),
    'True Crime': Color(0xFFB7A8C9),
    'Astrologie': Color(0xFF9FA8F2),
    'Astrology': Color(0xFF9FA8F2),
    'Sport': Color(0xFFF29C6B),
    'Santé': Color(0xFFF5A3A3),
    'Health': Color(0xFFF5A3A3),
    'Science': Color(0xFF8FC1F5),
    'Bébé': Color(0xFFFFD6A8),
    'Baby': Color(0xFFFFD6A8),
    'Documentaire': Color(0xFF8FE0EC),
    'Documentary': Color(0xFF8FE0EC),
    'Immobilier': Color(0xFFD8B48C),
    'Real Estate': Color(0xFFD8B48C),
    'Anime & Manga': Color(0xFFF0A8D0),
    'Politique': Color(0xFFA0AEC2),
    'Politics': Color(0xFFA0AEC2),
    'Crypto': Color(0xFFF7DC6F),
    'Langues': Color(0xFFA8D8E8),
    'Languages': Color(0xFFA8D8E8),
    'Art': Color(0xFFE080E0),
    'Photo': Color(0xFF8FC9E8),
    'Outdoor': Color(0xFF9ED9A0),
    'Psychologie': Color(0xFFB0B8F0),
    'Psychology': Color(0xFFB0B8F0),
    'Luxe': Color(0xFFF0D080),
    'Luxury': Color(0xFFF0D080),
    'Entrepreneuriat': Color(0xFF8ED0C8),
    'Entrepreneurship': Color(0xFF8ED0C8),
    'Éducation': Color(0xFF8FB8F0),
    'Education': Color(0xFF8FB8F0),
    'Cosplay': Color(0xFFC0A0F0),
    'Danse': Color(0xFFF28FC0),
    'Dance': Color(0xFFF28FC0),
    'Jardinage': Color(0xFFA8D084),
    'Gardening': Color(0xFFA8D084),
    'Extrême': Color(0xFFF29060),
    'Extreme': Color(0xFFF29060),
    'Nutrition': Color(0xFFA0DDB0),
    'Vintage': Color(0xFFD0C0A8),
    'Fails': Color(0xFFF09090),
  };

  /// Pictogramme associé à chaque fond de `_lightBadgeBackground` — toujours
  /// foncé et de la même famille chromatique pour rester lisible à petite
  /// taille (jamais de blanc ni de gris clair sur ces badges pastel).
  static const Map<String, Color> _lightBadgeForeground = {
    'Bien-être': Color(0xFF174A3A),
    'Wellness': Color(0xFF174A3A),
    'Musique': Color(0xFF5A2027),
    'Music': Color(0xFF5A2027),
    'Religion': Color(0xFF382255),
    'Gaming': Color(0xFF31194F),
    'Actualités': Color(0xFF203654),
    'News': Color(0xFF203654),
    'Food': Color(0xFF5C2A00),
    'Histoire': Color(0xFF204F2C),
    'History': Color(0xFF204F2C),
    'Société': Color(0xFF1C2E42),
    'Society': Color(0xFF1C2E42),
    'Culture': Color(0xFF4E204A),
    'Couture': Color(0xFF54204D),
    'Sewing': Color(0xFF54204D),
    'Tricot': Color(0xFF4A2050),
    'Knitting': Color(0xFF4A2050),
    'Crochet': Color(0xFF3A1C4A),
    'Stand-up': Color(0xFF4B3700),

    'Fitness': Color(0xFF6B1414),
    'Beauté': Color(0xFF5C1339),
    'Beauty': Color(0xFF5C1339),
    'Mode': Color(0xFF4A2900),
    'Fashion': Color(0xFF4A2900),
    'Voyage': Color(0xFF1C3155),
    'Travel': Color(0xFF1C3155),
    'Humour': Color(0xFF4A3100),
    'Humor': Color(0xFF4A3100),
    'Podcast': Color(0xFF3A342A),
    'Famille': Color(0xFF5C2210),
    'Family': Color(0xFF5C2210),
    'Finance': Color(0xFF1B4A28),
    'Business': Color(0xFF4A3200),
    'DIY': Color(0xFF3C4A17),
    'Déco': Color(0xFF4A3311),
    'Decor': Color(0xFF4A3311),
    'Auto': Color(0xFF1A2F57),
    'Cars': Color(0xFF1A2F57),
    'Moto': Color(0xFF16264A),
    'Bikes': Color(0xFF16264A),
    'Conduite': Color(0xFF1A2F57),
    'Cinéma': Color(0xFF5C2417),
    'Films': Color(0xFF5C2417),
    'Movies & Series': Color(0xFF5C2417),
    'Dév. Personnel': Color(0xFF12473A),
    'Self Growth': Color(0xFF12473A),
    'Animaux': Color(0xFF33471A),
    'Pets': Color(0xFF33471A),
    'Nature': Color(0xFF0E4A3C),
    'True Crime': Color(0xFF33204A),
    'Astrologie': Color(0xFF202A6B),
    'Astrology': Color(0xFF202A6B),
    'Sport': Color(0xFF4A2600),
    'Santé': Color(0xFF5C1616),
    'Health': Color(0xFF5C1616),
    'Science': Color(0xFF123A5E),
    'Bébé': Color(0xFF4A2E00),
    'Baby': Color(0xFF4A2E00),
    'Documentaire': Color(0xFF0E4A54),
    'Documentary': Color(0xFF0E4A54),
    'Immobilier': Color(0xFF4A2F13),
    'Real Estate': Color(0xFF4A2F13),
    'Anime & Manga': Color(0xFF4A1A3C),
    'Politique': Color(0xFF1E2B3E),
    'Politics': Color(0xFF1E2B3E),
    'Crypto': Color(0xFF4A3E00),
    'Langues': Color(0xFF143A47),
    'Languages': Color(0xFF143A47),
    'Art': Color(0xFF4A1A4A),
    'Photo': Color(0xFF12374A),
    'Outdoor': Color(0xFF1C4A22),
    'Psychologie': Color(0xFF26295E),
    'Psychology': Color(0xFF26295E),
    'Luxe': Color(0xFF4A3800),
    'Luxury': Color(0xFF4A3800),
    'Entrepreneuriat': Color(0xFF12473F),
    'Entrepreneurship': Color(0xFF12473F),
    'Éducation': Color(0xFF132C57),
    'Education': Color(0xFF132C57),
    'Cosplay': Color(0xFF33174A),
    'Danse': Color(0xFF4A1230),
    'Dance': Color(0xFF4A1230),
    'Jardinage': Color(0xFF2C4A13),
    'Gardening': Color(0xFF2C4A13),
    'Extrême': Color(0xFF4A2400),
    'Extreme': Color(0xFF4A2400),
    'Nutrition': Color(0xFF1C4A2C),
    'Vintage': Color(0xFF3A2F1C),
    'Fails': Color(0xFF4A1414),
  };

  /// Fond de badge à utiliser en mode clair pour [name], ou `null` si cette
  /// catégorie n'a pas besoin d'un override (couleur persistée déjà assez
  /// contrastée, ou catégorie personnalisée).
  static Color? lightBadgeBackground(String name) => _lightBadgeBackground[name];

  /// Pictogramme à utiliser en mode clair pour [name], ou `null` si aucun
  /// override n'est défini pour cette catégorie.
  static Color? lightBadgeForeground(String name) => _lightBadgeForeground[name];

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
