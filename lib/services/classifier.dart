import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
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
      // Pâtisserie, gâteaux, desserts, boulangerie, vin et cocktails ont leur
      // propre tuile (2026-10-15) : ils vont à Claude, pas à la couche locale.
      'pasta', 'pizza', 'soupe', 'soup', 'salade', 'salad',
      'breakfast', 'lunch', 'dinner', 'snack', 'apero', 'apéro',
      'raclette', 'tartiflette', 'fondue', 'quiche', 'tarte', 'crepe', 'crêpe',
      'lasagne', 'risotto', 'curry', 'ramen', 'sushi', 'burger', 'sandwich',
      'wrap', 'bowl', 'brunch', 'smoothie',
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
      'tuto maquillage', 'nail', 'nails', 'manucure',
      // Coiffure, cheveux, coloration ont leur propre tuile (2026-10-15).
      'beaute', 'beauté', 'beauty',
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
      'creer entreprise', 'créer entreprise', 'lancer startup',
      'levee fonds', 'levée de fonds', 'pitch investor', 'business plan',
      'product market fit', 'mvp', 'saas', 'bootstrapping', 'side project',
      'side hustle', 'passive income', 'revenu passif', 'indie maker',
      'solopreneur', 'fondateur startup', 'pivot startup',
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
      'ikea', 'amenagement', 'aménagement',
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
      'culture',
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
    // Decision seule (seuil >= 3) seulement si AUCUNE autre categorie n'a
    // d'indice dans le titre (2026-10-03). Sinon, plusieurs mots faibles
    // s'additionnaient et battaient le vrai sujet : une grille de point de
    // croix « cake, dessert, breakfast » donnait Food 3 contre Broderie 3,
    // Food gagnant l'egalite, sans que Claude soit consulte. Observe en
    // production. Avec un concurrent, c'est Claude qui tranche.
    // Le seuil 2 (indice de doute pour la couche 2) n'est pas concerne.
    if (minScore >= 3 && scores.length > 1) return null;
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
  /// Modele du classement. Defaut = Haiku 5.5 (decision du 2026-10-08).
  /// Pour mesurer un autre modele : --dart-define=REELR_MODEL=claude-haiku-4-5-20251001
  static const String _model = String.fromEnvironment('REELR_MODEL',
      defaultValue: 'claude-haiku-5-5');

  /// Haiku 5.x et Sonnet 5.x : pas de `temperature` (erreur 400), la
  /// reflexion se regle par `output_config.effort`.
  static bool get _isGen5 =>
      _model.startsWith('claude-haiku-5') ||
      _model.startsWith('claude-sonnet-5');
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
Tu es une personne réelle qui consomme énormément de contenu en ligne — YouTube, TikTok, Instagram Reels. Tu connais par cœur la culture internet française ET anglophone : les créateurs, les tendances, les codes visuels, les communautés. Les titres arrivent en français, en anglais ou dans une autre langue : tu appliques exactement les mêmes règles quelle que soit la langue.

Quand on te donne des métadonnées d'une vidéo, tu ne fais PAS de la classification mécanique par mots-clés. Tu fais ce qu'un humain fait naturellement : tu lis l'ensemble, tu ressens l'ambiance, et tu choisis la catégorie qui correspond à l'EXPÉRIENCE de regarder la vidéo.

━━━ ÉTAPE 0 — REGARDE L'IMAGE SI ELLE EST FOURNIE ━━━

Si une miniature est fournie, c'est souvent le signal le plus fiable, surtout quand le titre est vague.

• Salle de sport, haltères, corps musclé → cat_fitness, même si le titre dit "incroyable"
• Plat, ingrédients, cuisine en action → cat_food, même si le titre dit "elle s'est effondrée"
• Maquillage, palette, gros plan visage, pinceau sur la peau → cat_beauty (ce qu'on APPLIQUE sur le corps)
• Vêtements, tenue, essayage, lookbook, haul de vêtements → cat_mode (ce qu'on PORTE)
• Micro, casque audio, deux personnes face à face en studio, format long avec invité → cat_podcast
• Écran de jeu, manette, headset → cat_gaming
• Paysage, aéroport, sac à dos → cat_travel
• Personnes qui rient, caméra cachée, grimace exagérée → cat_humour
• Dessin, tablette, Procreate → cat_diy (cat_art si c'est une œuvre exposée)
• Scène, lumières de concert → cat_musique
• Bébé, poussette → cat_bebe ; enfants plus grands, vie de famille → cat_famille
• Graphiques boursiers → cat_finance ; bureau, réunion, startup → cat_business
• Nom propre lié à une affaire judiciaire du moment → cat_actu (cat_truecrime si l'affaire est racontée en profondeur)

Titre ambigu ET image ambiguë (ou absente) → confiance ≤ 40.

━━━ ÉTAPE 1 — LE FORMAT, PUIS LE SUJET ━━━

• PRANK / CAMÉRA CACHÉE / TROLL / GONE WRONG / SKETCH → cat_humour, sauf si un sujet précis est réellement montré (une vraie recette, même ratée ou drôle, reste cat_food : voir sa définition).
• FAIL / compilation d'accidents → cat_fail
• TUTO / "comment faire" / "how to" / RECETTE / ROUTINE → le SUJET décide (cat_food, cat_beauty, cat_fitness, cat_diy…). "Tuto", "tutorial" ou "DIY" seuls ne désignent jamais cat_diy.
• HAUL / UNBOXING / AVIS / TEST / REVIEW / COMPARATIF → le PRODUIT décide (vêtements → cat_mode, makeup → cat_beauty, téléphone → cat_tech, appareil photo → cat_photo).
• VLOG / "une journée" / "day in my life" → le contexte décide (cat_famille, cat_travel…).
• DOCUMENTAIRE / REPORTAGE / "expliqué" / "explained" → le SUJET décide, jamais le format (voir arbitrage 10).

━━━ ÉTAPE 2 — LIS LE TITRE EN ENTIER ━━━

Ne découpe pas le titre en mots isolés, lis-le comme une personne :

• "illustration #tattoo #art #pov #procreate" → cat_diy
• "j'ai fait semblant d'être un artiste 😂 prank" → cat_humour
• "je teste la cuisine moléculaire avec un vrai chef" → cat_food
• "Ed Sheeran - Perfect (Official Music Video)" → cat_musique (un nom d'artiste n'est pas un podcast)
• "Pixel 10 Pro unboxing" → cat_tech

😂 💀 🤣 lol mdr ptdr indiquent un ton drôle, mais le sujet montré compte toujours.

━━━ ÉTAPE 3 — LE NOM DE CHAÎNE ━━━

Si tu reconnais le créateur, c'est un signal fort, mais le titre de CETTE vidéo prime s'il désigne clairement autre chose.
"Squeezie" → cat_gaming ou cat_humour. "750g" → cat_food. "Tibo InShape" → cat_fitness.

━━━ ÉTAPE 4 — IMAGINE LE VIEWER ━━━

Dans quelle playlist cette personne range-t-elle la vidéo ?

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
Restaurant (→ cat_restaurant) : McDonald's, Burger King, KFC, Starbucks, Domino's, Five Guys, Pizza Hut, Quick, Flunch, Buffalo Grill, Hippopotamus, Paul, Brioche Dorée, Columbus Café, Chipotle, Taco Bell, Popeyes, Dunkin', Chick-fil-A, Shake Shack, Panera
Food (produits → cat_food) : Häagen-Dazs, Nutella, Red Bull, Monster
Maison : IKEA, Maisons du Monde, Leroy Merlin, Castorama, La Redoute
Sport : Decathlon, Go Sport, Salomon, The North Face, Patagonia, Arc'teryx
Voiture : Renault, Peugeot, Citroën, Tesla, BMW, Mercedes, Uber, BlaBlaCar

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

CATÉGORIES — Tu DOIS retourner EXACTEMENT un de ces IDs dans "categorie_principale", rien d'autre :

cat_food            → cuisine, recettes, chefs, gastronomie. Diff. cat_restaurant : food = on cuisine, goûte ou présente un plat ; restaurant = on parle d'un établissement. Diff. cat_humour : si la vidéo montre réellement une recette/un plat (même raté ou tourné sur un ton comique), reste cat_food ; cat_humour seulement si le comique est le vrai sujet et la nourriture n'est qu'un prétexte accessoire.
cat_restaurant      → restaurants, brasseries, bistrots, bars à vin, cafés-restaurants, adresses où manger, cartes et menus d'établissements, critiques et bonnes adresses. Diff. cat_food : restaurant = le lieu/l'établissement ; food = la recette, le plat, la cuisine faite maison.
cat_menage          → ménage, nettoyage, entretien de la maison, linge (lessive, adoucissant, repassage, séchage), détachage, produits ménagers, astuces de nettoyage. Diff. cat_deco : déco = l'allure de la maison ; ménage = son entretien. Diff. cat_rangement : ménage = nettoyer ; rangement = organiser.
cat_rangement       → rangement, organisation de la maison, désencombrement, minimalisme, optimisation de l'espace, organiseurs. Diff. cat_menage : rangement = placer et organiser ; ménage = nettoyer. Diff. cat_deco : déco = le style.
cat_travaux         → gros chantier de la maison : maçonnerie, gros œuvre, électricité, plomberie lourde, carrelage, isolation, rénovation complète, artisans. Diff. cat_diy : tout tuto de petit bricolage ou de réparation à faire soi-même (poncer un meuble, changer un joint, monter une étagère, customiser) reste cat_diy ; travaux = chantier lourd ou pose de matériaux. Diff. cat_deco : une pièce rénovée montrée par son RÉSULTAT, son style ou son budget reste cat_deco. Diff. cat_immo : immo = achat, location, investissement.
cat_coiffure        → coiffure, coupes, colorations, balayage, brushing, soins des cheveux, tutos coiffure. Diff. cat_beauty : beauty = visage et peau ; coiffure = cheveux.
cat_patisserie      → technique et métier de la pâtisserie : pâtissier, entremets, macarons, viennoiseries, pain et boulangerie, cake design, décoration de gâteaux. Diff. cat_food : TOUTE recette avec liste d'ingrédients reste cat_food, même sucrée (tarte tatin, brownie, crêpes, gâteau au yaourt) ; pâtisserie = le savoir-faire du pâtissier ou du boulanger, pas une recette du quotidien. Un tuto de pâte de base (brisée, sablée, à pizza) est une recette : cat_food. Les grands classiques de pâtissier (éclairs, choux, religieuse, millefeuille, macarons, entremets) restent cat_patisserie.
cat_boissons        → vin, cocktails, bières, spiritueux, café, thé, sodas, boissons énergisantes (Monster, Red Bull), tests et classements de boissons, mixologie, accords. Une enseigne de restauration (Starbucks, McDonald's) reste cat_restaurant, même quand la vidéo ne montre que ses boissons. Diff. cat_restaurant : un bar ou un restaurant = lieu ; la boisson elle-même = boissons. Diff. cat_food : food = plat ; boissons = ce qui se boit.
cat_livres          → livres, romans, lectures, critiques, BookTok, bibliothèque, auteurs, nouveautés littéraires. Diff. cat_culture : culture = analyse, explication d'une œuvre ou d'un auteur, philosophie, culture générale ; livres = recommandations, chroniques de lecture, BookTok, bibliothèque, nouveautés.
cat_nutrition       → diététique, rééquilibrage alimentaire, calories, macros, régimes. Diff. cat_food : food = plaisir de cuisiner/manger ; nutrition = logique diététique/santé.
cat_fitness         → musculation, entraînement, yoga, running, cardio. Diff. cat_sport_extreme : ici entraînement classique, pas la prise de risque.
cat_sport           → sport en général, compétition, matchs, résultats, équipes. Le karting (indoor ou en compétition) et les sports mécaniques pratiqués en loisir = cat_sport ; cat_auto = voitures, mécanique, essais
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
cat_business        → entrepreneuriat, création d'entreprise, récits de fondateurs, startup, marketing, management, conseils business
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
cat_design          → design appliqué : UX/UI, interfaces d'applis et de sites, maquettes, Figma, palettes et tendances de couleurs, typographie, logos, identité visuelle, branding, design graphique, inspiration design. Diff. cat_art : art = beaux-arts et démarche artistique ; design = conception visuelle appliquée à un usage (interface, marque, produit). Diff. cat_tech : tech = appareils et logiciels ; design = leur conception visuelle ou ergonomique. Diff. cat_deco : déco = intérieur d'un logement. Diff. cat_photo : une banque d'images sur un sujet de design reste cat_design.
cat_photo           → technique photo/vidéo, matériel, retouche. Diff. cat_art : photo = médium/technique, art = résultat artistique visé.
cat_tech            → high-tech, électronique, informatique, smartphones, ordinateurs, audio (écouteurs, enceintes), gadgets, applis. Diff. cat_photo : photo = technique et matériel de prise de vue ; tech = tout autre appareil ou produit électronique.
cat_cosplay         → cosplay, costumes de personnages, geek culture
cat_manga           → anime, manga, culture japonaise animée. Diff. cat_cosplay : manga = œuvres, cosplay = déguisement inspiré d'œuvres.
cat_deco            → décoration intérieure, home tour, aménagement
cat_immo            → achat/vente/investissement immobilier, visites de biens à vendre. Diff. cat_deco : immo = transaction, déco = esthétique du bien habité.
cat_jardin          → jardinage, potager, plantes d'extérieur ET d'intérieur (plantes vertes, entretien, achat de plantes). Diff. cat_deco : une plante, même d'intérieur, va dans cat_jardin ; cat_deco = meubles, objets, aménagement.
cat_nature          → écologie, environnement, biodiversité au sens large. Diff. cat_jardin : jardin = pratique personnelle, nature = sujet environnemental large.
cat_pets            → animaux de compagnie, chiens, chats, vétérinaire
cat_auto            → voitures, mécanique auto, conduite, essais de voitures. Diff. cat_moto : tout ce qui a deux roues motorisées va dans cat_moto.
cat_moto            → motos, scooters, balades et road trips à moto, mécanique et équipement moto, motocross. Diff. cat_auto : deux-roues motorisés uniquement. Diff. cat_sport_extreme : figures freestyle et prise de risque spectaculaire vont dans cat_sport_extreme.
cat_culture         → culture générale, littérature, philosophie
cat_histoire        → faits et récits historiques passés. Diff. cat_culture : histoire = événements du passé, culture = réflexion actuelle.
cat_education       → apprentissage scolaire/pédagogie, cours, méthodes. Diff. cat_culture : education = format pédagogique structuré. Révisions d'examen (bac, brevet, concours) et méthodes de travail = cat_education, même si la matière est la philosophie ou la littérature ; cat_culture seulement si la vidéo explique le fond (une œuvre, une idée) sans viser un examen.
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
    carte ou menu d'un établissement → cat_restaurant. Club, discothèque, salle
    de concert, programmation de soirées, billetterie d'un DJ ou d'un
    concert → cat_musique. cat_travel = hébergement ou destination.
    Ex : "OGAM / Restaurant Traditionnel / LYON" → cat_restaurant.
    Ex : "Evenements Archive - AZAR Club" → cat_musique.

    Tout ce qui parle d'un restaurant va dans cat_restaurant : le mot
    « restaurant » dans le titre, une enseigne de restauration (McDonald's,
    Starbucks, Flunch, Buffalo Grill, Five Guys, KFC…), un site qui
    réserve, livre ou répertorie des restaurants (TheFork, Uber Eats,
    Deliveroo, Guide Michelin, Yelp, Tripadvisor restaurants), une page qui
    se présente comme un restaurant ou une liste de restaurants.
    Ex : "Les 10 meilleurs restaurants de Lyon" → cat_restaurant.
    Ex : "Starbucks : menu de Noël" → cat_restaurant.

12. Une ACTIVITÉ pratiquée bat cat_travel, même dans une destination
    célèbre : trek, randonnée, escalade, alpinisme, camping, plongée →
    cat_outdoor ; balade ou voyage à moto → cat_moto. cat_travel =
    découvrir un lieu (visite, itinéraire, hébergement, culture locale).
    Ex : "Trek to Everest Base Camp" → cat_outdoor.
    Ex : "Road trip à moto en Corse" → cat_moto.

13. cat_sport_extreme seulement si la prise de risque spectaculaire est le
    sujet (base jump, wingsuit, free solo, vagues géantes). Escalade, ski,
    VTT pratiqués normalement → cat_outdoor.

14. Le sport reste cat_sport même quand c'est une nouvelle du jour :
    résultats, matchs, transferts, mercato, blessure, contrat d'un joueur.
    Ex : "Officiel : Dembélé prolonge au PSG" → cat_sport.

15. cat_actu = événement du jour (catastrophe, élection, attentat,
    décision tombée aujourd'hui). Un PHÉNOMÈNE de société expliqué
    (logement, jeunesse, transports, travail, inégalités, mode de vie) →
    cat_societe, même s'il fait l'actualité. Un reportage sur un mode de
    vie → cat_societe.
    Ex : "Why rent is so expensive in big cities" → cat_societe.

16. cat_bebe = grossesse, naissance et bébé jusqu'à environ 18 mois
    (allaitement, sommeil du nourrisson, diversification, portage).
    Enfant qui marche et parle, "toddler", crises, éducation, 2 ans et
    plus → cat_famille.
    Ex : "Terrible two : comment réagir" → cat_famille.

17. Appareils photo, objectifs, caméras, drones, réglages de prise de vue
    → cat_photo, même pour filmer en vidéo. Téléphones, ordinateurs,
    écouteurs, consoles et autres appareils → cat_tech.

18. Lune, pleine lune, astres, signes, énergie lunaire → cat_astro, même
    avec un rituel ou une méditation. cat_wellness = méditation,
    respiration, sommeil, sans dimension astrologique.

19. Un artiste musical reste cat_musique (portrait, hommage, documentaire
    sur sa carrière), sauf si l'enquête criminelle est le vrai sujet.

20. Une bande-annonce (trailer) de jeu vidéo → cat_gaming ; de film ou de
    série → cat_cinema.

21. L'humour bat le sujet dont on rit. Un humoriste, un sketch ou un
    stand-up sur la nourriture, le sport, les animaux, la famille… →
    cat_comedy (spectacle, humoriste sur scène) ou cat_humour (sketch
    court). cat_food exige qu'on cuisine, goûte, teste ou présente
    réellement de la nourriture ou une boisson (un lieu où manger = cat_restaurant).
    Ex : "Humoriste : les Français au restaurant" → cat_comedy.
    Ex : "I ranked every gas station snack" → cat_food.

22. Un ouvrage fait main se classe selon sa TECHNIQUE, jamais selon ce
    qu'il représente : grille de point de croix de gâteaux ou de fruits →
    cat_broderie ; amigurumi en forme de chat → cat_crochet ; pull tricoté
    motif sapin → cat_tricotage.

23. Le domaine précis bat toujours la forme (« tuto », « explication »,
    « univers », « voyage ») : production musicale (beat, FL Studio,
    mixage) → cat_musique ; dressage, éducation ou soins d'un animal →
    cat_pets ; histoire, lore ou théories d'un jeu vidéo → cat_gaming ;
    d'un anime → cat_manga ; une moto comme moyen de déplacement (Ducati,
    Harley, BMW GS…) → cat_moto, même pour un voyage.

24. Une page web d'inspiration ou de recherche se classe selon son SUJET, jamais selon le type de
    site qui l'héberge : banque d'images, portfolio, place de marché, plateforme de blog ou outil en ligne,
    le site ne compte pas. UX/UI, interface, maquette, palette ou tendance de couleurs, typographie,
    identité visuelle, logo, branding → cat_design. Quand une image est jointe, elle montre souvent le
    sujet mieux que le titre.
    Ex : "Dashboard UI kit | Figma Community" → cat_design.
    Ex : "Nouvelle identité visuelle : logo et charte graphique" → cat_design.

25. Une page de HASHTAG ("#recette", "#voyage", adresse /tag/ ou /hashtag/) n'a pas de contenu propre :
    le mot du hashtag EST le sujet, classe-le avec confiance (au moins 75) si le mot est clair.
    Ignore une image de mur de connexion ou de pause (logo, écran "Take a break", "Log in").
    Ex : "#recette" → cat_food. Ex : "#voyage" → cat_travel.

26. Maison : le sujet décide. Lessive, linge, adoucissant, nettoyage, détachage,
    produits ménagers → cat_menage. Ranger, trier, désencombrer → cat_rangement.
    Chantier technique (plomberie, électricité, carrelage, isolation, peinture
    des murs) → cat_travaux. Une pièce ou un meuble montré par son style, son
    résultat ou son budget → cat_deco. Un produit d'entretien précis va en
    cat_menage, jamais en cat_shopping.
    Ex : "Lenor Fresh Air" → cat_menage. Ex : "Poser du carrelage au sol" → cat_travaux.
    Ex : "Avant / après : ma cuisine rénovée" → cat_deco.

27. Pâtisserie, gâteaux, desserts, pain → cat_patisserie (le salé reste
    cat_food). Cheveux, coupes, colorations → cat_coiffure (le visage et la
    peau restent cat_beauty). Boire (vin, cocktails, café, thé) → cat_boissons.
    Un roman, une lecture, une critique de livre → cat_livres.
    Ex : "Tarte au citron meringuée" → cat_patisserie. Ex : "Balayage maison" → cat_coiffure.

RÈGLE ABSOLUE : "categorie_principale" doit être UN des IDs ci-dessus (ex: "cat_food"). JAMAIS un texte libre.

RÈGLES FINALES :
- `influenceur_detecte` : nom du créateur si reconnu, sinon null
- `raison` : UNE phrase courte, 15 mots maximum
- `tags_suggeres` : 3 mots-clés maximum
- `a_acheter` : true UNIQUEMENT si le lien est une PAGE WEB marchande d'un produit précis (fiche produit, page d'un article en vente sur le site d'une enseigne ou d'une marque). false pour TOUTE vidéo (YouTube, TikTok, Instagram, Facebook, reel, short), même si elle présente ou teste un produit ; false aussi pour une recette, un tuto, un lieu, un article, une page d'accueil ou d'enseigne. Cette étiquette ne change JAMAIS la catégorie : un pull reste cat_mode, des écouteurs cat_tech.
- `confiance` : sois HONNÊTE. Si le titre est court, vague ou peut être interprété de plusieurs façons sans autre signal (pas de chaîne, pas de description, pas d'image révélatrice), mets confiance ≤ 40. Mieux vaut admettre le doute que se tromper avec certitude.
  Exemples de titres ambigus (→ confiance ≤ 40) : "elle s'est effondrée", "incroyable", "je suis choquée", "vous allez pas le croire", "omg", "wtf", "c'est fou", "you won't believe this", "Part 3"
  Exemples clairs (→ confiance élevée) : "tuto maquillage naturel" (cat_beauty), "Squeezie vs ZeratoR" (cat_gaming)

Réponds UNIQUEMENT en JSON valide sur une seule ligne, sans markdown, sans aucun texte autour, exactement ces 6 champs :
{"categorie_principale": "cat_food", "confiance": 0, "influenceur_detecte": null, "raison": "...", "tags_suggeres": ["...", "..."], "a_acheter": false}''';

  /// Classifie [video] via Claude Haiku.
  /// Si [profile] est fourni et contient des données, le profil utilisateur
  /// est injecté dans le prompt pour améliorer la pertinence.
  static Future<ClassificationResult> classify({
    required VideoData video,
    ClientProfile? profile,
    List<String> customCategories = const [],
    List<String> userExamples = const [],
  }) async {
    final userText =
        _buildUserText(video, profile, customCategories, userExamples);

    // Construction du contenu (multimodal si thumbnail disponible)
    final dynamic messageContent;
    // Miniature envoyée à Claude pour les plateformes où l'URL de vignette
    // est stable. Facebook est exclu : ses URLs fbcdn.net contiennent des
    // tokens à courte durée de vie qui expirent souvent avant que l'API
    // Anthropic ne récupère l'image côté serveur.
    const platformsWithReliableThumbnails = {'youtube', 'tiktok', 'instagram', 'twitch'};
    // Liens web (2026-10-07) : l'image n'etait jamais envoyee, alors qu'une
    // page de recherche d'inspiration (UX, couleurs...) se reconnait au
    // premier coup d'oeil sur la vignette. Seules les images directes
    // (https) partent : ni la capture du proxy (lente, 502 frequents), ni
    // les vignettes locales (le proxy plafonne la requete a 50 Ko).
    final thumb = video.thumbnailUrl;
    final isWebWithDirectImage = video.platform == 'other' &&
        thumb != null &&
        thumb.startsWith('https://') &&
        !thumb.contains('reelr-proxy');
    if (thumb != null &&
        thumb.isNotEmpty &&
        (platformsWithReliableThumbnails.contains(video.platform) ||
            isWebWithDirectImage)) {
      messageContent = [
        {
          'type': 'image',
          'source': {
            'type': 'url',
            'url': thumb,
          },
        },
        {
          'type': 'text',
          'text': isWebWithDirectImage
              ? 'Voici l\'image principale de la page web. Elle montre '
                  'souvent le sujet : utilise-la avec le titre.\n\n$userText'
              : 'Voici la miniature de la vidéo. Utilise-la comme signal '
                  'principal si le titre est ambigu.\n\n$userText',
        },
      ];
    } else {
      messageContent = userText;
    }

    // Repli texte seul sur TOUTE erreur quand une miniature est jointe
    // (2026-10-03). Avant, seul un corps contenant « robots.txt »
    // declenchait ce repli : une miniature TikTok/Instagram expiree, refusee
    // ou trop lente a telecharger faisait echouer l'appel, la pile au-dessus
    // relancait le MEME appel avec la MEME image, echouait encore, puis
    // tombait dans le filet mots-cles (68 % de precision sur le golden).
    // Jusqu'a 2 x 20 s perdues pour un classement degrade.
    final hasImage = messageContent is List;
    http.Response response;
    try {
      response = await _post(messageContent);
    } on TimeoutException {
      if (!hasImage) rethrow;
      debugPrint('[classify] delai depasse avec miniature, relance texte seul');
      response = await _post(userText);
    }
    if (response.statusCode != 200 && hasImage) {
      debugPrint('[classify] erreur ${response.statusCode} avec miniature, '
          'relance texte seul');
      response = await _post(userText);
    }
    if (response.statusCode != 200) {
      throw Exception(
          'Claude API error ${response.statusCode}: ${response.body}');
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    // Haiku 5.x peut faire preceder la reponse de blocs `thinking` : on
    // prend le premier bloc de type `text` (identique a l'ancien `.first`
    // avec Haiku 4.5, dont la reponse n'a qu'un bloc texte).
    final blocks =
        (data['content'] as List<dynamic>).cast<Map<String, dynamic>>();
    final text =
        blocks.firstWhere((b) => b['type'] == 'text')['text'] as String;
    final jsonStr = _extractJson(text);
    final json = jsonDecode(jsonStr) as Map<String, dynamic>;
    json['categorie_principale'] =
        _validCategoryId(json['categorie_principale'], customCategories);
    return ClassificationResult.fromJson(json);
  }

  /// IDs autorises : exactement ceux listes dans le prompt
  /// (lignes « cat_xxx   → ... »), une seule source de verite.
  static final Set<String> _knownCategoryIds = RegExp(
    r'^(cat_\w+)\s+→',
    multiLine: true,
  ).allMatches(_systemPrompt).map((m) => m.group(1)!).toSet();

  /// Variantes inventees deja observees -> vrai ID.
  static const Map<String, String> _categoryIdAliases = {
    'cat_entrepreneuriat': 'cat_business',
    'cat_entrepreneurship': 'cat_business',
    'cat_anime': 'cat_manga',
    'cat_recette': 'cat_food',
    'cat_cuisine': 'cat_food',
    'cat_voyage': 'cat_travel',
    'cat_resto': 'cat_restaurant',
    'cat_restaurants': 'cat_restaurant',
    'cat_beaute': 'cat_beauty',
    'cat_humor': 'cat_humour',
    'cat_music': 'cat_musique',
    'cat_linge': 'cat_menage',
    'cat_cleaning': 'cat_menage',
    'cat_entretien': 'cat_menage',
    'cat_renovation': 'cat_travaux',
    'cat_organisation': 'cat_rangement',
    'cat_organizing': 'cat_rangement',
    'cat_hair': 'cat_coiffure',
    'cat_baking': 'cat_patisserie',
    'cat_drinks': 'cat_boissons',
    'cat_vin': 'cat_boissons',
    'cat_books': 'cat_livres',
    'cat_livre': 'cat_livres',
  };

  /// Garde-fou (2026-10-03) : Claude a renvoye « cat_anime », absent
  /// de la liste. Dans l'app, un ID inconnu devenait une NOUVELLE
  /// categorie nommee « cat_anime ». Un ID inconnu sans alias renvoie
  /// null : le clip reste « A trier » au lieu de creer une tuile fantome.
  static String? _validCategoryId(dynamic raw,
      [List<String> customCategories = const []]) {
    if (raw is! String) return null;
    final id = raw.trim();
    if (_knownCategoryIds.contains(id)) return id;
    // Tuile creee par l'utilisatrice (2026-10-06) : son nom exact est
    // une reponse valable. Il est resolu par nom dans l'app.
    for (final name in customCategories) {
      if (name.trim().toLowerCase() == id.toLowerCase()) return name;
    }
    final alias = _categoryIdAliases[id];
    if (alias != null) return alias;
    debugPrint('[classify] ID hors liste ignore : $id');
    return null;
  }

  /// Mode lot (2026-10-08) : consignes ajoutees au prompt quand plusieurs
  /// liens partages EN MEME TEMPS sont lus ensemble.
  static const String _lotInstructions = '''
━━━ MODE LOT (prioritaire sur le format de réponse ci-dessus) ━━━
Tu reçois plusieurs liens partagés EN MÊME TEMPS par la même personne. Lis-les ensemble, comme une personne qui range sa liste.
1. Sépare-les en groupes de même sujet. Un lien sans rapport avec les autres forme un groupe à lui seul.
2. Les liens d'une même liste (mêmes objets : tapis, coupes de cheveux, recettes...) vont dans la MÊME catégorie, même si leurs titres n'ont aucun mot en commun ou sont dans des langues différentes.
3. Pour chaque groupe, donne une catégorie : un ID cat_xxx de la liste, ou le nom exact d'une tuile personnelle si elle correspond mieux.
4. Réponds UNIQUEMENT avec ce JSON, sans texte autour :
{"groupes":[{"liens":[1,2],"categorie":"cat_xxx","confiance":0-100,"raison":"courte"}]}
Chaque lien apparaît dans exactement un groupe. Mets une confiance basse si tu hésites.
''';

  /// Consigne ajoutee quand les vignettes sont jointes au lot.
  static const String _lotImageHint =
      'Les images jointes sont les vignettes des liens, dans l\'ordre. '
      'Pour des liens de recherche visuelle (Pinterest, images, boutiques), '
      'ce que montrent les images compte plus que les titres : regroupe '
      'selon ce que l\'on voit.';

  /// Lit un lot de liens en un seul appel et renvoie les groupes de meme
  /// sujet. Mesure (Haiku 5.5, 8 lots, titres seuls) : 29/29 contre 24/29
  /// pour un appel par lien. [lines] : une ligne par lien (numerotees 1..).
  /// [images] : vignette de chaque lien (https), jointe a l'appel ; en cas
  /// d'echec avec images, l'appel est refait en texte seul.
  /// Renvoie null si l'appel ou la reponse est inutilisable : l'appelant
  /// retombe alors sur l'ancienne methode.
  static Future<List<LotGroup>?> classifyLot(
      List<String> lines, List<String> customCategories,
      [List<String?> images = const []]) async {
    try {
      final tiles = customCategories.isEmpty
          ? ''
          : '\nTuiles personnelles de l\'utilisatrice : '
              '${customCategories.join(', ')}.';
      final header = 'Lot de ${lines.length} liens partagés en même temps :\n';
      final textOnly = '$header'
          '${[for (var i = 0; i < lines.length; i++) '${i + 1}. ${lines[i]}'].join('\n')}'
          '\n$tiles';

      // Vignettes : https uniquement, 12 au plus (le telechargement se fait
      // cote Anthropic, il ne faut pas allonger l'appel).
      final usable = <int>{};
      for (var i = 0; i < lines.length && i < images.length; i++) {
        final u = images[i];
        if (u != null && u.startsWith('https://') && usable.length < 12) {
          usable.add(i);
        }
      }
      final List<Map<String, Object>>? withImages = usable.isEmpty
          ? null
          : [
              {'type': 'text', 'text': header},
              for (var i = 0; i < lines.length; i++) ...[
                {'type': 'text', 'text': '${i + 1}. ${lines[i]}'},
                if (usable.contains(i))
                  {
                    'type': 'image',
                    'source': {'type': 'url', 'url': images[i]!},
                  },
              ],
              {'type': 'text', 'text': '$_lotImageHint$tiles'},
            ];

      Future<http.Response> post(dynamic content) {
        final body = jsonEncode({
          'model': _model,
          'max_tokens': 900,
          if (_isGen5)
            'output_config': {'effort': 'low'}
          else
            'temperature': 0,
          'system': [
            {
              'type': 'text',
              'text': _systemPrompt,
              'cache_control': {'type': 'ephemeral'},
            },
            {'type': 'text', 'text': _lotInstructions},
          ],
          'messages': [
            {'role': 'user', 'content': content},
          ],
        });
        return Net.client.post(
          Uri.parse(_apiUrl),
          headers: {
            'x-reelr-secret': Secrets.appSharedSecret,
            'anthropic-version': '2023-06-01',
            'anthropic-beta': 'prompt-caching-2024-07-31',
            'content-type': 'application/json',
          },
          body: body,
        ).timeout(const Duration(seconds: 40));
      }

      http.Response resp;
      if (withImages != null) {
        debugPrint('[lot] lecture groupee : ${usable.length} image(s) jointe(s)');
        try {
          resp = await post(withImages);
        } on TimeoutException {
          debugPrint('[lot] delai depasse avec images, relance texte seul');
          resp = await post(textOnly);
        }
        if (resp.statusCode != 200) {
          final detail = resp.body.length > 300
              ? resp.body.substring(0, 300)
              : resp.body;
          debugPrint('[lot] erreur ${resp.statusCode} avec images, '
              'relance texte seul : $detail');
          resp = await post(textOnly);
        }
      } else {
        resp = await post(textOnly);
      }
      if (resp.statusCode != 200) {
        debugPrint('[lot] lecture groupee : HTTP ${resp.statusCode}');
        return null;
      }
      final text = (jsonDecode(utf8.decode(resp.bodyBytes))['content'] as List)
          .map((b) => (b as Map)['text'] ?? '')
          .join();
      final data = jsonDecode(_extractJson(text)) as Map<String, dynamic>;
      final out = <LotGroup>[];
      final seen = <int>{};
      for (final g in (data['groupes'] as List)) {
        final links = <int>[];
        for (final l in (g['liens'] as List)) {
          final n = (l as num).toInt();
          if (n >= 1 && n <= lines.length && seen.add(n)) links.add(n);
        }
        if (links.isEmpty) continue;
        out.add(LotGroup(
          links,
          _validCategoryId(g['categorie'], customCategories),
          (g['confiance'] as num).toInt(),
          (g['raison'] ?? '').toString(),
        ));
      }
      return out;
    } catch (e) {
      debugPrint('[lot] lecture groupee echouee : $e');
      return null;
    }
  }

  /// Un appel au proxy, avec [content] en message utilisateur (texte seul
  /// ou liste multimodale). Corps et en-tetes identiques a l'ancien code.
  static Future<http.Response> _post(dynamic content) {
    final body = jsonEncode({
      'model': _model,
      // 800 : le JSON de reponse depassait parfois 500 tokens (reponse
      // coupee, FormatException) ; Haiku 5.x y compte aussi sa reflexion.
      // Le Worker plafonne a 1000.
      'max_tokens': 800,
      if (_isGen5)
        'output_config': {'effort': 'low'}
      else
        'temperature': 0,
      'system': [
        {
          'type': 'text',
          'text': _systemPrompt,
          'cache_control': {'type': 'ephemeral'},
        }
      ],
      'messages': [
        {'role': 'user', 'content': content},
      ],
    });
    return Net.client.post(
      Uri.parse(_apiUrl),
      headers: {
        'x-reelr-secret': Secrets.appSharedSecret,
        'anthropic-version': '2023-06-01',
        'anthropic-beta': 'prompt-caching-2024-07-31',
        'content-type': 'application/json',
      },
      body: body,
    ).timeout(_requestTimeout);
  }

  static String _buildUserText(VideoData video, ClientProfile? profile,
      [List<String> customCategories = const [],
      List<String> userExamples = const []]) {
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

    // Tuiles creees par l'utilisatrice : absentes du prompt systeme (figé).
    // Claude peut répondre par leur nom exact au lieu d'un cat_xxx.
    final custom = customCategories
        .map((n) => n.trim())
        .where((n) => n.isNotEmpty)
        .toList();
    if (custom.isNotEmpty) {
      buf.writeln('\nTUILES CRÉÉES PAR L\'UTILISATRICE : '
          '${custom.map((n) => '"$n"').join(', ')}');
      buf.writeln('Si le sujet de ce contenu est clairement l\'une de ces '
          'tuiles (son nom, ou une marque/un site qu\'elle désigne), réponds '
          'avec son NOM EXACT dans categorie_principale, à la place d\'un '
          'cat_xxx. Sinon, ignore cette liste.');
    }

    // Rangements deja faits a la main par l'utilisatrice sur le meme sujet
    // (SortingNotebook) : un geste humain, donc le signal le plus fiable.
    if (userExamples.isNotEmpty) {
      buf.writeln('\nEXEMPLES DÉJÀ RANGÉS PAR L\'UTILISATRICE (son choix prime) :');
      for (final e in userExamples) {
        buf.writeln('  • $e');
      }
      buf.writeln('Si ce contenu traite du même sujet que l\'un de ces '
          'exemples, range-le dans la même catégorie, avec une confiance '
          'd\'au moins 70. Un mot en commun, la même plateforme (Instagram, '
          'TikTok...) ou le même format ne suffisent PAS : un mot comme '
          '"cheveux" dans une publicité ou une série ne fait pas de ce '
          'contenu une coupe de cheveux. Compare le sujet réel (ce dont '
          'parle ou ce que montre le contenu). Sinon, ignore ces exemples.');
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
    return _escapeControlChars(text.substring(start, end + 1));
  }

  /// Claude met parfois un saut de ligne brut dans une valeur : jsonDecode
  /// le refuse (« Control character in string »). On l'echappe, seulement
  /// a l'interieur des chaines.
  static String _escapeControlChars(String json) {
    final out = StringBuffer();
    var inString = false;
    var escaped = false;
    for (final r in json.runes) {
      final c = String.fromCharCode(r);
      if (inString && !escaped && r < 0x20) {
        out.write(r == 10 ? r'\n' : r == 13 ? r'\r' : r == 9 ? r'\t' : ' ');
        continue;
      }
      if (c == '"' && !escaped) inString = !inString;
      escaped = inString && c == r'\' && !escaped;
      out.write(c);
    }
    return out.toString();
  }
}


/// Un groupe de liens de meme sujet, tel que Claude l'a lu dans un lot
/// (voir ClaudeClassifier.classifyLot). [links] : numeros 1.. dans le lot.
class LotGroup {
  final List<int> links;
  final String? category;
  final int confidence;
  final String reason;
  const LotGroup(this.links, this.category, this.confidence, this.reason);
}
