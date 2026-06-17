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
      'recette', 'recettes', 'recipe', 'recipes', 'cuisiner', 'cooking', 'cook',
      'food', 'meal', 'dish', 'chef', 'restaurant', 'repas', 'plat', 'manger',
      'boulangerie', 'patisserie', 'pâtisserie', 'dessert', 'gateau', 'gâteau',
      'baking', 'pasta', 'pizza', 'soupe', 'soup', 'salade', 'salad',
      'breakfast', 'lunch', 'dinner', 'snack', 'apero', 'apéro',
      'raclette', 'tartiflette', 'fondue', 'quiche', 'tarte', 'crepe', 'crêpe',
      'lasagne', 'risotto', 'curry', 'ramen', 'sushi', 'burger', 'sandwich',
      'wrap', 'bowl', 'brunch', 'smoothie', 'cocktail', 'vin', 'wine',
      'grillades', 'barbecue', 'bbq', 'plancha', 'street food', 'mukbang',
    ],
    'fitness': [
      'musculation', 'muscu', 'bodybuilding', 'gym', 'workout', 'cardio',
      'hiit', 'crossfit', 'squat', 'pushup', 'abdos', 'pectoraux',
      'seche', 'sèche', 'prise de masse', 'proteines', 'protéines', 'whey',
      'programme sport', 'programme muscu', 'entrainement', 'entraînement',
      'transformation physique', 'avant apres sport', 'perdre du poids',
      'maigrir', 'minceur', 'regime sportif',
    ],
    'sport': [
      'foot', 'football', 'soccer', 'tennis', 'basket', 'basketball', 'rugby',
      'natation', 'swim', 'marathon', 'running', 'cyclisme', 'cycling', 'velo', 'vélo',
      'f1', 'formule 1', 'moto gp', 'nba', 'ligue 1', 'champions league',
      'sport', 'athletisme', 'athlétisme', 'handball', 'volleyball', 'golf',
      'boxe', 'mma', 'ufc', 'combat', 'match', 'competition', 'compétition',
      'tournoi', 'coupe du monde', 'jeux olympiques', 'jo', 'transfert foot',
    ],
    'gaming': [
      'gaming', 'game', 'jeu video', 'jeu vidéo', 'playstation', 'xbox',
      'nintendo', 'steam', 'twitch', 'esport', 'gamer', 'gameplay',
      'walkthrough', 'speedrun', 'minecraft', 'fortnite', 'valorant',
      'league of legends', 'lol', 'stream', 'streamer', 'lets play',
      'fps', 'mmorpg', 'rpg', 'battle royale', 'genshin', 'apex', 'overwatch',
      'pubg', 'fifa', 'cod', 'call of duty', 'cs go', 'csgo', 'dota',
      'hearthstone', 'pokemon', 'zelda', 'mario', 'ps5', 'xbox series',
    ],
    'beauty': [
      'maquillage', 'makeup', 'skincare', 'soin visage', 'routine beaute',
      'routine beauté', 'fond de teint', 'mascara', 'rouge levres', 'rouge lèvres',
      'highlighter', 'contouring', 'blush', 'palette', 'tutorial makeup',
      'tuto maquillage', 'nail', 'nails', 'manucure', 'coiffure', 'cheveux',
      'hair', 'lissage', 'coloration', 'beaute', 'beauté', 'beauty',
      'serum', 'creme visage', 'crème visage', 'acne', 'acné', 'peau',
    ],
    'mode': [
      'mode', 'fashion', 'tenue', 'outfit', 'ootd', 'lookbook', 'streetwear',
      'vetement', 'vêtement', 'fringues', 'sneaker', 'sneakers', 'haul mode',
      'haul vetements', 'haul vêtements', 'style vestimentaire', 'tendance mode',
      'capsule wardrobe', 'thrift', 'friperie', 'vintage clothes',
      'dressing', 'shopping mode', 'try on', 'styling',
    ],
    'travel': [
      'voyage', 'travel', 'vacances', 'trip', 'destination', 'hotel', 'hôtel',
      'avion', 'flight', 'plage', 'beach', 'montagne', 'mountain',
      'decouverte', 'découverte', 'roadtrip', 'road trip', 'backpack',
      'backpacking', 'adventure', 'aventure', 'explore', 'bali', 'japan',
      'thailand', 'paris', 'italie', 'espagne', 'maroc', 'dubai',
      'city guide', 'vlog voyage', 'travel vlog', 'expat',
    ],
    'humour': [
      'humour', 'drole', 'drôle', 'blague', 'rire', 'comique', 'sketch',
      'parodie', 'funny', 'humor', 'comedy', 'meme', 'memes', 'prank',
      'standup', 'stand-up', 'lol', 'mdr', 'ptdr', 'fail drole', 'troll',
      'reaction', 'réaction', 'wtf', 'bruh', 'awkward', 'camera cachee',
      'caméra cachée', 'gone wrong', 'challenge fail',
    ],
    'musique': [
      'musique', 'music', 'concert', 'chanson', 'song', 'guitare', 'guitar',
      'piano', 'clip officiel', 'album', 'lyrics', 'paroles', 'remix',
      'cover', 'acoustic', 'rap', 'hip-hop', 'hip hop', 'rock', 'pop',
      'jazz', 'dj', 'techno', 'electro', 'official video', 'mv',
      'beatbox', 'freestyle', 'prod', 'beat', 'rnb', 'r&b', 'afrobeats',
      'classique', 'classical', 'opera', 'chorale',
    ],
    'wellness': [
      'yoga', 'meditation', 'méditation', 'mindfulness', 'relaxation',
      'pilates', 'respiration', 'breathwork', 'zen', 'sophrologie',
      'asana', 'vinyasa', 'hatha', 'stretching', 'etirement', 'étirement',
      'bien-etre', 'bien-être', 'wellness', 'burnout', 'stress', 'anxiete',
      'anxiété', 'sommeil', 'sleep', 'chakra', 'spiritualite', 'spiritualité',
      'loi attraction', 'manifestation', 'vibration', 'energie', 'énergie',
    ],
    'podcast': [
      'podcast', 'episode', 'épisode', 'saison', 'invite', 'invité',
      'interview', 'guest', 'micro', 'studio radio', 'a ecouter', 'à écouter',
      'legend', 'transfert', 'gdiy', 'thinkerview', 'artichaut',
      'kiffe ta race', 'inner game', 'le gratin', 'binge audio',
      'france culture', 'france inter', 'arte podcast', 'nouvelles ecoutes',
      'passerelles', 'emotioncast', 'sur les dents', 'psycho criminelle',
    ],
    'famille': [
      'famille', 'family', 'enfant', 'enfants', 'kids', 'parents',
      'parenting', 'vlog famille', 'day in my life', 'une journee avec',
      'ecole', 'école', 'adolescent', 'ado', 'teenager', 'mariage',
      'wedding', 'anniversaire', 'birthday', 'noël', 'noel', 'christmas',
      'vacances famille', 'road trip famille',
    ],
    'bebe': [
      'bebe', 'bébé', 'nourrisson', 'grossesse', 'maternite', 'maternité',
      'puericulture', 'puériculture', 'baby', 'toddler', 'jouet bebe',
      'sommeil bebe', 'naissance', 'accouchement', 'sage femme',
      'allaitement', 'diversification', 'creche', 'crèche',
    ],
    'finance': [
      'epargne', 'épargne', 'budget', 'banque', 'bank', 'dividende',
      'portefeuille', 'retraite', 'patrimoine', 'bourse', 'trading',
      'investissement', 'invest', 'action bourse', 'etf', 'scpi',
      'assurance vie', 'livret a', 'per', 'fiscalite', 'fiscalité',
      'impots', 'impôts', 'argent', 'money', 'finance personnelle',
    ],
    'business': [
      'business', 'entreprise', 'entrepreneuriat', 'entrepreneur',
      'startup', 'marketing', 'management', 'strategie', 'stratégie',
      'leadership', 'ceo', 'fondateur', 'fondatrice', 'scale', 'scaling',
      'revenue', 'chiffre affaires', 'client', 'freelance', 'autoentrepreneur',
      'auto-entrepreneur', 'formation business', 'dropshipping', 'ecommerce',
      'e-commerce', 'amazon fba', 'personal branding', 'linkedin',
    ],
    'crypto': [
      'crypto', 'bitcoin', 'btc', 'ethereum', 'eth', 'nft', 'blockchain',
      'web3', 'defi', 'altcoin', 'binance', 'coinbase', 'cryptomonnaie',
      'token', 'wallet crypto', 'bull run', 'bear market', 'halving',
      'shitcoin', 'memecoin', 'doge', 'solana', 'cardano',
    ],
    'actu': [
      'actualite', 'actualité', 'news', 'info', 'infos', 'breaking',
      'election', 'élection', 'president', 'président', 'gouvernement',
      'parlement', 'assemblee', 'assemblée', 'senat', 'sénat',
      'greve', 'grève', 'manifestation', 'manif', 'syndicat',
      'guerre', 'conflit', 'crise', 'inflation', 'economie', 'économie',
      'bruel', 'affaire', 'scandale', 'tribunal', 'proces', 'procès',
      'mis en examen', 'arrestation', 'verdict', 'faits divers',
    ],
    'societe': [
      'societe', 'société', 'social', 'inegalites', 'inégalités',
      'discrimination', 'racisme', 'feminisme', 'féminisme', 'metoo',
      'genre', 'lgbtq', 'queer', 'trans', 'precarite', 'précarité',
      'pauvrete', 'pauvreté', 'logement', 'immigration', 'integration',
      'laicite', 'laïcité', 'travail', 'emploi', 'chomage', 'chômage',
      'inegalite', 'inégalité', 'justice sociale', 'militantisme',
    ],
    'politique': [
      'geopolitique', 'géopolitique', 'guerre ukraine', 'conflit moyen orient',
      'otan', 'nato', 'onu', 'union europeenne', 'union européenne',
      'macron', 'trump', 'putin', 'poutine', 'biden', 'election presidentielle',
      'élection présidentielle', 'debat politique', 'parti politique',
      'extreme droite', 'gauche', 'droite', 'referendum', 'referendum',
      'diplomatie', 'sanctions', 'traite', 'traité',
    ],
    'diy': [
      'diy', 'fait main', 'handmade', 'tuto', 'tutoriel', 'tutorial',
      'how to make', 'how to build', 'craft', 'crafts', 'crea', 'créa',
      'creation', 'création', 'fabrication', 'fabriquer', 'construire',
      'procreate', 'illustration', 'dessin', 'drawing', 'peinture',
      'painting', 'aquarelle', 'watercolor', 'sculpture', 'bricolage',
      'upcycling', 'recup', 'récup', 'zero dechet', 'zéro déchet',
    ],
    'art': [
      'art', 'artiste', 'artist', 'galerie', 'gallery', 'exposition',
      'musee', 'musée', 'tattoo', 'tatouage', 'street art', 'graffiti',
      'peinture artistique', 'sculpture artistique', 'art contemporain',
      'art numerique', 'art numérique', 'nft art', 'concept art',
      'illustration professionnelle', 'beaux arts', 'art digital',
    ],
    'photo': [
      'photographie', 'photography', 'photo', 'camera', 'appareil photo',
      'lightroom', 'photoshop', 'editing photo', 'retouche', 'portrait',
      'paysage photo', 'street photography', 'drone', 'gopro',
      'cinematographie', 'cinématographie', 'filmmaking', 'video editing',
      'premiere pro', 'after effects', 'davinci resolve', 'sony alpha',
      'canon', 'nikon', 'fujifilm', 'objectif', 'raw photo',
    ],
    'deco': [
      'decoration', 'décoration', 'deco', 'déco', 'interieur', 'intérieur',
      'ikea', 'amenagement', 'aménagement', 'rangement', 'organisation',
      'maisons du monde', 'leroy merlin', 'home tour', 'room tour',
      'before after deco', 'avant apres deco', 'renovation interieure',
      'rénovation intérieure', 'cuisine renovation', 'salle de bain',
      'chambre deco', 'salon deco', 'architecture interieure',
    ],
    'immo': [
      'immobilier', 'immo', 'appartement', 'achat appartement', 'maison achat',
      'investissement locatif', 'locataire', 'proprietaire', 'propriétaire',
      'loyer', 'rent', 'agence immobiliere', 'agence immobilière',
      'notaire', 'credit immobilier', 'crédit immobilier', 'hypotheque',
      'plus value immobiliere', 'rendement locatif', 'airbnb immo',
      'colocation', 'studio', 'loft', 'achat immobilier', 'vente immobilier',
    ],
    'auto': [
      'voiture', 'car', 'auto', 'moto', 'motorcycle', 'conduite', 'permis',
      'route', 'vitesse', 'garage', 'mecanique', 'mécanique', 'motorbike',
      'biker', 'harley', 'ducati', 'yamaha', 'kawasaki', 'honda moto',
      'bmw moto', 'ferrari', 'lamborghini', 'porsche', 'tesla', 'rally',
      'drift', 'tuning', 'essai voiture', 'test drive', 'electrique voiture',
      'f1 voiture', 'supercar', 'hypercar',
    ],
    'culture': [
      'culture', 'litterature', 'littérature', 'lecture', 'livre', 'book',
      'philosophie', 'philosophy', 'histoire culture', 'cinema culture',
      'art culture', 'musee visite', 'musée visite', 'exposition visite',
      'theatre', 'théâtre', 'opera', 'opéra', 'danse classique',
      'patrimoine', 'monument', 'architecture', 'unesco',
    ],
    'cinema': [
      'film', 'cinema', 'cinéma', 'movie', 'serie', 'série', 'series',
      'netflix', 'disney+', 'disney plus', 'hbo', 'prime video', 'apple tv',
      'canal+', 'bande annonce', 'trailer', 'teaser', 'casting',
      'realisateur', 'réalisateur', 'acteur', 'actrice', 'critique film',
      'review film', 'marvel', 'dc comics', 'star wars', 'cinema francais',
      'palme d or', 'oscars', 'cesar',
    ],
    'manga': [
      'anime', 'manga', 'one piece', 'naruto', 'dragon ball', 'dbz',
      'attack on titan', 'aot', 'demon slayer', 'kimetsu', 'jujutsu',
      'my hero academia', 'bleach', 'hunter hunter', 'fullmetal',
      'cosplay anime', 'figurine manga', 'japan culture', 'otaku',
      'webtoon', 'manhwa', 'shonen', 'shojo', 'seinen',
    ],
    'growth': [
      'developpement personnel', 'développement personnel', 'self help',
      'motivation', 'productivite', 'productivité', 'mindset', 'discipline',
      'habitudes', 'habits', 'morning routine', 'journaling', 'meditation dev',
      'stoicisme', 'stoïcisme', 'confiance en soi', 'self confidence',
      'objectifs', 'goals', 'succes', 'succès', 'leadership dev',
      'time management', 'organisation vie', 'life hack',
    ],
    'education': [
      'education', 'éducation', 'cours', 'lecon', 'leçon', 'apprendre',
      'learn', 'tutoriel educatif', 'mathematiques', 'mathématiques',
      'sciences physiques', 'chimie', 'biologie', 'histoire geo',
      'bacalaureat', 'baccalauréat', 'bac', 'brevet', 'concours',
      'grandes ecoles', 'grandes écoles', 'universite', 'université',
      'formation en ligne', 'mooc', 'e-learning', 'schoolmouv',
    ],
    'lang': [
      'apprendre anglais', 'apprendre espagnol', 'apprendre japonais',
      'apprendre arabe', 'apprendre allemand', 'apprendre italien',
      'apprendre coreen', 'apprendre coréen', 'apprendre chinois',
      'vocabulaire', 'vocabulary', 'grammaire', 'grammar',
      'prononciation', 'pronunciation', 'langue', 'language',
      'english lesson', 'cours anglais', 'bilingue', 'polyglotte',
      'duolingo', 'assimil', 'italki',
    ],
    'histoire': [
      'histoire', 'history', 'guerre mondiale', 'world war', 'napoleon',
      'revolution francaise', 'révolution française', 'antiquite', 'antiquité',
      'rome antique', 'egypte ancienne', 'moyen age', 'moyen âge',
      'renaissance', 'colonisation', 'esclavage', 'shoah', 'holocaust',
      'civilisation', 'empire', 'roi', 'reine', 'pharaon',
      'documentaire historique', 'archaeologie', 'archéologie',
    ],
    'science': [
      'science', 'astronomie', 'astronomy', 'espace', 'space', 'nasa',
      'planete', 'planète', 'etoile', 'étoile', 'galaxie', 'galaxy',
      'trou noir', 'black hole', 'big bang', 'telescope', 'hubble',
      'james webb', 'mars', 'jupiter', 'saturne', 'exoplanete',
      'physique quantique', 'relativite', 'relativité', 'biologie',
      'genetique', 'génétique', 'adn', 'chimie', 'neurologie',
    ],
    'sante': [
      'sante', 'santé', 'health', 'medecine', 'médecine', 'medical', 'médical',
      'medicament', 'médicament', 'maladie', 'disease', 'symptome', 'symptôme',
      'therapie', 'thérapie', 'docteur', 'doctor', 'hopital', 'hôpital',
      'sante mentale', 'santé mentale', 'depression', 'dépression',
      'anxiete sante', 'anxiété santé', 'tcc', 'psy', 'psychiatre',
      'dietetique', 'diététique', 'nutrition sante', 'microbiote',
    ],
    'nutrition': [
      'nutrition', 'diete', 'diète', 'regime', 'régime', 'calories',
      'macros', 'proteines nutrition', 'protéines nutrition', 'glucides',
      'lipides', 'alimentation saine', 'manger sain', 'healthy food',
      'vegan', 'vegetarien', 'végétarien', 'vegetalien', 'végétalien',
      'sans gluten', 'gluten free', 'keto', 'cetogene', 'cétogène',
      'intermittent fasting', 'jeune intermittent', 'detox',
    ],
    'nature': [
      'nature', 'foret', 'forêt', 'plante', 'plantes', 'fleur', 'fleurs',
      'flower', 'arbre', 'tree', 'riviere', 'rivière', 'lac', 'lake',
      'biodiversite', 'biodiversité', 'ecologie', 'écologie', 'environnement',
      'climate', 'climat', 'rechauffement', 'réchauffement', 'co2',
      'deforestation', 'déforestation', 'ocean', 'mer', 'montagne nature',
      'wildlife', 'faune', 'flore', 'animaux sauvages',
    ],
    'pets': [
      'animal', 'animaux', 'chien', 'dog', 'chat', 'cat', 'cheval', 'horse',
      'lapin', 'rabbit', 'oiseau', 'bird', 'poisson', 'fish', 'reptile',
      'hamster', 'veterinaire', 'vétérinaire', 'vet', 'pet', 'pets',
      'adoption animaux', 'refuge animaux', 'dressage chien', 'education chien',
      'chiot', 'chaton', 'kitten', 'puppy', 'aquarium',
    ],
    'outdoor': [
      'randonnee', 'randonnée', 'hiking', 'trekking', 'escalade', 'climbing',
      'surf', 'surfing', 'camping', 'bivouac', 'alpinisme', 'ski',
      'snowboard', 'vtt', 'mountain bike', 'kayak', 'canoe', 'canoë',
      'plongee', 'plongée', 'diving', 'parapente', 'trail running',
      'outdoor', 'plein air', 'nature aventure',
    ],
    'sport_extreme': [
      'sport extreme', 'sport extrême', 'base jump', 'parachute', 'saut',
      'motocross', 'moto cross', 'freestyle moto', 'bmx', 'skateboard',
      'parkour', 'freerun', 'wingsuit', 'speed riding', 'kitesurf',
      'wakeboard', 'snowkite', 'dirt bike', 'quad', 'adrenaline',
    ],
    'tricot': [
      'tricot', 'couture', 'crochet', 'broderie', 'knitting', 'sewing',
      'laine', 'wool', 'aiguille', 'machine coudre', 'patron', 'pattern',
      'point tricot', 'amigurumi', 'macrame', 'tissage', 'weaving',
      'fil', 'yarn', 'couture debutant', 'apprendre coudre',
    ],
    'diy_jardin': [
      'jardinage', 'jardin', 'garden', 'gardening', 'potager', 'plantes interieur',
      'plantes intérieur', 'terrarium', 'permaculture', 'compost',
      'semis', 'graines', 'rempotage', 'taille', 'fleurs jardin',
      'legumes', 'légumes', 'fruits jardin', 'herbes aromatiques',
    ],
    'doc': [
      'documentaire', 'documentary', 'reportage', 'investigation',
      'enquete', 'enquête', 'arte', 'france tv', 'netflix doc',
      'explique', 'expliqué', 'explained', 'histoire vraie',
      'behind the scenes', 'making of', 'immersion', 'grand format',
      'magazine tv', 'reportage terrain',
    ],
    'truecrime': [
      'true crime', 'crime', 'meurtre', 'murder', 'serial killer',
      'tueur serie', 'tueur en série', 'affaire criminelle', 'cold case',
      'disparition', 'enlevement', 'enlèvement', 'detective', 'détective',
      'enquete criminelle', 'enquête criminelle', 'polar', 'thriller',
      'affaire non elucidee', 'affaire non élucidée', 'criminologie',
    ],
    'religion': [
      'messe', 'eglise', 'église', 'priere', 'prière', 'dieu', 'allah',
      'jesus', 'jésus', 'christ', 'chretien', 'chrétien', 'islam', 'musulman',
      'catholique', 'protestant', 'evangile', 'évangile', 'bible', 'coran',
      'foi', 'croyant', 'paroisse', 'sermon', 'culte', 'pasteur', 'imam',
      'reveil spirituel', 'réveil spirituel', 'temple', 'mosquee', 'mosquée',
      'synagogue', 'shabbat', 'ramadan', 'preche', 'prêche',
    ],
    'astro': [
      'astrologie', 'astrology', 'zodiaque', 'zodiac', 'horoscope',
      'ascendant', 'gemeaux', 'gémeaux', 'taureau', 'vierge', 'scorpion',
      'esoterisme', 'ésotérisme', 'tarot', 'oracle', 'cristal',
      'pleine lune', 'full moon', 'nouvelle lune', 'signe astrologique',
      'theme astral', 'thème astral', 'numerologie', 'numérologie',
    ],
    'psycho': [
      'psychologie', 'psychology', 'therapie', 'thérapie', 'psy',
      'psychiatrie', 'tcc', 'psychanalyse', 'narcissisme', 'narcissique',
      'pervers narcissique', 'manipulation', 'relation toxique',
      'attachment', 'attachement', 'trauma', 'traumatisme', 'deuil',
      'relations amoureuses', 'couple psycho', 'communication non violente',
    ],
    'luxe': [
      'luxe', 'luxury', 'montre', 'rolex', 'richard mille', 'patek',
      'louis vuitton', 'hermes', 'hermès', 'chanel luxe', 'dior luxe',
      'ferrari luxe', 'lamborghini luxe', 'yacht', 'jet prive', 'jet privé',
      'villa luxe', 'hotel luxe', 'palace hotel', 'champagne', 'caviar',
      'haute couture luxe', 'bijoux luxe', 'investissement luxe',
    ],
    'entrepreneuriat': [
      'creer entreprise', 'créer entreprise', 'lancer startup',
      'levee fonds', 'levée de fonds', 'pitch investor', 'business plan',
      'product market fit', 'mvp', 'saas', 'bootstrapping', 'side project',
      'side hustle', 'passive income', 'revenu passif', 'indie maker',
      'solopreneur', 'fondateur startup', 'pivot startup',
    ],
    'cosplay': [
      'cosplay', 'costume', 'deguisement', 'déguisement', 'convention',
      'japan expo', 'comic con', 'geek', 'nerd', 'cosplayer',
      'prop making', 'armor cosplay', 'wig', 'perruque cosplay',
      'disney cosplay', 'marvel cosplay', 'anime cosplay',
    ],
    'dance': [
      'danse', 'dance', 'choreographie', 'chorégraphie', 'tiktok dance',
      'hip hop dance', 'ballet', 'contemporary dance', 'danse contemporaine',
      'salsa', 'bachata', 'kizomba', 'afrobeats dance', 'waacking',
      'popping', 'locking', 'breakdance', 'krump', 'dancehall',
    ],
    'comedy': [
      'stand up', 'stand-up', 'one man show', 'one woman show',
      'spectacle comique', 'humoriste', 'comedie', 'comédie',
      'scene ouverte', 'scène ouverte', 'open mic', 'cafe theatre',
      'café théâtre', 'gad elmaleh', 'jamel', 'fary', 'anne roumanoff',
    ],
    'vintage': [
      'vintage', 'retro', 'rétro', 'annees 80', 'années 80', 'annees 90',
      'années 90', 'nostalgie', 'throwback', 'brocante', 'vide grenier',
      'antiquite', 'antiquité', 'collection vintage', 'vinyle', 'vinyl',
      'cassette', 'polaroid', 'kodak', 'film photo', 'analogique',
    ],
    'fail': [
      'fail', 'fails', 'compilation', 'compilations', 'bloopers',
      'accident drole', 'accident drôle', 'chute', 'epic fail',
      'gone wrong', 'disaster', 'catastrophe', 'oops', 'wtf moment',
      'best fails', 'try not to laugh', 'funniest moments',
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
      key: 'yoga', name: 'Bien-être',
      color: Color.fromRGBO(166, 211, 220, 1),
      icon: Icons.self_improvement_outlined,
    ),
    'moto': CategorySuggestion(
      key: 'moto', name: 'Auto & Moto',
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
      key: 'tricot', name: 'Couture & Tricot',
      color: Color.fromRGBO(190, 140, 200, 1),
      icon: Icons.checkroom_outlined,
    ),
    'diy_crea': CategorySuggestion(
      key: 'diy_crea', name: 'DIY',
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
      key: 'cuisine', name: 'Food',
      color: Color(0xFFFF6B6B),
      icon: Icons.outdoor_grill_outlined,
    ),
    'finance': CategorySuggestion(
      key: 'finance', name: 'Finance',
      color: Color(0xFF4ECDC4),
      icon: Icons.account_balance_outlined,
    ),
    'business': CategorySuggestion(
      key: 'business', name: 'Business',
      color: Color(0xFF26A69A),
      icon: Icons.rocket_launch_outlined,
    ),
    'tech': CategorySuggestion(
      key: 'tech', name: 'Tech',
      color: Color(0xFF74B9FF),
      icon: Icons.memory_outlined,
    ),
    'nature': CategorySuggestion(
      key: 'nature', name: 'Nature & Écologie',
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
    'nature_eco': CategorySuggestion(
      key: 'nature_eco', name: 'Nature & Écologie',
      color: Color(0xFF81C784),
      icon: Icons.park_outlined,
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
    'podcast': CategorySuggestion(
      key: 'podcast', name: 'Podcast',
      color: Color(0xFF9E9E9E),
      icon: Icons.mic_outlined,
    ),
    'actu': CategorySuggestion(
      key: 'actu', name: 'Actualités',
      color: Color(0xFFB0BEC5),
      icon: Icons.newspaper_outlined,
    ),
    'societe': CategorySuggestion(
      key: 'societe', name: 'Société',
      color: Color(0xFF90A4AE),
      icon: Icons.people_outlined,
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
      key: 'astro_spirituel', name: 'Astrologie',
      color: Color(0xFFCE93D8),
      icon: Icons.auto_awesome_outlined,
    ),
    'immo': CategorySuggestion(
      key: 'immo', name: 'Immobilier',
      color: Color(0xFFBCAAA4),
      icon: Icons.apartment_outlined,
    ),
    'manga': CategorySuggestion(
      key: 'manga', name: 'Anime & Manga',
      color: Color(0xFFFF8A80),
      icon: Icons.auto_stories_outlined,
    ),
    'politique': CategorySuggestion(
      key: 'politique', name: 'Politique',
      color: Color(0xFF80CBC4),
      icon: Icons.account_balance_outlined,
    ),
    'crypto': CategorySuggestion(
      key: 'crypto', name: 'Crypto & Web3',
      color: Color(0xFFF7DC6F),
      icon: Icons.currency_bitcoin_outlined,
    ),
    'lang': CategorySuggestion(
      key: 'lang', name: 'Langues',
      color: Color(0xFF80DEEA),
      icon: Icons.translate_outlined,
    ),
    'histoire': CategorySuggestion(
      key: 'histoire', name: 'Histoire',
      color: Color(0xFFA5D6A7),
      icon: Icons.history_edu_outlined,
    ),
    'art_new': CategorySuggestion(
      key: 'art_new', name: 'Art',
      color: Color(0xFFE040FB),
      icon: Icons.palette_outlined,
    ),
    'photo': CategorySuggestion(
      key: 'photo', name: 'Photo & Vidéo',
      color: Color(0xFF4DD0E1),
      icon: Icons.camera_alt_outlined,
    ),
    'outdoor': CategorySuggestion(
      key: 'outdoor', name: 'Outdoor & Aventure',
      color: Color(0xFF69F0AE),
      icon: Icons.terrain_outlined,
    ),
    'psycho': CategorySuggestion(
      key: 'psycho', name: 'Psychologie',
      color: Color(0xFFFFAB91),
      icon: Icons.psychology_outlined,
    ),
    'luxe': CategorySuggestion(
      key: 'luxe', name: 'Luxe & Lifestyle',
      color: Color(0xFFFFD700),
      icon: Icons.diamond_outlined,
    ),
    'entrepreneuriat': CategorySuggestion(
      key: 'entrepreneuriat', name: 'Entrepreneuriat',
      color: Color(0xFF4CAF50),
      icon: Icons.lightbulb_outlined,
    ),
    'education': CategorySuggestion(
      key: 'education', name: 'Éducation',
      color: Color(0xFF29B6F6),
      icon: Icons.school_outlined,
    ),
    'cosplay': CategorySuggestion(
      key: 'cosplay', name: 'Cosplay & Geek',
      color: Color(0xFFBA68C8),
      icon: Icons.masks_outlined,
    ),
    'dance': CategorySuggestion(
      key: 'dance', name: 'Danse',
      color: Color(0xFFFF4081),
      icon: Icons.music_video_outlined,
    ),
    'comedy': CategorySuggestion(
      key: 'comedy', name: 'Stand-up',
      color: Color(0xFFFFEB3B),
      icon: Icons.mic_external_on_outlined,
    ),
    'jardin': CategorySuggestion(
      key: 'jardin', name: 'Jardinage',
      color: Color(0xFF8BC34A),
      icon: Icons.yard_outlined,
    ),
    'sport_extreme': CategorySuggestion(
      key: 'sport_extreme', name: 'Sports Extrêmes',
      color: Color(0xFFFF6D00),
      icon: Icons.paragliding_outlined,
    ),
    'nutrition': CategorySuggestion(
      key: 'nutrition', name: 'Nutrition & Diète',
      color: Color(0xFF66BB6A),
      icon: Icons.restaurant_menu_outlined,
    ),
    'vintage': CategorySuggestion(
      key: 'vintage', name: 'Vintage & Rétro',
      color: Color(0xFFD7CCC8),
      icon: Icons.watch_outlined,
    ),
    'fail': CategorySuggestion(
      key: 'fail', name: 'Fails & Compilations',
      color: Color(0xFFFF5722),
      icon: Icons.sentiment_very_dissatisfied_outlined,
    ),
    'langue_culture': CategorySuggestion(
      key: 'langue_culture', name: 'Langues',
      color: Color(0xFF80DEEA),
      icon: Icons.menu_book_outlined,
    ),
    'immo_deco': CategorySuggestion(
      key: 'immo_deco', name: 'Immobilier',
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
  static const String _apiUrl = Secrets.reelrProxyUrl;

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

CATÉGORIES — Tu DOIS retourner EXACTEMENT un de ces IDs dans "categorie_principale", rien d'autre :

cat_food        → cuisine, recettes, restaurants, chefs, gastronomie
cat_fitness     → sport, musculation, yoga, running, santé, nutrition
cat_gaming      → jeux vidéo, gaming, streaming, esport, Twitch
cat_beauty      → maquillage, skincare, makeup, soins, beauté
cat_mode        → vêtements, fashion, style, outfit, haul mode
cat_travel      → voyage, aventure, tourisme, découverte, destinations
cat_tech        → technologie, high-tech, science, IA, gadgets
cat_humour      → humour, comédie, prank, sketch, funny, mdr
cat_musique     → musique, chansons, concerts, clips, artistes
cat_wellness    → bien-être, méditation, développement spirituel
cat_podcast     → podcast, interview longue durée, débat, talk-show
cat_famille     → famille, enfants, bébé, parentalité, vlog famille
cat_finance     → finance personnelle, investissement, bourse, épargne, budget
cat_business    → entrepreneuriat, business, startup, marketing, management
cat_actu        → actualité, news, politique, élections, guerre, faits divers
cat_societe     → société, féminisme, inégalités, éducation, conditions de vie, débats sociaux
cat_diy         → DIY, création, art, dessin, procreate, artisanat
cat_deco        → décoration, intérieur, maison, home, architecture
cat_auto        → voiture, moto, automobile, conduite, mécanque
cat_culture     → culture, histoire, littérature, philosophie, éducation
cat_cinema      → cinéma, séries, films, critiques, Netflix
cat_growth      → développement personnel, motivation, productivité
cat_pets        → animaux, chiens, chats, animaux de compagnie, vétérinaire
cat_nature      → nature, écologie, plantes, jardinage, environnement, biodiversité
cat_truecrime   → true crime, affaires criminelles, enquêtes, faits divers
cat_astro       → astrologie, horoscope, zodiaque, tarot, ésotérisme
cat_wellness    → bien-être, méditation, mindfulness, spiritualité, développement intérieur
cat_vibes       → lifestyle, ambiance, esthétique, aesthetic, vibes

RÈGLE ABSOLUE : "categorie_principale" doit être UN des IDs ci-dessus (ex: "cat_food"). JAMAIS un texte libre.

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
  "categorie_principale": "cat_food",
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
      'max_tokens': 500,
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
        'x-reelr-secret': Secrets.appSharedSecret,
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
    var end = text.lastIndexOf('}');
    if (start == -1) {
      throw const FormatException('Aucun JSON trouvé dans la réponse Claude');
    }
    // JSON tronqué (max_tokens atteint) : on ferme les accolades manquantes
    if (end == -1 || end <= start) {
      var partial = text.substring(start);
      final opens = partial.split('{').length - 1;
      final closes = partial.split('}').length - 1;
      partial += '}' * (opens - closes).clamp(0, 5);
      end = partial.lastIndexOf('}');
      return partial.substring(0, end + 1);
    }
    return text.substring(start, end + 1);
  }
}
