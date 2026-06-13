import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../config/secrets.dart';
import '../models/category.dart';
import '../models/classification_result.dart';
import '../models/client_profile.dart';

/// Suggestion de catégorie produite par l'IA (analyse du titre).
class CategorySuggestion {
  final String key;
  final String name;
  final Color color;
  final IconData icon;
  final bool isUnclassified;

  const CategorySuggestion({
    required this.key,
    required this.name,
    required this.color,
    required this.icon,
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
      'raclette', 'tartiflette', 'fondue', 'gratin',
      'quiche', 'tarte', 'crêpe', 'crepe', 'galette',
      'lasagne', 'risotto', 'curry', 'wok', 'marinade',
      'smoothie', 'jus', 'bouillon', 'ramen', 'sushi',
      'burger', 'sandwich', 'wrap', 'bowl', 'brunch',
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
      'laine', 'wool', 'aiguille', 'machine à coudre', 'machine a coudre',
      'patron', 'pattern',
    ],
    'diy_crea': [
      'diy', 'fait main', 'handmade', 'tuto', 'tutoriel', 'tutorial',
      'how to make', 'how to build', 'how to craft', 'craft', 'crafts',
      'créa', 'crea', 'creation', 'création', 'fabrication', 'fabriquer',
      'construire', 'build', 'make', 'trap', 'piège', 'piege',
      'procreate', 'illustration', 'dessin', 'drawing', 'peinture',
      'painting', 'aquarelle', 'watercolor', 'sculpture',
      'photography', 'photographie', 'créatif', 'creatif', 'creative',
    ],
    'bebe': [
      'bébé', 'bebe', 'enfant', 'enfants', 'kids', 'puériculture',
      'puericulture', 'grossesse', 'maternité', 'maternite', 'jouet',
      'jouets', 'école', 'ecole', 'baby', 'toddler', 'parenting',
      'parents',
    ],
    'humour': [
      'humour', 'drôle', 'drole', 'blague', 'rire', 'comique', 'sketch',
      'parodie', 'funny', 'humor', 'comedy', 'meme', 'memes', 'prank',
      'standup', 'stand-up', 'stand up',
    ],
    'beaute': [
      'beauté', 'beaute', 'maquillage', 'makeup', 'soin', 'soins',
      'skincare', 'coiffure', 'beauty', 'manucure',
      'nail', 'nails', 'hair', 'cheveux', 'rouge à lèvres',
      'rouge a levres',
    ],
    'mode': [
      'mode', 'fashion', 'tenue', 'outfit', 'ootd', 'lookbook',
      'streetwear', 'vêtement', 'vetement', 'fringues',
      'sneaker', 'sneakers', 'tendance mode', 'haul mode',
      'haul vêtements', 'style vestimentaire',
    ],
    'gaming': [
      'gaming', 'game', 'jeu', 'jeux', 'jeu vidéo', 'jeu video',
      'playstation', 'xbox', 'nintendo', 'steam', 'twitch', 'esport',
      'esports', 'gamer', 'gameplay', 'walkthrough', 'speedrun',
      'minecraft', 'fortnite', 'valorant', 'lol', 'league of legends',
      'stream', 'streaming', 'streamer', 'clip twitch', 'lets play',
      'fps', 'mmorpg', 'rpg', 'moba', 'battle royale', 'ranked',
      'genshin', 'apex', 'overwatch', 'pubg', 'fifa', 'cod', 'call of duty',
      'hearthstone', 'dota', 'cs go', 'csgo', 'counter strike',
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
      'art', 'artiste', 'artist', 'galerie', 'gallery', 'exposition',
      'musée', 'musee', 'tattoo', 'tatouage', 'street art', 'graffiti',
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
    'podcast': [
      'podcast', 'épisode', 'episode', 'saison', 'invité', 'invite',
      'interview', 'interviewe', 'guest', 'micro', 'studio radio',
      'à écouter', 'a ecouter', 'écouter', 'ecouter',
      // Podcasts français connus
      'legend', 'transfert', 'génération do it yourself', 'generation do it yourself',
      'gdiy', 'artichaut', 'arte podcast', 'france inter', 'france culture',
      'binge audio', 'nouvelles écoutes', 'nouvelles ecoutes',
      'passerelles', 'la story', 'les couilles sur la table',
      'emotioncast', 'les pieds sur terre', 'yala', 'kiffe ta race',
      'inner game', 'innermost', 'le gratin', 'thinkerview',
    ],
    'actu': [
      // Affaires / scandales
      'bruel', 'affaire bruel', 'affaire', 'scandale', 'polémique',
      'polemique', 'tribunal', 'jugement', 'condamné', 'condamne',
      'mis en examen', 'garde à vue', 'garde a vue', 'arrestation',
      'procès', 'proces', 'verdict', 'peine', 'victime', 'témoignage',
      'temoignage', 'accusé', 'accuse', 'plainte', 'enquête', 'enquete',
      // Actualité générale
      'actualité', 'actualite', 'news', 'info', 'infos', 'politique',
      'élection', 'election', 'président', 'president', 'gouvernement',
      'parlement', 'assemblée', 'assemblee', 'sénat', 'senat',
      'grève', 'greve', 'manifestation', 'manif', 'syndicat',
      'guerre', 'conflit', 'crise', 'inflation', 'économie', 'economie',
      'société', 'societe', 'social', 'inégalités', 'inegalites',
      'discrimination', 'racisme', 'féminisme', 'feminisme',
    ],
    'true_crime': [
      'true crime', 'crime', 'meurtre', 'murder', 'serial killer',
      'tueur en série', 'tueur en serie', 'affaire criminelle',
      'cold case', 'disparition', 'enlèvement', 'enlevement',
      'détective', 'detective', 'enquête criminelle', 'enquete criminelle',
      'fait divers', 'faits divers', 'polar', 'thriller',
    ],
    'documentaire': [
      'documentaire', 'documentary', 'doc', 'reportage', 'investigation',
      'enquête', 'enquete', 'arte', 'france tv', 'netflix doc',
      'expliqué', 'explique', 'explained', 'histoire vraie', 'vrai histoire',
      'derrière', 'derriere', 'behind the scenes', 'making of',
    ],
    'cinema_series': [
      'film', 'cinéma', 'cinema', 'movie', 'série', 'serie', 'series',
      'saison', 'épisode', 'episode', 'netflix', 'disney+', 'disney plus',
      'hbo', 'prime video', 'apple tv', 'canal+', 'bande annonce',
      'trailer', 'teaser', 'casting', 'réalisateur', 'realisateur',
      'acteur', 'actrice', 'critique film', 'review film',
      'marvel', 'dc comics', 'star wars', 'anime', 'manga',
    ],
    'religion': [
      'messe', 'église', 'eglise', 'prière', 'priere', 'dieu', 'allah',
      'jésus', 'jesus', 'christ', 'chrétien', 'chretien', 'islam', 'musulman',
      'catholique', 'protestant', 'évangile', 'evangile', 'bible', 'coran',
      'foi', 'croyant', 'paroisse', 'sermon', 'culte', 'pasteur', 'imam',
      'réveil spirituel', 'reveil spirituel', 'live spirituel', 'prêche', 'preche',
      'temple', 'mosquée', 'mosquee', 'synagogue', 'shabbat', 'ramadan',
    ],
    'astro_spirituel': [
      'astrologie', 'astrology', 'zodiaque', 'zodiac', 'horoscope',
      'ascendant', 'gémeaux', 'gemeaux', 'taureau', 'vierge', 'scorpion',
      'spiritualité', 'spiritualite', 'spirituel', 'spiritual',
      'chakra', 'méditation guidée', 'meditation guidee', 'manifestation',
      'loi de l\'attraction', 'law of attraction', 'vibration',
      'ésotérisme', 'esoterisme', 'tarot', 'oracle', 'cristal',
      'full moon', 'pleine lune', 'énergie', 'energie',
    ],
    'langue_culture': [
      'apprendre', 'learn', 'langue', 'language', 'anglais', 'english',
      'espagnol', 'spanish', 'italien', 'italian', 'allemand', 'german',
      'japonais', 'japanese', 'coréen', 'korean', 'arabe', 'arabic',
      'vocabulaire', 'vocabulary', 'grammaire', 'grammar',
      'prononciation', 'pronunciation', 'cours de', 'leçon', 'lecon',
      'histoire', 'history', 'philosophie', 'philosophy',
      'littérature', 'litterature', 'lecture', 'livre', 'book',
    ],
    'immo_deco': [
      'immobilier', 'immo', 'appartement', 'maison', 'house', 'flat',
      'achat', 'vente', 'loyer', 'rent', 'locataire', 'propriétaire',
      'proprietaire', 'investissement locatif', 'rénovation', 'renovation',
      'déco', 'deco', 'décoration', 'decoration', 'intérieur', 'interieur',
      'ikea', 'aménagement', 'amenagement', 'rangement', 'organisation',
      'maisons du monde', 'leroy merlin', 'home tour', 'room tour',
      'before after', 'avant après', 'avant apres',
    ],
  };

  static const Map<String, CategorySuggestion> _suggestions = {
    'food': CategorySuggestion(
      key: 'food', name: 'Food',
      color: Color.fromRGBO(212, 133, 106, 1),
      icon: Icons.restaurant_outlined,
    ),
    'sport': CategorySuggestion(
      key: 'sport', name: 'Sport',
      color: Color.fromRGBO(220, 100, 100, 1),
      icon: Icons.fitness_center_outlined,
    ),
    'yoga': CategorySuggestion(
      key: 'yoga', name: 'Yoga',
      color: Color.fromRGBO(166, 211, 220, 1),
      icon: Icons.self_improvement_outlined,
    ),
    'moto': CategorySuggestion(
      key: 'moto', name: 'Moto/Auto',
      color: Color.fromRGBO(253, 174, 84, 1),
      icon: Icons.two_wheeler_rounded,
    ),
    'voyage': CategorySuggestion(
      key: 'voyage', name: 'Voyage',
      color: Color.fromRGBO(148, 164, 255, 1),
      icon: Icons.travel_explore_outlined,
    ),
    'musique': CategorySuggestion(
      key: 'musique', name: 'Musique',
      color: Color.fromRGBO(140, 200, 130, 1),
      icon: Icons.music_note_outlined,
    ),
    'tricot': CategorySuggestion(
      key: 'tricot', name: 'Tricot/Couture',
      color: Color.fromRGBO(190, 140, 200, 1),
      icon: Icons.checkroom_outlined,
    ),
    'diy_crea': CategorySuggestion(
      key: 'diy_crea', name: 'DIY & Créa',
      color: Color.fromRGBO(255, 180, 100, 1),
      icon: Icons.palette_outlined,
    ),
    'bebe': CategorySuggestion(
      key: 'bebe', name: 'Bébé',
      color: Color.fromRGBO(255, 200, 160, 1),
      icon: Icons.child_care_rounded,
    ),
    'humour': CategorySuggestion(
      key: 'humour', name: 'Humour',
      color: Color.fromRGBO(255, 215, 100, 1),
      icon: Icons.sentiment_very_satisfied_outlined,
    ),
    'beaute': CategorySuggestion(
      key: 'beaute', name: 'Beauté',
      color: Color.fromRGBO(240, 150, 180, 1),
      icon: Icons.brush_outlined,
    ),
    'mode': CategorySuggestion(
      key: 'mode', name: 'Mode',
      color: Color(0xFFEC4899),
      icon: Icons.style_outlined,
    ),
    'gaming': CategorySuggestion(
      key: 'gaming', name: 'Gaming',
      color: Color(0xFF9B59B6),
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
      icon: Icons.memory_outlined,
    ),
    'nature': CategorySuggestion(
      key: 'nature', name: 'Nature',
      color: Color(0xFF4ECDC4),
      icon: Icons.park_outlined,
    ),
    'art': CategorySuggestion(
      key: 'art', name: 'DIY & Créa',
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
      key: 'science', name: 'Culture',
      color: Color(0xFF4ECDC4),
      icon: Icons.science_outlined,
    ),
    'podcast': CategorySuggestion(
      key: 'podcast', name: 'Podcast',
      color: Color(0xFF9E9E9E),
      icon: Icons.mic_outlined,
    ),
    'actu': CategorySuggestion(
      key: 'actu', name: 'Actu & Société',
      color: Color(0xFFB0BEC5),
      icon: Icons.newspaper_outlined,
    ),
    'true_crime': CategorySuggestion(
      key: 'true_crime', name: 'True Crime',
      color: Color(0xFF78909C),
      icon: Icons.policy_outlined,
    ),
    'documentaire': CategorySuggestion(
      key: 'documentaire', name: 'Documentaire',
      color: Color(0xFF90A4AE),
      icon: Icons.video_library_outlined,
    ),
    'cinema_series': CategorySuggestion(
      key: 'cinema_series', name: 'Cinéma & Séries',
      color: Color(0xFFEF9A9A),
      icon: Icons.movie_outlined,
    ),
    'religion': CategorySuggestion(
      key: 'religion', name: 'Religion & Foi',
      color: Color(0xFFB39DDB),
      icon: Icons.auto_awesome_outlined,
    ),
    'astro_spirituel': CategorySuggestion(
      key: 'astro_spirituel', name: 'Astro & Spirituel',
      color: Color(0xFFCE93D8),
      icon: Icons.auto_awesome_outlined,
    ),
    'langue_culture': CategorySuggestion(
      key: 'langue_culture', name: 'Culture',
      color: Color(0xFF80DEEA),
      icon: Icons.menu_book_outlined,
    ),
    'immo_deco': CategorySuggestion(
      key: 'immo_deco', name: 'Déco & Home',
      color: Color(0xFFBCAAA4),
      icon: Icons.home_outlined,
    ),
  };

  /// Poids par mot-clé (défaut : 1 si absent).
  /// Permet aux buckets spécialisés de l'emporter sur les buckets génériques
  /// lorsque le titre est ambigu (ex. "NASA" dans un titre tech vs. science).
  static const Map<String, int> _weights = {
    // True Crime — très spécifiques
    'true crime': 4, 'serial killer': 4, 'tueur en série': 4, 'tueur en serie': 4,
    'cold case': 3, 'fait divers': 3, 'affaire criminelle': 3,
    'meurtre': 2, 'crime': 2,
    // Documentaire
    'documentaire': 3, 'documentary': 3, 'reportage': 3,
    // Cinéma / Séries
    'bande annonce': 3, 'trailer': 3, 'critique film': 3, 'review film': 3,
    'netflix': 2, 'disney+': 2, 'disney plus': 2, 'hbo': 2,
    // Astro / Spirituel
    'astrologie': 3, 'astrology': 3, 'horoscope': 3,
    'chakra': 3, 'tarot': 3, 'pleine lune': 3, 'full moon': 3,
    'loi de l\'attraction': 3, 'law of attraction': 3,
    // Langue / Culture
    'apprendre': 2, 'vocabulaire': 3, 'grammaire': 3,
    // Immo / Déco
    'home tour': 3, 'room tour': 3, 'avant après': 3, 'avant apres': 3,
    'investissement locatif': 3, 'rénovation': 2, 'renovation': 2,
    // Podcast — noms propres, poids très fort
    'legend': 4, 'transfert': 4, 'thinkerview': 4, 'gdiy': 4,
    'artichaut': 4, 'inner game': 4, 'kiffe ta race': 4,
    'les couilles sur la table': 4, 'yala': 4, 'le gratin': 4,
    'binge audio': 3, 'france culture': 3, 'france inter': 3,
    // Actu — affaires nommées, poids fort
    'bruel': 4, 'affaire bruel': 4,
    'mis en examen': 3, 'garde à vue': 3, 'garde a vue': 3,
    'affaire': 2, 'scandale': 2, 'polémique': 2, 'polemique': 2,
    'procès': 2, 'proces': 2, 'tribunal': 2,
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

  /// Renvoie le bucket thématique détecté pour [title], ou `null`.
  /// Contrairement à [suggestDetailed], ne crée pas de [CategorySuggestion]
  /// et fonctionne même si la catégorie n'existe pas encore.
  static String? detectTheme(String title) {
    if (title.trim().isEmpty) return null;
    final lower = title.toLowerCase();
    for (final entry in _keywords.entries) {
      for (final kw in entry.value) {
        if (lower.contains(kw.toLowerCase())) {
          return entry.key;
        }
      }
    }
    return null;
  }

  /// Renvoie la meilleure suggestion pour [title] ou `unclassified`.
  /// Retourne true si [kw] est présent dans [text] en tant que mot entier.
  /// Utilise des frontières alphanumériques pour éviter les faux positifs
  /// comme "art" dans "karting" ou "partir".
  static bool _kwMatches(String text, String kw) {
    final escaped = RegExp.escape(kw);
    // La frontière = ni lettre ni chiffre avant/après le mot-clé
    final pattern = '(?<![a-z0-9])$escaped(?![a-z0-9])';
    return RegExp(pattern).hasMatch(text);
  }

  static CategorySuggestion suggestDetailed(String title) {
    if (title.trim().isEmpty) return CategorySuggestion.unclassified;
    // Retire les hashtags (#art, #viral…) : ce sont des tags SEO, pas du contenu.
    // On ne les utilise pas pour la détection, Claude les lira dans les métadonnées.
    final lower = title.replaceAll(RegExp(r'#\w+'), '').toLowerCase();
    final scores = <String, int>{};
    _keywords.forEach((key, kws) {
      int s = 0;
      for (final kw in kws) {
        if (_kwMatches(lower, kw)) s += _weights[kw] ?? 1;
      }
      if (s > 0) scores[key] = s;
    });
    if (scores.isEmpty) return CategorySuggestion.unclassified;
    final best =
        scores.entries.reduce((a, b) => a.value >= b.value ? a : b).key;
    return _suggestions[best]!;
  }

  /// Renvoie l'ID d'une catégorie existante correspondant à [suggestion].
  static String? matchExisting(
      CategorySuggestion suggestion, List<ClipCategory> categories) {
    if (suggestion.isUnclassified) return null;
    final sName = suggestion.name.toLowerCase().trim();
    for (final c in categories) {
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

  /// Détecte un nom de catégorie par mots-clés.
  /// Retourne le nom exact d'une catégorie existante si correspondance,
  /// sinon le nom suggéré (nouvelle catégorie à créer),
  /// sinon null si aucun mot-clé ne correspond.
  static String? detectByKeywords(
      String title, List<String> categoryNames) {
    final lowerTitle = title.toLowerCase();

    // Priorité aux catégories existantes courtes/acronymes (ex: "EMI")
    // quand elles apparaissent comme mots entiers dans le titre.
    for (final name in categoryNames) {
      final cName = name.toLowerCase().trim();
      if (cName.length < 3) continue;
      final wholeWord = RegExp(
        '(^|[^a-z0-9])${RegExp.escape(cName)}([^a-z0-9]|\$)',
        caseSensitive: false,
      );
      if (wholeWord.hasMatch(lowerTitle)) {
        return name;
      }
    }

    final suggestion = suggestDetailed(title);
    if (suggestion.isUnclassified) return null;
    final sName = suggestion.name.toLowerCase().trim();
    for (final name in categoryNames) {
      final cName = name.toLowerCase().trim();
      if (cName == sName) return name;
      final shorter = cName.length <= sName.length ? cName : sName;
      final longer  = cName.length >  sName.length ? cName : sName;
      if (shorter.length >= 5 &&
          longer.contains(shorter) &&
          shorter.length / longer.length > 0.6) {
        return name;
      }
    }
    return suggestion.name;
  }

  // ── Marques connues ───────────────────────────────────────────────────────
  // Liste plate : exactement les termes à chercher (insensible à la casse).
  // Triés du plus long au plus court pour éviter les faux positifs
  // (ex. "noz" avant "no").
  static const List<String> _knownBrands = [
    // Déstockage / petits prix
    'action', 'centrakor', 'stokomani', 'dealabs', 'leboncoin',
    'aliexpress', 'pandabuy', 'temu', 'shein', 'vinted', 'gifi', 'b&m', 'noz',
    // Grande distribution
    'intermarché', 'intermache', 'carrefour', 'monoprix',
    'leclerc', 'biocoop', 'picard', 'grand frais', 'lidl', 'aldi',
    // Mode
    'jacquemus', 'balenciaga', 'louis vuitton', 'sézane', 'sezane',
    'new balance', 'primark', 'uniqlo', 'lacoste', 'stüssy', 'stussy',
    'carhartt', 'supreme', 'palace', 'jordan', 'adidas', 'nike',
    'hermès', 'hermes', 'chanel', 'mango', 'zara', 'h&m', 'dior',
    // Beauté
    'charlotte tilbury', 'rare beauty', 'la roche-posay', 'la roche posay',
    'maybelline', 'glossier', 'bioderma', 'cerave', 'nocibé', 'nocibe',
    'sephora', 'yves rocher', 'l\'oréal', 'loreal', 'nuxe', 'vichy',
    'caudalie', 'mac cosmetics', 'nyx',
    // Tech
    'nothing phone', 'oneplus', 'samsung', 'xiaomi', 'dyson',
    'microsoft', 'google', 'apple', 'amazon', 'darty', 'fnac', 'sony',
    // Food / restauration
    'häagen-dazs', 'haagen-dazs', 'burger king', 'five guys',
    'domino\'s', 'dominos', 'starbucks', 'mcdonald\'s', 'mcdonalds', 'mcd',
    'red bull', 'monster', 'nutella', 'coca-cola', 'coca cola', 'kfc',
    // Maison
    'maisons du monde', 'leroy merlin', 'castorama', 'la redoute',
    'bouchara', 'ikea',
    // Sport
    'the north face', 'arc\'teryx', 'arcteryx', 'patagonia',
    'salomon', 'decathlon', 'go sport',
    // Voiture
    'blablacar', 'citroën', 'citroen', 'peugeot', 'renault',
    'volkswagen', 'mercedes', 'tesla', 'uber', 'bmw', 'toyota',
  ];

  // ── Influenceurs connus (nom de chaîne exact ou quasi-exact) ──────────────
  static const List<String> _knownInfluencers = [
    'squeezie', 'zerator', 'gotaga', 'solary', 'solaryhs', 'fregepaul', 'domingo', 'alderiate', 'markoonix', 'oxentiel', 'exidil', 'ultia', 'lourlo', 'drakeoz', 'maghla', 'mistermv', 'ponce',
    'kameto', 'mynthos', 'domingo', 'antoine daniel', 'sardoche',
    'joueur du grenier', 'deujna', 'etoiles', 'ultia', 'doigby',
    'mcfly', 'carlito', 'mcfly & carlito', 'mcfly carlito',
    'amixem', 'kemar', 'pierre croce', 'joyca', 'natoo', 'cyprien',
    'norman', 'golden moustache', 'le rire jaune', 'seb la frite',
    'david lafarge', 'maskey', 'jhon rachid', 'wankil studio', 'axotak',
    'vilebrequin', 'gus on the road',
    'enjoyphoenix', 'enjoy phoenix', 'léna situations', 'lena situations',
    'sananas', 'lufy', 'noholita', 'sissy mua', 'bilal hassani',
    'lena mahfouf', 'margaud lys', 'melek zerrak', 'virginie sauveur',
    'tibo inshape', 'ilona verley', 'dr nozman', 'max gicquel',
    'aude wtf', 'supertramp', 'corentin chevalier', 'dirtybiology',
    'heureka', 'heu?reka', 'la martingale', 'yann darwin', 'swan businesstrotteur',
    'hugo décrypte', 'hugo decrypte', 'science étonnante', 'science etonnante',
    'e-penser', 'axolot', 'nota bene', 'parlons peu parlons tech', 'kaizen',
    '750g', 'hervé cuisine', 'herve cuisine', 'chef damien', 'cooking jules',
    'mimi cuisine',
    'studio bubble tea', 'famille bordier', 'bapt&gael', 'bapt gael',
    'cyrus north', 'agathe auproux', 'inoxtag',
  ];

  /// Retourne le nom exact d'une marque connue si détectée dans [text],
  /// ou `null`. Cherche dans le titre ET le nom de chaîne.
  static String? detectKnownBrand(String text) {
    final lower = text.toLowerCase();
    for (final brand in _knownBrands) {
      // Vérifie que "action" est un mot isolé (pas dans "interaction" etc.)
      final pattern = RegExp(
        '(^|[\\s\\-_\\/\\(\\[«"\':])'
        '${RegExp.escape(brand)}'
        '([\\s\\-_\\/\\)\\]»"\':.!?,]|\$)',
        caseSensitive: false,
      );
      if (pattern.hasMatch(lower)) return brand;
    }
    return null;
  }

  /// Retourne le nom exact d'un influenceur connu si détecté dans [text],
  /// ou `null`.
  static String? detectKnownInfluencer(String text) {
    final lower = text.toLowerCase();
    for (final name in _knownInfluencers) {
      if (lower.contains(name)) return name;
    }
    return null;
  }
}

// ─────────────────────────────────────────────
// Claude AI classification
// ─────────────────────────────────────────────

/// Métadonnées envoyées à Claude pour une classification enrichie.
class VideoData {
  final String title;
  final String? channel;
  final String? description;
  final List<String> tags;
  final int? views;
  final String? duration;
  final String? publishedAt;
  final String platform;
  final String? thumbnailUrl;
  final String? transcriptExcerpt;

  const VideoData({
    required this.title,
    this.channel,
    this.description,
    this.tags = const [],
    this.views,
    this.duration,
    this.publishedAt,
    required this.platform,
    this.thumbnailUrl,
    this.transcriptExcerpt,
  });
}

/// Classifieur basé sur Claude Haiku via l'API Anthropic.
class ClaudeClassifier {
  static const String _model = 'claude-haiku-4-5-20251001';
  static const String _apiUrl = 'https://api.anthropic.com/v1/messages';

  static const String _systemPrompt = '''
Tu es une personne réelle qui consomme énormément de contenu en ligne — YouTube, TikTok, Instagram Reels. Tu connais la culture internet française par cœur : les créateurs, les tendances, les codes visuels, les communautés.

Quand on te donne des métadonnées d'une vidéo, tu ne fais PAS de la classification mécanique par mots-clés. Tu fais ce qu'un humain fait naturellement : tu lis l'ensemble, tu ressens l'ambiance, et tu choisis la catégorie qui correspond à l'EXPÉRIENCE de regarder la vidéo.

━━━ ÉTAPE 0 — REGARDE L'IMAGE EN PREMIER ━━━

Si une image (miniature/thumbnail) est fournie, c'est ton signal le plus fort — souvent plus fiable que le titre.
Lis-la comme un humain qui scroll son feed : en une fraction de seconde, l'image te dit tout.

• Salle de sport, haltères, corps musclé → Fitness, même si le titre dit "incroyable"
• Cuisine, plat, ingrédients, chef → Food, même si le titre dit "elle s'est effondrée"
• Maquillage, palette, gros plan visage — personne qui se touche le visage,
  s'applique quelque chose sur la peau, tient un pinceau → Beauty, même si le
  titre ne dit pas "makeup". Un humain sait immédiatement.
• Vêtements, tenue, outfit, essayage, lookbook, haul de vêtements, streetwear → Mode.
  La règle : Beauty = ce qu'on APPLIQUE sur son corps (crème, mascara, fond de teint).
  Mode = ce qu'on PORTE (fringues, chaussures, accessoires, sacs).
  Une personne qui s'habille devant la caméra → Mode. Même si elle est jolie.
• Micro, casque audio, deux personnes face à face dans un studio → Podcast
• Fond noir/neutre, sous-titres stylisés, format long avec invité → Podcast
• Écran de jeu, manette, headset → Gaming
• Paysage, aéroport, sac à dos → Travel
• Personnes qui rient, caméra cachée, grimace exagérée → Humour
• Graphisme, dessin, tablette, Procreate → DIY & Créa
• Studio, scène, lumières de concert → Musique
• Bébé, famille, poussette → Famille
• Graphiques, costard, bureau → Finance & Business
• Titre ou visuel avec nom propre lié à une affaire judiciaire ou scandale
  (ex. "Bruel", "DSK", "Weinstein", "affaire X") → Actu & Société

En cas de titre AMBIGU ("elle s'est effondrée", "incroyable", "vous allez pas le croire") :
→ L'image TRANCHE. Utilise-la. Augmente ta confiance si l'image est claire.
→ Si l'image est aussi ambiguë (visage neutre, texte illisible), ALORS mets confiance ≤ 40.

━━━ ÉTAPE 1 — LIS LE FORMAT AVANT LE SUJET ━━━

Le FORMAT de la vidéo est le signal le plus fort. Repère ces patterns dès le début :

• PRANK / TROLL / CAMÉRA CACHÉE / RÉACTION / GONE WRONG / CHALLENGE
  → Humour, même si le titre mentionne de l'art, de la cuisine ou du sport

• POV: / "j'ai essayé de..." / FAIL / "je suis nul en..." / "mon tatoueur m'a trollé"
  → Humour ou Vibes, pas la catégorie du sujet mentionné

• TUTO / "comment faire" / "apprendre à" / RECETTE / ROUTINE
  → Là le sujet compte vraiment (Food, Beauty, Fitness, DIY & Créa…)

• HAUL / UNBOXING / AVIS / TEST / COMPARATIF
  → Le sujet compte ET potentiellement une marque à détecter
  → HAUL vêtements / OOTD / lookbook → Mode (pas Beauty)
  → HAUL makeup / skincare / soins → Beauty (pas Mode)

• VLOG / "une journée" / "avec moi" / "day in my life"
  → Famille ou Travel ou Vibes selon le contexte

• STORYTELLING / "je vous raconte" / "mon histoire" / "vlog" / thread
  → Actu & Société, Growth ou Famille selon le sujet

━━━ ÉTAPE 2 — DÉCODE LE TITRE DANS SA GLOBALITÉ ━━━

Ne découpe pas le titre en mots isolés. Lis-le comme une personne le lirait :

• "illustration #tattoo #art #pov #procreate" → Le mot-clé "art" + "procreate" → vraiment DIY & Créa
• "j'ai fait semblant d'être un artiste 😂 prank" → "prank" + "😂" écrasent "artiste" → Humour
• "mon chef tattoo artist m'a abandonné en plein milieu 💀" → Drama/storytelling → Humour ou Actu & Société
• "recette de pâtes mais en 30 secondes 😂 fail" → "fail" + "😂" → Humour, pas Food
• "je teste la cuisine moléculaire avec un vrai chef" → "je teste" + "vrai chef" → Food

SIGNAUX HUMOUR qui écrasent le sujet si présents en contexte drôle :
😂 💀 🤣 lol mdr ptdr xd omg oh non bruh fail trop nul awkward gênant
prank troll réaction challenge gone wrong impossible

SIGNAUX SÉRIEUX qui confirment le sujet :
tuto guide comment routine recette résultats transformation avant/après
analyse critique explication science

━━━ ÉTAPE 3 — LE NOM DE CHAÎNE EST UN RACCOURCI ━━━

Si tu reconnais le créateur, c'est souvent le signal le plus fiable de tous.
"Squeezie" → Gaming/Humour. "750g" → Food. "Tibo InShape" → Fitness. Ne l'ignore jamais.

━━━ ÉTAPE 4 — IMAGINE LE VIEWER ━━━

Qui ouvre cette vidéo ? Une ado qui se maquille le matin ? Un gars de 25 ans qui joue après le boulot ? Une maman qui cherche des recettes rapides ? Cette personne, dans quelle playlist elle met la vidéo ?

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

CRÉATEURS FRANÇAIS — si tu reconnais la chaîne, c'est un signal fort :

Gaming / Streaming :
Squeezie, ZeratoR, Gotaga, Maghla, Mistermv, Ponce, Kameto, Mynthos, Domingo, Antoine Daniel, Sardoche, Alphacast, Deujna, Etoiles, Ultia, Joueur du Grenier, Valouzz, Luffyz, Atif, LittleBigWhale, Mickalow, Mister MV, Théo Sonics, Doigby, Lyloo, LRB, BaptisteWorld, Kenny Stream, DFG, Aypierre, Frigiel, Maxildan, CedricBelbo, InoxTag

Humour / Divertissement :
Mcfly & Carlito, Amixem, Kemar, Pierre Croce, Joyca, Natoo, Cyprien, Norman, Golden Moustache, Le Rire Jaune, Seb la Frite, David Lafarge, Maskey, Jhon Rachid, Wankil Studio, Wass Freestyle, Paul Pouyat, Aurélien Taché, Monsieur Phi, Nota Bene, Axotak, Vilebrequin, Gus on the Road

Beauté / Mode / Lifestyle :
EnjoyPhoenix, Léna Situations, Sananas, Lufy, Joyca, Noholita, Habiba da Silva, Camille Dg, Sissy Mua, Pauline Tantot, Margaud Lys, Melek Zerrak, Bilal Hassani, Maquillage de Camille, Justine Gallice, Stéphanie Durant, Aline Dessine, Lena Mahfouf, Virginie Sauveur

Fitness / Sport / Nutrition :
Tibo InShape, Ilona Verley, Ultime Santé, Bertrand Loreau, Yoanass Fitness, Florian Lenormand, Fabrice Gaignard, Maud Chauvin, Marine Leleu, Dr Nozman, Médicament ou Poison, Max Gicquel

Voyage / Aventure :
Aude WTF, Supertramp, Mieux que prévu, Corentin Chevalier, Léo Grasset (DirtyBiology), Jankois, Kévin Tréaut, Bref j'voyage, Romain Lanery, Taïna Gartner, Thomas Soliveres

Finance / Business :
Heu?reka, La Martingale, Théo Poinsignon, Julien Delagrandanne, Eric Larchevêque, Yann Darwin, Business Insider France, Swan Businesstrotteur, Xavier Fontanet, Romain Pittet

Tech / Science / Culture :
Hugo Décrypte, Mr. Phi, Léo Duff, Science Étonnante, e-penser, Axolot, Mickaël Launay (Micmaths), Gnotis, Fouloscopie, Anthropia, Risque Alpha, Kaizen, Nota Bene, Parlons Peu Parlons Tech

Cuisine / Food :
750g, Hervé Cuisine, Chef Damien, Quentin Leclerc, Cooking Jules, Margot Zhang, Cuisine Actuelle, Papilles et Pupilles, Mimi Cuisine

Famille / Parentalité / Vlog :
Cyrus North, Studio Bubble Tea, Famille Bordier, Mini et Mathieu, Les Bodin's, Bapt&Gael, Agathe Auproux, Lola & Colin

Podcasts connus — si la chaîne ou le titre contient un de ces noms, c'est un Podcast :
Legend (avec Adel Chibah), Transfert (Slate), Génération Do It Yourself (GDIY), Thinkerview,
Artichaut, Kiffe ta race, Les Couilles sur la table, Yala, Le Gratin, Inner Game,
Les Pieds sur terre, La Story (Libération), Nouvelles Écoutes, Binge Audio,
France Culture, France Inter (format podcast), Arte Podcast, Europe 1 podcast,
Passerelles, Emotioncast, Innermost, Psycho Criminelle, Sur les Dents

Affaires & Scandales — si le titre ou la chaîne mentionne ces noms propres, c'est Actu & Société :
Affaire Bruel, Patrick Bruel, DSK, Dominique Strauss-Kahn, Gérard Depardieu,
Nicolas Hulot, affaire Baupin, Luc Besson, Roman Polanski (dans contexte judiciaire),
Weinstein, MeToo France, balance ton porc

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

MARQUES & ENSEIGNES — si la vidéo tourne principalement autour d'une enseigne :

Déstockage / Petits prix : Action, Noz, Gifi, Centrakor, Stokomani, B&M, Temu, Shein, Aliexpress, Vinted, Leboncoin
Grande distribution : Lidl, Aldi, Leclerc, Intermarché, Carrefour, Monoprix, Picard, Grand Frais, Biocoop
Mode : Zara, H&M, Primark, Mango, Uniqlo, Sézane, Jacquemus, Nike, Adidas, New Balance, Jordan, Palace, Supreme, Stüssy, Carhartt, Balenciaga, Louis Vuitton, Dior, Chanel, Hermès
Beauté : Sephora, Nocibé, Yves Rocher, L'Oréal, Maybelline, NYX, MAC, Charlotte Tilbury, Rare Beauty, Glossier, CeraVe, La Roche-Posay, Vichy, Bioderma, Nuxe, Caudalie
Tech : Apple, Samsung, Sony, Google, Microsoft, Fnac, Darty, Amazon, Dyson, Xiaomi, OnePlus, Nothing Phone
Food : McDonald's, Burger King, KFC, Starbucks, Domino's, Five Guys, Häagen-Dazs, Nutella, Red Bull, Monster
Maison : IKEA, Maisons du Monde, Leroy Merlin, Castorama, La Redoute
Sport : Decathlon, Go Sport, Salomon, The North Face, Patagonia, Arc'teryx
Voiture : Renault, Peugeot, Citroën, Tesla, BMW, Mercedes, Uber, BlaBlaCar

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

CATÉGORIES (choisis celle qui correspond le mieux au RESSENTI de la vidéo, pas juste aux mots-clés) :
Beauty, Mode, Food, Fitness, Gaming, Tech, Travel, Finance & Business, Famille, Humour, Musique,
Wellness, Growth, Actu & Société, DIY & Créa, Pets & Nature, Déco & Home, Auto & Moto,
Culture, Podcast, True Crime, Documentaire, Cinéma & Séries, Astro & Spirituel, Religion & Foi, Tricot/Couture

STYLES DE VIE (celui qui colle à l'ambiance générale du créateur/contenu) :
Minimaliste, Luxe & Premium, Streetwear / Urban, Sportif / Athleisure, Geek / Gamer, Entrepreneur / Hustle culture, Parent / Famille, Étudiant / Budget, Wellness / Slow life

RÈGLES FINALES :
- `influenceur_detecte` : nom du créateur si reconnu, sinon null
- `marque_detectee` : nom de la marque si la vidéo lui est dédiée (haul, test, unboxing, avis), sinon null
- `raison` : écris 1-2 phrases naturelles comme tu l'expliquerais à un ami — pas de jargon
- `confiance` : sois HONNÊTE. Si le titre est court, vague ou peut être interprété de plusieurs façons sans autre signal (pas de chaîne, pas de description, pas de tags révélateurs), mets confiance ≤ 40. Mieux vaut admettre le doute que se tromper avec certitude.
  Exemples de titres ambigus (→ confiance ≤ 40) : "elle s'est effondrée", "incroyable", "je suis choquée", "vous allez pas le croire", "omg", "wtf", "c'est fou"
  Exemples clairs (→ confiance élevée) : "tuto maquillage naturel procreate" (Beauty/DIY), "Squeezie vs ZeratoR" (Gaming)

Réponds UNIQUEMENT en JSON valide, sans markdown, sans aucun texte autour :
{
  "categorie_principale": "...",
  "sous_categories": ["...", "..."],
  "influenceur_detecte": "nom ou null",
  "marque_detectee": "nom de la marque ou null",
  "style_de_vie": "...",
  "ambiance": "...",
  "audience_cible": "...",
  "confiance": 0,
  "raison": "...",
  "tags_suggeres": ["...", "..."]
}''';

  /// Classifie [video] via Claude Haiku.
  /// Si [profile] est fourni et contient des données, le profil utilisateur
  /// est injecté dans le prompt pour améliorer la pertinence.
  static Future<ClassificationResult> classify({
    required VideoData video,
    ClientProfile? profile,
  }) async {
    final userText = _buildUserText(video, profile);

    // Construction du contenu (multimodal si thumbnail disponible)
    final dynamic messageContent;
    if (video.thumbnailUrl != null && video.thumbnailUrl!.isNotEmpty && video.platform == 'youtube') {
      messageContent = [
        {
          'type': 'image',
          'source': {
            'type': 'url',
            'url': video.thumbnailUrl!,
          },
        },
        {
          'type': 'text',
          'text': 'Voici la miniature de la vidéo. Utilise-la comme signal '
              'principal si le titre est ambigu.\n\n$userText',
        },
      ];
    } else {
      messageContent = userText;
    }

    final body = jsonEncode({
      'model': _model,
      'max_tokens': 300,
      'system': [
        {
          'type': 'text',
          'text': _systemPrompt,
          'cache_control': {'type': 'ephemeral'},
        }
      ],
      'messages': [
        {'role': 'user', 'content': messageContent},
      ],
    });

    final response = await http.post(
      Uri.parse(_apiUrl),
      headers: {
        'x-api-key': Secrets.anthropicApiKey,
        'anthropic-version': '2023-06-01',
        'anthropic-beta': 'prompt-caching-2024-07-31',
        'content-type': 'application/json',
      },
      body: body,
    );

    if (response.statusCode != 200) {
      throw Exception(
          'Claude API error ${response.statusCode}: ${response.body}');
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final text =
        ((data['content'] as List<dynamic>).first as Map<String, dynamic>)['text']
            as String;
    final jsonStr = _extractJson(text);
    return ClassificationResult.fromJson(
        jsonDecode(jsonStr) as Map<String, dynamic>);
  }

  static String _buildUserText(VideoData video, ClientProfile? profile) {
    final buf = StringBuffer()..writeln('MÉTADONNÉES VIDÉO :');
    buf.writeln('Titre: ${video.title}');
    if (video.channel != null) buf.writeln('Chaîne: ${video.channel}');
    if (video.description != null && video.description!.isNotEmpty) {
      final desc = video.description!.length > 800
          ? video.description!.substring(0, 800)
          : video.description!;
      buf.writeln('Description: $desc');
    }
    if (video.tags.isNotEmpty) buf.writeln('Tags: ${video.tags.join(', ')}');
    if (video.views != null) buf.writeln('Vues: ${video.views}');
    if (video.duration != null) buf.writeln('Durée: ${video.duration}');
    buf.writeln('Plateforme: ${video.platform}');
    if (video.transcriptExcerpt != null &&
        video.transcriptExcerpt!.isNotEmpty) {
      final words = video.transcriptExcerpt!.split(' ');
      final excerpt =
          words.length > 200 ? words.take(200).join(' ') : video.transcriptExcerpt!;
      buf.writeln('Extrait transcript: $excerpt');
    }

    if (profile != null && profile.totalVideosClassified > 0) {
      buf.writeln('\nPROFIL CLIENT :');
      if (profile.topCategories.isNotEmpty) {
        buf.writeln(
            '- Catégories les plus regardées : ${profile.topCategories.join(', ')}');
      }
      if (profile.knownInfluencers.isNotEmpty) {
        buf.writeln(
            '- Influenceurs suivis : ${profile.knownInfluencers.join(', ')}');
      }
      if (profile.dominantLifestyle != null) {
        buf.writeln('- Style de vie détecté : ${profile.dominantLifestyle}');
      }
      final lastCorrections =
          profile.corrections.reversed.take(3).toList();
      if (lastCorrections.isNotEmpty) {
        buf.writeln('- Corrections récentes :');
        for (final c in lastCorrections) {
          buf.writeln(
              '  • "${c.videoTitle}" : ${c.wrongCategory} → ${c.correctCategory}');
        }
      }
      buf.writeln(
          "En cas d'ambiguïté, privilégie la catégorie que cet utilisateur regarde le plus.");
    }

    return buf.toString();
  }

  static String _extractJson(String text) {
    final start = text.indexOf('{');
    final end = text.lastIndexOf('}');
    if (start == -1 || end == -1 || end <= start) {
      throw const FormatException('Aucun JSON trouvé dans la réponse Claude');
    }
    return text.substring(start, end + 1);
  }
}
