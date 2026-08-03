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
      'reorder_hint': 'Maintenez la poignée et faites glisser la vidéo',
      'reorder_order_saved': 'Ordre enregistré',
      'reorder_move_up': 'Déplacer vers le haut',
      'reorder_move_down': 'Déplacer vers le bas',
      'onboardingReorderCategoryTiles':
          'Maintenez une tuile, puis faites-la glisser pour réorganiser vos catégories.',
      'onboardingAssignVideoToSubcategory':
          'Sous-catégorie créée. Pour y ajouter une vidéo, ouvrez le menu ⋯ de la vidéo, puis choisissez cette sous-catégorie.',
      'onboardingGotIt': 'Compris',
      'add_subcategory_tooltip': 'Ajouter une sous-catégorie',
      'sharePlaylist': 'Partager la playlist',
      'onboardingSharePlaylist': 'Partage ta playlist avec tes amis.',
      'playlist_import_action': 'Importer',
      'playlist_import_select_all': 'Tout sélectionner',
      'playlist_import_deselect_all': 'Tout désélectionner',
      'playlist_import_already_saved': 'Déjà enregistrée',
      'playlist_import_none_selected': 'Sélectionnez au moins une vidéo à importer.',
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
      'reorder_hint': 'Hold the handle and drag the video',
      'reorder_order_saved': 'Order saved',
      'reorder_move_up': 'Move up',
      'reorder_move_down': 'Move down',
      'onboardingReorderCategoryTiles':
          'Touch and hold a tile, then drag it to reorder your categories.',
      'onboardingAssignVideoToSubcategory':
          'Subcategory created. To add a video, open the video\'s ⋯ menu, then choose this subcategory.',
      'onboardingGotIt': 'Got it',
      'add_subcategory_tooltip': 'Add a subcategory',
      'sharePlaylist': 'Share playlist',
      'onboardingSharePlaylist': 'Share your playlist with your friends.',
      'playlist_import_action': 'Import',
      'playlist_import_select_all': 'Select all',
      'playlist_import_deselect_all': 'Deselect all',
      'playlist_import_already_saved': 'Already saved',
      'playlist_import_none_selected': 'Select at least one video to import.',
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
  /// ("1 vidéo importée" / "3 vidéos importées").
  String playlistImportedCount(int count) {
    if (locale.languageCode == 'en') {
      return '$count ${count == 1 ? "video" : "videos"} imported';
    }
    return '$count vidéo${count > 1 ? "s" : ""} importée${count > 1 ? "s" : ""}';
  }

  String subcategoriesCount(int count) {
    if (locale.languageCode == 'en') {
      return '$count ${count == 1 ? "subcategory" : "subcategories"}';
    }
    return '$count sous-cat.';
  }

  // Noms FR des catégories (par ID)
  static const Map<String, String> _categoryNamesFr = {
    'cat_food':           'Food',
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

  String localizeCategory(String name) {
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
