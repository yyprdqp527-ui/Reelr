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
          version: 8, onCreate: _onCreate, onUpgrade: _onUpgrade);
    }
    final dbPath = await getDatabasesPath();
    final fullPath = path_helper.join(dbPath, 'clips.db');
    return openDatabase(fullPath,
      version: 8, onCreate: _onCreate, onUpgrade: _onUpgrade);
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
    // Vision Reelr : aucune catégorie pré-créée — elles naissent au fil des partages.
  }

  // ignore: unused_element
  Future<void> _seedDefaultCategories(Database db) async {
    for (final cat in _defaultCategories) {
      await db.insert('categories', cat.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace);
    }
  }

  // ignore: unused_field
  static final List<ClipCategory> _defaultCategories = [
    const ClipCategory(
      id: 'default_food',
      name: 'Food',
      color: Color(0xFFFF6B6B),
      icon: Icons.restaurant_outlined,
    ),
    const ClipCategory(
      id: 'default_workout',
      name: 'Workout',
      color: Color(0xFF4ECDC4),
      icon: Icons.fitness_center_outlined,
    ),
    const ClipCategory(
      id: 'default_vibes',
      name: 'Vibes',
      color: Color(0xFFFFE66D),
      icon: Icons.explore_outlined,
    ),
    const ClipCategory(
      id: 'default_wellness',
      name: 'Wellness',
      color: Color(0xFFA8E6CF),
      icon: Icons.self_improvement_outlined,
    ),
    const ClipCategory(
      id: 'default_inspo',
      name: 'Inspo',
      color: Color(0xFFC77DFF),
      icon: Icons.style_outlined,
    ),
    const ClipCategory(
      id: 'default_gaming',
      name: 'Gaming',
      color: Color(0xFF74B9FF),
      icon: Icons.sports_esports_outlined,
    ),
  ];

  /// Icône Material affichée dans la grille pour chaque catégorie par défaut.
  static const Map<String, IconData> categoryIcons = {
    'default_food': Icons.restaurant_outlined,
    'default_workout': Icons.fitness_center_outlined,
    'default_vibes': Icons.explore_outlined,
    'default_wellness': Icons.self_improvement_outlined,
    'default_inspo': Icons.style_outlined,
    'default_gaming': Icons.sports_esports_outlined,
  };

  /// Icônes pour les catégories créées automatiquement par l'IA.
  static const Map<String, IconData> aiCategoryIcons = {
    'ai_food': Icons.restaurant_rounded,
    'ai_sport': Icons.fitness_center_rounded,
    'ai_yoga': Icons.self_improvement_rounded,
    'ai_moto': Icons.two_wheeler_rounded,
    'ai_voyage': Icons.flight_takeoff_rounded,
    'ai_musique': Icons.music_note_rounded,
    'ai_tricot': Icons.content_cut_rounded,
    'ai_bebe': Icons.child_care_rounded,
    'ai_humour': Icons.sentiment_very_satisfied_rounded,
    'ai_beaute': Icons.brush_rounded,
    'ai_mode': Icons.style_rounded,
  };

  /// Lookup unifié (catégories par défaut + IA).
  static IconData? iconFor(String id) =>
      categoryIcons[id] ?? aiCategoryIcons[id];

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
    var maps = await db.query('categories');
    // Si aucune cat_xxx en DB, on reseed
    final hasNew = maps.any((m) => (m['id'] as String).startsWith('cat_'));
    if (!hasNew) {
      await _seedDefaultCategories(db);
      maps = await db.query('categories');
    }
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
