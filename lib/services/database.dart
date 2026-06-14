import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:path/path.dart' as path_helper;
import 'package:sqflite/sqflite.dart';

import '../models/category.dart';
import '../models/clip.dart';

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
          version: 9, onCreate: _onCreate, onUpgrade: _onUpgrade);
    }
    final dbPath = await getDatabasesPath();
    final fullPath = path_helper.join(dbPath, 'clips.db');
    return openDatabase(fullPath,
      version: 9, onCreate: _onCreate, onUpgrade: _onUpgrade);
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    // ── Migrations structurelles uniquement (jamais de DELETE sur categories) ──
    if (oldVersion < 4) {
      await db.execute(
          'ALTER TABLE clips ADD COLUMN position INTEGER DEFAULT 0');
    }
    if (oldVersion < 5) {
      await db.execute(
          'ALTER TABLE clips ADD COLUMN subcategoryId TEXT');
      await db.execute('''
        CREATE TABLE IF NOT EXISTS subcategories (
          id TEXT PRIMARY KEY,
          name TEXT NOT NULL,
          categoryId TEXT NOT NULL,
          color INTEGER NOT NULL,
          icon INTEGER NOT NULL,
          position INTEGER DEFAULT 0
        )
      ''');
    }
    if (oldVersion < 6) {
      // Supprime uniquement les anciennes catégories par défaut obsolètes
      // sans toucher aux catégories créées par l'utilisateur ou l'IA.
      const oldIds = [
        'default_recettes',
        'default_yoga',
        'default_moto',
        'default_voyage',
        'default_musique',
        'default_sport',
      ];
      for (final id in oldIds) {
        final rows = await db.query('categories',
            where: 'id = ?', whereArgs: [id], limit: 1);
        if (rows.isNotEmpty) {
          await db.delete('categories', where: 'id = ?', whereArgs: [id]);
          await db.update('clips', {'categoryId': null},
              where: 'categoryId = ?', whereArgs: [id]);
        }
      }
    }
    if (oldVersion < 7) {
      // Corrige les icônes des catégories créées automatiquement par l'IA
      // qui avaient été sauvegardées avec l'icône générique folder_outlined.
      final iconFixes = <String, int>{
        'Bébé':          Icons.child_care_rounded.codePoint,
        'Humour':        Icons.sentiment_very_satisfied_rounded.codePoint,
        'Musique':       Icons.music_note_rounded.codePoint,
        'Beauté':        Icons.brush_rounded.codePoint,
        'Voyage':        Icons.flight_takeoff_rounded.codePoint,
        'Moto/Auto':     Icons.two_wheeler_rounded.codePoint,
        'Yoga':          Icons.self_improvement_rounded.codePoint,
        'Tricot/Couture':Icons.content_cut_rounded.codePoint,
        'Gaming':        Icons.sports_esports_rounded.codePoint,
        'Sport':         Icons.fitness_center_rounded.codePoint,
        'Food':          Icons.restaurant_rounded.codePoint,
      };
      for (final entry in iconFixes.entries) {
        await db.update(
          'categories',
          {'icon': entry.value},
          where: 'name = ? AND icon = ?',
          whereArgs: [entry.key, Icons.folder_outlined.codePoint],
        );
      }
    }
    if (oldVersion < 8) {
      await db.execute(
        'ALTER TABLE clips ADD COLUMN classification_category TEXT');
      await db.execute(
        'ALTER TABLE clips ADD COLUMN classification_confidence INTEGER');
      await db.execute(
        'ALTER TABLE clips ADD COLUMN classification_reason TEXT');
      await db.execute(
        'ALTER TABLE clips ADD COLUMN classification_tags TEXT');
    }
    await _seedDefaultCategories(db);
  }

  Future<void> _seedDefaultCategories(Database db) async {
    for (final cat in _defaultCategories) {
      await db.insert('categories', cat.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace);
    }
  }

  static final List<ClipCategory> _defaultCategories = [
    const ClipCategory(id: 'cat_food',      name: 'Food',              color: Color(0xFFFF6B6B), icon: Icons.restaurant_rounded),
    const ClipCategory(id: 'cat_fitness',   name: 'Fitness',           color: Color(0xFF4ECDC4), icon: Icons.fitness_center_rounded),
    const ClipCategory(id: 'cat_gaming',    name: 'Gaming',            color: Color(0xFF74B9FF), icon: Icons.sports_esports_rounded),
    const ClipCategory(id: 'cat_beauty',    name: 'Beauty',            color: Color(0xFFFF85B3), icon: Icons.brush_rounded),
    const ClipCategory(id: 'cat_mode',      name: 'Mode',              color: Color(0xFFC77DFF), icon: Icons.style_rounded),
    const ClipCategory(id: 'cat_travel',    name: 'Travel',            color: Color(0xFF81ECEC), icon: Icons.flight_takeoff_rounded),
    const ClipCategory(id: 'cat_tech',      name: 'Tech',              color: Color(0xFF6C5CE7), icon: Icons.computer_rounded),
    const ClipCategory(id: 'cat_humour',    name: 'Humour',            color: Color(0xFFFFE66D), icon: Icons.sentiment_very_satisfied_rounded),
    const ClipCategory(id: 'cat_musique',   name: 'Musique',           color: Color(0xFFFF7675), icon: Icons.music_note_rounded),
    const ClipCategory(id: 'cat_wellness',  name: 'Wellness',          color: Color(0xFFA8E6CF), icon: Icons.self_improvement_rounded),
    const ClipCategory(id: 'cat_podcast',   name: 'Podcast',           color: Color(0xFFB2BEC3), icon: Icons.mic_rounded),
    const ClipCategory(id: 'cat_famille',   name: 'Famille',           color: Color(0xFFFD79A8), icon: Icons.family_restroom_rounded),
    const ClipCategory(id: 'cat_finance',   name: 'Finance & Business',color: Color(0xFF00B894), icon: Icons.trending_up_rounded),
    const ClipCategory(id: 'cat_actu',      name: 'Actu & Societe',    color: Color(0xFF636E72), icon: Icons.newspaper_rounded),
    const ClipCategory(id: 'cat_diy',       name: 'DIY & Crea',        color: Color(0xFFE17055), icon: Icons.brush_outlined),
    const ClipCategory(id: 'cat_deco',      name: 'Deco & Home',       color: Color(0xFFFAB1A0), icon: Icons.home_rounded),
    const ClipCategory(id: 'cat_auto',      name: 'Auto & Moto',       color: Color(0xFF2D3436), icon: Icons.directions_car_rounded),
    const ClipCategory(id: 'cat_culture',   name: 'Culture',           color: Color(0xFF8E44AD), icon: Icons.theater_comedy_rounded),
    const ClipCategory(id: 'cat_cinema',    name: 'Cinema & Series',   color: Color(0xFF2C3E50), icon: Icons.movie_rounded),
    const ClipCategory(id: 'cat_growth',    name: 'Growth',            color: Color(0xFF27AE60), icon: Icons.rocket_launch_rounded),
    const ClipCategory(id: 'cat_pets',      name: 'Pets & Nature',     color: Color(0xFF16A085), icon: Icons.pets_rounded),
    const ClipCategory(id: 'cat_truecrime', name: 'True Crime',        color: Color(0xFF922B21), icon: Icons.gavel_rounded),
    const ClipCategory(id: 'cat_astro',     name: 'Astro & Spirituel', color: Color(0xFF1A237E), icon: Icons.auto_awesome_rounded),
    const ClipCategory(id: 'cat_vibes',     name: 'Vibes',             color: Color(0xFFFFE66D), icon: Icons.explore_rounded),
  ];

  static const Map<String, IconData> categoryIcons = {
    'cat_food':      Icons.restaurant_rounded,
    'cat_fitness':   Icons.fitness_center_rounded,
    'cat_gaming':    Icons.sports_esports_rounded,
    'cat_beauty':    Icons.brush_rounded,
    'cat_mode':      Icons.style_rounded,
    'cat_travel':    Icons.flight_takeoff_rounded,
    'cat_tech':      Icons.computer_rounded,
    'cat_humour':    Icons.sentiment_very_satisfied_rounded,
    'cat_musique':   Icons.music_note_rounded,
    'cat_wellness':  Icons.self_improvement_rounded,
    'cat_podcast':   Icons.mic_rounded,
    'cat_famille':   Icons.family_restroom_rounded,
    'cat_finance':   Icons.trending_up_rounded,
    'cat_actu':      Icons.newspaper_rounded,
    'cat_diy':       Icons.brush_outlined,
    'cat_deco':      Icons.home_rounded,
    'cat_auto':      Icons.directions_car_rounded,
    'cat_culture':   Icons.theater_comedy_rounded,
    'cat_cinema':    Icons.movie_rounded,
    'cat_growth':    Icons.rocket_launch_rounded,
    'cat_pets':      Icons.pets_rounded,
    'cat_truecrime': Icons.gavel_rounded,
    'cat_astro':     Icons.auto_awesome_rounded,
    'cat_vibes':     Icons.explore_rounded,
  };

  static IconData? iconFor(String id) => categoryIcons[id];

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
        position INTEGER DEFAULT 0,
        subcategoryId TEXT,
        classification_category TEXT,
        classification_confidence INTEGER,
        classification_reason TEXT,
        classification_tags TEXT
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
    await db.execute('''
      CREATE TABLE subcategories (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        categoryId TEXT NOT NULL,
        color INTEGER NOT NULL,
        icon INTEGER NOT NULL,
        position INTEGER DEFAULT 0
      )
    ''');
    // Vision Reelr : aucune catégorie pré-créée.
  }

  Future<List<Clip>> getAllClips() async {
    final db = await database;
    final maps = await db.query('clips', orderBy: 'position ASC, addedAt DESC');
    return maps.map(Clip.fromMap).toList();
  }

  Future<void> updateClipPositions(List<Map<String, dynamic>> updates) async {
    final db = await database;
    final batch = db.batch();
    for (final u in updates) {
      batch.update('clips', {'position': u['position'] as int},
          where: 'id = ?', whereArgs: [u['id'] as String]);
    }
    await batch.commit(noResult: true);
  }

  Future<void> insertClip(Clip clip) async {
    final db = await database;
    await db.insert('clips', clip.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> updateClipClassification({
    required String clipId,
    required String category,
    required int confidence,
    required String reason,
    required List<String> tags,
  }) async {
    final db = await database;
    await db.update(
      'clips',
      {
        'classification_category': category,
        'classification_confidence': confidence,
        'classification_reason': reason,
        'classification_tags': tags.join(','),
      },
      where: 'id = ?',
      whereArgs: [clipId],
    );
  }

  Future<void> updateClip({
    required String clipId,
    String? categoryId,
  }) async {
    final db = await database;
    await db.update(
      'clips',
      {'categoryId': categoryId},
      where: 'id = ?',
      whereArgs: [clipId],
    );
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

  Future<List<Map<String, dynamic>>> getAllSubCategories() async {
    final db = await database;
    return db.query('subcategories', orderBy: 'position ASC');
  }

  Future<List<Map<String, dynamic>>> getSubCategories(String categoryId) async {
    final db = await database;
    return db.query('subcategories',
        where: 'categoryId = ?',
        whereArgs: [categoryId],
        orderBy: 'position ASC');
  }

  Future<void> insertSubCategory(Map<String, dynamic> sub) async {
    final db = await database;
    await db.insert('subcategories', sub,
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> deleteSubCategory(String id) async {
    final db = await database;
    await db.delete('subcategories', where: 'id = ?', whereArgs: [id]);
    await db.update('clips', {'subcategoryId': null},
        where: 'subcategoryId = ?', whereArgs: [id]);
  }

  Future<void> setClipSubcategory(String clipId, String? subcategoryId) async {
    final db = await database;
    await db.update('clips', {'subcategoryId': subcategoryId},
        where: 'id = ?', whereArgs: [clipId]);
  }

  Future<void> moveClipsToCategoryBatch({
    required List<String> clipIds,
    required String toCategoryId,
    String? toSubcategoryId,
  }) async {
    if (clipIds.isEmpty) return;
    final db = await database;
    final batch = db.batch();

    for (final clipId in clipIds) {
      batch.update(
        'clips',
        {
          'categoryId': toCategoryId,
          'subcategoryId': toSubcategoryId,
        },
        where: 'id = ?',
        whereArgs: [clipId],
      );
    }

    await batch.commit(noResult: true);
  }

  Future<Map<String, String>> getClipSubcategoryMapAll() async {
    final db = await database;
    final maps = await db.query('clips',
        columns: ['id', 'subcategoryId'],
        where: 'subcategoryId IS NOT NULL');
    return {for (final m in maps) m['id'] as String: m['subcategoryId'] as String};
  }
}
