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
      'search': 'Rechercher…',
      'all': 'Tout',
      'no_category': 'Aucune catégorie',
      'edit': 'Classer',
      'edit_clip': 'Classer',
      'edit_category': 'Modifier la catégorie',
      'settings_my_data_section': 'Mes données',
      'settings_export_clips': 'Exporter mes clips',
      'settings_delete_all_data': 'Supprimer toutes les données',
      'settings_delete_all_confirm': 'Supprimer toutes les données ?',
      'settings_delete_all_confirm_sub':
          'Cette action supprimera définitivement tous vos clips.',
      'settings_legal_section': 'Légal',
      'settings_privacy_policy': 'Politique de confidentialité',
      'settings_terms': 'Conditions d\'utilisation',
      'settings_contact': 'Contact',
      'settings_about_section': 'À propos',
      'settings_version': 'Version',
      'settings_rate_app': 'Noter l\'app',
      'settings_share_app': 'Partager l\'app',
      'rate_app': 'Noter l\'app',
      'share_app': 'Partager l\'app',
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
      'search': 'Search…',
      'all': 'All',
      'no_category': 'No categories yet',
      'edit': 'Classer',
      'edit_clip': 'Classer',
      'edit_category': 'Edit category',
      'settings_my_data_section': 'My data',
      'settings_export_clips': 'Export my clips',
      'settings_delete_all_data': 'Delete all data',
      'settings_delete_all_confirm': 'Delete all data?',
      'settings_delete_all_confirm_sub':
          'This will permanently delete all your clips.',
      'settings_legal_section': 'Legal',
      'settings_privacy_policy': 'Privacy Policy',
      'settings_terms': 'Terms of Use',
      'settings_contact': 'Contact',
      'settings_about_section': 'About',
      'settings_version': 'Version',
      'settings_rate_app': 'Rate the app',
      'settings_share_app': 'Share the app',
      'rate_app': 'Rate the app',
      'share_app': 'Share the app',
    },
  };

  String t(String key) =>
      _strings[locale.languageCode]?[key] ?? _strings['en']![key] ?? key;
}

class _AppL10nDelegate extends LocalizationsDelegate<AppL10n> {
  const _AppL10nDelegate();

  @override
  bool isSupported(Locale locale) =>
      ['en', 'fr'].contains(locale.languageCode);

  @override
  Future<AppL10n> load(Locale locale) async => AppL10n(locale);

  @override
  bool shouldReload(_AppL10nDelegate old) => false;
}
