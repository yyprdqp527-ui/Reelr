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
import 'package:package_info_plus/package_info_plus.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
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
  final int position;

  const Clip({
    required this.id,
    required this.url,
    required this.title,
    required this.platform,
    this.categoryId,
    required this.tags,
    required this.addedAt,
    this.thumbnailUrl,
    this.position = 0,
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
        'position': position,
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
        position: (map['position'] as int?) ?? 0,
      );

  Clip copyWith({String? categoryId, int? position}) => Clip(
        id: id,
        url: url,
        title: title,
        platform: platform,
        categoryId: categoryId ?? this.categoryId,
        tags: tags,
        addedAt: addedAt,
        thumbnailUrl: thumbnailUrl,
        position: position ?? this.position,
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
        version: 4, onCreate: _onCreate, onUpgrade: _onUpgrade);
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 3) {
      await db.delete('categories');
      await _seedDefaultCategories(db);
    }
    if (oldVersion < 4) {
      await db.execute(
          'ALTER TABLE clips ADD COLUMN position INTEGER NOT NULL DEFAULT 0');
    }
  }

  Future<void> _seedDefaultCategories(Database db) async {
    for (final cat in _defaultCategories) {
      await db.insert('categories', cat.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace);
    }
  }

  static final List<ClipCategory> _defaultCategories = [
    const ClipCategory(id: '1', name: 'Food',    icon: Icons.restaurant_outlined,      color: Color(0xFFFF6B6B)),
    const ClipCategory(id: '2', name: 'Workout', icon: Icons.fitness_center_outlined,  color: Color(0xFF4ECDC4)),
    const ClipCategory(id: '3', name: 'Vibes',   icon: Icons.explore_outlined,          color: Color(0xFFFFE66D)),
    const ClipCategory(id: '4', name: 'Wellness',icon: Icons.self_improvement_outlined, color: Color(0xFFA8E6CF)),
    const ClipCategory(id: '5', name: 'Inspo',   icon: Icons.style_outlined,            color: Color(0xFFC77DFF)),
    const ClipCategory(id: '6', name: 'Gaming',  icon: Icons.sports_esports_outlined,   color: Color(0xFF74B9FF)),
  ];

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
        thumbnailUrl TEXT,
        position INTEGER NOT NULL DEFAULT 0
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
    final maps =
        await db.query('clips', orderBy: 'position ASC, addedAt DESC');
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

  Future<void> resetCategories() async {
    final db = await database;
    await db.delete('categories');
    await _seedDefaultCategories(db);
  }

  Future<void> deleteCategory(String id) async {
    final db = await database;
    await db.delete('categories', where: 'id = ?', whereArgs: [id]);
    await db.update('clips', {'categoryId': null},
        where: 'categoryId = ?', whereArgs: [id]);
  }

  Future<void> updateClipPositions(List<String> orderedIds) async {
    final db = await database;
    final batch = db.batch();
    for (int i = 0; i < orderedIds.length; i++) {
      batch.update(
        'clips',
        {'position': i},
        where: 'id = ?',
        whereArgs: [orderedIds[i]],
      );
    }
    await batch.commit(noResult: true);
  }
}

// ─────────────────────────────────────────────
// OEMBED SERVICE
// ─────────────────────────────────────────────

class OEmbedService {
  /// Retourne la meilleure URL de miniature pour un clip.
  /// Pour YouTube : construction directe (gratuit, sans clé API).
  /// Pour les autres : on utilise l'URL stockée via oEmbed.
  static String? bestThumbnailUrl(String url, String? storedThumbUrl) {
    final lower = url.toLowerCase();
    if (lower.contains('youtube.com') || lower.contains('youtu.be')) {
      final id = _youtubeVideoId(url);
      if (id != null) {
        return 'https://img.youtube.com/vi/$id/hqdefault.jpg';
      }
    }
    return storedThumbUrl;
  }

  static String? _youtubeVideoId(String url) {
    final regex = RegExp(
        r'(?:youtube\.com\/watch\?v=|youtu\.be\/)([a-zA-Z0-9_-]{11})');
    final match = regex.firstMatch(url);
    return match?.group(1);
  }

  static Future<Map<String, String?>> fetchMetadata(String url) async {
    try {
      final lower = url.toLowerCase();
      final isYoutube =
          lower.contains('youtube.com') || lower.contains('youtu.be');

      if (isYoutube) {
        // Miniature directe — gratuit, sans quota
        final videoId = _youtubeVideoId(url);
        final thumbUrl = videoId != null
            ? 'https://img.youtube.com/vi/$videoId/hqdefault.jpg'
            : null;
        // Titre via oEmbed
        try {
          final oembedUrl =
              'https://www.youtube.com/oembed?url=${Uri.encodeComponent(url)}&format=json';
          final response = await http
              .get(Uri.parse(oembedUrl),
                  headers: {'Accept': 'application/json'})
              .timeout(const Duration(seconds: 6));
          if (response.statusCode == 200) {
            final data =
                json.decode(response.body) as Map<String, dynamic>;
            return {
              'title': data['title'] as String?,
              'thumbnailUrl': thumbUrl,
            };
          }
        } catch (_) {}
        return {'title': null, 'thumbnailUrl': thumbUrl};
      }

      // Autres plateformes : oEmbed pour titre + miniature
      String? oembedUrl;
      if (lower.contains('vimeo.com')) {
        oembedUrl =
            'https://vimeo.com/api/oembed.json?url=${Uri.encodeComponent(url)}';
      } else if (lower.contains('tiktok.com')) {
        oembedUrl =
            'https://www.tiktok.com/oembed?url=${Uri.encodeComponent(url)}';
      }
      if (oembedUrl != null) {
        final response = await http
            .get(Uri.parse(oembedUrl),
                headers: {'Accept': 'application/json'})
            .timeout(const Duration(seconds: 6));
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
      'recette', 'recettes', 'recipe', 'recipes', 'cuisine', 'cuisiner',
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
      'parents',
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
  };

  static const Map<String, CategorySuggestion> _suggestions = {
    'food': CategorySuggestion(
      key: 'food', name: 'Food',
      color: Color(0xFFFF6B6B),
      icon: Icons.restaurant_outlined,
      defaultCategoryId: '1',
    ),
    'sport': CategorySuggestion(
      key: 'sport', name: 'Workout',
      color: Color(0xFF4ECDC4),
      icon: Icons.fitness_center_outlined,
      defaultCategoryId: '2',
    ),
    'yoga': CategorySuggestion(
      key: 'yoga', name: 'Wellness',
      color: Color(0xFFA8E6CF),
      icon: Icons.self_improvement_outlined,
      defaultCategoryId: '4',
    ),
    'moto': CategorySuggestion(
      key: 'moto', name: 'Vibes',
      color: Color(0xFFFFE66D),
      icon: Icons.explore_outlined,
      defaultCategoryId: '3',
    ),
    'voyage': CategorySuggestion(
      key: 'voyage', name: 'Vibes',
      color: Color(0xFFFFE66D),
      icon: Icons.explore_outlined,
      defaultCategoryId: '3',
    ),
    'musique': CategorySuggestion(
      key: 'musique', name: 'Inspo',
      color: Color(0xFFC77DFF),
      icon: Icons.style_outlined,
      defaultCategoryId: '5',
    ),
    'tricot': CategorySuggestion(
      key: 'tricot', name: 'Inspo',
      color: Color(0xFFC77DFF),
      icon: Icons.style_outlined,
    ),
    'bebe': CategorySuggestion(
      key: 'bebe', name: 'Wellness',
      color: Color(0xFFA8E6CF),
      icon: Icons.self_improvement_outlined,
    ),
    'humour': CategorySuggestion(
      key: 'humour', name: 'Vibes',
      color: Color(0xFFFFE66D),
      icon: Icons.explore_outlined,
    ),
    'beaute': CategorySuggestion(
      key: 'beaute', name: 'Inspo',
      color: Color(0xFFC77DFF),
      icon: Icons.style_outlined,
    ),
  };

  /// Renvoie la meilleure suggestion pour [title] ou `unclassified`.
  static CategorySuggestion suggestDetailed(String title) {
    if (title.trim().isEmpty) return CategorySuggestion.unclassified;
    final lower = title.toLowerCase();
    final scores = <String, int>{};
    _keywords.forEach((key, kws) {
      int s = 0;
      for (final kw in kws) {
        if (lower.contains(kw)) s++;
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
    for (final c in categories) {
      if (c.id == suggestion.defaultCategoryId) return c.id;
      if (c.id == suggestion.aiCategoryId) return c.id;
      if (c.name.toLowerCase() == suggestion.name.toLowerCase()) return c.id;
    }
    return null;
  }

  /// Compat legacy : ID d'une catégorie existante si match, sinon null.
  static String? suggest(String title, List<ClipCategory> categories) {
    return matchExisting(suggestDetailed(title), categories);
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
    // Migration : anciennes catégories FR → nouvelles EN
    await _migrateCategories();
    _isLoading = false;
    notifyListeners();
  }

  Future<void> _migrateCategories() async {
    const oldNames = {'Recettes', 'Yoga', 'Moto', 'Voyage', 'Musique', 'Sport'};
    final hasOld = _categories.any((c) => oldNames.contains(c.name));
    if (!hasOld) return;
    await DatabaseHelper.instance.resetCategories();
    _categories = await DatabaseHelper.instance.getAllCategories();
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

  Clip? lastClipFor(String? categoryId) {
    final pool = categoryId == null
        ? _clips
        : _clips.where((c) => c.categoryId == categoryId).toList();
    if (pool.isEmpty) return null;
    return pool.reduce((a, b) => a.addedAt.isAfter(b.addedAt) ? a : b);
  }

  Future<void> reorderClips(
      int oldIndex, int newIndex, String? categoryId) async {
    // Extraire la liste filtrée, appliquer le déplacement
    final filtered = categoryId == null
        ? List<Clip>.from(_clips)
        : _clips.where((c) => c.categoryId == categoryId).toList();
    if (oldIndex < 0 ||
        newIndex < 0 ||
        oldIndex >= filtered.length ||
        newIndex >= filtered.length) return;
    final moved = filtered.removeAt(oldIndex);
    filtered.insert(newIndex, moved);
    // Mettre à jour les positions dans _clips
    for (int i = 0; i < filtered.length; i++) {
      final idx = _clips.indexWhere((c) => c.id == filtered[i].id);
      if (idx != -1) {
        _clips[idx] = _clips[idx].copyWith(position: i);
      }
    }
    notifyListeners();
    // Persister en arrière-plan
    await DatabaseHelper.instance
        .updateClipPositions(filtered.map((c) => c.id).toList());
  }
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
      'app_name': 'Savid',
      'categories': 'Catégories',
      'settings': 'Paramètres',
      'add_clip': 'Ajouter',
      'paste_url': 'Coller un lien vidéo…',
      'add': 'Ajouter',
      'cancel': 'Annuler',
      'delete': 'Supprimer',
      'share': 'Partager',
      'open': 'Ouvrir',
      'no_clips': 'Aucune vidéo',
      'no_clips_sub': 'Ajoutez votre première vidéo ici',
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
      'app_name': 'Savid',
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
      ['en', 'fr', 'es', 'de', 'it', 'pt'].contains(locale.languageCode);

  @override
  Future<AppL10n> load(Locale locale) async => AppL10n(locale);

  @override
  bool shouldReload(_AppL10nDelegate old) => false;
}

// ─────────────────────────────────────────────
// THEME
// ─────────────────────────────────────────────

class AppTheme {
  // ─── Background gradient ─────────────────────────────
  static const Color bgTop    = Color(0xFF0A0A0F);
  static const Color bgBottom = Color(0xFF1A0A2E);

  // ─── Accent gradient (bouton +, highlights) ──────────
  static const Color accentPurple = Color(0xFF7C3AED);
  static const Color accentBlue   = Color(0xFF2563EB);

  // ─── Orbes d'arrière-plan ────────────────────────────
  static const Color orbPurple = Color(0xFF6D28D9);
  static const Color orbBlue   = Color(0xFF1D4ED8);

  // ─── Couleurs accent par catégorie ───────────────────
  static const Color recettesAccent = Color(0xFFFF6B6B);
  static const Color yogaAccent     = Color(0xFF4ECDC4);
  static const Color motoAccent     = Color(0xFFFFE66D);
  static const Color voyageAccent   = Color(0xFFA8E6CF);
  static const Color musiqueAccent  = Color(0xFFC77DFF);
  static const Color sportAccent    = Color(0xFFFF8B94);
  static const Color toutAccent     = Color(0xFF74B9FF);

  // ─── Compat legacy ───────────────────────────────────
  static const Color orange     = accentPurple;
  static const Color darkGreen  = bgBottom;
  static const Color shadowGrey = Color(0xFF2D1B69);

  static ThemeData light() => ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        scaffoldBackgroundColor: const Color(0xFFF5F5F7),
        colorScheme: ColorScheme.fromSeed(
          seedColor: accentPurple,
          brightness: Brightness.light,
          primary: accentPurple,
          secondary: accentBlue,
          surface: Colors.white,
        ),
      );
  static ThemeData dark()  => _darkTheme();

  static ThemeData _darkTheme() => ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: bgTop,
        colorScheme: ColorScheme.fromSeed(
          seedColor: accentPurple,
          brightness: Brightness.dark,
          primary: accentPurple,
          secondary: accentBlue,
          surface: bgTop,
        ),
        textTheme: const TextTheme().apply(
          bodyColor: Colors.white,
          displayColor: Colors.white,
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
    this.blur = 20,
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
              color: isDark
                  ? Colors.white.withValues(alpha: 0.06)
                  : Colors.white.withValues(alpha: 0.85),
              borderRadius: BorderRadius.circular(borderRadius),
              border: Border.all(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.10)
                    : Colors.black.withValues(alpha: 0.08),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: isDark
                      ? Colors.black.withValues(alpha: 0.30)
                      : Colors.black.withValues(alpha: 0.08),
                  blurRadius: 24,
                  offset: const Offset(0, 6),
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
  final ValueNotifier<ThemeMode> _themeModeNotifier =
      ValueNotifier(ThemeMode.system);
  Locale? _locale;
  bool _notifications = false;
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();
  StreamSubscription<List<SharedMediaFile>>? _shareSub;

  ThemeMode get themeMode => _themeModeNotifier.value;
  ValueNotifier<ThemeMode> get themeModeNotifier => _themeModeNotifier;
  Locale? get locale => _locale;
  bool get notifications => _notifications;

  void setThemeMode(ThemeMode mode) {
    _themeModeNotifier.value = mode;
    SharedPreferences.getInstance()
        .then((p) => p.setString('theme_mode', mode.name));
  }

  void setLocale(Locale? locale) {
    setState(() => _locale = locale);
    SharedPreferences.getInstance().then((p) {
      if (locale == null) {
        p.remove('locale');
      } else {
        p.setString('locale', locale.languageCode);
      }
    });
  }

  void setNotifications(bool value) {
    setState(() => _notifications = value);
    SharedPreferences.getInstance()
        .then((p) => p.setBool('notifications', value));
  }

  Future<void> _loadPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final themeStr = prefs.getString('theme_mode');
    final localeStr = prefs.getString('locale');
    final notifs = prefs.getBool('notifications') ?? false;
    if (mounted) {
      _themeModeNotifier.value = ThemeMode.values.firstWhere(
        (m) => m.name == themeStr,
        orElse: () => ThemeMode.system,
      );
      setState(() {
        _locale = localeStr != null ? Locale(localeStr) : null;
        _notifications = notifs;
      });
    }
  }

  @override
  void initState() {
    super.initState();
    _loadPrefs();
    _initShareIntent();
  }

  void _initShareIntent() {
    if (kIsWeb) return;
    try {
      // Cold start (app opened via share)
      ReceiveSharingIntent.instance.getInitialMedia().then((files) {
        _handleSharedFiles(files);
        ReceiveSharingIntent.instance.reset();
      }).catchError((e) {
        debugPrint('Share intent unsupported on this platform: $e');
      });
      // Warm shares (app already running)
      try {
        _shareSub =
            ReceiveSharingIntent.instance.getMediaStream().listen((files) {
          _handleSharedFiles(files);
        }, onError: (e) {
          debugPrint('Share intent stream unsupported on this platform: $e');
        });
      } catch (e) {
        debugPrint('Share intent stream unsupported on this platform: $e');
      }
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
    _themeModeNotifier.dispose();
    _shareSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([widget.state, _themeModeNotifier]),
      builder: (context, _) => MaterialApp(
        title: 'Savid',
        debugShowCheckedModeBanner: false,
        navigatorKey: _navigatorKey,
        theme: ThemeData.light().copyWith(
          scaffoldBackgroundColor: const Color(0xFFF5F5F5),
          colorScheme: const ColorScheme.light(primary: Color(0xFF7C3AED)),
          cardColor: Colors.white,
        ),
        darkTheme: ThemeData.dark().copyWith(
          scaffoldBackgroundColor: const Color(0xFF0A0A1F),
          colorScheme: const ColorScheme.dark(primary: Color(0xFF7C3AED)),
          cardColor: const Color(0xFF1A1A2E),
        ),
        themeMode: _themeModeNotifier.value,
        locale: _locale,
        supportedLocales: const [
          Locale('fr'), Locale('en'), Locale('es'),
          Locale('de'), Locale('it'), Locale('pt'),
        ],
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

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      extendBody: true,
      body: Stack(
        children: [
          const _GradientBackground(isDark: true),
          IndexedStack(
            index: _index,
            children: [
              HomeScreen(state: widget.state),
              CategoriesScreen(state: widget.state),
              SettingsScreen(state: widget.state),
            ],
          ),
        ],
      ),
      floatingActionButton: _index == 0
          ? Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF7C3AED), Color(0xFF2563EB)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(18),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF7C3AED).withValues(alpha: 0.55),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(18),
                child: InkWell(
                  borderRadius: BorderRadius.circular(18),
                  onTap: () => _openAddSheet(context),
                  child: const Center(
                    child: Icon(Icons.add_rounded,
                        color: Colors.white, size: 30),
                  ),
                ),
              ),
            )
          : null,
      bottomNavigationBar: _buildNavBar(l),
    );
  }

  Widget _buildNavBar(AppL10n l) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final navBgColor = isDark
        ? Colors.white.withValues(alpha: 0.08)
        : Colors.white.withValues(alpha: 0.85);
    final navBorderColor = isDark
        ? Colors.white.withValues(alpha: 0.10)
        : Colors.black.withValues(alpha: 0.08);
    final labelColor = isDark ? Colors.white.withValues(alpha: 0.45) : Colors.black54;
    final selectedColor = isDark ? Colors.white : Colors.black87;
    final unselectedColor =
        isDark ? Colors.white.withValues(alpha: 0.40) : Colors.black45;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
          child: Container(
            decoration: BoxDecoration(
              color: navBgColor,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: navBorderColor, width: 1),
            ),
            child: NavigationBarTheme(
              data: NavigationBarThemeData(
                indicatorColor: AppTheme.accentPurple.withValues(alpha: 0.20),
                labelTextStyle: WidgetStatePropertyAll(
                  TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: labelColor,
                  ),
                ),
                iconTheme: WidgetStateProperty.resolveWith((states) {
                  final selected = states.contains(WidgetState.selected);
                  return IconThemeData(
                    color: selected ? selectedColor : unselectedColor,
                    size: 22,
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
                    label: 'Accueil',
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
  // isDark kept for API compat but unused — always dark design
  final bool isDark;
  const _GradientBackground({required this.isDark});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    if (!isDark) {
      return const Positioned.fill(
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFFF5F5F5), Color(0xFFEDE9FF)],
            ),
          ),
        ),
      );
    }
    return Positioned.fill(
      child: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [AppTheme.bgTop, AppTheme.bgBottom],
          ),
        ),
        child: Stack(
          children: [
            Positioned(
              top: -100,
              left: -80,
              child: _Orb(
                size: 420,
                color: AppTheme.orbPurple.withValues(alpha: 0.45),
              ),
            ),
            Positioned(
              bottom: 60,
              right: -100,
              child: _Orb(
                size: 380,
                color: AppTheme.orbBlue.withValues(alpha: 0.35),
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
                          color: AppTheme.toutAccent,
                          icon: Icons.apps_rounded,
                          count: widget.state.totalCount,
                          lastClip: widget.state.lastClipFor(null),
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
                        icon: cat.icon,
                        count: widget.state.countForCategory(cat.id),
                        lastClip: widget.state.lastClipFor(cat.id),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fgColor = isDark ? Colors.white : Colors.black87;
    return SliverAppBar(
      floating: true,
      snap: true,
      backgroundColor: Colors.transparent,
      elevation: 0,
      expandedHeight: 110,
      flexibleSpace: FlexibleSpaceBar(
        titlePadding: const EdgeInsets.only(left: 20, bottom: 16),
        title: Text(
          'Savid',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 32,
            letterSpacing: -1,
            color: fgColor,
          ),
        ),
      ),
      actions: [
        if (clips.isNotEmpty)
          IconButton(
            icon: Icon(Icons.ios_share_rounded, color: fgColor),
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
  final IconData icon;
  final int count;
  final VoidCallback onTap;
  final bool isAdd;
  final Clip? lastClip;

  const _CategoryTile({
    required this.name,
    required this.color,
    required this.icon,
    required this.count,
    required this.onTap,
    this.isAdd = false,
    this.lastClip,
  });

  factory _CategoryTile.add({
    required String label,
    required VoidCallback onTap,
  }) =>
      _CategoryTile(
        name: label,
        color: AppTheme.orange,
        icon: Icons.add_rounded,
        count: 0,
        onTap: onTap,
        isAdd: true,
      );

  @override
  State<_CategoryTile> createState() => _CategoryTileState();
}

class _CategoryTileState extends State<_CategoryTile> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final resolvedThumbUrl = widget.lastClip != null
        ? OEmbedService.bestThumbnailUrl(
            widget.lastClip!.url, widget.lastClip!.thumbnailUrl)
        : null;
    final hasThumbnail =
        !widget.isAdd && (resolvedThumbUrl?.isNotEmpty ?? false);
    final platform = widget.lastClip != null
        ? SocialPlatform.detect(widget.lastClip!.url)
        : null;

    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.97 : 1.0,
        duration: const Duration(milliseconds: 140),
        curve: Curves.easeOut,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: widget.color.withValues(alpha: 0.30),
                blurRadius: 18,
                offset: const Offset(0, 7),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: hasThumbnail
                ? _buildThumbnailTile(resolvedThumbUrl!, platform)
                : _buildEmptyTile(),
          ),
        ),
      ),
    );
  }

  Widget _buildThumbnailTile(String thumbUrl, SocialPlatform? platform) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // Miniature en plein fond
        Image.network(
          thumbUrl,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => Container(
            color: const Color(0xFF1A0A2E),
            child: Center(
              child: Icon(
                platform?.icon ?? widget.icon,
                color: platform?.color ?? widget.color,
                size: 32,
              ),
            ),
          ),
        ),
        // Dégradé sombre bas
        Positioned.fill(
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  stops: const [0.30, 1.0],
                  colors: [
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.82),
                  ],
                ),
              ),
            ),
          ),
        ),
        // Logo plateforme — haut droite
        if (platform != null && platform.id != 'other')
          Positioned(
            top: 8,
            right: 8,
            child: Container(
              padding: const EdgeInsets.all(5),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.55),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(platform.icon, color: platform.color, size: 14),
            ),
          ),
        // Nom + compteur — bas gauche
        Positioned(
          left: 10,
          right: 10,
          bottom: 10,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                widget.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                  letterSpacing: -0.2,
                  shadows: [
                    Shadow(
                        color: Colors.black,
                        blurRadius: 8,
                        offset: Offset(0, 1))
                  ],
                ),
              ),
              const SizedBox(height: 1),
              Text(
                '${widget.count} vidéo${widget.count > 1 ? 's' : ''}',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.60),
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyTile() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surfaceColor = isDark
        ? Colors.white.withValues(alpha: 0.06)
        : Colors.white.withValues(alpha: 0.70);
    final borderColor = isDark
        ? Colors.white.withValues(alpha: 0.12)
        : Colors.black.withValues(alpha: 0.08);
    final contentColor = isDark ? Colors.white : Colors.black87;
    final subtitleColor =
        isDark ? Colors.white.withValues(alpha: 0.50) : Colors.black45;
    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 40, sigmaY: 40),
      child: Container(
        decoration: BoxDecoration(
          color: surfaceColor,
          border: Border.all(color: borderColor, width: 1),
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Teinte accent
            Positioned.fill(
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        widget.color.withValues(alpha: 0.18),
                        widget.color.withValues(alpha: 0.04),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            // Contenu centré
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(widget.icon, size: 22, color: contentColor),
                  const SizedBox(height: 2),
                  Text(
                    widget.name.toUpperCase(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 9,
                      letterSpacing: 1.0,
                      color: contentColor,
                    ),
                  ),
                  if (!widget.isAdd) ...[
                    const SizedBox(height: 2),
                    Text(
                      'Ajouter une vidéo',
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11,
                        fontStyle: FontStyle.italic,
                        color: subtitleColor,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
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
      floatingActionButton: Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF7C3AED), Color(0xFF2563EB)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF7C3AED).withValues(alpha: 0.55),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(18),
          child: InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: () => showModalBottomSheet(
              context: context,
              isScrollControlled: true,
              backgroundColor: Colors.transparent,
              builder: (_) => AddClipSheet(state: state),
            ),
            child: const Center(
              child: Icon(Icons.add_rounded, color: Colors.white, size: 30),
            ),
          ),
        ),
      ),
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
                    foregroundColor: Colors.white,
                    elevation: 0,
                    leading: IconButton(
                      icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
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
                      sliver: SliverReorderableList(
                        itemCount: clips.length,
                        proxyDecorator: (child, index, animation) {
                          return AnimatedBuilder(
                            animation: animation,
                            child: child,
                            builder: (context, child) {
                              final scale =
                                  1.0 + 0.05 * animation.value;
                              return Transform.scale(
                                scale: scale,
                                child: Material(
                                  color: Colors.transparent,
                                  elevation: 12 * animation.value,
                                  shadowColor: Colors.black54,
                                  borderRadius: BorderRadius.circular(16),
                                  child: child,
                                ),
                              );
                            },
                          );
                        },
                        itemBuilder: (ctx, i) {
                          final clip = clips[i];
                          return ReorderableDelayedDragStartListener(
                            key: ValueKey(clip.id),
                            index: i,
                            child: Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: ClipCard(clip: clip, state: state),
                            ),
                          );
                        },
                        onReorder: (oldIndex, newIndex) {
                          if (newIndex > oldIndex) newIndex--;
                          state.reorderClips(
                              oldIndex, newIndex, categoryId);
                        },
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surfaceColor = isDark
        ? Colors.white.withValues(alpha: 0.08)
        : Colors.black.withValues(alpha: 0.06);
    final borderColor = isDark
        ? Colors.white.withValues(alpha: 0.10)
        : Colors.black.withValues(alpha: 0.10);
    final textColor = isDark ? Colors.white : Colors.black87;
    final hintColor =
        isDark ? Colors.white.withValues(alpha: 0.40) : Colors.black38;
    final iconColor =
        isDark ? Colors.white.withValues(alpha: 0.70) : Colors.black54;
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          decoration: BoxDecoration(
            color: surfaceColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: borderColor, width: 1),
          ),
          child: TextField(
            controller: widget.controller,
            style: TextStyle(color: textColor),
            onChanged: (v) {
              widget.onChanged(v);
              setState(() {});
            },
            decoration: InputDecoration(
              hintText: widget.hint,
              hintStyle: TextStyle(color: hintColor),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(vertical: 14),
              prefixIcon: Icon(
                Icons.search_rounded,
                color: iconColor,
                size: 22,
              ),
              suffixIcon: widget.controller.text.isNotEmpty
                  ? IconButton(
                      icon: Icon(Icons.clear_rounded, color: iconColor),
                      onPressed: () {
                        widget.controller.clear();
                        widget.onChanged('');
                        setState(() {});
                      },
                    )
                  : null,
            ),
          ),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black87;
    final iconColor = isDark
        ? Colors.white.withValues(alpha: 0.20)
        : Colors.black.withValues(alpha: 0.20);
    final subtitleColor =
        isDark ? Colors.white.withValues(alpha: 0.45) : Colors.black54;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.videocam_off_rounded, size: 72, color: iconColor),
          const SizedBox(height: 16),
          Text(
            l.t('no_clips'),
            style: TextStyle(
                fontSize: 20, fontWeight: FontWeight.w700, color: textColor),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 48),
            child: Text(
              l.t('no_clips_sub'),
              style: TextStyle(color: subtitleColor, fontSize: 14),
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

// ─────────────────────────────────────────────
// THUMBNAIL BANNER — 16:9, Image.network + fallback icône
// ─────────────────────────────────────────────

class _ThumbnailBanner extends StatelessWidget {
  final String? thumbUrl;
  final SocialPlatform platform;

  const _ThumbnailBanner({required this.thumbUrl, required this.platform});

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 16 / 9,
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        child: thumbUrl != null
            ? Image.network(
                thumbUrl!,
                fit: BoxFit.cover,
                // Loader
                loadingBuilder: (ctx, child, progress) {
                  if (progress == null) return child;
                  return _fallback(shimmer: true);
                },
                // Erreur → icône plateforme
                errorBuilder: (_, __, ___) => _fallback(),
              )
            : _fallback(),
      ),
    );
  }

  Widget _fallback({bool shimmer = false}) {
    return Container(
      color: platform.color.withValues(alpha: 0.12),
      child: shimmer
          ? const Center(
              child: SizedBox(
                width: 28,
                height: 28,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          : Center(
              child: Icon(
                platform.icon,
                color: platform.color.withValues(alpha: 0.6),
                size: 48,
              ),
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
    final thumbUrl =
        OEmbedService.bestThumbnailUrl(clip.url, clip.thumbnailUrl);

    return GlassCard(
      padding: EdgeInsets.zero,
      onTap: () => _openUrl(clip.url),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Miniature 16:9 ──────────────────────────────────────────
          _ThumbnailBanner(thumbUrl: thumbUrl, platform: platform),
          // ── Infos principales ───────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 8, 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Logo réseau social
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: platform.color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(platform.icon, color: platform.color, size: 20),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        clip.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                          height: 1.35,
                          color: Theme.of(context).brightness ==
                                  Brightness.dark
                              ? Colors.white
                              : Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 4),
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
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            DateFormat.yMMMd(lang).format(clip.addedAt),
                            style: TextStyle(
                              color: Colors.grey.withValues(alpha: 0.65),
                              fontSize: 11,
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
          // ── Badges catégorie + tags ──────────────────────────────────
          if (clip.tags.isNotEmpty || category != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
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
            )
          else
            const SizedBox(height: 10),
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
    });
    if (fetchedTitle.isNotEmpty && _selectedCategoryId == null) {
      await _proposeCategory(fetchedTitle);
    }
  }

  /// Affiche la popup IA de confirmation de catégorie.
  Future<void> _proposeCategory(String title) async {
    final suggestion = CategoryClassifier.suggestDetailed(title);
    final existingId = CategoryClassifier.matchExisting(
        suggestion, widget.state.categories);
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _CategorySuggestionDialog(
        suggestion: suggestion,
        hasExisting: existingId != null,
      ),
    );
    if (!mounted) return;
    if (confirmed == true) {
      await _applySuggestion(suggestion, existingId);
    }
  }

  Future<void> _applySuggestion(
      CategorySuggestion s, String? existingId) async {
    if (s.isUnclassified) {
      setState(() {
        _selectedCategoryId = null;
        _wasAutoSuggested = false;
      });
      return;
    }
    if (existingId != null) {
      setState(() {
        _selectedCategoryId = existingId;
        _wasAutoSuggested = true;
      });
      return;
    }
    // Nouvelle catégorie automatique → création à la volée.
    final newCat = ClipCategory(
      id: s.aiCategoryId,
      name: s.name,
      color: s.color,
      icon: s.icon,
    );
    await widget.state.addCategory(newCat);
    if (!mounted) return;
    setState(() {
      _selectedCategoryId = newCat.id;
      _wasAutoSuggested = true;
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
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final sheetBg = isDark
        ? const Color(0xFF0A0A0F).withValues(alpha: 0.85)
        : Colors.white.withValues(alpha: 0.97);
    final borderTopColor = isDark
        ? Colors.white.withValues(alpha: 0.12)
        : Colors.black.withValues(alpha: 0.08);
    final titleColor = isDark ? Colors.white : Colors.black87;
    final handleColor = isDark
        ? Colors.white.withValues(alpha: 0.25)
        : Colors.black.withValues(alpha: 0.20);
    final cancelFgColor = isDark ? Colors.white : Colors.black87;
    final cancelBorderColor = isDark
        ? Colors.white.withValues(alpha: 0.25)
        : Colors.black.withValues(alpha: 0.25);
    return Padding(
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
          child: Container(
            decoration: BoxDecoration(
              color: sheetBg,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(28)),
              border: Border(
                top: BorderSide(color: borderTopColor),
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
                          color: handleColor,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    Text(
                      l.t('add_clip'),
                      style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: titleColor),
                    ),
                    const SizedBox(height: 20),
                    _SheetField(
                      controller: _urlCtrl,
                      hint: l.t('paste_url'),
                      icon: Icons.link_rounded,
                      onChanged: _onUrlChanged,
                      prefixWidget: _detectedPlatform != null
                          ? Container(
                              margin: const EdgeInsets.only(right: 8),
                              padding: const EdgeInsets.all(5),
                              decoration: BoxDecoration(
                                color: _detectedPlatform!.color
                                    .withValues(alpha: 0.20),
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
                    ),
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        Text(l.t('category'),
                            style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                                color: titleColor)),
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
                              foregroundColor: cancelFgColor,
                              side: BorderSide(color: cancelBorderColor),
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
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [
                                  Color(0xFF7C3AED),
                                  Color(0xFF2563EB)
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(14),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFF7C3AED)
                                      .withValues(alpha: 0.45),
                                  blurRadius: 14,
                                  offset: const Offset(0, 6),
                                ),
                              ],
                            ),
                            child: Material(
                              color: Colors.transparent,
                              borderRadius: BorderRadius.circular(14),
                              child: InkWell(
                                borderRadius: BorderRadius.circular(14),
                                onTap: _submit,
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                      vertical: 15),
                                  child: Center(
                                    child: Text(
                                      l.t('add'),
                                      style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w700,
                                          fontSize: 15),
                                    ),
                                  ),
                                ),
                              ),
                            ),
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

/// Popup IA "On a détecté : 🍳 Food — confirmer ?"
class _CategorySuggestionDialog extends StatelessWidget {
  final CategorySuggestion suggestion;
  final bool hasExisting;

  const _CategorySuggestionDialog({
    required this.suggestion,
    required this.hasExisting,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final dialogBg = isDark
        ? const Color(0xFF0A0A0F).withValues(alpha: 0.90)
        : Colors.white.withValues(alpha: 0.97);
    final borderColor = isDark
        ? Colors.white.withValues(alpha: 0.12)
        : Colors.black.withValues(alpha: 0.08);
    final titleColor = isDark ? Colors.white : Colors.black87;
    final subtitleColor =
        isDark ? Colors.white.withValues(alpha: 0.60) : Colors.black54;
    final suggestionTextColor = isDark ? Colors.white : Colors.black87;
    final suggestionSubColor =
        isDark ? Colors.white.withValues(alpha: 0.55) : Colors.black45;
    final isUnclassified = suggestion.isUnclassified;
    final subtitle = isUnclassified
        ? 'Aucun mot-clé reconnu dans le titre.'
        : (hasExisting
            ? 'Ajouter à cette liste existante ?'
            : 'Nouvelle liste à créer automatiquement.');
    final cancelFgColor = isDark ? Colors.white : Colors.black87;
    final cancelBorderColor = isDark
        ? Colors.white.withValues(alpha: 0.25)
        : Colors.black.withValues(alpha: 0.25);
    return Dialog(
      backgroundColor: Colors.transparent,
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
          child: Container(
            decoration: BoxDecoration(
              color: dialogBg,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: borderColor),
            ),
            padding: const EdgeInsets.fromLTRB(22, 22, 22, 18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(colors: [
                          Color(0xFF6C63FF),
                          Color(0xFFFF6EC7),
                        ]),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.auto_awesome_rounded,
                          size: 14, color: Colors.white),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Détection automatique',
                      style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 14,
                          color: titleColor),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  'On a détecté :',
                  style: TextStyle(fontSize: 13, color: subtitleColor),
                ),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: suggestion.color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                        color: suggestion.color.withValues(alpha: 0.40),
                        width: 1.2),
                  ),
                  child: Row(
                    children: [
                      Icon(suggestion.icon,
                          color: suggestion.color, size: 32),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              suggestion.name.toUpperCase(),
                              style: TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 15,
                                letterSpacing: 0.5,
                                color: suggestionTextColor,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              subtitle,
                              style: TextStyle(
                                fontSize: 12,
                                color: suggestionSubColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context, false),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: cancelFgColor,
                          side: BorderSide(color: cancelBorderColor),
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                        child: const Text('Changer'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(colors: [
                            Color(0xFF7C3AED),
                            Color(0xFF2563EB)
                          ]),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Material(
                          color: Colors.transparent,
                          borderRadius: BorderRadius.circular(12),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(12),
                            onTap: () => Navigator.pop(context, true),
                            child: Padding(
                              padding:
                                  const EdgeInsets.symmetric(vertical: 13),
                              child: Center(
                                child: Text(
                                  isUnclassified ? 'OK' : 'Confirmer',
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w700),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
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
  final ValueChanged<String>? onChanged;
  final Widget? prefixWidget;

  const _SheetField({
    required this.controller,
    required this.hint,
    required this.icon,
    this.onChanged,
    this.prefixWidget,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surfaceColor =
        isDark ? Colors.white.withValues(alpha: 0.07) : Colors.black.withValues(alpha: 0.05);
    final borderColor =
        isDark ? Colors.white.withValues(alpha: 0.10) : Colors.black.withValues(alpha: 0.10);
    final iconColor =
        isDark ? Colors.white.withValues(alpha: 0.55) : Colors.black45;
    final textColor = isDark ? Colors.white : Colors.black87;
    final hintColor =
        isDark ? Colors.white.withValues(alpha: 0.35) : Colors.black38;
    return Container(
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        children: [
          if (prefixWidget != null) ...[
            const SizedBox(width: 12),
            prefixWidget!,
          ] else
            Padding(
              padding: const EdgeInsets.only(left: 14),
              child: Icon(icon, size: 20, color: iconColor),
            ),
          Expanded(
            child: TextField(
              controller: controller,
              onChanged: onChanged,
              style: TextStyle(color: textColor),
              decoration: InputDecoration(
                hintText: hint,
                hintStyle: TextStyle(color: hintColor),
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
              'Catégories',
              style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 26,
                  letterSpacing: -0.5,
                  color: Theme.of(context).brightness == Brightness.dark
                      ? Colors.white
                      : Colors.black87),
            ),
            actions: [
              IconButton(
                icon: Icon(
                  Icons.add_rounded,
                  color: Theme.of(context).brightness == Brightness.dark
                      ? Colors.white
                      : Colors.black87,
                ),
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
                      color: Theme.of(context).brightness == Brightness.dark
                          ? Colors.white.withValues(alpha: 0.35)
                          : Colors.black38,
                      fontSize: 16),
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
                                color: cat.color.withValues(alpha: 0.18),
                                borderRadius: BorderRadius.circular(13),
                              ),
                              child: Icon(cat.icon,
                                  color: cat.color, size: 22),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Text(
                                cat.name,
                                style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 16,
                                    color: Theme.of(ctx).brightness ==
                                            Brightness.dark
                                        ? Colors.white
                                        : Colors.black87),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(
                                  Icons.delete_outline_rounded),
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

class SettingsScreen extends StatefulWidget {
  final ClipsState state;

  const SettingsScreen({super.key, required this.state});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  String _appVersion = '—';

  @override
  void initState() {
    super.initState();
    PackageInfo.fromPlatform().then((info) {
      if (mounted) {
        setState(
            () => _appVersion = '${info.version} (${info.buildNumber})');
      }
    }).catchError((_) {
      if (mounted) setState(() => _appVersion = '1.0.0');
    });
  }

  // ─── Section header ─────────────────────────────────────
  Widget _sectionHeader(String title) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 0, 0, 8),
        child: Text(
          title.toUpperCase(),
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.5,
            color: Theme.of(context).brightness == Brightness.dark
                ? Colors.white.withValues(alpha: 0.40)
                : Colors.black45,
          ),
        ),
      );

  // ─── Glass group (multiple tiles) ───────────────────────
  Widget _glassGroup(List<Widget> tiles) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          decoration: BoxDecoration(
            color: isDark
                ? Colors.white.withValues(alpha: 0.06)
                : Colors.white.withValues(alpha: 0.85),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.09)
                  : Colors.black.withValues(alpha: 0.07),
            ),
            boxShadow: isDark
                ? []
                : [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.06),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    )
                  ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (int i = 0; i < tiles.length; i++) ...[
                tiles[i],
                if (i < tiles.length - 1)
                  Padding(
                    padding: const EdgeInsets.only(left: 58),
                    child: Divider(
                      height: 1,
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.07)
                          : Colors.black.withValues(alpha: 0.06),
                    ),
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  // ─── Single tile row ────────────────────────────────────
  Widget _tile({
    required IconData icon,
    Color? iconColor,
    required String label,
    String? value,
    Widget? trailing,
    VoidCallback? onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
          child: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: (iconColor ?? AppTheme.accentPurple)
                      .withValues(alpha: 0.20),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon,
                    size: 17,
                    color: iconColor ?? AppTheme.accentPurple),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: Theme.of(context).brightness == Brightness.dark
                        ? Colors.white
                        : Colors.black87,
                  ),
                ),
              ),
              if (value != null) ...[
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 13,
                    color: Theme.of(context).brightness == Brightness.dark
                        ? Colors.white.withValues(alpha: 0.45)
                        : Colors.black45,
                  ),
                ),
                const SizedBox(width: 4),
              ],
              if (trailing != null)
                trailing
              else if (onTap != null)
                Icon(
                  Icons.chevron_right_rounded,
                  color: Theme.of(context).brightness == Brightness.dark
                      ? Colors.white.withValues(alpha: 0.30)
                      : Colors.black26,
                  size: 20,
                ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Helpers ────────────────────────────────────────────
  String _themeName(ThemeMode mode) => switch (mode) {
        ThemeMode.light => 'Clair',
        ThemeMode.dark => 'Sombre',
        ThemeMode.system => 'Auto',
      };

  String _localeName(Locale? locale) => switch (locale?.languageCode) {
        'fr' => 'Français',
        'en' => 'English',
        'es' => 'Español',
        'de' => 'Deutsch',
        'it' => 'Italiano',
        'pt' => 'Português',
        _ => 'Auto',
      };

  void _showLanguagePicker(
      BuildContext ctx, _ClipsAppState appState) {
    final opts = <(Locale?, String)>[
      (null, 'Auto (système)'),
      (const Locale('fr'), 'Français'),
      (const Locale('en'), 'English'),
      (const Locale('es'), 'Español'),
      (const Locale('de'), 'Deutsch'),
      (const Locale('it'), 'Italiano'),
      (const Locale('pt'), 'Português'),
    ];
    showModalBottomSheet(
      context: ctx,
      backgroundColor: Colors.transparent,
      builder: (_) => ClipRRect(
        borderRadius:
            const BorderRadius.vertical(top: Radius.circular(24)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
          child: Builder(
            builder: (innerCtx) {
              final isDark =
                  Theme.of(innerCtx).brightness == Brightness.dark;
              final sheetBg = isDark
                  ? const Color(0xFF120828).withValues(alpha: 0.97)
                  : Colors.white.withValues(alpha: 0.97);
              final borderColor = isDark
                  ? Colors.white.withValues(alpha: 0.10)
                  : Colors.black.withValues(alpha: 0.08);
              final handleColor = isDark
                  ? Colors.white.withValues(alpha: 0.20)
                  : Colors.black.withValues(alpha: 0.15);
              final textColor = isDark ? Colors.white : Colors.black87;
              final unselectedTextColor =
                  isDark ? Colors.white.withValues(alpha: 0.60) : Colors.black54;
              final unselectedIconColor =
                  isDark ? Colors.white.withValues(alpha: 0.60) : Colors.black45;
              return Container(
                decoration: BoxDecoration(
                  color: sheetBg,
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(24)),
                  border: Border.all(color: borderColor),
                ),
                child: SafeArea(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(height: 12),
                      Container(
                        width: 36,
                        height: 4,
                        decoration: BoxDecoration(
                          color: handleColor,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(height: 8),
                      ...opts.map((o) {
                        final (loc, name) = o;
                        final selected = appState.locale?.languageCode ==
                            loc?.languageCode;
                        return ListTile(
                          leading: Icon(
                            loc == null
                                ? Icons.phone_android_rounded
                                : Icons.language_rounded,
                            color: selected
                                ? AppTheme.accentPurple
                                : unselectedIconColor,
                          ),
                          title: Text(
                            name,
                            style: TextStyle(
                              color: selected
                                  ? AppTheme.accentPurple
                                  : textColor,
                              fontWeight: selected
                                  ? FontWeight.w700
                                  : FontWeight.w400,
                            ),
                          ),
                          trailing: selected
                              ? const Icon(Icons.check_rounded,
                                  color: AppTheme.accentPurple)
                              : null,
                          onTap: () {
                            appState.setLocale(loc);
                            Navigator.pop(ctx);
                          },
                        );
                      }),
                      const SizedBox(height: 8),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Future<void> _exportData(BuildContext ctx) async {
    final clips = widget.state.allClips;
    final jsonStr = const JsonEncoder.withIndent('  ')
        .convert(clips.map((c) => c.toMap()).toList());
    await Share.share(jsonStr, subject: 'Savid Export');
  }

  void _clearCache(BuildContext ctx) {
    PaintingBinding.instance.imageCache.clear();
    PaintingBinding.instance.imageCache.clearLiveImages();
    ScaffoldMessenger.of(ctx).showSnackBar(
      const SnackBar(
        content: Text('Cache des miniatures vidé ✓'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _launchUri(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final appState = ClipsApp.of(context)!;

    return CustomScrollView(
      slivers: [
        SliverAppBar(
          floating: true,
          backgroundColor: Colors.transparent,
          elevation: 0,
          title: Text(
            'Paramètres',
            style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 26,
                letterSpacing: -0.5,
                color: Theme.of(context).brightness == Brightness.dark
                    ? Colors.white
                    : Colors.black87),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 120),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              // ══ APPARENCE ══════════════════════════════════
              _sectionHeader('Apparence'),
              _glassGroup([
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: AppTheme.accentPurple
                                  .withValues(alpha: 0.20),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(
                                Icons.brightness_6_rounded,
                                size: 17,
                                color: AppTheme.accentPurple),
                          ),
                          const SizedBox(width: 14),
                          const Text('Thème',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w500,
                              )),
                          const Spacer(),
                          Text(
                            _themeName(appState.themeMode),
                            style: TextStyle(
                              fontSize: 13,
                              color:
                                  Theme.of(context).brightness == Brightness.dark
                                      ? Colors.white.withValues(alpha: 0.45)
                                      : Colors.black45,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      ValueListenableBuilder<ThemeMode>(
                        valueListenable: appState.themeModeNotifier,
                        builder: (context, currentMode, _) =>
                            SizedBox(
                          width: double.infinity,
                          child: SegmentedButton<ThemeMode>(
                            segments: const [
                              ButtonSegment(
                                  value: ThemeMode.light,
                                  label: Text('Clair',
                                      style: TextStyle(fontSize: 13))),
                              ButtonSegment(
                                  value: ThemeMode.dark,
                                  label: Text('Sombre',
                                      style: TextStyle(fontSize: 13))),
                              ButtonSegment(
                                  value: ThemeMode.system,
                                  label: Text('Auto',
                                      style: TextStyle(fontSize: 13))),
                            ],
                            selected: {currentMode},
                            onSelectionChanged: (s) =>
                                appState.setThemeMode(s.first),
                            style: SegmentedButton.styleFrom(
                              backgroundColor: Theme.of(context).brightness ==
                                      Brightness.dark
                                  ? Colors.white.withValues(alpha: 0.07)
                                  : Colors.black.withValues(alpha: 0.05),
                              selectedBackgroundColor: AppTheme.accentPurple,
                              selectedForegroundColor: Colors.white,
                              foregroundColor: Theme.of(context).brightness ==
                                      Brightness.dark
                                  ? Colors.white.withValues(alpha: 0.70)
                                  : Colors.black54,
                              side: BorderSide(
                                color: Theme.of(context).brightness ==
                                        Brightness.dark
                                    ? Colors.white.withValues(alpha: 0.12)
                                    : Colors.black.withValues(alpha: 0.12),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ]),
              const SizedBox(height: 24),

              // ══ LANGUE ══════════════════════════════════════
              _sectionHeader('Langue'),
              _glassGroup([
                _tile(
                  icon: Icons.language_rounded,
                  iconColor: const Color(0xFF4ECDC4),
                  label: 'Langue de l\'app',
                  value: _localeName(appState.locale),
                  onTap: () => _showLanguagePicker(context, appState),
                ),
              ]),
              const SizedBox(height: 24),

              // ══ NOTIFICATIONS ════════════════════════════════
              _sectionHeader('Notifications'),
              _glassGroup([
                _tile(
                  icon: Icons.notifications_outlined,
                  iconColor: const Color(0xFFFFE66D),
                  label: 'Rappels',
                  trailing: Switch.adaptive(
                    value: appState.notifications,
                    activeColor: AppTheme.accentPurple,
                    onChanged: (v) => appState.setNotifications(v),
                  ),
                ),
              ]),
              const SizedBox(height: 24),

              // ══ MES DONNÉES ══════════════════════════════════
              _sectionHeader('Mes données'),
              _glassGroup([
                _tile(
                  icon: Icons.download_rounded,
                  iconColor: const Color(0xFF4ECDC4),
                  label: 'Exporter mes vidéos',
                  onTap: () => _exportData(context),
                ),
                _tile(
                  icon: Icons.image_not_supported_outlined,
                  iconColor: const Color(0xFFFF8B94),
                  label: 'Vider le cache miniatures',
                  onTap: () => _clearCache(context),
                ),
              ]),
              const SizedBox(height: 24),

              // ══ LÉGAL ════════════════════════════════════════
              _sectionHeader('Légal'),
              _glassGroup([
                _tile(
                  icon: Icons.shield_outlined,
                  iconColor: const Color(0xFF74B9FF),
                  label: 'Politique de confidentialité',
                  onTap: () =>
                      _launchUri('https://example.com/savid/privacy'),
                ),
                _tile(
                  icon: Icons.description_outlined,
                  iconColor: const Color(0xFF74B9FF),
                  label: 'Conditions d\'utilisation',
                  onTap: () =>
                      _launchUri('https://example.com/savid/terms'),
                ),
                _tile(
                  icon: Icons.mail_outline_rounded,
                  iconColor: const Color(0xFFA8E6CF),
                  label: 'Contact / Support',
                  onTap: () => _launchUri('mailto:support@savid.app'),
                ),
              ]),
              const SizedBox(height: 24),

              // ══ À PROPOS ══════════════════════════════════════
              _sectionHeader('À propos'),
              _glassGroup([
                _tile(
                  icon: Icons.info_outline_rounded,
                  iconColor: Theme.of(context).brightness == Brightness.dark
                      ? Colors.white.withValues(alpha: 0.45)
                      : Colors.black45,
                  label: 'Version',
                  value: _appVersion,
                ),
                _tile(
                  icon: Icons.star_border_rounded,
                  iconColor: const Color(0xFFFFE66D),
                  label: 'Noter l\'app',
                  onTap: () => _launchUri(
                      'https://apps.apple.com/app/id000000000'),
                ),
                _tile(
                  icon: Icons.ios_share_rounded,
                  iconColor: const Color(0xFFC77DFF),
                  label: 'Partager avec un ami',
                  onTap: () => Share.share(
                    'Découvrez Savid, l\'app pour sauvegarder tes vidéos préférées ! 🎬',
                  ),
                ),
              ]),
            ]),
          ),
        ),
      ],
    );
  }
}

