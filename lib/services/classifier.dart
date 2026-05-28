import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../models/category.dart';

/// Suggestion de catégorie produite par l'IA (analyse du titre).
class CategorySuggestion {
  final String key;
  final String name;
  final Color color;
  final IconData icon;
  final String? defaultCategoryId;
  final bool isUnclassified;

  const CategorySuggestion({
    required this.key,
    required this.name,
    required this.color,
    required this.icon,
    this.defaultCategoryId,
    this.isUnclassified = false,
  });

  String get aiCategoryId => 'ai_$key';

  static const unclassified = CategorySuggestion(
    key: 'unclassified',
    name: 'Non classé',
    color: Color.fromRGBO(150, 150, 150, 1),
    icon: Icons.help_outline_rounded,
    isUnclassified: true,
  );
}

class CategoryClassifier {
  /// Mots-clés (FR + EN) par bucket de suggestion.
  static const Map<String, List<String>> _keywords = {
    'food': [
      'recettes', 'recipe', 'recipes', 'cuisiner',
      'cooking', 'cook', 'food', 'meal', 'dish', 'chef', 'restaurant',
      'repas', 'plat', 'manger', 'boire', 'vin', 'wine', 'cocktail',
      'boulangerie', 'pâtisserie', 'patisserie', 'dessert', 'gâteau',
      'gateau', 'baking', 'bake', 'pasta', 'pizza', 'soup', 'soupe',
      'salade', 'salad', 'breakfast', 'lunch', 'dinner', 'snack',
      'apéro', 'apero',
    ],
    'sport': [
      'sport', 'foot', 'football', 'soccer', 'tennis', 'basket',
      'basketball', 'rugby', 'natation', 'swim', 'swimming', 'course',
      'marathon', 'running', 'musculation', 'muscu', 'bodybuilding',
      'fitness', 'gym', 'workout', 'cardio', 'hiit', 'crossfit',
      'cyclisme', 'cycling', 'vélo', 'velo', 'squat', 'pushup',
    ],
    'yoga': [
      'yoga', 'méditation', 'meditation', 'mindfulness', 'relaxation',
      'pilates', 'respiration', 'breathwork', 'zen', 'sophrologie',
      'asana', 'vinyasa', 'hatha', 'ashtanga', 'stretching',
      'étirement', 'etirement', 'bien-être', 'bien etre', 'wellness',
    ],
    'moto': [
      'moto', 'voiture', 'car', 'auto', 'conduite', 'permis', 'route',
      'vitesse', 'garage', 'mécanique', 'mecanique', 'motorcycle',
      'motorbike', 'biker', 'harley', 'ducati', 'yamaha', 'kawasaki',
      'honda', 'bmw', 'ktm', 'triumph', 'porsche', 'ferrari', 'tesla',
      'rally', 'wheelie',
    ],
    'voyage': [
      'voyage', 'travel', 'vacances', 'trip', 'destination', 'hotel',
      'hôtel', 'avion', 'flight', 'plage', 'beach', 'montagne',
      'mountain', 'découverte', 'decouverte', 'holiday', 'roadtrip',
      'road trip', 'backpack', 'backpacking', 'adventure', 'aventure',
      'explore', 'tour', 'bali', 'japan', 'thailand', 'paris',
    ],
    'musique': [
      'musique', 'music', 'concert', 'chanson', 'song', 'guitare',
      'guitar', 'piano', 'clip officiel', 'album', 'artiste', 'lyrics',
      'paroles', 'remix', 'cover', 'acoustic', 'rap', 'hip-hop',
      'hip hop', 'rock', 'pop', 'jazz', 'dj', 'techno', 'house',
      'electro', 'mv', 'official video',
    ],
    'tricot': [
      'tricot', 'couture', 'crochet', 'broderie', 'knitting', 'sewing',
      'diy', 'fait main', 'handmade', 'laine', 'wool', 'aiguille',
      'machine à coudre', 'machine a coudre', 'patron', 'pattern',
    ],
    'bebe': [
      'bébé', 'bebe', 'enfant', 'enfants', 'kids', 'puériculture',
      'puericulture', 'grossesse', 'maternité', 'maternite', 'jouet',
      'jouets', 'école', 'ecole', 'baby', 'toddler', 'parenting',
    ],
    'humour': [
      'humour', 'drôle', 'drole', 'blague', 'rire', 'comique', 'sketch',
      'parodie', 'funny', 'humor', 'comedy', 'meme', 'memes', 'prank',
      'standup', 'stand-up', 'stand up',
    ],
    'beaute': [
      'beauté', 'beaute', 'maquillage', 'makeup', 'soin', 'soins',
      'skincare', 'coiffure', 'mode', 'fashion', 'beauty', 'manucure',
      'nail', 'nails', 'hair', 'cheveux', 'rouge à lèvres',
      'rouge a levres',
    ],
    'gaming': [
      'gaming', 'game', 'jeu', 'jeux', 'jeu vidéo', 'jeu video',
      'playstation', 'xbox', 'nintendo', 'steam', 'twitch', 'esport',
      'esports', 'gamer', 'gameplay', 'walkthrough', 'speedrun',
      'minecraft', 'fortnite', 'valorant', 'lol', 'league of legends',
    ],
    'cuisine': [
      'grillades', 'barbecue', 'bbq', 'plancha', 'cuisson', 'rôti', 'roti',
      'poêle', 'wok', 'friture', 'frire', 'fumé', 'fume', 'marinade',
      'épices', 'epices', 'assaisonnement', 'grill', 'braise',
    ],
    'finance': [
      'finance', 'argent', 'money', 'bourse', 'investissement', 'invest',
      'trading', 'crypto', 'bitcoin', 'ethereum', 'épargne', 'epargne',
      'budget', 'banque', 'bank', 'immobilier', 'dividende',
      'action', 'portefeuille', 'retraite', 'patrimoine',
    ],
    'tech': [
      'tech', 'technologie', 'technology', 'informatique', 'code',
      'coding', 'programmation', 'programming', 'développement',
      'developpement', 'logiciel', 'software', 'hardware', 'iphone',
      'android', 'ia', 'intelligence artificielle', 'ai', 'robot',
      'ordinateur', 'computer', 'javascript', 'python', 'flutter',
    ],
    'nature': [
      'nature', 'forêt', 'foret', 'plante', 'plantes', 'jardin',
      'jardinage', 'garden', 'gardening', 'fleur', 'fleurs', 'flower',
      'arbre', 'tree', 'rivière', 'riviere', 'lac', 'lake',
      'biodiversité', 'biodiversite', 'écologie', 'ecologie', 'environnement',
    ],
    'art': [
      'art', 'dessin', 'drawing', 'peinture', 'painting', 'illustration',
      'aquarelle', 'watercolor', 'sculpture', 'photographie', 'photo',
      'photography', 'créatif', 'creatif', 'creative', 'artiste', 'artist',
      'galerie', 'gallery', 'exposition',
    ],
    'animaux': [
      'animal', 'animaux', 'chien', 'dog', 'chat', 'cat', 'cheval',
      'horse', 'lapin', 'rabbit', 'oiseau', 'bird', 'poisson', 'fish',
      'reptile', 'hamster', 'vétérinaire', 'veterinaire', 'vet',
      'pet', 'pets', 'adoption', 'refuge',
    ],
    'sante': [
      'santé', 'sante', 'health', 'médecine', 'medecine', 'médical',
      'medical', 'médicament', 'medicament', 'maladie', 'disease',
      'symptôme', 'symptome', 'symptom', 'thérapie', 'therapie',
      'docteur', 'doctor', 'hôpital', 'hopital', 'hospital',
      'nutrition', 'diète', 'diete', 'diet', 'vitamine',
    ],
    'science': [
      'astro', 'astronomie', 'espace', 'planète', 'planete', 'étoile',
      'etoile', 'cosmos', 'nasa', 'science', 'univers', 'galaxie',
      'comète', 'comete', 'météorite', 'meteorite',
      'astronomy', 'space', 'planet', 'star', 'universe', 'galaxy', 'comet',
      'trou noir', 'black hole', 'big bang', 'telescope', 'télescope',
      'hubble', 'james webb', 'mars', 'jupiter', 'saturne',
      'exoplanète', 'exoplanete', 'supernova', 'nébuleuse', 'nebuleuse',
    ],
  };

  static const Map<String, CategorySuggestion> _suggestions = {
    'food': CategorySuggestion(
      key: 'food', name: 'Food',
      color: Color.fromRGBO(212, 133, 106, 1),
      icon: Icons.restaurant_outlined,
      defaultCategoryId: 'default_recettes',
    ),
    'sport': CategorySuggestion(
      key: 'sport', name: 'Sport',
      color: Color.fromRGBO(220, 100, 100, 1),
      icon: Icons.fitness_center_outlined,
      defaultCategoryId: 'default_sport',
    ),
    'yoga': CategorySuggestion(
      key: 'yoga', name: 'Yoga',
      color: Color.fromRGBO(166, 211, 220, 1),
      icon: Icons.self_improvement_outlined,
      defaultCategoryId: 'default_yoga',
    ),
    'moto': CategorySuggestion(
      key: 'moto', name: 'Moto/Auto',
      color: Color.fromRGBO(253, 174, 84, 1),
      icon: Icons.two_wheeler_rounded,
      defaultCategoryId: 'default_moto',
    ),
    'voyage': CategorySuggestion(
      key: 'voyage', name: 'Voyage',
      color: Color.fromRGBO(148, 164, 255, 1),
      icon: Icons.travel_explore_outlined,
      defaultCategoryId: 'default_voyage',
    ),
    'musique': CategorySuggestion(
      key: 'musique', name: 'Musique',
      color: Color.fromRGBO(140, 200, 130, 1),
      icon: Icons.music_note_outlined,
      defaultCategoryId: 'default_musique',
    ),
    'tricot': CategorySuggestion(
      key: 'tricot', name: 'Tricot/Couture',
      color: Color.fromRGBO(190, 140, 200, 1),
      icon: Icons.checkroom_outlined,
    ),
    'bebe': CategorySuggestion(
      key: 'bebe', name: 'Bébé',
      color: Color.fromRGBO(255, 200, 160, 1),
      icon: Icons.family_restroom_outlined,
    ),
    'humour': CategorySuggestion(
      key: 'humour', name: 'Humour',
      color: Color.fromRGBO(255, 215, 100, 1),
      icon: Icons.sentiment_very_satisfied_outlined,
    ),
    'beaute': CategorySuggestion(
      key: 'beaute', name: 'Beauté',
      color: Color.fromRGBO(240, 150, 180, 1),
      icon: Icons.style_outlined,
    ),
    'gaming': CategorySuggestion(
      key: 'gaming', name: 'Gaming',
      color: Color(0xFF74B9FF),
      icon: Icons.sports_esports_outlined,
    ),
    'cuisine': CategorySuggestion(
      key: 'cuisine', name: 'Cuisine',
      color: Color(0xFFFF6B6B),
      icon: Icons.outdoor_grill_outlined,
    ),
    'finance': CategorySuggestion(
      key: 'finance', name: 'Finance',
      color: Color(0xFF4ECDC4),
      icon: Icons.account_balance_outlined,
    ),
    'tech': CategorySuggestion(
      key: 'tech', name: 'Tech',
      color: Color(0xFF74B9FF),
      icon: Icons.computer_outlined,
    ),
    'nature': CategorySuggestion(
      key: 'nature', name: 'Nature',
      color: Color(0xFF4ECDC4),
      icon: Icons.park_outlined,
    ),
    'art': CategorySuggestion(
      key: 'art', name: 'Art',
      color: Color(0xFFC77DFF),
      icon: Icons.palette_outlined,
    ),
    'animaux': CategorySuggestion(
      key: 'animaux', name: 'Animaux',
      color: Color(0xFFFFE66D),
      icon: Icons.pets_outlined,
    ),
    'sante': CategorySuggestion(
      key: 'sante', name: 'Santé',
      color: Color(0xFFFF6B6B),
      icon: Icons.favorite_border,
    ),
    'science': CategorySuggestion(
      key: 'science', name: 'Science',
      color: Color(0xFF4ECDC4),
      icon: Icons.science_outlined,
    ),
  };

  /// Poids par mot-clé (défaut : 1 si absent).
  /// Permet aux buckets spécialisés de l'emporter sur les buckets génériques
  /// lorsque le titre est ambigu (ex. "NASA" dans un titre tech vs. science).
  static const Map<String, int> _weights = {
    // Science — très spécifiques, poids 3
    'astro': 3, 'astronomie': 3, 'nasa': 3,
    'galaxie': 3, 'galaxy': 3, 'cosmos': 3,
    'trou noir': 3, 'black hole': 3, 'big bang': 3,
    'telescope': 3, 'télescope': 3, 'hubble': 3, 'james webb': 3,
    'mars': 3, 'jupiter': 3, 'saturne': 3,
    'exoplanète': 3, 'exoplanete': 3,
    'supernova': 3, 'nébuleuse': 3, 'nebuleuse': 3,
    // Science — spécifiques, poids 2
    'planète': 2, 'planete': 2, 'étoile': 2, 'etoile': 2,
    'comète': 2, 'comete': 2, 'météorite': 2, 'meteorite': 2,
    'astronomy': 2, 'universe': 2, 'comet': 2,
  };

  /// Renvoie la meilleure suggestion pour [title] ou `unclassified`.
  static CategorySuggestion suggestDetailed(String title) {
    if (title.trim().isEmpty) return CategorySuggestion.unclassified;
    final lower = title.toLowerCase();
    final scores = <String, int>{};
    _keywords.forEach((key, kws) {
      int s = 0;
      for (final kw in kws) {
        if (lower.contains(kw)) s += _weights[kw] ?? 1;
      }
      if (s > 0) scores[key] = s;
    });
    if (scores.isEmpty) return CategorySuggestion.unclassified;
    final best =
        scores.entries.reduce((a, b) => a.value >= b.value ? a : b).key;
    return _suggestions[best]!;
  }

  /// Renvoie une [CategorySuggestion] à partir d'un categoryId YouTube,
  /// ou null si l'ID n'est pas mappé.
  /// Priorité sur la classification par mots-clés dans [suggestDetailed].
  static CategorySuggestion? categoryFromYouTubeId(String youtubeCategoryId) {
    switch (youtubeCategoryId) {
      case '1':  // Film & Animation
      case '10': // Music
        return _suggestions['musique'];
      case '2':  // Cars & Vehicles
        return _suggestions['moto'];
      case '15': // Pets & Animals
        return _suggestions['animaux'];
      case '17': // Sports
        return _suggestions['sport'];
      case '19': // Travel & Events
        return _suggestions['voyage'];
      case '20': // Gaming
        return _suggestions['gaming'];
      case '23': // Comedy
      case '24': // Entertainment
        return _suggestions['humour'];
      case '27': // Education
        return _suggestions['science'];
      case '28': // Science & Technology
        return _suggestions['tech'];
      case '22': // People & Blogs
      case '25': // News & Politics
      case '29': // Nonprofits & Activism
        return const CategorySuggestion(
          key: 'societe', name: 'Société',
          color: Color(0xFF74B9FF),
          icon: Icons.public_outlined,
        );
      case '26': // Howto & Style
        return const CategorySuggestion(
          key: 'maison', name: 'Maison',
          color: Color(0xFF4ECDC4),
          icon: Icons.home_outlined,
        );
      default:
        return null;
    }
  }

  /// Renvoie l'ID d'une catégorie existante correspondant à [suggestion].
  static String? matchExisting(
      CategorySuggestion suggestion, List<ClipCategory> categories) {
    if (suggestion.isUnclassified) return null;
    final sName = suggestion.name.toLowerCase().trim();
    for (final c in categories) {
      if (c.id == suggestion.defaultCategoryId) return c.id;
      if (c.id == suggestion.aiCategoryId) return c.id;
      final cName = c.name.toLowerCase().trim();
      if (cName == sName) return c.id;
      // Évite les faux positifs (ex: "sport" ⊂ "transport")
      // Le plus court doit représenter >60% du plus long
      final shorter = cName.length <= sName.length ? cName : sName;
      final longer  = cName.length >  sName.length ? cName : sName;
      if (shorter.length >= 5 &&
          longer.contains(shorter) &&
          shorter.length / longer.length > 0.6) {
        return c.id;
      }
    }
    return null;
  }

  /// Classifie [title] via l'API Gemini.
  /// Retourne null si la clé est absente ou si l'appel échoue (fallback suggestDetailed).
  static Future<CategorySuggestion?> classifyWithAI(
    String title,
    List<ClipCategory> existingCategories,
  ) async {
    if (existingCategories.isEmpty) return null;
    const apiKey = String.fromEnvironment('GEMINI_API_KEY');
    if (apiKey.isEmpty) return null;

    try {
      final response = await http
          .post(
            Uri.parse(
              'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent?key=$apiKey',
            ),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'contents': [
                {
                  'parts': [
                    {
                      'text':
                          'Tu es un assistant de classification de vidéos YouTube. '
                          'Titre: "$title". '
                          'Propose UNE catégorie courte (1-2 mots max) en français '
                          'qui correspond le mieux à cette vidéo. '
                          'Réponds UNIQUEMENT avec le nom de la catégorie, rien d\'autre.',
                    }
                  ]
                }
              ]
            }),
          )
          .timeout(const Duration(seconds: 8));

      if (response.statusCode != 200) return null;

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final answer =
          (((data['candidates'] as List).first as Map<String, dynamic>)['content']
                  as Map<String, dynamic>)['parts'][0]['text']
              .toString()
              .trim();

      // Cherche une catégorie existante (insensible à la casse).
      final candidates = existingCategories.where(
        (c) => c.name.toLowerCase() == answer.toLowerCase(),
      );

      if (candidates.isNotEmpty) {
        // Catégorie existante trouvée.
        final matched = candidates.first;
        return CategorySuggestion(
          key: matched.id,
          name: matched.name,
          icon: matched.icon,
          color: matched.color,
          defaultCategoryId: matched.id,
        );
      } else {
        // Nouvelle catégorie proposée par Gemini.
        final key = answer.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '_');
        return CategorySuggestion(
          key: key,
          name: answer,
          icon: Icons.folder_outlined,
          color: const Color(0xFF7C3AED),
        );
      }
    } catch (_) {
      return null;
    }
  }

}
