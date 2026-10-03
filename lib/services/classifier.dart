import 'dart:convert';

import 'package:flutter/material.dart';
import 'net.dart';

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
    name: 'À trier',
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
      // « cuisine » manquait : seul « cuisiner » y etait, et la
      // correspondance se fait au mot entier. Voir _weights.
      'cuisine', 'cuisson', 'culinaire', 'gastronomie', 'gastronomique',
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
      // Sans ça, « défilé haute couture » partait dans Couture (le seau
      // 'tricot') parce que « couture » y matche seul.
      'haute couture', 'défilé mode', 'defile mode',
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
      // « tuto », « tutoriel » et « tutorial » ont été retirés le
      // 2026-08-10. Ces mots décrivent la FORME d'une vidéo, pas son
      // SUJET : un tutoriel de maquillage, de cuisine ou de fitness en
      // est un. Les garder ici gonflait DIY sur n'importe quel titre
      // pédagogique, au point de battre la vraie catégorie —
      // « Tuto maquillage : smoky eye fait main » donnait DIY 3 contre
      // Beauté 2. C'est l'origine probable des vidéos de cuisine
      // classées en DIY.
      //
      // La convention du fichier est d'ailleurs de qualifier ces mots :
      // le bucket `beauty` contient déjà « tuto maquillage ». Un mot de
      // forme seul ne doit jamais désigner une catégorie.
      'diy', 'fait main', 'handmade',
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
      // La cuisine-PIECE, pour qu'elle ne bascule pas en Food depuis que
      // « cuisine » y compte double.
      'renovation cuisine', 'rénovation cuisine', 'cuisine renovee',
      'cuisine rénovée', 'cuisine equipee', 'cuisine équipée',
      'cuisine ikea', 'plan de travail', 'credence', 'crédence',
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
      'voiture', 'car', 'auto', 'conduite', 'permis',
      'route', 'vitesse', 'garage', 'mecanique', 'mécanique',
      'ferrari', 'lamborghini', 'porsche', 'tesla', 'rally',
      'drift', 'tuning', 'essai voiture', 'test drive', 'electrique voiture',
      'f1 voiture', 'supercar', 'hypercar',
    ],
    'moto': [
      'moto', 'motorcycle', 'motorbike', 'biker', 'harley', 'ducati',
      'yamaha', 'kawasaki', 'honda moto', 'bmw moto',
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
    // ATTENTION : le seau 'tricot' s'affiche « Couture », le seau 'tricotage'
    // s'affiche « Tricot ». Nommage historique, ne pas s'y fier : ajoute un
    // mot de tricot dans 'tricotage', un mot de couture dans 'tricot'.
    'tricot': [
      'couture', 'coutures', 'machine coudre', 'machine à coudre',
      'couture debutant', 'couture débutant', 'apprendre coudre', 'sewing',
      // « patron » seul = le chef, « pattern » seul = design/trading/sommeil.
      // « fil » seul = fil rouge, fil d'actu. On qualifie.
      'patron couture', 'patron de couture', 'sewing pattern',
      'fil a coudre', 'fil à coudre',
      'tissage', 'weaving',
      // Formes conjuguées : les listes ne contenaient que l'infinitif,
      // donc « j'ai cousu » ou « je couds » n'était jamais reconnu.
      'cousu', 'cousue', 'coudre',
    ],
    'tricotage': [
      'tricot', 'tricots', 'tricoter', 'tricotin', 'laine', 'wool',
      'aiguille', 'aiguilles', 'point tricot', 'yarn', 'knitting',
      'tricote', 'tricotes', 'tricoté', 'tricotée', 'tricotee',
      'point mousse', 'point jersey',
    ],
    'crochet': [
      'crochet', 'crochets', 'crocheter', 'crochete', 'crocheté', 'amigurumi',
      // « macrame » sans accent ne matchait jamais l'orthographe française.
      'macramé', 'macrame',
    ],
    'broderie': [
      'broderie', 'broderies', 'broder', 'brodé', 'brode', 'brodée', 'brodee',
      'point de croix', 'points de croix', 'point compté', 'point compte',
      'embroidery', 'embroider', 'embroidered', 'needlepoint',
      // Jamais « stitch » seul : Lilo & Stitch, stitch Instagram...
      'cross stitch', 'cross-stitch', 'crossstitch', 'cross stitching', 'xstitch',
      'punto croce', 'punto de cruz', 'punto cruz', 'bordado', 'bordados',
      'kreuzstich', 'stickerei', 'sticken',
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

  /// Correspondance bucket de mots-cles -> cle de suggestion.
  ///
  /// Les cles de `_keywords` et celles de `_suggestions` ont diverge au fil
  /// du temps : 15 buckets pointaient dans le vide, ce qui faisait lever
  /// `_suggestions[best]!` sur environ un titre sur cinq. Cette table est
  /// desormais la seule autorite sur cette correspondance.
  ///
  /// Regle : tout nouveau bucket ajoute a `_keywords` doit soit porter le
  /// meme nom que sa suggestion, soit etre declare ici.
  static const Map<String, String> _bucketToSuggestionKey = {
    'beauty': 'beaute',
    'travel': 'voyage',
    'wellness': 'yoga',
    'diy': 'diy_crea',
    'pets': 'animaux',
    'diy_jardin': 'jardin',
    'doc': 'documentaire',
    'truecrime': 'true_crime',
    'astro': 'astro_spirituel',
    'cinema': 'cinema_series',
  };

  /// Resout un bucket de mots-cles vers sa suggestion, alias compris.
  /// Renvoie `null` plutot que de lever : une couche de classification n'a
  /// jamais le droit de faire tomber le pipeline.
  static CategorySuggestion? _suggestionFor(String bucket) =>
      _suggestions[_bucketToSuggestionKey[bucket] ?? bucket];

  static const Map<String, CategorySuggestion> _suggestions = {
    // Ces cinq suggestions manquaient completement : leurs buckets de
    // mots-cles existaient dans `_keywords` mais ne menaient nulle part.
    'fitness': CategorySuggestion(
      key: 'fitness', name: 'Fitness',
      color: Color(0xFF4ECDC4),
      icon: Icons.fitness_center_rounded,
    ),
    'famille': CategorySuggestion(
      key: 'famille', name: 'Famille',
      color: Color(0xFFFD79A8),
      icon: Icons.family_restroom_rounded,
    ),
    'deco': CategorySuggestion(
      key: 'deco', name: 'Déco',
      color: Color(0xFFFAB1A0),
      icon: Icons.home_rounded,
    ),
    'culture': CategorySuggestion(
      key: 'culture', name: 'Culture',
      color: Color(0xFF8E44AD),
      icon: Icons.theater_comedy_rounded,
    ),
    'growth': CategorySuggestion(
      key: 'growth', name: 'Dév. Personnel',
      color: Color(0xFF27AE60),
      icon: Icons.rocket_launch_rounded,
    ),
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
    'auto': CategorySuggestion(
      key: 'auto', name: 'Auto',
      color: Color.fromRGBO(155, 184, 232, 1),
      icon: Icons.directions_car_rounded,
    ),
    'moto': CategorySuggestion(
      key: 'moto', name: 'Moto',
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
      key: 'tricot', name: 'Couture',
      color: Color.fromRGBO(190, 140, 200, 1),
      icon: Icons.content_cut_rounded,
    ),
    'tricotage': CategorySuggestion(
      key: 'tricotage', name: 'Tricot',
      color: Color.fromRGBO(212, 165, 217, 1),
      icon: Icons.checkroom_outlined,
    ),
    'crochet': CategorySuggestion(
      key: 'crochet', name: 'Crochet',
      color: Color.fromRGBO(192, 143, 208, 1),
      icon: Icons.gesture_rounded,
    ),
    'broderie': CategorySuggestion(
      key: 'broderie', name: 'Broderie',
      color: Color.fromRGBO(225, 166, 200, 1),
      icon: Icons.grid_on_rounded,
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
    'nature_eco': CategorySuggestion(
      key: 'nature_eco', name: 'Nature',
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
      key: 'cinema_series', name: 'Cinéma',
      color: Color(0xFFEF9A9A),
      icon: Icons.movie_outlined,
    ),
    'religion': CategorySuggestion(
      key: 'religion', name: 'Religion',
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
      key: 'crypto', name: 'Crypto',
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
      key: 'photo', name: 'Photo',
      color: Color(0xFF4DD0E1),
      icon: Icons.camera_alt_outlined,
    ),
    'outdoor': CategorySuggestion(
      key: 'outdoor', name: 'Outdoor',
      color: Color(0xFF69F0AE),
      icon: Icons.terrain_outlined,
    ),
    'psycho': CategorySuggestion(
      key: 'psycho', name: 'Psychologie',
      color: Color(0xFFFFAB91),
      icon: Icons.psychology_outlined,
    ),
    'luxe': CategorySuggestion(
      key: 'luxe', name: 'Luxe',
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
      key: 'cosplay', name: 'Cosplay',
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
      key: 'sport_extreme', name: 'Extrême',
      color: Color(0xFFFF6D00),
      icon: Icons.paragliding_outlined,
    ),
    'nutrition': CategorySuggestion(
      key: 'nutrition', name: 'Nutrition',
      color: Color(0xFF66BB6A),
      icon: Icons.restaurant_menu_outlined,
    ),
    'vintage': CategorySuggestion(
      key: 'vintage', name: 'Vintage',
      color: Color(0xFFD7CCC8),
      icon: Icons.watch_outlined,
    ),
    'fail': CategorySuggestion(
      key: 'fail', name: 'Fails',
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
    // Cuisine : poids 2 pour que, seul dans un titre, il suffise au
    // garde-fou de la couche 2 (seuil 2) a contredire une chaine apprise
    // dans une autre categorie. Il ne suffit pas seul a court-circuiter
    // Claude (seuil 3) : « cuisine » designe aussi la piece.
    'cuisine': 2,
    'renovation cuisine': 3, 'rénovation cuisine': 3,
    'cuisine renovee': 3, 'cuisine rénovée': 3,
    'cuisine equipee': 3, 'cuisine équipée': 3, 'cuisine ikea': 3,
    // True Crime — très spécifiques
    'true crime': 4, 'serial killer': 4, 'tueur en série': 4, 'tueur en serie': 4,
    'cold case': 3, 'fait divers': 3, 'affaire criminelle': 3,
    'meurtre': 2, 'crime': 2,
    // Documentaire
    // « documentaire », « documentary », « reportage » ne sont plus
    // ponderes (2026-10-03) : ce sont des mots de FORMAT. A poids 3 ils
    // decidaient seuls et contredisaient le prompt (le sujet prime) :
    // « Documentaire : l'affaire Gregory » partait en Documentaire.
    // Mode vs Couture : « haute couture » doit battre « couture » seul.
    'haute couture': 3, 'défilé mode': 3, 'defile mode': 3,
    // Moto vs Auto. Le prompt demande à Haiku une « correspondance
    // approchée » avec les catégories existantes : tant que l'utilisateur
    // a une tuile Auto et pas de tuile Moto, toute vidéo de moto est
    // rapprochée d'Auto — Haiku fait exactement ce qu'on lui demande.
    // Observé en production.
    //
    // La couche locale, elle, sépare correctement les deux buckets, mais
    // ne se déclenchait jamais : « Balade en moto Ducati » marquait 2,
    // sous le seuil de 3. Ces trois mots sont sans ambiguïté dans toutes
    // les langues rencontrées (fr, en, pt, es) et suffisent désormais à
    // eux seuls, ce qui court-circuite Haiku avant le rapprochement.
    //
    // Volontairement pas 'yamaha' (pianos, guitares) ni 'kawasaki'
    // (maladie de Kawasaki) : trop ambigus isolés.
    'moto': 3, 'motorcycle': 3, 'motorbike': 3,
    'harley': 2, 'ducati': 2,
    // Couture et Tricot : même mécanisme que Moto vs Auto. Sans tuile
    // dédiée, Haiku rapproche ces vidéos de Mode ou de DIY. Les termes
    // sans ambiguïté suffisent donc désormais à eux seuls.
    //
    // « haute couture » vaut 3 pour `mode` et « couture » 3 pour le
    // bucket couture : à égalité, `mode` l'emporte car il est déclaré
    // avant — le comportement voulu est préservé, vérifié sur
    // « Défilé haute couture Paris ».
    //
    // Volontairement PAS pondérés : « tricot », présent à la fois dans
    // `mode` et `tricotage` — les poids étant globaux par mot, le
    // pondérer boosterait les deux à égalité et Mode gagnerait le
    // départage. Ni « tissage » (extensions capillaires), « laine »
    // (laine de verre), « aiguille » (acupuncture, seringue).
    'couture': 3, 'coutures': 3, 'coudre': 3, 'cousu': 3, 'cousue': 3,
    'machine coudre': 3, 'machine à coudre': 3, 'apprendre coudre': 3,
    'patron couture': 3, 'patron de couture': 3, 'sewing': 3,
    'sewing pattern': 3,
    'tricoter': 3, 'tricote': 3, 'tricotes': 3, 'tricoté': 3,
    'tricotée': 3, 'tricotee': 3, 'tricotin': 3, 'point tricot': 3,
    'point mousse': 3, 'point jersey': 3,
    'knitting': 3,
    // « crochet » nu reste à 2 : en français c'est aussi un coup de
    // poing (« le crochet du gauche »). Il lui faut un second indice.
    'crochet': 2, 'crochets': 2,
    'crocheter': 3, 'crochete': 3, 'crocheté': 3, 'amigurumi': 3,
    // Broderie / point de croix : termes sans ambiguïté, suffisants seuls.
    // Volontairement PAS pondérés : « broder », « brode » (« broder une
    // histoire » = enjoliver). Jamais « stitch » seul (Lilo & Stitch).
    'broderie': 3, 'broderies': 3, 'brodée': 3, 'brodee': 3, 'brodé': 3,
    'point de croix': 3, 'points de croix': 3, 'point compté': 3, 'point compte': 3,
    'embroidery': 3, 'embroider': 3, 'embroidered': 3, 'needlepoint': 3,
    'cross stitch': 3, 'cross-stitch': 3, 'crossstitch': 3, 'cross stitching': 3,
    'xstitch': 3, 'punto croce': 3, 'punto de cruz': 3, 'punto cruz': 3,
    'bordado': 3, 'bordados': 3, 'kreuzstich': 3, 'stickerei': 3, 'sticken': 3,
    // Cinéma / Séries
    // « trailer » n'est plus pondere et « bande annonce » passe a 2
    // (2026-10-03) : une bande-annonce de jeu video (GTA 6) partait en
    // Cinema, « trailer park » aussi.
    'bande annonce': 2, 'critique film': 3, 'review film': 3,
    'netflix': 2, 'disney+': 2, 'disney plus': 2, 'hbo': 2,
    // Astro / Spirituel
    'astrologie': 3, 'astrology': 3, 'horoscope': 3,
    // « full moon » n'est plus pondere (2026-10-03) : Full Moon Party.
    'chakra': 3, 'tarot': 3, 'pleine lune': 3,
    'loi de l\'attraction': 3, 'law of attraction': 3,
    // Langue / Culture
    'apprendre': 2, 'vocabulaire': 3, 'grammaire': 3,
    // Immo / Déco
    // « room tour » passe a 2 (2026-10-03) : un room tour d'hotel est
    // du Voyage, pas de la Deco.
    'home tour': 3, 'room tour': 2, 'avant après': 3, 'avant apres': 3,
    'investissement locatif': 3, 'rénovation': 2, 'renovation': 2,
    // Podcast — noms propres, poids très fort
    // « legend » et « transfert » ne sont plus ponderes (2026-10-03) :
    // a 4 ils envoyaient en Podcast « The Legend of Zelda », « John
    // Legend » et le transfert d'un footballeur. Les podcasts Legend
    // et Transfert restent reconnus par Claude (liste du prompt).
    'thinkerview': 4, 'gdiy': 4,
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
    // « galaxy » n'est plus pondere (2026-10-03) : Samsung Galaxy.
    'galaxie': 3, 'cosmos': 3,
    // « big bang » n'est plus pondere (2026-10-03) : la serie The Big
    // Bang Theory partait en Science.
    'trou noir': 3, 'black hole': 3,
    'telescope': 3, 'télescope': 3, 'hubble': 3, 'james webb': 3,
    // « mars » n'est plus pondere (2026-10-03) : c'est aussi le mois
    // (« recette du 2 mars ») et Bruno Mars, tous deux partis en Science.
    'jupiter': 3, 'saturne': 3,
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
    // Les lettres accentuees comptent comme des lettres (2026-10-03) :
    // sans elles, « saut » matchait dans « saute » accentue (poulet
    // saute -> Extreme), « art » dans « arte » accentue, etc.
    const letters = 'a-z0-9àâäáãåçéèêëíìîïñóòôöõúùûüýÿœæ';
    final pattern = '(?<![$letters])$escaped(?![$letters])';
    return RegExp(pattern).hasMatch(text);
  }

  static CategorySuggestion suggestDetailed(String title) {
    if (title.trim().isEmpty) return CategorySuggestion.unclassified;
    // Le `#` est retiré, le mot conservé.
    //
    // La version précédente supprimait le hashtag ENTIER, en le tenant
    // pour du bruit SEO. C'est faux sur TikTok, Instagram et les Shorts
    // YouTube, où le sujet n'est souvent QUE dans les hashtags. Observé
    // en production sur deux Shorts de moto titrés « Vous prenez le 85 ou
    // le 450 vous? #moto #bikelife #yamaha » et « Harley … #moto
    // #motorcycle » : privés de leurs hashtags, ces titres ne
    // contenaient plus rien d'exploitable, la couche locale s'abstenait,
    // et Haiku rapprochait les deux vidéos de la tuile Auto existante.
    //
    // Aucun bruit ajouté : un hashtag absent de tous les buckets rapporte
    // zéro. Vérifié sur 13 titres réels — deux gains, aucun classement
    // existant modifié.
    final lower = title.replaceAll('#', ' ').toLowerCase();
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
    return _suggestionFor(best) ?? CategorySuggestion.unclassified;
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

  // Chaines d'information connues : le nom de la chaine seul suffit a
  // indiquer la categorie Actualites, sans avoir besoin d'analyser le titre.
  static const List<String> _knownNewsOutlets = [
    'tf1 info', 'm6 info', 'bfmtv', 'bfm tv', 'franceinfo', 'france info',
    'france 24', 'le monde', 'le figaro', 'liberation', 'libération',
    'europe 1', 'rtl', 'cnews', 'lci', 'rmc', 'rmc info', 'rmc story',
    'ouest-france', 'ouest france', 'huffpost', 'konbini news', 'brut',
    'loopsider', 'l\'obs', 'la depeche', 'la dépêche',
    // Anglophones
    'bbc news', 'bbc', 'cnn', 'reuters', 'associated press', 'sky news',
    'the guardian', 'new york times', 'nytimes', 'washington post',
    'nbc news', 'abc news', 'cbs news', 'fox news', 'al jazeera english',
    'al jazeera', 'npr', 'the independent', 'the times', 'axios',
  ];

  static bool _isKnownNewsOutlet(String channel) {
    final lower = channel.toLowerCase().trim();
    return _knownNewsOutlets.any((outlet) => lower.contains(outlet));
  }

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
      // Mot entier (2026-10-03) : « ponce » matchait « poncer »,
      // « norman » « Normandie », « axolot » « axolotl ».
      if (_kwMatches(lower, name)) return name;
    }
    return null;
  }

  /// Detection forte et sans ambiguite, utilisee pour classer un clip SANS
  /// appeler Claude : influenceur connu, marque connue, ou mot-cle a poids
  /// eleve (par defaut >=3, les mots-cles calibres comme non ambigus).
  /// [minScore] est parametrable : abaisse a 2 par
  /// [ClipsState.classifyClipInBackground] pour simplement detecter un doute
  /// (pas pour decider seul) avant d'appliquer aveuglement l'historique
  /// d'une chaine deja apprise. Retourne le nom de categorie ou null si
  /// aucun signal suffisant -- dans ce cas on part sur Claude comme avant.
  static String? detectStrongMatch(String title,
      {String? channel, int minScore = 3}) {
    if (channel != null &&
        channel.trim().isNotEmpty &&
        _isKnownNewsOutlet(channel)) {
      return 'Actualités';
    }
    if (title.trim().isEmpty) return null;
    final hasChannelMatch = channel != null &&
        channel.trim().isNotEmpty &&
        (detectKnownInfluencer(channel) != null ||
            detectKnownBrand(channel) != null);
    final hasTitleMatch = detectKnownInfluencer(title) != null ||
        detectKnownBrand(title) != null;
    // Une marque ou un influenceur ne dit pas la categorie a lui seul
    // (2026-10-03). Avant, il suffisait d'UN mot-cle faible a cote :
    // « Samsung Galaxy » -> Science, « Supreme Court ... explained » ->
    // Documentaire. Le signal abaisse seulement le seuil a 2, plus bas.
    // Même traitement que dans `suggestDetailed` : le `#` seul est
    // retiré, le mot est conservé (voir le commentaire détaillé là-bas).
    final lower = title.replaceAll('#', ' ').toLowerCase();
    final scores = <String, int>{};
    _keywords.forEach((key, kws) {
      int s = 0;
      for (final kw in kws) {
        if (_kwMatches(lower, kw)) s += _weights[kw] ?? 1;
      }
      if (s > 0) scores[key] = s;
    });
    if (scores.isEmpty) return null;
    final best = scores.entries.reduce((a, b) => a.value >= b.value ? a : b);
    final needed =
        (hasChannelMatch || hasTitleMatch) && minScore > 2 ? 2 : minScore;
    if (best.value < needed) return null;
    return _suggestionFor(best.key)?.name;
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

  /// Plafond d'attente d'une reponse du proxy.
  ///
  /// Etait a 8 s, pour des appels reussis mesures a 4,4 / 4,9 / 5,6 / 5,7 s le
  /// 2026-08-09 : deux a trois secondes de marge seulement. Le multimodal
  /// creuse encore l'ecart, Anthropic allant chercher la miniature cote
  /// serveur. Chaque depassement declenchait un second appel complet -- cout
  /// double, et huit secondes perdues avant meme de reessayer.
  ///
  /// Le classement tourne en arriere-plan : personne n'attend devant l'ecran.
  /// Patienter coute bien moins cher qu'un appel de plus.
  static const Duration _requestTimeout = Duration(seconds: 20);

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
Squeezie, ZeratoR, Gotaga, Maghla, Mistermv, Ponce, Kameto, Mynthos, Domingo, Antoine Daniel, Sardoche, Alphacast, Deujna, Etoiles, Ultia, Joueur du Grenier, Valouzz, Luffyz, Atif, LittleBigWhale, Mickalow, Mister MV, Théo Sonics, Doigby, Lyloo, LRB, BaptisteWorld, Kenny Stream, DFG, Aypierre, Frigiel, Maxildan, CedricBelbo, InoxTag, Anyme023

Humour / Divertissement :
Mcfly & Carlito, Amixem, Kemar, Pierre Croce, Joyca, Natoo, Cyprien, Norman, Golden Moustache, Le Rire Jaune, Seb la Frite, David Lafarge, Maskey, Jhon Rachid, Wankil Studio, Wass Freestyle, Paul Pouyat, Aurélien Taché, Monsieur Phi, Nota Bene, Axotak, Vilebrequin, Gus on the Road, Nicocapone, OVSIE, Tuvok12, Michou

Beauté / Mode / Lifestyle :
EnjoyPhoenix, Léna Situations, Sananas, Lufy, Joyca, Noholita, Habiba da Silva, Camille Dg, Sissy Mua, Pauline Tantot, Margaud Lys, Melek Zerrak, Bilal Hassani, Maquillage de Camille, Justine Gallice, Stéphanie Durant, Aline Dessine, Lena Mahfouf, Virginie Sauveur, Léa Elui

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

CRÉATEURS ANGLOPHONES / INTERNATIONAUX — mêmes réflexes que pour les créateurs français, à utiliser quand la vidéo est en anglais ou vient d'un créateur non-francophone :

Gaming / Streaming :
MrBeast Gaming, PewDiePie, xQc, Ninja, Pokimane, Ludwig, Valkyrae, Dream, TommyInnit, KSI, Sidemen, Jacksepticeye, Markiplier, DanTDM, Khaby Lame, IShowSpeed

Humour / Divertissement :
Emma Chamberlain, David Dobrik, Logan Paul, Jake Paul, Charli D'Amelio, Zach King, Good Mythical Morning, Rhett and Link, SNL, James Corden, MrBeast, Alix Earle, Jake Shane, Brooke Monk, Lexi Rivera, Druski

Beauté / Mode / Lifestyle :
James Charles, NikkieTutorials, Huda Kattan, Jeffree Star, Bretman Rock, Wisdom Kaye, Alix Earle, Hyram, Mikayla Nogueira

Fitness / Sport / Nutrition :
Chloe Ting, Athlean-X, Jeff Nippard, Whitney Simmons, Jeremy Ethier, Stephanie Buttermore

Voyage / Aventure :
Kara and Nate, Yes Theory, Drew Binsky, Nomadic Matt, Eva zu Beck

Finance / Business :
Graham Stephan, Meet Kevin, Ali Abdaal, Gary Vaynerchuk, Andrei Jikh, Minority Mindset

Tech / Science / Culture :
MKBHD, Marques Brownlee, Linus Tech Tips, Veritasium, Kurzgesagt, MinutePhysics, Mark Rober, Vsauce, SmarterEveryDay

Cuisine / Food :
Gordon Ramsay, Binging with Babish, Joshua Weissman, Bon Appétit, Tasty, Uncle Roger, Nara Smith

Podcasts anglophones connus — si la chaîne ou le titre contient un de ces noms, c'est un Podcast :
The Joe Rogan Experience, Call Her Daddy, Crime Junkie, My Favorite Murder,
The Tim Ferriss Show, The Daily (New York Times), Serial, This American Life,
Armchair Expert, The Diary of a CEO

Affaires & Scandales internationaux — si le titre ou la chaîne mentionne ces noms propres, c'est Actu & Société :
MeToo, Harvey Weinstein, Depp v. Heard, Elon Musk (controverses), Diddy (affaire judiciaire),
cancel culture, Epstein

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

cat_food            → cuisine, recettes, restaurants, chefs, gastronomie. Diff. cat_humour : si la vidéo montre réellement une recette/un plat (même raté ou tourné sur un ton comique), reste cat_food ; cat_humour seulement si le comique est le vrai sujet et la nourriture n'est qu'un prétexte accessoire.
cat_nutrition       → diététique, rééquilibrage alimentaire, calories, macros, régimes. Diff. cat_food : food = plaisir de cuisiner/manger ; nutrition = logique diététique/santé.
cat_fitness         → musculation, entraînement, yoga, running, cardio. Diff. cat_sport_extreme : ici entraînement classique, pas la prise de risque.
cat_sport           → sport en général, compétition, matchs, résultats, équipes
cat_sport_extreme   → sports à sensations et prise de risque (parkour, base jump, surf de gros, freeride). Diff. cat_fitness : ici risque/adrénaline, pas entraînement classique.
cat_sante           → santé physique, maladies, médecine, système de santé. Diff. cat_fitness : santé/médical vs entraînement volontaire.
cat_gaming          → jeux vidéo, gaming, streaming, esport, Twitch
cat_beauty          → maquillage, skincare, makeup, soins du visage. Règle : ce qu'on APPLIQUE sur le corps.
cat_mode            → vêtements, fashion, style, outfit, haul mode. Règle : ce qu'on PORTE.
cat_luxe            → produits/lifestyle haut de gamme, marques de luxe, montres, sacs de luxe. Diff. cat_mode : luxe = univers très haut de gamme mis en avant comme sujet.
cat_vintage         → mode ou objets rétro/seconde main d'époque (friperie, brocante). Diff. cat_mode : provenance ancienne/rétro, pas tendance actuelle.
cat_shopping        → magasins et enseignes (page d'accueil, catalogue, promotions de la semaine), bons plans, codes promo, hauls d'achats multi-produits, sites marchands généralistes (Temu, Shein, Aliexpress). Diff. : un produit PRÉCIS va dans la catégorie de son usage (écouteurs → cat_tech, meuble → cat_deco, chocolat → cat_food, vêtement → cat_mode).
cat_travel          → voyage, découverte de destinations, tourisme, road trip
cat_outdoor         → activités en pleine nature sans notion de destination touristique (randonnée, camping, survie). Diff. cat_travel : travel = destination/pays ; outdoor = activité elle-même.
cat_humour          → humour, prank, sketch, situations comiques, mdr
cat_comedy          → stand-up, one-man-show. Diff. cat_humour : humour = contenu drôle spontané/court ; comedy = spectacle structuré.
cat_fail            → compilations d'échecs, "fail", "gone wrong". Diff. cat_humour : ratés/accidents, même sans intention comique.
cat_musique         → chansons, concerts, clips, artistes musicaux
cat_dance           → chorégraphie, danse, battle de danse. Diff. cat_musique : mouvement/chorégraphie est le sujet, pas la musique elle-même.
cat_wellness        → bien-être, méditation, mindfulness, spiritualité intérieure, slow life
cat_growth          → développement personnel, motivation, productivité. Diff. cat_wellness : wellness = apaisement ; growth = action/performance.
cat_psycho          → psychologie, comportement humain, relations, santé mentale expliquée. Diff. cat_wellness : psycho analyse/explique, wellness pratique/ressent.
cat_astro           → astrologie, horoscope, zodiaque, tarot, ésotérisme
cat_podcast         → interview longue durée, débat, talk-show, format micro/casque
cat_famille         → vie de famille, parentalité, vlog familial (enfants déjà nés)
cat_bebe            → grossesse, nouveau-né, petite enfance. Diff. cat_famille : bebe cible grossesse/tout-petit, famille = vie de famille au sens large.
cat_finance         → finance personnelle, épargne, bourse, budget individuel
cat_business        → entrepreneuriat au sens large, startup, marketing, management
cat_entrepreneuriat → parcours/récit de création d'entreprise, storytelling de fondateur. Diff. cat_business : business = techniques/conseils ; entrepreneuriat = histoire d'un fondateur.
cat_crypto          → cryptomonnaies, blockchain, Web3, NFT
cat_actu            → actualité chaude, news, élections, guerre
cat_politique       → analyse/débat politique, partis, personnalités. Diff. cat_actu : actu = événement brut, politique = angle partisan explicite.
cat_societe         → débats de société, féminisme, inégalités, conditions de vie
cat_truecrime       → affaires criminelles, enquêtes, tueurs en série. Diff. cat_actu : fait divers criminel en profondeur/storytelling, pas actualité du jour.
cat_diy             → création manuelle, artisanat, procreate, bricolage créatif
cat_tricot          → couture (machine, patron). Diff. cat_diy : couture = sous-univers textile/aiguilles.
cat_tricotage       → tricot aux aiguilles, laine, points de tricot (point mousse, point jersey, côtes, torsades). Diff. cat_broderie : un « point » de tricot n'est pas de la broderie.
cat_crochet         → crochet, amigurumi, macramé.
cat_broderie        → broderie, point de croix (cross stitch), grilles et motifs à broder, canevas. Diff. cat_art/cat_diy : une grille de motif pixel destinée au point de croix va ici, même si le texte parle aussi de « pixel art », de perles Hama ou de « DIY ».
cat_art             → beaux-arts, peinture, dessin artistique, exposition. Diff. cat_diy : art = démarche artistique exposée, diy = fabrication pratique.
cat_photo           → technique photo/vidéo, matériel, retouche. Diff. cat_art : photo = médium/technique, art = résultat artistique visé.
cat_tech            → high-tech, électronique, informatique, smartphones, ordinateurs, audio (écouteurs, enceintes), gadgets, applis. Diff. cat_photo : photo = technique et matériel de prise de vue ; tech = tout autre appareil ou produit électronique.
cat_cosplay         → cosplay, costumes de personnages, geek culture
cat_manga           → anime, manga, culture japonaise animée. Diff. cat_cosplay : manga = œuvres, cosplay = déguisement inspiré d'œuvres.
cat_deco            → décoration intérieure, home tour, aménagement
cat_immo            → achat/vente/investissement immobilier, visites de biens à vendre. Diff. cat_deco : immo = transaction, déco = esthétique du bien habité.
cat_jardin          → jardinage, potager, plantes d'extérieur
cat_nature          → écologie, environnement, biodiversité au sens large. Diff. cat_jardin : jardin = pratique personnelle, nature = sujet environnemental large.
cat_pets            → animaux de compagnie, chiens, chats, vétérinaire
cat_auto            → voitures, mécanique auto, conduite, essais de voitures. Diff. cat_moto : tout ce qui a deux roues motorisées va dans cat_moto.
cat_moto            → motos, scooters, balades et road trips à moto, mécanique et équipement moto, motocross. Diff. cat_auto : deux-roues motorisés uniquement. Diff. cat_sport_extreme : figures freestyle et prise de risque spectaculaire vont dans cat_sport_extreme.
cat_culture         → culture générale, littérature, philosophie
cat_histoire        → faits et récits historiques passés. Diff. cat_culture : histoire = événements du passé, culture = réflexion actuelle.
cat_education       → apprentissage scolaire/pédagogie, cours, méthodes. Diff. cat_culture : education = format pédagogique structuré.
cat_lang            → apprentissage des langues étrangères
cat_science         → sciences dures, espace, physique, biologie
cat_doc             → documentaire long format, reportage de fond. Le SUJET prime sur le format : un documentaire sur une affaire criminelle va dans cat_truecrime, un doc sur l'espace dans cat_science. cat_doc ne recueille que les documentaires dont le sujet n'a pas de catégorie propre.
cat_religion        → religion, foi, spiritualité religieuse organisée. Diff. cat_astro/cat_wellness : lié à une religion établie, pas ésotérisme ou bien-être individuel.
cat_cinema          → cinéma, séries, films, critiques, Netflix

ARBITRAGES — quand deux catégories s'appliquent

PRINCIPE : la catégorie la plus SPÉCIFIQUE qui s'applique gagne toujours.
Les catégories larges — cat_diy, cat_science, cat_actu, cat_education,
cat_culture, cat_doc, cat_travel, cat_finance — sont des filets de dernier
recours. Ne les choisis que si aucune catégorie plus précise ne convient.

1. Une catégorie précise bat cat_diy. cat_diy = fabrication créative SANS
   sous-univers dédié. Si cat_tricot (couture), cat_tricotage, cat_crochet,
   cat_broderie, cat_art, cat_jardin, cat_auto ou cat_deco s'applique, elle gagne — même
   si le titre dit "tuto", "DIY" ou "fabriquer soi-même".
   Ex : "coudre une robe" → cat_tricot. "macramé mural" → cat_crochet.
   "grille point de croix, motif pixel art à broder" → cat_broderie.
   "changer ses plaquettes de frein" → cat_auto.

2. cat_sante bat cat_science dès que le sujet est le corps humain, une
   maladie, un organe ou un traitement, même en vulgarisation.
   cat_science = sciences dures, espace, physique, biologie non humaine.
   Ex : "ce que l'AVC fait au cerveau" → cat_sante.

3. cat_nature bat cat_science dès que le sujet est un écosystème, une
   espèce ou le climat.
   Ex : "pourquoi les coraux blanchissent" → cat_nature.

4. cat_outdoor bat cat_travel quand l'ACTIVITÉ est le sujet (bivouac,
   randonnée, camping, survie), même si un lieu est nommé. cat_travel =
   découverte d'une destination.
   Ex : "bivouac 3 jours dans le Mercantour" → cat_outdoor.

5. cat_art bat cat_culture pour les arts visuels : exposition, peintre,
   musée, œuvre plastique. cat_culture = littérature, philosophie,
   culture générale.
   Ex : "exposition Vermeer au Rijksmuseum" → cat_art.

6. cat_politique bat cat_actu quand le sujet est une institution, une loi
   ou une réforme. cat_actu = événement daté, fait du jour.
   Ex : "réforme des retraites : ce qui change" → cat_politique.

7. cat_education ne gagne QUE si la matière enseignée n'a pas sa propre
   catégorie. Si on enseigne une langue, une science, l'histoire ou la
   politique, c'est cette catégorie-là. cat_education = méthode
   d'apprentissage, révisions, pédagogie en général.
   Ex : "tuto : conjuguer au prétérit" → cat_lang.
   Ex : "comment fonctionne le Sénat" → cat_politique.

8. cat_immo bat cat_finance dès qu'un bien immobilier est en jeu (locatif,
   rentabilité, achat, visite). cat_finance = épargne, bourse, budget.
   Ex : "investissement locatif : calcul de rentabilité" → cat_immo.

9. cat_bebe bat cat_nutrition et cat_sante quand le sujet est un tout-petit.
   Ex : "diversification alimentaire : par où commencer" → cat_bebe.

10. Le sujet précis bat le format. Une affaire criminelle traitée en
    profondeur est cat_truecrime, pas cat_doc ni cat_actu, quelle que soit
    la longueur ou le ton du reportage.
    Ex : "femmes infanticides : le tabou" → cat_truecrime.
    Ex : "révélations dans l'affaire Jubillar" → cat_truecrime.

11. Un lieu de sortie se classe selon ce qu'on y fait, jamais en
    cat_travel ni cat_business. Restaurant, brasserie, bistrot, bar à vin,
    carte ou menu d'un établissement → cat_food. Club, discothèque, salle
    de concert, programmation de soirées, billetterie d'un DJ ou d'un
    concert → cat_musique. cat_travel = hébergement ou destination.
    Ex : "OGAM / Restaurant Traditionnel / LYON" → cat_food.
    Ex : "Evenements Archive - AZAR Club" → cat_musique.

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
    // Miniature envoyée à Claude pour les plateformes où l'URL de vignette
    // est stable. Facebook est exclu : ses URLs fbcdn.net contiennent des
    // tokens à courte durée de vie qui expirent souvent avant que l'API
    // Anthropic ne récupère l'image côté serveur.
    const platformsWithReliableThumbnails = {'youtube', 'tiktok', 'instagram', 'twitch'};
    if (video.thumbnailUrl != null && video.thumbnailUrl!.isNotEmpty && platformsWithReliableThumbnails.contains(video.platform)) {
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
      'temperature': 0,
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

    final response = await Net.client.post(
      Uri.parse(_apiUrl),
      headers: {
        'x-reelr-secret': Secrets.appSharedSecret,
        'anthropic-version': '2023-06-01',
        'anthropic-beta': 'prompt-caching-2024-07-31',
        'content-type': 'application/json',
      },
      body: body,
    ).timeout(_requestTimeout);

    if (response.statusCode != 200) {
      // Certains CDN (Instagram, Twitch, LinkedIn...) bloquent parfois
      // l'acces a l'image de miniature via leur robots.txt, de facon
      // intermittente (pas systematique). Dans ce cas precis, on relance
      // une fois immediatement en texte seul (sans image) plutot que de
      // propager l'echec : sans ce repli cible, le retry generique plus
      // haut dans la pile renverrait la meme image, avec la meme
      // probabilite d'echec, pour un cout de 8s supplementaires perdues.
      final isRobotsBlocked = response.body.contains('robots.txt');
      if (isRobotsBlocked && messageContent is List) {
        final textOnlyBody = jsonEncode({
          'model': _model,
          'max_tokens': 500,
          'temperature': 0,
          'system': [
            {
              'type': 'text',
              'text': _systemPrompt,
              'cache_control': {'type': 'ephemeral'},
            }
          ],
          'messages': [
            {'role': 'user', 'content': userText},
          ],
        });
        final retryResponse = await Net.client.post(
          Uri.parse(_apiUrl),
          headers: {
            'x-reelr-secret': Secrets.appSharedSecret,
            'anthropic-version': '2023-06-01',
            'anthropic-beta': 'prompt-caching-2024-07-31',
            'content-type': 'application/json',
          },
          body: textOnlyBody,
        ).timeout(_requestTimeout);
        if (retryResponse.statusCode != 200) {
          throw Exception(
              'Claude API error ${retryResponse.statusCode}: ${retryResponse.body}');
        }
        final retryData = jsonDecode(retryResponse.body) as Map<String, dynamic>;
        final retryText = ((retryData['content'] as List<dynamic>).first
            as Map<String, dynamic>)['text'] as String;
        final retryJsonStr = _extractJson(retryText);
        return ClassificationResult.fromJson(
            jsonDecode(retryJsonStr) as Map<String, dynamic>);
      }
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
    // Lien web hors plateformes connues (article, fiche, page produit) :
    // presente comme une video, il faisait chercher a Claude une video
    // inexistante et faisait chuter sa confiance (Wikipedia « Belgique »
    // a 35, des ecouteurs Amazon a 25). Les videos ne sont pas concernees :
    // leur texte reste strictement identique.
    final isWebPage = video.platform == 'other';
    final buf = StringBuffer()
      ..writeln(isWebPage ? 'MÉTADONNÉES PAGE WEB :' : 'MÉTADONNÉES VIDÉO :');
    if (isWebPage) {
      buf.writeln('Type: page web (article, fiche, page produit...), pas une '
          'vidéo. Classe-la selon son SUJET, ou pour un produit selon son '
          'USAGE. Ignore le nom du site et le rayon ou fil d\'Ariane ajoutés '
          'au titre (ex. « Amazon.fr: Cuisine et Maison » ne dit rien du '
          'produit).');
    }
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
      // RETIRE le 2026-08-09 : la liste des categories dominantes et la
      // consigne « privilegie la categorie la plus regardee » coutaient
      // -4,3 points sur le jeu golden (94,1 % -> 89,8 %) et detournaient
      // 7 clips sur 127 vers les categories dejà dominantes.
      //
      // `categoryCount` s'incremente sur les propres predictions du modele,
      // sans validation humaine : c'etait une boucle fermee, une categorie
      // dominante devenait mecaniquement plus dominante.
      //
      // Ce qui reste ci-dessous — influenceurs, style de vie, corrections —
      // n'a pas ete mesure isolement et est conserve. Les corrections, elles,
      // viennent d'un geste humain : c'est le seul signal legitime.
      if (profile.knownInfluencers.isNotEmpty) {
        buf.writeln(
            '- Influenceurs suivis : ${profile.knownInfluencers.join(', ')}');
      }
      // RETIRE : « Style de vie détecté ». La valeur vient du champ
      // style_de_vie des propres reponses de Claude, sans validation
      // humaine : meme boucle fermee que les categories dominantes
      // ci-dessus. Un profil devenu « healthy » tirait les videos de
      // cuisine vers Bien-etre.
      final lastCorrections =
          profile.corrections.reversed.take(3).toList();
      if (lastCorrections.isNotEmpty) {
        buf.writeln('- Corrections récentes :');
        for (final c in lastCorrections) {
          buf.writeln(
              '  • "${c.videoTitle}" : ${c.wrongCategory} → ${c.correctCategory}');
        }
      }
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
