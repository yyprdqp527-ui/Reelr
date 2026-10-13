import 'package:flutter/material.dart';

class AppL10n {
  final Locale locale;
  AppL10n(this.locale);

  static AppL10n of(BuildContext context) =>
      Localizations.of<AppL10n>(context, AppL10n)!;

  static const LocalizationsDelegate<AppL10n> delegate = _AppL10nDelegate();

  static const Map<String, Map<String, String>> _strings = {
    'fr': {
      'app_name': 'Reelr',
      'home': 'Accueil',
      'categories': 'Catégories',
      'settings': 'Paramètres',
      'add_clip': 'Ajouter',
      'paste_url': 'Coller un lien vidéo…',
      'add': 'Ajouter',
      'cancel': 'Annuler',
      'move_to_category': 'Déplacer vers...',
      // Puce affichée sur une carte que la classification n'a pas su
      // trancher. Un appui ouvre le sélecteur de catégorie.
      'to_sort': 'À trier',
      'to_sort_hint': "Titre trop vague pour classer — appuie pour choisir",
      'delete_category_confirm': 'Supprimer « {name} » ?',
      'delete_category_empty': 'Cette catégorie est vide.',
      'delete_category_keeps_clips':
          'Les {n} vidéos de cette catégorie ne seront pas supprimées : '
              'elles repasseront simplement en « À trier ».',
      'delete': 'Supprimer',
      'share': 'Partager',
      'open': 'Ouvrir',
      'no_clips': 'Aucun clip',
      'no_clips_sub': 'Appuyez sur + pour ajouter votre premier lien vidéo',
      'title': 'Titre',
      'tags': 'Tags (séparés par virgules)',
      'category': 'Catégorie',
      'none': 'Aucune',
      'new_category': 'Nouvelle catégorie',
      'category_name': 'Nom de la catégorie',
      'color': 'Couleur',
      'icon': 'Icône',
      'save': 'Enregistrer',
      'confirm_delete': 'Supprimer ?',
      'confirm_delete_sub': 'Cette action est irréversible.',
      'no_title': 'Vidéo sans titre',
      'share_list': 'Partager la liste',
      'theme': 'Thème',
      'language': 'Langue',
      'system': 'Auto',
      'light': 'Clair',
      'dark': 'Sombre',
      'search': 'Retrouve une vidéo…',
      'all': 'Tout',
      'no_category': 'Aucune catégorie',
      'edit': 'Sous-catégorie...',
      'edit_clip': 'Sous-catégorie...',
      'edit_category': 'Modifier la catégorie',
      'settings_my_data_section': 'Mes données',
      'settings_export_clips': 'Exporter mes clips',
      'settings_notebook': 'Ce que Reelr a appris',
      'notebook_intro': "Chaque fois que tu ranges un lien toi-même, Reelr le retient ici. Il s'en sert pour classer les liens qui parlent du même sujet. Supprime un exemple s'il est faux.",
      'notebook_empty': "Rien pour l'instant. Range un lien à la main et il apparaîtra ici.",
      'notebook_clear': 'Tout effacer',
      'notebook_clear_confirm': 'Effacer tous les exemples appris ?',
      'settings_delete_all_data': 'Supprimer toutes les données',
      'settings_delete_all_confirm': 'Supprimer toutes les données ?',
      'settings_delete_all_confirm_sub':
          'Cette action supprimera définitivement tous vos clips.',
      'settings_upgrade_premium': 'Passer à Premium',
      'settings_manage_subscription': 'Gérer mon abonnement',
      'settings_restore_purchases': 'Restaurer mes achats',
      'settings_restore_purchases_started':
          'Recherche de tes achats précédents…',
      'settings_legal_section': 'Légal',
      'settings_privacy_policy': 'Politique de confidentialité',
      'settings_terms': 'Conditions d\'utilisation',
      'settings_contact': 'Contact',
      'thumbnail_unavailable_title': 'Vignette non disponible',
      'thumbnail_unavailable_body':
          'Certaines plateformes limitent la durée de vie des liens d\'image. Le contenu original reste accessible en ouvrant le lien.',
      'settings_about_section': 'À propos',
      'settings_version': 'Version',
      'settings_rate_app': 'Noter l\'app',
      'settings_share_app': 'Partager l\'app',
      'rate_app': 'Noter l\'app',
      'share_app': 'Partager l\'app',
      'sort': 'Trier',
      'sort_date_added': 'Date d\'ajout',
      'sort_alphabetical': 'Alphabétique',
      'sort_manual': 'Manuel',
      'reorder': 'Réorganiser',
      'reorder_done': 'Terminé',
      'reorder_hint': 'Maintenez et faites glisser une vidéo pour la réordonner',
      'reorder_order_saved': 'Ordre enregistré',
      'reorder_move_up': 'Déplacer vers le haut',
      'reorder_move_down': 'Déplacer vers le bas',
      'onboardingReorderCategoryTiles':
          'Maintenez une tuile, puis faites-la glisser pour réorganiser vos catégories.',
      'onboardingAssignVideoToSubcategory':
          'Sous-catégorie créée. Pour y ajouter une vidéo, ouvrez le menu ⋯ de la vidéo, puis choisissez cette sous-catégorie.',
      'onboardingGotIt': 'Compris',
      'fallibleNoticeTitle':
          'Reelr range tes liens… mais il peut se tromper.',
      'fallibleNoticeBody':
          "Si un lien n'est pas au bon endroit, déplace-le : Reelr s'en souvient pour les prochains.",
      'fallibleNoticeOk': 'OK',
      'add_subcategory_tooltip': 'Ajouter une sous-catégorie',
      'add_subsubcategory_tooltip': 'Ajouter un sous-dossier',
      'sharePlaylist': 'Partager la playlist',
      'onboardingSharePlaylist': 'Partage ta playlist avec tes amis.',
      'playlist_import_action': 'Importer',
      'playlist_import_select_all': 'Tout sélectionner',
      'playlist_import_deselect_all': 'Tout désélectionner',
      'playlist_import_already_saved': 'Déjà enregistré',
      'playlist_import_none_selected': 'Sélectionne au moins un lien à importer.',
    },
    'en': {
      'app_name': 'Reelr',
      'home': 'Home',
      'categories': 'Categories',
      'settings': 'Settings',
      'add_clip': 'Add',
      'paste_url': 'Paste a video URL…',
      'add': 'Add',
      'cancel': 'Cancel',
      'move_to_category': 'Move to...',
      'to_sort': 'To sort',
      'to_sort_hint': 'Title too vague to classify — tap to choose',
      'delete_category_confirm': 'Delete "{name}"?',
      'delete_category_empty': 'This category is empty.',
      'delete_category_keeps_clips':
          "The {n} videos in this category won't be deleted: "
              'they will simply move back to "To sort".',
      'delete': 'Delete',
      'share': 'Share',
      'open': 'Open',
      'no_clips': 'No clips yet',
      'no_clips_sub': 'Tap + to add your first video link',
      'title': 'Title',
      'tags': 'Tags (comma separated)',
      'category': 'Category',
      'none': 'None',
      'new_category': 'New Category',
      'category_name': 'Category name',
      'color': 'Color',
      'icon': 'Icon',
      'save': 'Save',
      'confirm_delete': 'Delete?',
      'confirm_delete_sub': 'This action cannot be undone.',
      'no_title': 'Untitled Video',
      'share_list': 'Share list',
      'theme': 'Theme',
      'language': 'Language',
      'system': 'Auto',
      'light': 'Light',
      'dark': 'Dark',
      'search': 'Find a video…',
      'all': 'All',
      'no_category': 'No categories yet',
      'edit': 'Subcategory...',
      'edit_clip': 'Subcategory...',
      'edit_category': 'Edit category',
      'settings_my_data_section': 'My data',
      'settings_export_clips': 'Export my clips',
      'settings_notebook': 'What Reelr has learned',
      'notebook_intro': 'Whenever you sort a link yourself, Reelr remembers it here. It uses these examples to sort links about the same topic. Remove an example if it is wrong.',
      'notebook_empty': 'Nothing yet. Sort a link by hand and it will appear here.',
      'notebook_clear': 'Clear all',
      'notebook_clear_confirm': 'Clear all learned examples?',
      'settings_delete_all_data': 'Delete all data',
      'settings_delete_all_confirm': 'Delete all data?',
      'settings_delete_all_confirm_sub':
          'This will permanently delete all your clips.',
      'settings_upgrade_premium': 'Upgrade to Premium',
      'settings_manage_subscription': 'Manage my subscription',
      'settings_restore_purchases': 'Restore purchases',
      'settings_restore_purchases_started':
          'Checking for previous purchases…',
      'settings_legal_section': 'Legal',
      'settings_privacy_policy': 'Privacy Policy',
      'settings_terms': 'Terms of Use',
      'settings_contact': 'Contact',
      'thumbnail_unavailable_title': 'Thumbnail unavailable',
      'thumbnail_unavailable_body':
          'Some platforms limit how long image links stay valid. The original content is still accessible by opening the link.',
      'settings_about_section': 'About',
      'settings_version': 'Version',
      'settings_rate_app': 'Rate the app',
      'settings_share_app': 'Share the app',
      'rate_app': 'Rate the app',
      'share_app': 'Share the app',
      'sort': 'Sort',
      'sort_date_added': 'Date added',
      'sort_alphabetical': 'Alphabetical',
      'sort_manual': 'Manual',
      'reorder': 'Reorder',
      'reorder_done': 'Done',
      'reorder_hint': 'Hold and drag a video to reorder it',
      'reorder_order_saved': 'Order saved',
      'reorder_move_up': 'Move up',
      'reorder_move_down': 'Move down',
      'onboardingReorderCategoryTiles':
          'Touch and hold a tile, then drag it to reorder your categories.',
      'onboardingAssignVideoToSubcategory':
          'Subcategory created. To add a video, open the video\'s ⋯ menu, then choose this subcategory.',
      'onboardingGotIt': 'Got it',
      'fallibleNoticeTitle':
          'Reelr sorts your links… but it can get it wrong.',
      'fallibleNoticeBody':
          "If a link isn't in the right place, move it: Reelr remembers it for the next ones.",
      'fallibleNoticeOk': 'OK',
      'add_subcategory_tooltip': 'Add a subcategory',
      'add_subsubcategory_tooltip': 'Add a subfolder',
      'sharePlaylist': 'Share playlist',
      'onboardingSharePlaylist': 'Share your playlist with your friends.',
      'playlist_import_action': 'Import',
      'playlist_import_select_all': 'Select all',
      'playlist_import_deselect_all': 'Deselect all',
      'playlist_import_already_saved': 'Already saved',
      'playlist_import_none_selected': 'Select at least one link to import.',
    },
  };

  String t(String key) =>
      _strings[locale.languageCode]?[key] ?? _strings['en']![key] ?? key;

  String videosSaved(int count) {
    if (locale.languageCode == 'en') {
      return '$count ${count == 1 ? "video" : "videos"} saved';
    }
    return '$count vidéo${count > 1 ? "s" : ""} sauvegardée${count > 1 ? "s" : ""}';
  }

  /// Compteur court affiché sur les cartes de catégories de l'accueil
  /// ("1 vidéo", "2 vidéos", "23 vidéos") — gère le singulier/pluriel,
  /// contrairement à [videosSaved] qui inclut "sauvegardée(s)".
  String videosCount(int count) {
    if (locale.languageCode == 'en') {
      return '$count ${count == 1 ? "video" : "videos"}';
    }
    return '$count vidéo${count > 1 ? "s" : ""}';
  }

  /// Message de confirmation après import d'une playlist reçue par lien
  /// ("1 lien importé" / "3 liens importés").
  String playlistImportedCount(int count) {
    if (locale.languageCode == 'en') {
      return '$count ${count == 1 ? "link" : "links"} imported';
    }
    return '$count lien${count > 1 ? "s" : ""} importé${count > 1 ? "s" : ""}';
  }

  String subcategoriesCount(int count) {
    if (locale.languageCode == 'en') {
      return '$count ${count == 1 ? "subcategory" : "subcategories"}';
    }
    return '$count sous-cat.';
  }

  // Noms FR des catégories (par ID)
  static const Map<String, String> _categoryNamesFr = {
    'cat_food':           'Recette',
    'cat_fitness':        'Fitness',
    'cat_gaming':         'Gaming',
    'cat_beauty':         'Beauté',
    'cat_mode':           'Mode',
    'cat_travel':         'Voyage',
    'cat_humour':         'Humour',
    'cat_musique':        'Musique',
    'cat_wellness':       'Bien-être',
    'cat_podcast':        'Podcast',
    'cat_famille':        'Famille',
    'cat_finance':        'Finance',
    'cat_business':       'Business',
    'cat_actu':           'Actualités',
    'cat_societe':        'Société',
    'cat_diy':            'DIY',
    'cat_deco':           'Déco',
    'cat_auto':           'Auto',
    'cat_moto':           'Moto',
    'cat_shopping':       'Shopping',
    'cat_tech':           'Tech',
    'cat_design':         'Design & UX',
    'cat_culture':        'Culture',
    'cat_cinema':         'Cinéma',
    'cat_growth':         'Dév. Personnel',
    'cat_pets':           'Animaux',
    'cat_nature':         'Nature',
    'cat_truecrime':      'True Crime',
    'cat_astro':          'Astrologie',
    'cat_sport':          'Sport',
    'cat_sante':          'Santé',
    'cat_science':        'Science',
    'cat_bebe':           'Bébé',
    'cat_tricot':         'Couture',
    'cat_tricotage':      'Tricot',
    'cat_crochet':        'Crochet',
    'cat_broderie':       'Broderie',
    'cat_doc':            'Documentaire',
    'cat_religion':       'Religion',
    'cat_immo':           'Immobilier',
    'cat_manga':          'Anime & Manga',
    'cat_politique':      'Politique',
    'cat_crypto':         'Crypto',
    'cat_lang':           'Langues',
    'cat_histoire':       'Histoire',
    'cat_art':            'Art',
    'cat_photo':          'Photo',
    'cat_outdoor':        'Outdoor',
    'cat_psycho':         'Psychologie',
    'cat_luxe':           'Luxe',
    'cat_entrepreneuriat':'Entrepreneuriat',
    'cat_education':      'Éducation',
    'cat_cosplay':        'Cosplay',
    'cat_dance':          'Danse',
    'cat_comedy':         'Stand-up',
    'cat_jardin':         'Jardinage',
    'cat_sport_extreme':  'Extrême',
    'cat_nutrition':      'Nutrition',
    'cat_vintage':        'Vintage',
    'cat_fail':           'Fails',
  };

  // Noms EN des catégories (par ID)
  static const Map<String, String> _categoryNamesEn = {
    'cat_food':           'Food',
    'cat_fitness':        'Fitness',
    'cat_gaming':         'Gaming',
    'cat_beauty':         'Beauty',
    'cat_mode':           'Fashion',
    'cat_travel':         'Travel',
    'cat_humour':         'Humor',
    'cat_musique':        'Music',
    'cat_wellness':       'Wellness',
    'cat_podcast':        'Podcast',
    'cat_famille':        'Family',
    'cat_finance':        'Finance',
    'cat_business':       'Business',
    'cat_actu':           'News',
    'cat_societe':        'Society',
    'cat_diy':            'DIY',
    'cat_deco':           'Decor',
    'cat_auto':           'Cars',
    'cat_moto':           'Bikes',
    'cat_shopping':       'Shopping',
    'cat_tech':           'Tech',
    'cat_design':         'Design & UX',
    'cat_culture':        'Culture',
    'cat_cinema':         'Films',
    'cat_growth':         'Self Growth',
    'cat_pets':           'Pets',
    'cat_nature':         'Nature',
    'cat_truecrime':      'True Crime',
    'cat_astro':          'Astrology',
    'cat_sport':          'Sport',
    'cat_sante':          'Health',
    'cat_science':        'Science',
    'cat_bebe':           'Baby',
    'cat_tricot':         'Sewing',
    'cat_tricotage':      'Knitting',
    'cat_crochet':        'Crochet',
    'cat_broderie':       'Embroidery',
    'cat_doc':            'Documentary',
    'cat_religion':       'Religion',
    'cat_immo':           'Real Estate',
    'cat_manga':          'Anime & Manga',
    'cat_politique':      'Politics',
    'cat_crypto':         'Crypto',
    'cat_lang':           'Languages',
    'cat_histoire':       'History',
    'cat_art':            'Art',
    'cat_photo':          'Photo',
    'cat_outdoor':        'Outdoor',
    'cat_psycho':         'Psychology',
    'cat_luxe':           'Luxury',
    'cat_entrepreneuriat':'Entrepreneurship',
    'cat_education':      'Education',
    'cat_cosplay':        'Cosplay',
    'cat_dance':          'Dance',
    'cat_comedy':         'Stand-up',
    'cat_jardin':         'Gardening',
    'cat_sport_extreme':  'Extreme',
    'cat_nutrition':      'Nutrition',
    'cat_vintage':        'Vintage',
    'cat_fail':           'Fails',
    // anciens noms texte libre
    'Musique': 'Music', 'Voyage': 'Travel', 'Famille': 'Family',
    'Humour': 'Humor', 'Beauté': 'Beauty', 'Mode': 'Fashion',
    'Cuisine': 'Cooking', 'Finance & Business': 'Finance & Business',
  };

  /// Variantes connues qui ne sont ni le nom FR ni le nom EN "officiel"
  /// d'une catégorie `cat_xxx`, mais désignent la même chose (anciennes
  /// catégories créées à la main, anciennes versions de l'app, pluriels...).
  /// Sert uniquement à la résolution vers l'ID canonique ci-dessous — jamais
  /// affiché directement.
  ///
  /// REGLE : uniquement des equivalents stricts. Jamais des categories
  /// voisines que le classement separe expres (Sport/Fitness,
  /// Nutrition/Food, Couture/Tricot, Sante/Bien-etre) : un synonyme de
  /// trop fusionnerait deux tuiles voulues. Toute ajout doit passer
  /// test/category_dedup_test.dart.
  ///
  /// Accents, casse et pluriel simple sont geres par
  /// [normalizeCategoryLabel] : inutile de les lister ici.
  static const Map<String, List<String>> _extraSynonyms = {
    'cat_food': ['food', 'recette', 'cuisine', 'cooking', 'recipe'],
    'cat_fitness': ['workout', 'muscu', 'musculation', 'gym'],
    'cat_actu': ['actu', 'info', 'infos', 'news', 'actualite'],
    'cat_beauty': ['maquillage', 'makeup', 'make up', 'beauty', 'skincare'],
    'cat_travel': ['voyage', 'travel'],
    'cat_humour': ['humor', 'humour', 'comedie', 'comedy'],
    'cat_wellness': ['bien etre', 'wellness', 'wellbeing'],
    'cat_musique': ['music', 'musique'],
    'cat_gaming': ['gaming', 'jeu video', 'jeux video', 'video game'],
    'cat_deco': ['deco', 'decoration', 'home decor'],
    'cat_design': ['design', 'ux', 'ui', 'ui ux', 'ux ui', 'design ux', 'graphisme', 'graphic design'],
    'cat_pets': ['animaux', 'animal', 'pets', 'animaux de compagnie'],
    'cat_shopping': ['bons plans', 'bon plan', 'achats', 'deals', 'promos'],
    'cat_broderie': ['broderie', 'embroidery', 'point de croix', 'cross stitch', 'crossstitch', 'cross stich', 'punto croce', 'punto de cruz', 'kreuzstich'],
  };

  /// Forme de comparaison d'un nom de categorie : minuscules, sans
  /// accents, tirets / « & » / « _ » ramenes a des espaces, espaces
  /// multiples reduits, pluriel simple retire (s ou x final des mots de
  /// plus de 3 lettres). Sert uniquement a comparer, jamais a afficher.
  static String normalizeCategoryLabel(String raw) {
    const accents = {
      'à': 'a', 'â': 'a', 'ä': 'a', 'á': 'a', 'ã': 'a', 'å': 'a',
      'ç': 'c', 'é': 'e', 'è': 'e', 'ê': 'e', 'ë': 'e',
      'í': 'i', 'ì': 'i', 'î': 'i', 'ï': 'i', 'ñ': 'n',
      'ó': 'o', 'ò': 'o', 'ô': 'o', 'ö': 'o', 'õ': 'o',
      'ú': 'u', 'ù': 'u', 'û': 'u', 'ü': 'u', 'ý': 'y', 'ÿ': 'y',
      'œ': 'oe', 'æ': 'ae',
    };
    final buf = StringBuffer();
    for (final ch in raw.trim().toLowerCase().split('')) {
      if (ch == '-' || ch == '_' || ch == '&' || ch == '/' || ch == "'") {
        buf.write(' ');
      } else {
        buf.write(accents[ch] ?? ch);
      }
    }
    return buf
        .toString()
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .map((w) => w.length > 3 && (w.endsWith('s') || w.endsWith('x'))
            ? w.substring(0, w.length - 1)
            : w)
        .join(' ');
  }

  /// Couleur/icône "officielles" de chaque catégorie standard `cat_xxx` —
  /// source unique, reprise à l'identique de `ClipsState` (couleurs/icônes)
  /// et de `CategoryVisuals` (les 3 entrées qui manquaient : tricotage,
  /// crochet, moto). Utilisée à la fois pour créer une nouvelle catégorie
  /// IA avec le bon rendu dès le départ, et pour réparer en base celles qui
  /// étaient déjà tombées sur le violet/dossier par défaut à cause du même
  /// bug (voir `DatabaseHelper._repairGenericCategoryVisuals`).
  static const Map<String, Color> categoryColors = {
    'cat_food': Color(0xFFFF6B6B), 'cat_fitness': Color(0xFF4ECDC4),
    'cat_gaming': Color(0xFF74B9FF), 'cat_beauty': Color(0xFFFF85B3),
    'cat_mode': Color(0xFFC77DFF), 'cat_travel': Color(0xFF81ECEC),
    'cat_humour': Color(0xFFFFE66D), 'cat_musique': Color(0xFFFF7675),
    'cat_wellness': Color(0xFFA8E6CF), 'cat_podcast': Color(0xFFB2BEC3),
    'cat_famille': Color(0xFFFD79A8), 'cat_finance': Color(0xFF00B894),
    'cat_actu': Color(0xFF90A4AE), 'cat_diy': Color(0xFFE17055),
    'cat_deco': Color(0xFFFAB1A0), 'cat_auto': Color(0xFFFFB347),
    'cat_culture': Color(0xFF8E44AD), 'cat_cinema': Color(0xFFEF9A9A),
    'cat_growth': Color(0xFF27AE60), 'cat_pets': Color(0xFF16A085),
    'cat_truecrime': Color(0xFFE57373), 'cat_astro': Color(0xFFCE93D8),
    'cat_business': Color(0xFF26A69A), 'cat_societe': Color(0xFF78909C),
    'cat_nature': Color(0xFF81C784), 'cat_sport': Color(0xFFFF5252),
    'cat_sante': Color(0xFFFF8A65), 'cat_science': Color(0xFF4FC3F7),
    'cat_bebe': Color(0xFFFFCC80), 'cat_tricot': Color(0xFFCE93D8),
    'cat_doc': Color(0xFF90A4AE), 'cat_religion': Color(0xFFB39DDB),
    'cat_immo': Color(0xFFBCAAA4), 'cat_manga': Color(0xFFFF8A80),
    'cat_politique': Color(0xFF80CBC4), 'cat_crypto': Color(0xFFF7DC6F),
    'cat_lang': Color(0xFF80DEEA), 'cat_histoire': Color(0xFFA5D6A7),
    'cat_art': Color(0xFFE040FB), 'cat_photo': Color(0xFF4DD0E1),
    'cat_outdoor': Color(0xFF69F0AE), 'cat_psycho': Color(0xFFFFAB91),
    'cat_luxe': Color(0xFFFFD700), 'cat_entrepreneuriat': Color(0xFF4CAF50),
    'cat_education': Color(0xFF29B6F6), 'cat_cosplay': Color(0xFFBA68C8),
    'cat_dance': Color(0xFFFF4081), 'cat_comedy': Color(0xFFFFEB3B),
    'cat_jardin': Color(0xFF8BC34A), 'cat_sport_extreme': Color(0xFFFF6D00),
    'cat_nutrition': Color(0xFF66BB6A), 'cat_vintage': Color(0xFFD7CCC8),
    'cat_fail': Color(0xFFFF5722),
    'cat_vibes': Color(0xFFCDB4FF), 'cat_tech': Color(0xFF64B5F6),
    'cat_design': Color(0xFF7C4DFF),
    // Repris de CategoryVisuals — absents des catégories "standard" d'origine.
    'cat_tricotage': Color(0xFFD4A5D9),
    'cat_crochet': Color(0xFFC08FD0),
    'cat_broderie': Color(0xFFE1A6C8),
    'cat_moto': Color(0xFF7FA0D8),
    'cat_shopping': Color(0xFFF48FB1),
  };

  static const Map<String, IconData> categoryIcons = {
    'cat_food': Icons.restaurant_rounded, 'cat_fitness': Icons.fitness_center_rounded,
    'cat_gaming': Icons.sports_esports_rounded, 'cat_beauty': Icons.brush_rounded,
    'cat_mode': Icons.style_rounded, 'cat_travel': Icons.flight_takeoff_rounded,
    'cat_humour': Icons.sentiment_very_satisfied_rounded, 'cat_musique': Icons.music_note_rounded,
    'cat_wellness': Icons.self_improvement_rounded, 'cat_podcast': Icons.mic_rounded,
    'cat_famille': Icons.family_restroom_rounded, 'cat_finance': Icons.trending_up_rounded,
    'cat_actu': Icons.newspaper_rounded, 'cat_diy': Icons.handyman_rounded,
    'cat_deco': Icons.home_rounded, 'cat_auto': Icons.directions_car_rounded,
    'cat_culture': Icons.theater_comedy_rounded, 'cat_cinema': Icons.movie_rounded,
    'cat_growth': Icons.rocket_launch_rounded, 'cat_pets': Icons.pets_rounded,
    'cat_truecrime': Icons.gavel_rounded, 'cat_astro': Icons.auto_awesome_rounded,
    'cat_business': Icons.business_center_rounded, 'cat_societe': Icons.people_rounded,
    'cat_nature': Icons.park_rounded, 'cat_sport': Icons.sports_soccer_rounded,
    'cat_sante': Icons.favorite_rounded, 'cat_science': Icons.science_rounded,
    'cat_bebe': Icons.child_care_rounded, 'cat_tricot': Icons.content_cut_rounded,
    'cat_doc': Icons.video_library_rounded, 'cat_religion': Icons.church_rounded,
    'cat_immo': Icons.apartment_rounded, 'cat_manga': Icons.auto_stories_rounded,
    'cat_politique': Icons.account_balance_rounded, 'cat_crypto': Icons.currency_bitcoin_rounded,
    'cat_lang': Icons.translate_rounded, 'cat_histoire': Icons.history_edu_rounded,
    'cat_art': Icons.palette_rounded, 'cat_photo': Icons.camera_alt_rounded,
    'cat_outdoor': Icons.terrain_rounded, 'cat_psycho': Icons.psychology_rounded,
    'cat_luxe': Icons.diamond_rounded, 'cat_entrepreneuriat': Icons.lightbulb_rounded,
    'cat_education': Icons.school_rounded, 'cat_cosplay': Icons.masks_rounded,
    'cat_dance': Icons.music_video_rounded, 'cat_comedy': Icons.mic_external_on_rounded,
    'cat_jardin': Icons.yard_rounded, 'cat_sport_extreme': Icons.paragliding_rounded,
    'cat_nutrition': Icons.no_food_rounded, 'cat_vintage': Icons.watch_rounded,
    'cat_fail': Icons.sentiment_very_dissatisfied_rounded,
    'cat_vibes': Icons.blur_on_rounded, 'cat_tech': Icons.devices_rounded,
    'cat_design': Icons.design_services_rounded,
    // Repris de CategoryVisuals — absents des catégories "standard" d'origine.
    'cat_tricotage': Icons.checkroom_outlined,
    'cat_crochet': Icons.gesture_rounded,
    'cat_broderie': Icons.grid_on_rounded,
    'cat_moto': Icons.two_wheeler_rounded,
    'cat_shopping': Icons.shopping_bag_rounded,
  };

  /// Résout un libellé brut de catégorie (renvoyé par Claude, saisi à la
  /// main, ou hérité d'une ancienne version) vers l'ID canonique `cat_xxx`
  /// correspondant, si connu — insensible à la casse/aux espaces.
  ///
  /// Permet de reconnaître qu'une catégorie nommée "Food" et une catégorie
  /// nommée "Recette" désignent la même chose (l'IA répond toujours en
  /// anglais, quelle que soit la langue de l'app), afin de les fusionner au
  /// lieu d'en créer une par langue. Généralisable à toute autre paire
  /// FR/EN du catalogue standard.
  static String? canonicalCategoryId(String rawLabel) {
    final normalized = normalizeCategoryLabel(rawLabel);
    if (normalized.isEmpty) return null;
    // Un identifiant standard passe tel quel (« cat_food »).
    if (_categoryNamesFr.containsKey(rawLabel.trim()) &&
        rawLabel.trim().startsWith('cat_')) {
      return rawLabel.trim();
    }
    for (final entry in _categoryNamesEn.entries) {
      if (entry.key.startsWith('cat_') &&
          normalizeCategoryLabel(entry.value) == normalized) {
        return entry.key;
      }
    }
    for (final entry in _categoryNamesFr.entries) {
      if (entry.key.startsWith('cat_') &&
          normalizeCategoryLabel(entry.value) == normalized) {
        return entry.key;
      }
    }
    for (final entry in _extraSynonyms.entries) {
      if (entry.value.any((s) => normalizeCategoryLabel(s) == normalized)) {
        return entry.key;
      }
    }
    return null;
  }

  /// Nom francais d'une categorie standard (ex. cat_design -> Design & UX),
  /// ou null si l'identifiant est inconnu.
  static String? standardCategoryName(String id) => _categoryNamesFr[id];

  String localizeCategory(String name) {
    final canonicalId = canonicalCategoryId(name);
    if (canonicalId != null) return localizeCategoryById(canonicalId);
    if (locale.languageCode == 'en') {
      return _categoryNamesEn[name] ?? _categoryNamesEn[name.toLowerCase()] ?? name;
    }
    return _categoryNamesFr[name] ?? _categoryNamesFr[name.toLowerCase()] ?? name;
  }

  /// Localise par ID de catégorie (cat_xxx)
  String localizeCategoryById(String id) {
    if (locale.languageCode == 'en') {
      return _categoryNamesEn[id] ?? id;
    }
    return _categoryNamesFr[id] ?? id;
  }

  /// Point d'entrée unique pour afficher le nom d'une catégorie.
  ///
  /// Pour les catégories prédéfinies (id `cat_xxx`) dont le nom n'a
  /// jamais été modifié par l'utilisateur, on traduit dynamiquement
  /// via l'ID (ce qui permet de suivre un changement de langue). Mais
  /// si l'utilisateur a renommé la catégorie, `name` ne correspond plus
  /// au libellé par défaut dans aucune des deux langues : on affiche
  /// alors ce nom personnalisé tel quel, sans quoi le renommage n'a
  /// jamais d'effet visible (bug corrigé le 13 juillet 2026 : le
  /// renommage écrivait bien en base mais l'affichage ignorait `name`
  /// pour toute catégorie `cat_xxx`).
  String localizeCategoryDisplay(String id, String name) {
    if (!id.startsWith('cat_')) {
      return localizeCategory(name);
    }
    final isUnmodified =
        name.isEmpty || name == _categoryNamesFr[id] || name == _categoryNamesEn[id];
    if (isUnmodified) {
      return localizeCategoryById(id);
    }
    return name;
  }
}

class _AppL10nDelegate extends LocalizationsDelegate<AppL10n> {
  const _AppL10nDelegate();

  @override
  bool isSupported(Locale locale) =>
      ['en', 'fr'].contains(locale.languageCode);

  @override
  Future<AppL10n> load(Locale locale) async => AppL10n(locale);

  @override
  bool shouldReload(_AppL10nDelegate old) => true;
}
