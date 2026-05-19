import 'dart:async';
import 'dart:convert';
import 'dart:ui';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:path/path.dart' as path_helper;
import 'package:receive_sharing_intent/receive_sharing_intent.dart';
import 'package:share_plus/share_plus.dart';
import 'package:sqflite/sqflite.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:uuid/uuid.dart';

// ─────────────────────────────────────────────
// MODELS
// ─────────────────────────────────────────────

class SocialPlatform {
  final String id;
  final String name;
  final IconData icon;
  final Color color;

  const SocialPlatform({
    required this.id,
    required this.name,
    required this.icon,
    required this.color,
  });

  static SocialPlatform detect(String url) {
    final lower = url.toLowerCase();
    if (lower.contains('youtube.com') || lower.contains('youtu.be')) {
      return _platforms['youtube']!;
    } else if (lower.contains('tiktok.com')) {
      return _platforms['tiktok']!;
    } else if (lower.contains('instagram.com')) {
      return _platforms['instagram']!;
    } else if (lower.contains('twitter.com') || lower.contains('x.com')) {
      return _platforms['x']!;
    } else if (lower.contains('facebook.com') || lower.contains('fb.watch')) {
      return _platforms['facebook']!;
    } else if (lower.contains('twitch.tv')) {
      return _platforms['twitch']!;
    } else if (lower.contains('vimeo.com')) {
      return _platforms['vimeo']!;
    } else if (lower.contains('reddit.com')) {
      return _platforms['reddit']!;
    } else if (lower.contains('pinterest.com')) {
      return _platforms['pinterest']!;
    } else if (lower.contains('linkedin.com')) {
      return _platforms['linkedin']!;
    }
    return _platforms['other']!;
  }

  static final Map<String, SocialPlatform> _platforms = {
    'youtube': const SocialPlatform(
      id: 'youtube',
      name: 'YouTube',
      icon: Icons.smart_display_rounded,
      color: Color(0xFFFF0000),
    ),
    'tiktok': const SocialPlatform(
      id: 'tiktok',
      name: 'TikTok',
      icon: Icons.music_note_rounded,
      color: Color(0xFF69C9D0),
    ),
    'instagram': const SocialPlatform(
      id: 'instagram',
      name: 'Instagram',
      icon: Icons.camera_alt_rounded,
      color: Color(0xFFE1306C),
    ),
    'x': const SocialPlatform(
      id: 'x',
      name: 'X / Twitter',
      icon: Icons.alternate_email_rounded,
      color: Color(0xFF1DA1F2),
    ),
    'facebook': const SocialPlatform(
      id: 'facebook',
      name: 'Facebook',
      icon: Icons.facebook_rounded,
      color: Color(0xFF1877F2),
    ),
    'twitch': const SocialPlatform(
      id: 'twitch',
      name: 'Twitch',
      icon: Icons.live_tv_rounded,
      color: Color(0xFF9146FF),
    ),
    'vimeo': const SocialPlatform(
      id: 'vimeo',
      name: 'Vimeo',
      icon: Icons.videocam_rounded,
      color: Color(0xFF1AB7EA),
    ),
    'reddit': const SocialPlatform(
      id: 'reddit',
      name: 'Reddit',
      icon: Icons.forum_rounded,
      color: Color(0xFFFF4500),
    ),
    'pinterest': const SocialPlatform(
      id: 'pinterest',
      name: 'Pinterest',
      icon: Icons.push_pin_rounded,
      color: Color(0xFFE60023),
    ),
    'linkedin': const SocialPlatform(
      id: 'linkedin',
      name: 'LinkedIn',
      icon: Icons.work_rounded,
      color: Color(0xFF0A66C2),
    ),
    'other': const SocialPlatform(
      id: 'other',
      name: 'Autre',
      icon: Icons.link_rounded,
      color: Color(0xFF9E9E9E),
    ),
  };
}

class ClipCategory {
  final String id;
  final String name;
  final Color color;
  final IconData icon;

  const ClipCategory({
    required this.id,
    required this.name,
    required this.color,
    required this.icon,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'color': color.toARGB32(),
        'icon': icon.codePoint,
      };

  factory ClipCategory.fromMap(Map<String, dynamic> map) => ClipCategory(
        id: map['id'] as String,
        name: map['name'] as String,
        color: Color(map['color'] as int),
        icon: IconData(map['icon'] as int, fontFamily: 'MaterialIcons'),
      );
}

class Clip {
  final String id;
  final String url;
  final String title;
  final String platform;
  final String? categoryId;
  final List<String> tags;
  final DateTime addedAt;
  final String? thumbnailUrl;

  const Clip({
    required this.id,
    required this.url,
    required this.title,
    required this.platform,
    this.categoryId,
    required this.tags,
    required this.addedAt,
    this.thumbnailUrl,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'url': url,
        'title': title,
        'platform': platform,
        'categoryId': categoryId,
        'tags': tags.join(','),
        'addedAt': addedAt.toIso8601String(),
        'thumbnailUrl': thumbnailUrl,
      };

  factory Clip.fromMap(Map<String, dynamic> map) => Clip(
        id: map['id'] as String,
        url: map['url'] as String,
        title: map['title'] as String,
        platform: map['platform'] as String,
        categoryId: map['categoryId'] as String?,
        tags: (map['tags'] as String? ?? '').isEmpty
            ? []
            : (map['tags'] as String)
                .split(',')
                .where((t) => t.isNotEmpty)
                .toList(),
        addedAt: DateTime.parse(map['addedAt'] as String),
        thumbnailUrl: map['thumbnailUrl'] as String?,
      );

  Clip copyWith({String? categoryId}) => Clip(
        id: id,
        url: url,
        title: title,
        platform: platform,
        categoryId: categoryId,
        tags: tags,
        addedAt: addedAt,
        thumbnailUrl: thumbnailUrl,
      );
}

// ─────────────────────────────────────────────
// DATABASE
// ─────────────────────────────────────────────

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._();
  static Database? _database;

  DatabaseHelper._();

  Future<Database> get database async {
    _database ??= await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    if (kIsWeb) {
      return openDatabase('clips.db',
          version: 2, onCreate: _onCreate, onUpgrade: _onUpgrade);
    }
    final dbPath = await getDatabasesPath();
    final fullPath = path_helper.join(dbPath, 'clips.db');
    return openDatabase(fullPath,
        version: 3, onCreate: _onCreate, onUpgrade: _onUpgrade);
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 3) {
      await db.delete('categories');
      await _seedDefaultCategories(db);
    }
  }

  Future<void> _seedDefaultCategories(Database db) async {
    for (final cat in _defaultCategories) {
      await db.insert('categories', cat.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace);
    }
  }

  static final List<ClipCategory> _defaultCategories = [
    const ClipCategory(
      id: 'default_recettes',
      name: 'Recettes',
      color: Color.fromRGBO(212, 133, 106, 1),
      icon: Icons.restaurant_rounded,
    ),
    const ClipCategory(
      id: 'default_yoga',
      name: 'Yoga',
      color: Color.fromRGBO(166, 211, 220, 1),
      icon: Icons.self_improvement_rounded,
    ),
    const ClipCategory(
      id: 'default_moto',
      name: 'Moto',
      color: Color.fromRGBO(253, 174, 84, 1),
      icon: Icons.two_wheeler_rounded,
    ),
    const ClipCategory(
      id: 'default_voyage',
      name: 'Voyage',
      color: Color.fromRGBO(148, 164, 255, 1),
      icon: Icons.flight_takeoff_rounded,
    ),
    const ClipCategory(
      id: 'default_musique',
      name: 'Musique',
      color: Color.fromRGBO(140, 200, 130, 1),
      icon: Icons.music_note_rounded,
    ),
    const ClipCategory(
      id: 'default_sport',
      name: 'Sport',
      color: Color.fromRGBO(220, 100, 100, 1),
      icon: Icons.fitness_center_rounded,
    ),
  ];

  /// Emoji affiché dans la grille pour chaque catégorie par défaut.
  static const Map<String, String> categoryEmojis = {
    'default_recettes': '🍳',
    'default_yoga': '🧘',
    'default_moto': '🏍️',
    'default_voyage': '✈️',
    'default_musique': '🎵',
    'default_sport': '💪',
  };

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE clips (
        id TEXT PRIMARY KEY,
        url TEXT NOT NULL,
        title TEXT NOT NULL,
        platform TEXT NOT NULL,
        categoryId TEXT,
        tags TEXT,
        addedAt TEXT NOT NULL,
        thumbnailUrl TEXT
      )
    ''');
    await db.execute('''
      CREATE TABLE categories (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        color INTEGER NOT NULL,
        icon INTEGER NOT NULL
      )
    ''');
    await _seedDefaultCategories(db);
  }

  Future<List<Clip>> getAllClips() async {
    final db = await database;
    final maps = await db.query('clips', orderBy: 'addedAt DESC');
    return maps.map(Clip.fromMap).toList();
  }

  Future<void> insertClip(Clip clip) async {
    final db = await database;
    await db.insert('clips', clip.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> deleteClip(String id) async {
    final db = await database;
    await db.delete('clips', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<ClipCategory>> getAllCategories() async {
    final db = await database;
    final maps = await db.query('categories');
    return maps.map(ClipCategory.fromMap).toList();
  }

  Future<void> insertCategory(ClipCategory category) async {
    final db = await database;
    await db.insert('categories', category.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> deleteCategory(String id) async {
    final db = await database;
    await db.delete('categories', where: 'id = ?', whereArgs: [id]);
    await db.update('clips', {'categoryId': null},
        where: 'categoryId = ?', whereArgs: [id]);
  }
}

// ─────────────────────────────────────────────
// OEMBED SERVICE
// ─────────────────────────────────────────────

class OEmbedService {
  static Future<Map<String, String?>> fetchMetadata(String url) async {
    try {
      final lower = url.toLowerCase();
      String? oembedUrl;
      if (lower.contains('youtube.com') || lower.contains('youtu.be')) {
        oembedUrl =
            'https://www.youtube.com/oembed?url=${Uri.encodeComponent(url)}&format=json';
      } else if (lower.contains('vimeo.com')) {
        oembedUrl =
            'https://vimeo.com/api/oembed.json?url=${Uri.encodeComponent(url)}';
      } else if (lower.contains('tiktok.com')) {
        oembedUrl =
            'https://www.tiktok.com/oembed?url=${Uri.encodeComponent(url)}';
      }
      if (oembedUrl != null) {
        final response = await http.get(Uri.parse(oembedUrl),
            headers: {'Accept': 'application/json'}).timeout(
          const Duration(seconds: 6),
        );
        if (response.statusCode == 200) {
          final data = json.decode(response.body) as Map<String, dynamic>;
          return {
            'title': data['title'] as String?,
            'thumbnailUrl': data['thumbnail_url'] as String?,
          };
        }
      }
    } catch (_) {}
    return {'title': null, 'thumbnailUrl': null};
  }
}

// ─────────────────────────────────────────────
// CATEGORY CLASSIFIER (keyword-based "AI")
// ─────────────────────────────────────────────

class CategoryClassifier {
  /// Maps default category IDs to keyword lists (FR + EN).
  static const Map<String, List<String>> _keywords = {
    'default_recettes': [
      'recette', 'recettes', 'recipe', 'recipes',
      'cuisine', 'cuisiner', 'cooking', 'cook',
      'food', 'meal', 'dish', 'chef', 'baking', 'bake',
      'pâtisserie', 'patisserie', 'dessert', 'gâteau', 'gateau',
      'pasta', 'pizza', 'soup', 'soupe', 'salade', 'salad',
      'breakfast', 'lunch', 'dinner', 'snack', 'apéro', 'apero',
    ],
    'default_yoga': [
      'yoga', 'méditation', 'meditation', 'meditate',
      'mindfulness', 'breathwork', 'pranayama',
      'asana', 'vinyasa', 'hatha', 'ashtanga',
      'relaxation', 'détente', 'detente', 'zen',
      'stretching', 'étirement', 'etirement',
    ],
    'default_moto': [
      'moto', 'motorcycle', 'motorbike', 'biker',
      'harley', 'ducati', 'yamaha', 'kawasaki', 'honda cb',
      'bmw motorrad', 'ktm', 'triumph',
      'roadtrip moto', 'wheelie', 'stunt',
      'mt-07', 'mt-09', 'r1', 'gsxr',
    ],
    'default_voyage': [
      'voyage', 'travel', 'trip', 'tour',
      'destination', 'vacation', 'vacances', 'holiday',
      'roadtrip', 'road trip', 'backpack', 'backpacking',
      'paris', 'bali', 'japan', 'thailand', 'thaïlande', 'thailande',
      'island', 'beach', 'plage', 'mountain', 'montagne',
      'flight', 'avion', 'hotel', 'hôtel',
      'aventure', 'adventure', 'explore',
    ],
    'default_musique': [
      'music', 'musique', 'song', 'chanson', 'lyrics', 'paroles',
      'album', 'concert', 'live', 'guitar', 'guitare',
      'piano', 'drum', 'batterie', 'bass', 'basse',
      'remix', 'cover', 'acoustic', 'acoustique',
      'rap', 'hip-hop', 'hip hop', 'rock', 'pop', 'jazz',
      'edm', 'techno', 'house', 'electro', 'dj',
      'official video', 'clip officiel', 'mv',
    ],
    'default_sport': [
      'sport', 'fitness', 'workout', 'entraînement', 'entrainement',
      'gym', 'muscu', 'musculation', 'bodybuilding',
      'cardio', 'hiit', 'crossfit',
      'running', 'course', 'marathon', 'jog',
      'football', 'soccer', 'basketball', 'tennis',
      'rugby', 'cyclisme', 'cycling', 'vélo', 'velo',
      'natation', 'swim', 'swimming',
      'abs', 'biceps', 'squat', 'pushup',
    ],
  };

  /// Returns the best matching category ID from [categories] given [title],
  /// or `null` if no keyword matches.
  static String? suggest(String title, List<ClipCategory> categories) {
    if (title.trim().isEmpty) return null;
    final lower = title.toLowerCase();
    final scores = <String, int>{};
    for (final entry in _keywords.entries) {
      int s = 0;
      for (final kw in entry.value) {
        if (lower.contains(kw)) s++;
      }
      if (s > 0) scores[entry.key] = s;
    }
    if (scores.isEmpty) return null;
    final best =
        scores.entries.reduce((a, b) => a.value >= b.value ? a : b).key;
    // Only return if that category actually exists in user's list.
    final exists = categories.any((c) => c.id == best);
    return exists ? best : null;
  }
}

// ─────────────────────────────────────────────
// APP STATE
// ─────────────────────────────────────────────

class ClipsState extends ChangeNotifier {
  List<Clip> _clips = [];
  List<ClipCategory> _categories = [];
  String _searchQuery = '';
  String? _selectedCategoryId;
  bool _isLoading = false;

  bool get isLoading => _isLoading;
  String get searchQuery => _searchQuery;
  String? get selectedCategoryId => _selectedCategoryId;
  List<ClipCategory> get categories => _categories;

  List<Clip> get clips {
    var result = _clips;
    if (_selectedCategoryId != null) {
      result =
          result.where((c) => c.categoryId == _selectedCategoryId).toList();
    }
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      result = result
          .where((c) =>
              c.title.toLowerCase().contains(q) ||
              c.url.toLowerCase().contains(q) ||
              c.tags.any((t) => t.toLowerCase().contains(q)))
          .toList();
    }
    return result;
  }

  List<String> get searchSuggestions {
    if (_searchQuery.isEmpty) return [];
    final q = _searchQuery.toLowerCase();
    final set = <String>{};
    for (final c in _clips) {
      if (c.title.toLowerCase().contains(q)) set.add(c.title);
      for (final t in c.tags) {
        if (t.toLowerCase().contains(q)) set.add('#$t');
      }
    }
    return set.take(5).toList();
  }

  Future<void> loadAll() async {
    _isLoading = true;
    notifyListeners();
    _clips = await DatabaseHelper.instance.getAllClips();
    _categories = await DatabaseHelper.instance.getAllCategories();
    _isLoading = false;
    notifyListeners();
  }

  void setSearch(String query) {
    _searchQuery = query;
    notifyListeners();
  }

  void setCategory(String? id) {
    _selectedCategoryId = id;
    notifyListeners();
  }

  Future<void> addClip(Clip clip) async {
    await DatabaseHelper.instance.insertClip(clip);
    _clips.insert(0, clip);
    notifyListeners();
  }

  Future<void> removeClip(String id) async {
    await DatabaseHelper.instance.deleteClip(id);
    _clips.removeWhere((c) => c.id == id);
    notifyListeners();
  }

  Future<void> addCategory(ClipCategory category) async {
    await DatabaseHelper.instance.insertCategory(category);
    _categories.add(category);
    notifyListeners();
  }

  Future<void> removeCategory(String id) async {
    await DatabaseHelper.instance.deleteCategory(id);
    _categories.removeWhere((c) => c.id == id);
    _clips = _clips
        .map((c) => c.categoryId == id ? c.copyWith(categoryId: null) : c)
        .toList();
    notifyListeners();
  }

  ClipCategory? categoryById(String? id) {
    if (id == null) return null;
    try {
      return _categories.firstWhere((c) => c.id == id);
    } catch (_) {
      return null;
    }
  }

  List<Clip> get allClips => List.unmodifiable(_clips);

  int countForCategory(String? categoryId) =>
      _clips.where((c) => c.categoryId == categoryId).length;

  int get totalCount => _clips.length;

  List<Clip> clipsForCategory(String? categoryId) =>
      _clips.where((c) => c.categoryId == categoryId).toList();
}

// ─────────────────────────────────────────────
// LOCALIZATION
// ─────────────────────────────────────────────

class AppL10n {
  final Locale locale;
  AppL10n(this.locale);

  static AppL10n of(BuildContext context) =>
      Localizations.of<AppL10n>(context, AppL10n)!;

  static const LocalizationsDelegate<AppL10n> delegate = _AppL10nDelegate();

  static const Map<String, Map<String, String>> _strings = {
    'fr': {
      'app_name': 'Clips',
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
    },
    'en': {
      'app_name': 'Clips',
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

// ─────────────────────────────────────────────
// THEME
// ─────────────────────────────────────────────

class AppTheme {
  // Palette principale (reprise de l'app jumelle)
  static const Color orange = Color(0xFFFDAE54);
  static const Color darkGreen = Color(0xFF153036);
  static const Color shadowGrey = Color(0xFF597176);

  static ThemeData light() => ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        scaffoldBackgroundColor: Colors.white,
        colorScheme: ColorScheme.fromSeed(
          seedColor: orange,
          brightness: Brightness.light,
          primary: orange,
          secondary: darkGreen,
          surface: Colors.white,
        ),
        textTheme: const TextTheme().apply(
          bodyColor: darkGreen,
          displayColor: darkGreen,
        ),
      );

  static ThemeData dark() => ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: darkGreen,
        colorScheme: ColorScheme.fromSeed(
          seedColor: orange,
          brightness: Brightness.dark,
          primary: orange,
          secondary: orange,
          surface: darkGreen,
        ),
      );
}

// ─────────────────────────────────────────────
// GLASS CARD
// ─────────────────────────────────────────────

class GlassCard extends StatelessWidget {
  final Widget child;
  final double borderRadius;
  final EdgeInsetsGeometry? padding;
  final VoidCallback? onTap;
  final double blur;

  const GlassCard({
    super.key,
    required this.child,
    this.borderRadius = 20,
    this.padding,
    this.onTap,
    this.blur = 10,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: isDark
                    ? [
                        Colors.white.withValues(alpha: 0.08),
                        AppTheme.orange.withValues(alpha: 0.12),
                      ]
                    : [
                        Colors.white.withValues(alpha: 0.92),
                        AppTheme.orange.withValues(alpha: 0.15),
                      ],
              ),
              borderRadius: BorderRadius.circular(borderRadius),
              border: Border.all(
                color: AppTheme.orange.withValues(alpha: 0.3),
                width: 1.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.shadowGrey.withValues(alpha: 0.15),
                  blurRadius: 32,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            padding: padding ?? const EdgeInsets.all(16),
            child: child,
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// MAIN
// ─────────────────────────────────────────────

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (kIsWeb) {
    databaseFactory = databaseFactoryFfiWeb;
  }
  final state = ClipsState();
  try {
    await state.loadAll();
  } catch (e, st) {
    debugPrint('DB init error: $e\n$st');
  }
  runApp(ClipsApp(state: state));
}

// ─────────────────────────────────────────────
// APP ROOT
// ─────────────────────────────────────────────

class ClipsApp extends StatefulWidget {
  final ClipsState state;

  const ClipsApp({super.key, required this.state});

  static _ClipsAppState? of(BuildContext context) =>
      context.findAncestorStateOfType<_ClipsAppState>();

  @override
  State<ClipsApp> createState() => _ClipsAppState();
}

class _ClipsAppState extends State<ClipsApp> {
  ThemeMode _themeMode = ThemeMode.system;
  Locale _locale = const Locale('fr');
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();
  StreamSubscription<List<SharedMediaFile>>? _shareSub;

  ThemeMode get themeMode => _themeMode;
  Locale get locale => _locale;

  void setThemeMode(ThemeMode mode) => setState(() => _themeMode = mode);
  void setLocale(Locale locale) => setState(() => _locale = locale);

  @override
  void initState() {
    super.initState();
    _initShareIntent();
  }

  void _initShareIntent() {
    if (kIsWeb) return;
    try {
      // Cold start (app opened via share)
      ReceiveSharingIntent.instance.getInitialMedia().then((files) {
        _handleSharedFiles(files);
        ReceiveSharingIntent.instance.reset();
      });
      // Warm shares (app already running)
      _shareSub =
          ReceiveSharingIntent.instance.getMediaStream().listen((files) {
        _handleSharedFiles(files);
      });
    } catch (e) {
      debugPrint('Share intent unsupported on this platform: $e');
    }
  }

  void _handleSharedFiles(List<SharedMediaFile> files) {
    if (files.isEmpty) return;
    // Look for the first text/URL among shared items.
    String? url;
    for (final f in files) {
      final v = f.path.trim();
      if (v.startsWith('http')) {
        url = v;
        break;
      }
    }
    if (url == null) return;
    // Wait for the navigator to be mounted, then open the sheet.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctx = _navigatorKey.currentContext;
      if (ctx == null) return;
      showModalBottomSheet(
        context: ctx,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) =>
            AddClipSheet(state: widget.state, initialUrl: url),
      );
    });
  }

  @override
  void dispose() {
    _shareSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.state,
      builder: (context, _) => MaterialApp(
        title: 'Clips',
        debugShowCheckedModeBanner: false,
        navigatorKey: _navigatorKey,
        theme: AppTheme.light(),
        darkTheme: AppTheme.dark(),
        themeMode: _themeMode,
        locale: _locale,
        supportedLocales: const [Locale('fr'), Locale('en')],
        localizationsDelegates: const [
          AppL10n.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: MainShell(state: widget.state),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// MAIN SHELL — Navigation
// ─────────────────────────────────────────────

class MainShell extends StatefulWidget {
  final ClipsState state;

  const MainShell({super.key, required this.state});

  static void switchTab(BuildContext context, int index) {
    final state = context.findAncestorStateOfType<_MainShellState>();
    state?.setIndex(index);
  }

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _index = 0;

  void setIndex(int i) => setState(() => _index = i);

  @override
  Widget build(BuildContext context) {
    final l = AppL10n.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF08081A) : const Color(0xFFF0EFFF);

    return Scaffold(
      backgroundColor: bg,
      extendBody: true,
      body: Stack(
        children: [
          _GradientBackground(isDark: isDark),
          IndexedStack(
            index: _index,
            children: [
              HomeScreen(state: widget.state),
              CategoriesScreen(state: widget.state),
              const SettingsScreen(),
            ],
          ),
        ],
      ),
      floatingActionButton: _index == 0
          ? FloatingActionButton.extended(
              onPressed: () => _openAddSheet(context),
              icon: const Icon(Icons.add_rounded),
              label: Text(l.t('add_clip')),
              elevation: 2,
            )
          : null,
      bottomNavigationBar: _buildNavBar(l, isDark),
    );
  }

  Widget _buildNavBar(AppL10n l, bool isDark) {
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: isDark
                  ? [
                      AppTheme.darkGreen.withValues(alpha: 0.9),
                      AppTheme.orange.withValues(alpha: 0.15),
                    ]
                  : [
                      Colors.white.withValues(alpha: 0.92),
                      AppTheme.orange.withValues(alpha: 0.15),
                    ],
            ),
            border: Border(
              top: BorderSide(
                color: AppTheme.orange.withValues(alpha: 0.3),
                width: 1,
              ),
            ),
            boxShadow: [
              BoxShadow(
                color: AppTheme.shadowGrey.withValues(alpha: 0.15),
                blurRadius: 32,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          child: NavigationBarTheme(
            data: NavigationBarThemeData(
              indicatorColor: AppTheme.orange.withValues(alpha: 0.25),
              labelTextStyle: WidgetStatePropertyAll(
                TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white : AppTheme.darkGreen,
                ),
              ),
              iconTheme: WidgetStateProperty.resolveWith((states) {
                final selected = states.contains(WidgetState.selected);
                return IconThemeData(
                  color: selected
                      ? AppTheme.orange
                      : (isDark
                          ? Colors.white.withValues(alpha: 0.7)
                          : AppTheme.darkGreen.withValues(alpha: 0.6)),
                );
              }),
            ),
            child: NavigationBar(
              selectedIndex: _index,
              onDestinationSelected: (i) => setState(() => _index = i),
              backgroundColor: Colors.transparent,
              elevation: 0,
              destinations: [
                NavigationDestination(
                  icon: const Icon(Icons.home_outlined),
                  selectedIcon: const Icon(Icons.home_rounded),
                  label: l.t('home'),
                ),
                NavigationDestination(
                  icon: const Icon(Icons.folder_outlined),
                  selectedIcon: const Icon(Icons.folder_rounded),
                  label: l.t('categories'),
                ),
                NavigationDestination(
                  icon: const Icon(Icons.settings_outlined),
                  selectedIcon: const Icon(Icons.settings_rounded),
                  label: l.t('settings'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _openAddSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AddClipSheet(state: widget.state),
    );
  }
}

class _GradientBackground extends StatelessWidget {
  final bool isDark;

  const _GradientBackground({required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isDark
                ? const [
                    Color(0xFF0E1F23),
                    Color(0xFF153036),
                    Color(0xFF1F4248),
                  ]
                : const [
                    Colors.white,
                    Color(0xFFFFF6EC),
                    Colors.white,
                  ],
          ),
        ),
        child: Stack(
          children: [
            Positioned(
              top: -120,
              right: -80,
              child: _Orb(
                size: 360,
                color: AppTheme.orange
                    .withValues(alpha: isDark ? 0.28 : 0.35),
              ),
            ),
            Positioned(
              top: 220,
              left: -120,
              child: _Orb(
                size: 300,
                color: AppTheme.orange
                    .withValues(alpha: isDark ? 0.18 : 0.22),
              ),
            ),
            Positioned(
              bottom: 40,
              right: -60,
              child: _Orb(
                size: 280,
                color: AppTheme.darkGreen
                    .withValues(alpha: isDark ? 0.4 : 0.08),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Orb extends StatelessWidget {
  final double size;
  final Color color;

  const _Orb({required this.size, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(colors: [color, Colors.transparent]),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// HOME SCREEN
// ─────────────────────────────────────────────

class HomeScreen extends StatefulWidget {
  final ClipsState state;

  const HomeScreen({super.key, required this.state});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppL10n.of(context);

    return ListenableBuilder(
      listenable: widget.state,
      builder: (context, _) {
        final searching = widget.state.searchQuery.isNotEmpty;
        final suggestions = widget.state.searchSuggestions;
        final filtered = widget.state.clips;

        return CustomScrollView(
          slivers: [
            _buildAppBar(l, widget.state.allClips),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: Column(
                  children: [
                    _SearchBar(
                      controller: _searchCtrl,
                      hint: l.t('search'),
                      onChanged: widget.state.setSearch,
                    ),
                    if (searching && suggestions.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      _SuggestionsList(
                        suggestions: suggestions,
                        onTap: (s) {
                          _searchCtrl.text =
                              s.startsWith('#') ? s.substring(1) : s;
                          widget.state.setSearch(_searchCtrl.text);
                        },
                      ),
                    ],
                  ],
                ),
              ),
            ),
            if (widget.state.isLoading)
              const SliverFillRemaining(
                child: Center(child: CircularProgressIndicator()),
              )
            else if (searching)
              filtered.isEmpty
                  ? SliverFillRemaining(child: _EmptyState(l: l))
                  : SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 140),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (ctx, i) => Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: ClipCard(
                                clip: filtered[i], state: widget.state),
                          ),
                          childCount: filtered.length,
                        ),
                      ),
                    )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 140),
                sliver: SliverGrid(
                  gridDelegate:
                      const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    mainAxisSpacing: 14,
                    crossAxisSpacing: 14,
                    childAspectRatio: 1, // carré parfait
                  ),
                  delegate: SliverChildBuilderDelegate(
                    (ctx, i) {
                      if (i == 0) {
                        return _CategoryTile(
                          name: l.t('all'),
                          color: AppTheme.orange,
                          emoji: '📱',
                          count: widget.state.totalCount,
                          onTap: () =>
                              _openCategory(context, null, l.t('all')),
                        );
                      }
                      if (i == widget.state.categories.length + 1) {
                        return _CategoryTile.add(
                          label: l.t('add'),
                          onTap: () {
                            // Aller à l'onglet « Catégories » pour en créer une
                            MainShell.switchTab(context, 1);
                          },
                        );
                      }
                      final cat = widget.state.categories[i - 1];
                      return _CategoryTile(
                        name: cat.name,
                        color: cat.color,
                        emoji: DatabaseHelper.categoryEmojis[cat.id],
                        icon: cat.icon,
                        count: widget.state.countForCategory(cat.id),
                        onTap: () =>
                            _openCategory(context, cat.id, cat.name),
                      );
                    },
                    childCount: widget.state.categories.length + 2,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  void _openCategory(BuildContext context, String? categoryId, String name) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => CategoryDetailScreen(
        state: widget.state,
        categoryId: categoryId,
        title: name,
      ),
    ));
  }

  SliverAppBar _buildAppBar(AppL10n l, List<Clip> clips) {
    return SliverAppBar(
      floating: true,
      snap: true,
      backgroundColor: Colors.transparent,
      elevation: 0,
      expandedHeight: 110,
      flexibleSpace: FlexibleSpaceBar(
        titlePadding: const EdgeInsets.only(left: 20, bottom: 16),
        title: Text(
          l.t('app_name'),
          style: const TextStyle(
            fontWeight: FontWeight.w900,
            fontSize: 30,
            letterSpacing: -1,
          ),
        ),
      ),
      actions: [
        if (clips.isNotEmpty)
          IconButton(
            icon: const Icon(Icons.ios_share_rounded),
            tooltip: l.t('share_list'),
            onPressed: () {
              final text =
                  clips.map((c) => '${c.title}\n${c.url}').join('\n\n');
              Share.share(text);
            },
          ),
          const SizedBox(width: 8),
      ],
    );
  }
}

// ─────────────────────────────────────────────
// CATEGORY TILE (iOS-style big rounded square)
// ─────────────────────────────────────────────

class _CategoryTile extends StatefulWidget {
  final String name;
  final Color color;
  final IconData? icon;
  final String? emoji;
  final int count;
  final VoidCallback onTap;
  final bool isAdd;

  const _CategoryTile({
    required this.name,
    required this.color,
    required this.count,
    required this.onTap,
    this.icon,
    this.emoji,
    this.isAdd = false,
  });

  factory _CategoryTile.add({
    required String label,
    required VoidCallback onTap,
  }) =>
      _CategoryTile(
        name: label,
        color: AppTheme.orange,
        emoji: '➕',
        count: 0,
        onTap: onTap,
        isAdd: true,
      );

  @override
  State<_CategoryTile> createState() => _CategoryTileState();
}

class _CategoryTileState extends State<_CategoryTile> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final tintColor = widget.color;

    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
          transform: Matrix4.identity()
            ..translate(0.0, _hover ? -4.0 : 0.0)
            ..scale(_hover ? 1.03 : 1.0),
          transformAlignment: Alignment.center,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(22),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
              child: Stack(
                children: [
                  // Fond glass : gradient blanc → teinte couleur catégorie
                  Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(22),
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: isDark
                            ? [
                                Colors.white.withValues(alpha: 0.10),
                                tintColor.withValues(alpha: 0.22),
                              ]
                            : [
                                Colors.white.withValues(alpha: 0.92),
                                tintColor.withValues(alpha: 0.18),
                              ],
                      ),
                      border: Border.all(
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.25)
                            : Colors.white.withValues(alpha: 0.55),
                        width: 2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.shadowGrey
                              .withValues(alpha: _hover ? 0.22 : 0.14),
                          blurRadius: _hover ? 36 : 28,
                          offset: Offset(0, _hover ? 12 : 8),
                        ),
                      ],
                    ),
                  ),
                  // Reflet interne (RadialGradient) en haut à gauche
                  Positioned.fill(
                    child: IgnorePointer(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(22),
                          gradient: RadialGradient(
                            center: const Alignment(-0.7, -0.8),
                            radius: 0.9,
                            colors: [
                              Colors.white.withValues(alpha: 0.55),
                              Colors.white.withValues(alpha: 0.0),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  // Contenu : emoji + label
                  Padding(
                    padding: const EdgeInsets.all(10),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Spacer(),
                        // Icône emoji 38px avec drop-shadow
                        Text(
                          widget.emoji ?? '📁',
                          style: TextStyle(
                            fontSize: 38,
                            height: 1,
                            shadows: [
                              Shadow(
                                color: AppTheme.shadowGrey
                                    .withValues(alpha: 0.35),
                                blurRadius: 6,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                        // Label 13px / w900 / UPPERCASE / #153036
                        Text(
                          widget.name.toUpperCase(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 13,
                            letterSpacing: 0.4,
                            color: isDark
                                ? Colors.white
                                : AppTheme.darkGreen,
                          ),
                        ),
                        if (!widget.isAdd) ...[
                          const SizedBox(height: 2),
                          Text(
                            '${widget.count}',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: isDark
                                  ? Colors.white.withValues(alpha: 0.55)
                                  : AppTheme.darkGreen
                                      .withValues(alpha: 0.5),
                            ),
                          ),
                        ],
                        const Spacer(),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// CATEGORY DETAIL SCREEN
// ─────────────────────────────────────────────

class CategoryDetailScreen extends StatelessWidget {
  final ClipsState state;
  final String? categoryId;
  final String title;

  const CategoryDetailScreen({
    super.key,
    required this.state,
    required this.categoryId,
    required this.title,
  });

  @override
  Widget build(BuildContext context) {
    final l = AppL10n.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
          _GradientBackground(isDark: isDark),
          ListenableBuilder(
            listenable: state,
            builder: (context, _) {
              final clips = categoryId == null
                  ? state.allClips
                  : state.clipsForCategory(categoryId);
              return CustomScrollView(
                slivers: [
                  SliverAppBar(
                    floating: true,
                    backgroundColor: Colors.transparent,
                    elevation: 0,
                    leading: IconButton(
                      icon: const Icon(Icons.arrow_back_ios_new_rounded),
                      onPressed: () => Navigator.pop(context),
                    ),
                    title: Text(
                      title,
                      style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 22,
                          letterSpacing: -0.5),
                    ),
                    actions: [
                      if (clips.isNotEmpty)
                        IconButton(
                          icon: const Icon(Icons.ios_share_rounded),
                          onPressed: () {
                            final text = clips
                                .map((c) => '${c.title}\n${c.url}')
                                .join('\n\n');
                            Share.share(text);
                          },
                        ),
                      const SizedBox(width: 8),
                    ],
                  ),
                  if (clips.isEmpty)
                    SliverFillRemaining(child: _EmptyState(l: l))
                  else
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (ctx, i) => Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child:
                                ClipCard(clip: clips[i], state: state),
                          ),
                          childCount: clips.length,
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _SearchBar extends StatefulWidget {
  final TextEditingController controller;
  final String hint;
  final ValueChanged<String> onChanged;

  const _SearchBar({
    required this.controller,
    required this.hint,
    required this.onChanged,
  });

  @override
  State<_SearchBar> createState() => _SearchBarState();
}

class _SearchBarState extends State<_SearchBar> {
  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
      blur: 16,
      child: TextField(
        controller: widget.controller,
        onChanged: (v) {
          widget.onChanged(v);
          setState(() {});
        },
        decoration: InputDecoration(
          hintText: widget.hint,
          border: InputBorder.none,
          icon: const Icon(Icons.search_rounded),
          suffixIcon: widget.controller.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear_rounded),
                  onPressed: () {
                    widget.controller.clear();
                    widget.onChanged('');
                    setState(() {});
                  },
                )
              : null,
        ),
      ),
    );
  }
}

class _SuggestionsList extends StatelessWidget {
  final List<String> suggestions;
  final ValueChanged<String> onTap;

  const _SuggestionsList({required this.suggestions, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        children: suggestions
            .map((s) => InkWell(
                  onTap: () => onTap(s),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    child: Row(
                      children: [
                        Icon(
                          s.startsWith('#')
                              ? Icons.tag_rounded
                              : Icons.history_rounded,
                          size: 16,
                          color: Colors.grey,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                            child: Text(s,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis)),
                      ],
                    ),
                  ),
                ))
            .toList(),
      ),
    );
  }
}

class _CategoryFilter extends StatelessWidget {
  final ClipsState state;
  final AppL10n l;

  const _CategoryFilter({required this.state, required this.l});

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return SizedBox(
      height: 38,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          _Chip(
            label: l.t('all'),
            color: primary,
            selected: state.selectedCategoryId == null,
            onTap: () => state.setCategory(null),
          ),
          ...state.categories.map((cat) => Padding(
                padding: const EdgeInsets.only(left: 8),
                child: _Chip(
                  label: cat.name,
                  color: cat.color,
                  selected: state.selectedCategoryId == cat.id,
                  onTap: () => state.setCategory(cat.id),
                ),
              )),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  const _Chip({
    required this.label,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? color : color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withValues(alpha: 0.4)),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : color,
            fontWeight: FontWeight.w600,
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final AppL10n l;

  const _EmptyState({required this.l});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.videocam_off_rounded,
            size: 72,
            color: Colors.grey.withValues(alpha: 0.35),
          ),
          const SizedBox(height: 16),
          Text(
            l.t('no_clips'),
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 48),
            child: Text(
              l.t('no_clips_sub'),
              style: TextStyle(
                color: Colors.grey.withValues(alpha: 0.7),
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// CLIP CARD
// ─────────────────────────────────────────────

class ClipCard extends StatelessWidget {
  final Clip clip;
  final ClipsState state;

  const ClipCard({super.key, required this.clip, required this.state});

  @override
  Widget build(BuildContext context) {
    final l = AppL10n.of(context);
    final platform = SocialPlatform.detect(clip.url);
    final category = state.categoryById(clip.categoryId);
    final lang = Localizations.localeOf(context).languageCode;

    return GlassCard(
      padding: EdgeInsets.zero,
      onTap: () => _openUrl(clip.url),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: platform.color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(platform.icon, color: platform.color, size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        clip.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                          height: 1.3,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Row(
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                              color: platform.color,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 5),
                          Text(
                            platform.name,
                            style: TextStyle(
                              color: platform.color,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            DateFormat.yMMMd(lang).format(clip.addedAt),
                            style: TextStyle(
                              color: Colors.grey.withValues(alpha: 0.65),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  icon: Icon(
                    Icons.more_vert_rounded,
                    color: Colors.grey.withValues(alpha: 0.7),
                    size: 20,
                  ),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                  itemBuilder: (_) => [
                    PopupMenuItem(
                        value: 'share',
                        child: _MenuItem(
                            icon: Icons.share_rounded, label: l.t('share'))),
                    PopupMenuItem(
                        value: 'open',
                        child: _MenuItem(
                            icon: Icons.open_in_new_rounded,
                            label: l.t('open'))),
                    PopupMenuItem(
                        value: 'delete',
                        child: _MenuItem(
                            icon: Icons.delete_rounded,
                            label: l.t('delete'),
                            danger: true)),
                  ],
                  onSelected: (v) => _handleAction(context, v, l),
                ),
              ],
            ),
          ),
          if (clip.tags.isNotEmpty || category != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
              child: Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  if (category != null)
                    _Badge(
                      label: category.name,
                      color: category.color,
                      icon: category.icon,
                    ),
                  ...clip.tags.map((t) => _Badge(
                        label: '#$t',
                        color: Theme.of(context).colorScheme.primary,
                      )),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _openUrl(String url) async {
    final uri = Uri.tryParse(url);
    if (uri != null && await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  void _handleAction(BuildContext context, String action, AppL10n l) {
    switch (action) {
      case 'share':
        Share.share('${clip.title}\n${clip.url}');
      case 'open':
        _openUrl(clip.url);
      case 'delete':
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20)),
            title: Text(l.t('confirm_delete')),
            content: Text(l.t('confirm_delete_sub')),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text(l.t('cancel')),
              ),
              TextButton(
                style: TextButton.styleFrom(foregroundColor: Colors.red),
                onPressed: () {
                  state.removeClip(clip.id);
                  Navigator.pop(ctx);
                },
                child: Text(l.t('delete')),
              ),
            ],
          ),
        );
    }
  }
}

class _MenuItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool danger;

  const _MenuItem(
      {required this.icon, required this.label, this.danger = false});

  @override
  Widget build(BuildContext context) {
    final color = danger ? Colors.red : null;
    return Row(
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 10),
        Text(label, style: TextStyle(color: color)),
      ],
    );
  }
}

class _Badge extends StatelessWidget {
  final String label;
  final Color color;
  final IconData? icon;

  const _Badge({required this.label, required this.color, this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: color),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// ADD CLIP SHEET
// ─────────────────────────────────────────────

class AddClipSheet extends StatefulWidget {
  final ClipsState state;
  final String? initialUrl;

  const AddClipSheet({super.key, required this.state, this.initialUrl});

  @override
  State<AddClipSheet> createState() => _AddClipSheetState();
}

class _AddClipSheetState extends State<AddClipSheet> {
  final _urlCtrl = TextEditingController();
  final _titleCtrl = TextEditingController();
  final _tagsCtrl = TextEditingController();
  String? _selectedCategoryId;
  SocialPlatform? _detectedPlatform;
  bool _isFetchingTitle = false;
  String? _thumbnailUrl;
  bool _wasAutoSuggested = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialUrl != null && widget.initialUrl!.isNotEmpty) {
      _urlCtrl.text = widget.initialUrl!;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _onUrlChanged(widget.initialUrl!);
      });
    } else {
      _tryPaste();
    }
  }

  Future<void> _tryPaste() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (!mounted) return;
    final text = data?.text?.trim() ?? '';
    if (text.startsWith('http')) {
      _urlCtrl.text = text;
      _onUrlChanged(text);
    }
  }

  Future<void> _onUrlChanged(String url) async {
    if (!url.startsWith('http')) return;
    final platform = SocialPlatform.detect(url);
    setState(() {
      _detectedPlatform = platform;
      _isFetchingTitle = true;
    });
    final meta = await OEmbedService.fetchMetadata(url);
    if (!mounted) return;
    final fetchedTitle = meta['title'] ?? '';
    setState(() {
      _isFetchingTitle = false;
      _thumbnailUrl = meta['thumbnailUrl'];
      if (fetchedTitle.isNotEmpty && _titleCtrl.text.isEmpty) {
        _titleCtrl.text = fetchedTitle;
      }
      // 🤖 Auto-suggest a category from the fetched title (only if the user
      // hasn't already picked one manually).
      if (_selectedCategoryId == null && fetchedTitle.isNotEmpty) {
        final suggested = CategoryClassifier.suggest(
            fetchedTitle, widget.state.categories);
        if (suggested != null) {
          _selectedCategoryId = suggested;
          _wasAutoSuggested = true;
        }
      }
    });
  }

  Future<void> _submit() async {
    final url = _urlCtrl.text.trim();
    if (url.isEmpty) return;
    final l = AppL10n.of(context);
    final tags = _tagsCtrl.text.trim().isEmpty
        ? <String>[]
        : _tagsCtrl.text
            .split(',')
            .map((t) => t.trim())
            .where((t) => t.isNotEmpty)
            .toList();
    final clip = Clip(
      id: const Uuid().v4(),
      url: url,
      title: _titleCtrl.text.trim().isEmpty
          ? l.t('no_title')
          : _titleCtrl.text.trim(),
      platform: SocialPlatform.detect(url).id,
      categoryId: _selectedCategoryId,
      tags: tags,
      addedAt: DateTime.now(),
      thumbnailUrl: _thumbnailUrl,
    );
    await widget.state.addClip(clip);
    if (mounted) Navigator.pop(context);
  }

  @override
  void dispose() {
    _urlCtrl.dispose();
    _titleCtrl.dispose();
    _tagsCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppL10n.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final scheme = Theme.of(context).colorScheme;

    return Padding(
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
          child: Container(
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.black.withValues(alpha: 0.72)
                  : Colors.white.withValues(alpha: 0.88),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(28)),
              border: Border(
                top: BorderSide(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.1)
                      : Colors.black.withValues(alpha: 0.06),
                ),
              ),
            ),
            child: SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        margin: const EdgeInsets.only(bottom: 20),
                        decoration: BoxDecoration(
                          color: Colors.grey.withValues(alpha: 0.4),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    Text(
                      l.t('add_clip'),
                      style: const TextStyle(
                          fontSize: 22, fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 20),
                    _SheetField(
                      controller: _urlCtrl,
                      hint: l.t('paste_url'),
                      icon: Icons.link_rounded,
                      isDark: isDark,
                      onChanged: _onUrlChanged,
                      prefixWidget: _detectedPlatform != null
                          ? Container(
                              margin: const EdgeInsets.only(right: 8),
                              padding: const EdgeInsets.all(5),
                              decoration: BoxDecoration(
                                color: _detectedPlatform!.color
                                    .withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(_detectedPlatform!.icon,
                                  color: _detectedPlatform!.color, size: 18),
                            )
                          : null,
                    ),
                    const SizedBox(height: 10),
                    Stack(
                      children: [
                        _SheetField(
                          controller: _titleCtrl,
                          hint: l.t('title'),
                          icon: Icons.title_rounded,
                          isDark: isDark,
                        ),
                        if (_isFetchingTitle)
                          Positioned(
                            right: 14,
                            top: 14,
                            child: SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: scheme.primary),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    _SheetField(
                      controller: _tagsCtrl,
                      hint: l.t('tags'),
                      icon: Icons.tag_rounded,
                      isDark: isDark,
                    ),
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        Text(l.t('category'),
                            style: const TextStyle(
                                fontWeight: FontWeight.w600, fontSize: 14)),
                        if (_wasAutoSuggested) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(colors: [
                                Color(0xFF6C63FF),
                                Color(0xFFFF6EC7),
                              ]),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.auto_awesome_rounded,
                                    size: 12, color: Colors.white),
                                SizedBox(width: 4),
                                Text('IA',
                                    style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 10,
                                        fontWeight: FontWeight.w700)),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 10),
                    _CategoryPicker(
                      categories: widget.state.categories,
                      selected: _selectedCategoryId,
                      l: l,
                      onChanged: (id) => setState(() {
                        _selectedCategoryId = id;
                        _wasAutoSuggested = false;
                      }),
                    ),
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.pop(context),
                            style: OutlinedButton.styleFrom(
                              padding:
                                  const EdgeInsets.symmetric(vertical: 15),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14)),
                            ),
                            child: Text(l.t('cancel')),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 2,
                          child: FilledButton(
                            onPressed: _submit,
                            style: FilledButton.styleFrom(
                              padding:
                                  const EdgeInsets.symmetric(vertical: 15),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14)),
                            ),
                            child: Text(l.t('add')),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SheetField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final IconData icon;
  final bool isDark;
  final ValueChanged<String>? onChanged;
  final Widget? prefixWidget;

  const _SheetField({
    required this.controller,
    required this.hint,
    required this.icon,
    required this.isDark,
    this.onChanged,
    this.prefixWidget,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.07)
            : Colors.black.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.1)
              : Colors.black.withValues(alpha: 0.08),
        ),
      ),
      child: Row(
        children: [
          if (prefixWidget != null) ...[
            const SizedBox(width: 12),
            prefixWidget!,
          ] else
            Padding(
              padding: const EdgeInsets.only(left: 14),
              child: Icon(icon, size: 20, color: Colors.grey),
            ),
          Expanded(
            child: TextField(
              controller: controller,
              onChanged: onChanged,
              decoration: InputDecoration(
                hintText: hint,
                border: InputBorder.none,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CategoryPicker extends StatelessWidget {
  final List<ClipCategory> categories;
  final String? selected;
  final AppL10n l;
  final ValueChanged<String?> onChanged;

  const _CategoryPicker({
    required this.categories,
    required this.selected,
    required this.l,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _CatChip(
          label: l.t('none'),
          color: Colors.grey,
          icon: Icons.block_rounded,
          selected: selected == null,
          onTap: () => onChanged(null),
        ),
        ...categories.map((cat) => _CatChip(
              label: cat.name,
              color: cat.color,
              icon: cat.icon,
              selected: selected == cat.id,
              onTap: () => onChanged(cat.id),
            )),
      ],
    );
  }
}

class _CatChip extends StatelessWidget {
  final String label;
  final Color color;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _CatChip({
    required this.label,
    required this.color,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? color : color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: selected ? color : color.withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: selected ? Colors.white : color),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: selected ? Colors.white : color,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// CATEGORIES SCREEN
// ─────────────────────────────────────────────

class CategoriesScreen extends StatelessWidget {
  final ClipsState state;

  const CategoriesScreen({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    final l = AppL10n.of(context);

    return ListenableBuilder(
      listenable: state,
      builder: (context, _) => CustomScrollView(
        slivers: [
          SliverAppBar(
            floating: true,
            backgroundColor: Colors.transparent,
            elevation: 0,
            title: Text(
              l.t('categories'),
              style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 26,
                  letterSpacing: -0.5),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.add_rounded),
                onPressed: () => _showAddDialog(context),
              ),
              const SizedBox(width: 8),
            ],
          ),
          if (state.categories.isEmpty)
            SliverFillRemaining(
              child: Center(
                child: Text(
                  l.t('no_category'),
                  style: TextStyle(
                      color: Colors.grey.withValues(alpha: 0.5), fontSize: 16),
                ),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 120),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (ctx, i) {
                    final cat = state.categories[i];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: GlassCard(
                        child: Row(
                          children: [
                            Container(
                              width: 46,
                              height: 46,
                              decoration: BoxDecoration(
                                color: cat.color.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(13),
                              ),
                              child: Icon(cat.icon,
                                  color: cat.color, size: 22),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Text(
                                cat.name,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 16),
                              ),
                            ),
                            IconButton(
                              icon:
                                  const Icon(Icons.delete_outline_rounded),
                              color: Colors.red.withValues(alpha: 0.75),
                              onPressed: () =>
                                  _confirmDelete(context, cat.id, l),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                  childCount: state.categories.length,
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _showAddDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AddCategoryDialog(state: state),
    );
  }

  void _confirmDelete(BuildContext context, String id, AppL10n l) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(l.t('confirm_delete')),
        content: Text(l.t('confirm_delete_sub')),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: Text(l.t('cancel'))),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            onPressed: () {
              state.removeCategory(id);
              Navigator.pop(ctx);
            },
            child: Text(l.t('delete')),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// ADD CATEGORY DIALOG
// ─────────────────────────────────────────────

class AddCategoryDialog extends StatefulWidget {
  final ClipsState state;

  const AddCategoryDialog({super.key, required this.state});

  @override
  State<AddCategoryDialog> createState() => _AddCategoryDialogState();
}

class _AddCategoryDialogState extends State<AddCategoryDialog> {
  final _nameCtrl = TextEditingController();
  Color _color = const Color(0xFF4F8EF7);
  IconData _icon = Icons.folder_rounded;

  static const _colors = [
    Color(0xFF4F8EF7),
    Color(0xFFFF5252),
    Color(0xFF2ECC71),
    Color(0xFFFF9800),
    Color(0xFF9C27B0),
    Color(0xFF00BCD4),
    Color(0xFFE91E63),
    Color(0xFFFFB300),
    Color(0xFF009688),
    Color(0xFF3F51B5),
  ];

  static const _icons = [
    Icons.folder_rounded,
    Icons.star_rounded,
    Icons.bookmark_rounded,
    Icons.favorite_rounded,
    Icons.work_rounded,
    Icons.school_rounded,
    Icons.sports_esports_rounded,
    Icons.music_note_rounded,
    Icons.movie_rounded,
    Icons.restaurant_rounded,
    Icons.travel_explore_rounded,
    Icons.science_rounded,
  ];

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppL10n.of(context);
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text(l.t('new_category')),
      content: SizedBox(
        width: 320,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _nameCtrl,
                decoration: InputDecoration(
                  labelText: l.t('category_name'),
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 18),
              Text(l.t('color'),
                  style: const TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 10),
              Wrap(
                spacing: 10,
                runSpacing: 8,
                children: _colors
                    .map((c) => GestureDetector(
                          onTap: () => setState(() => _color = c),
                          child: Container(
                            width: 30,
                            height: 30,
                            decoration: BoxDecoration(
                              color: c,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: _color == c
                                    ? Colors.white
                                    : Colors.transparent,
                                width: 3,
                              ),
                              boxShadow: _color == c
                                  ? [
                                      BoxShadow(
                                          color: c.withValues(alpha: 0.5),
                                          blurRadius: 8)
                                    ]
                                  : [],
                            ),
                          ),
                        ))
                    .toList(),
              ),
              const SizedBox(height: 18),
              Text(l.t('icon'),
                  style: const TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _icons
                    .map((ic) => GestureDetector(
                          onTap: () => setState(() => _icon = ic),
                          child: Container(
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              color: _icon == ic
                                  ? _color.withValues(alpha: 0.2)
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: _icon == ic
                                    ? _color
                                    : Colors.grey.withValues(alpha: 0.3),
                              ),
                            ),
                            child: Icon(
                              ic,
                              size: 20,
                              color: _icon == ic ? _color : Colors.grey,
                            ),
                          ),
                        ))
                    .toList(),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l.t('cancel'))),
        FilledButton(
          onPressed: () {
            if (_nameCtrl.text.trim().isEmpty) return;
            widget.state.addCategory(ClipCategory(
              id: const Uuid().v4(),
              name: _nameCtrl.text.trim(),
              color: _color,
              icon: _icon,
            ));
            Navigator.pop(context);
          },
          child: Text(l.t('save')),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────
// SETTINGS SCREEN
// ─────────────────────────────────────────────

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l = AppL10n.of(context);
    final appState = ClipsApp.of(context)!;

    return CustomScrollView(
      slivers: [
        SliverAppBar(
          floating: true,
          backgroundColor: Colors.transparent,
          elevation: 0,
          title: Text(
            l.t('settings'),
            style: const TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 26,
                letterSpacing: -0.5),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 120),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              GlassCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(l.t('theme'),
                        style: const TextStyle(
                            fontWeight: FontWeight.w700, fontSize: 16)),
                    const SizedBox(height: 14),
                    SegmentedButton<ThemeMode>(
                      segments: [
                        ButtonSegment(
                            value: ThemeMode.system,
                            label: Text(l.t('system')),
                            icon: const Icon(Icons.brightness_auto_rounded)),
                        ButtonSegment(
                            value: ThemeMode.light,
                            label: Text(l.t('light')),
                            icon: const Icon(Icons.light_mode_rounded)),
                        ButtonSegment(
                            value: ThemeMode.dark,
                            label: Text(l.t('dark')),
                            icon: const Icon(Icons.dark_mode_rounded)),
                      ],
                      selected: {appState.themeMode},
                      onSelectionChanged: (s) =>
                          appState.setThemeMode(s.first),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              GlassCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(l.t('language'),
                        style: const TextStyle(
                            fontWeight: FontWeight.w700, fontSize: 16)),
                    const SizedBox(height: 14),
                    SegmentedButton<Locale>(
                      segments: const [
                        ButtonSegment(
                            value: Locale('fr'),
                            label: Text('Français'),
                            icon: Icon(Icons.language_rounded)),
                        ButtonSegment(
                            value: Locale('en'),
                            label: Text('English'),
                            icon: Icon(Icons.language_rounded)),
                      ],
                      selected: {appState.locale},
                      onSelectionChanged: (s) => appState.setLocale(s.first),
                    ),
                  ],
                ),
              ),
            ]),
          ),
        ),
      ],
    );
  }
}

