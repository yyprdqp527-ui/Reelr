import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:path/path.dart' as path_helper;
import 'package:sqflite/sqflite.dart';

import '../models/category.dart';
import '../models/clip.dart';
import '../core/l10n.dart';

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
          version: 16, onCreate: _onCreate, onUpgrade: _onUpgrade);
    }
    final dbPath = await getDatabasesPath();
    final fullPath = path_helper.join(dbPath, 'clips.db');
    return openDatabase(fullPath,
      version: 16, onCreate: _onCreate, onUpgrade: _onUpgrade);
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
    if (oldVersion < 9) {
      await db.execute(
          'ALTER TABLE categories ADD COLUMN position INTEGER DEFAULT 0');
      // Initialise les positions selon l'ordre actuel (rowid = ordre d'insertion)
      final existing = await db.query('categories', orderBy: 'rowid ASC');
      for (var i = 0; i < existing.length; i++) {
        await db.update('categories', {'position': i},
            where: 'id = ?', whereArgs: [existing[i]['id']]);
      }
    }
    if (oldVersion < 10) {
      // Supprime les catégories par défaut uniquement si elles sont vides
      // (aucun clip dedans) — ne touche pas à celles utilisées par l'utilisateur.
      const defaultIds = [
        'default_food',
        'default_workout',
        'default_vibes',
        'default_wellness',
        'default_inspo',
        'default_gaming',
      ];
      for (final id in defaultIds) {
        final clipCount = Sqflite.firstIntValue(await db.rawQuery(
            'SELECT COUNT(*) FROM clips WHERE categoryId = ?', [id]));
        if ((clipCount ?? 0) == 0) {
          await db.delete('categories', where: 'id = ?', whereArgs: [id]);
        }
      }
    }
    if (oldVersion < 11) {
      await db.execute('ALTER TABLE clips ADD COLUMN channel TEXT');
    }
    if (oldVersion < 12) {
      await db.execute(
          'ALTER TABLE clips ADD COLUMN subsubcategoryId TEXT');
      await db.execute('''
        CREATE TABLE IF NOT EXISTS subsubcategories (
          id TEXT PRIMARY KEY,
          name TEXT NOT NULL,
          subCategoryId TEXT NOT NULL,
          color INTEGER NOT NULL,
          icon INTEGER NOT NULL,
          position INTEGER DEFAULT 0
        )
      ''');
    }
    if (oldVersion < 13) {
      // La description publique etait deja recuperee a l'hydratation puis
      // jetee : le classifieur recevait un VideoData sans description alors
      // que le prompt sait la lire. On la persiste pour la lui rendre.
      // Les clips existants restent a NULL, sans refetch.
      await db.execute('ALTER TABLE clips ADD COLUMN description TEXT');
    }
    if (oldVersion < 14) {
      // Fusionne les categories qui designent la meme chose dans deux
      // langues differentes (typiquement "Food" cree par l'IA a cote d'une
      // "Recette" plus ancienne : Claude repond toujours dans la langue
      // fixee par son prompt, pas dans celle de l'app -> voir
      // `AppL10n.canonicalCategoryId`). Generalise a tout le catalogue
      // standard, pas seulement a Food/Recette.
      await _mergeLanguageDuplicateCategories(db);
    }
    if (oldVersion < 15) {
      // Meme bug racine que la fusion ci-dessus, cote visuel cette fois :
      // avant le correctif, une categorie creee par l'IA ne retrouvait
      // jamais sa couleur/icone officielle (la cle de recherche etait le
      // libelle brut de Claude, ex. "Crochet", alors que les tables de
      // correspondance sont indexees par ID `cat_xxx`) et retombait
      // systematiquement sur le violet + dossier generique. Le correctif
      // empeche que ça se reproduise pour les nouvelles categories, mais ne
      // repare pas retroactivement celles deja enregistrees ainsi — d'ou
      // cette passe unique.
      await _repairGenericCategoryVisuals(db);
    }
    if (oldVersion < 16) {
      // Nouvelle passe de fusion avec la comparaison elargie (accents,
      // pluriels, synonymes stricts) : « Beaute » + « Beauté »,
      // « Workout » + « Fitness », « Actu » + « Actualités »... ainsi que
      // deux categories personnelles au nom identique a l'accent pres.
      await _mergeLanguageDuplicateCategories(db);
    }
    // Vision Reelr : aucune catégorie pré-créée — elles naissent au fil des partages.
  }

  /// Redonne sa couleur/icone officielle a toute categorie existante encore
  /// bloquee sur le violet/dossier generique (`0xFF7C3AED` +
  /// `Icons.folder_rounded`), quand son ID ou son nom correspond a une
  /// categorie standard reconnue. Ne touche a rien d'autre : une categorie
  /// personnalisee que l'utilisateur a lui-meme mise en violet/dossier
  /// n'a aucune raison de correspondre en plus a un nom standard, donc ne
  /// sera jamais modifiee par erreur.
  Future<void> _repairGenericCategoryVisuals(Database db) async {
    const genericColor = 0xFF7C3AED; // Color(0xFF7C3AED).toARGB32()
    final genericIcon = Icons.folder_rounded.codePoint;
    final rows = await db.query('categories',
        where: 'color = ? AND icon = ?',
        whereArgs: [genericColor, genericIcon]);
    for (final row in rows) {
      final id = row['id'] as String;
      final name = (row['name'] as String?) ?? '';
      final canonicalId =
          id.startsWith('cat_') ? id : AppL10n.canonicalCategoryId(name);
      if (canonicalId == null) continue;
      final color = AppL10n.categoryColors[canonicalId];
      final icon = AppL10n.categoryIcons[canonicalId];
      if (color == null || icon == null) continue;
      await db.update(
        'categories',
        {'color': color.toARGB32(), 'icon': icon.codePoint},
        where: 'id = ?',
        whereArgs: [id],
      );
    }
  }

  /// Regroupe les categories existantes par ID canonique `cat_xxx` (deduit
  /// de l'ID lui-meme s'il est deja canonique, sinon du nom affiche via
  /// `AppL10n.canonicalCategoryId`). Pour chaque groupe de 2+ categories
  /// designant la meme chose, garde celle qui a le plus de clips (a egalite,
  /// celle dont l'ID est deja canonique), lui rattache les clips et
  /// sous-categories des autres, puis supprime les doublons. Ignore toute
  /// categorie qui ne correspond a aucun nom standard reconnu : les
  /// categories entierement personnalisees de l'utilisateur restent
  /// intactes, jamais fusionnees entre elles.
  Future<void> _mergeLanguageDuplicateCategories(Database db) async {
    final rows = await db.query('categories');
    final groups = <String, List<Map<String, Object?>>>{};
    for (final row in rows) {
      final id = row['id'] as String;
      final name = (row['name'] as String?) ?? '';
      final canonicalId =
          id.startsWith('cat_') ? id : AppL10n.canonicalCategoryId(name);
      // Categorie personnelle : regroupee seulement avec une autre au nom
      // IDENTIQUE a l'accent, la casse et au pluriel pres. Deux categories
      // personnelles differentes ne sont jamais fusionnees.
      final key = canonicalId ??
          'custom:${AppL10n.normalizeCategoryLabel(name)}';
      if (key == 'custom:') continue;
      groups.putIfAbsent(key, () => []).add(row);
    }
    for (final group in groups.values) {
      if (group.length < 2) continue;
      var winner = group.first;
      var winnerCount = Sqflite.firstIntValue(await db.rawQuery(
              'SELECT COUNT(*) FROM clips WHERE categoryId = ?',
              [winner['id']])) ??
          0;
      for (final cat in group.skip(1)) {
        final count = Sqflite.firstIntValue(await db.rawQuery(
                'SELECT COUNT(*) FROM clips WHERE categoryId = ?',
                [cat['id']])) ??
            0;
        final catIsCanonical = (cat['id'] as String).startsWith('cat_');
        final winnerIsCanonical = (winner['id'] as String).startsWith('cat_');
        final better = count > winnerCount ||
            (count == winnerCount && catIsCanonical && !winnerIsCanonical);
        if (better) {
          winner = cat;
          winnerCount = count;
        }
      }
      for (final loser in group) {
        final loserId = loser['id'] as String;
        if (loserId == winner['id']) continue;
        await db.update('clips', {'categoryId': winner['id']},
            where: 'categoryId = ?', whereArgs: [loserId]);
        await db.update('subcategories', {'categoryId': winner['id']},
            where: 'categoryId = ?', whereArgs: [loserId]);
        await db.delete('categories', where: 'id = ?', whereArgs: [loserId]);
      }
    }
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
        subsubcategoryId TEXT,
        classification_category TEXT,
        classification_confidence INTEGER,
        classification_reason TEXT,
        classification_tags TEXT,
        channel TEXT,
        description TEXT
      )
    ''');
    await db.execute('''
      CREATE TABLE categories (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        color INTEGER NOT NULL,
        icon INTEGER NOT NULL,
        position INTEGER DEFAULT 0
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
    await db.execute('''
      CREATE TABLE subsubcategories (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        subCategoryId TEXT NOT NULL,
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

  /// Insertion d'un clip NEUF. `replace` ecrase la ligne entiere : reserve
  /// donc a la creation, ou il n'y a rien a preserver. Pour modifier un clip
  /// existant, passer par `upsertClip`.
  Future<void> insertClip(Clip clip) async {
    final db = await database;
    await db.insert('clips', clip.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  /// Met a jour un clip sans detruire les colonnes que `Clip.toMap()` ne porte
  /// pas. La table compte 16 colonnes, `toMap()` en connait 11 : passer par
  /// `insertClip` (DELETE + INSERT) remettait les 5 autres a NULL a chaque
  /// modification, y compris pour un simple renommage.
  ///
  /// Etaient perdus : `subcategoryId` et `subsubcategoryId` (ecrits a part par
  /// `setClipSubcategory`), et les quatre colonnes `classification_*` du
  /// journal de decision. Cette derniere perte etait la plus couteuse :
  /// `classification_category` retient ce que la machine avait predit, et
  /// c'est en le comparant a la categorie choisie par l'utilisateur qu'on
  /// reconnait une correction. Le geste de correction effacait donc sa propre
  /// preuve.
  ///
  /// `UPDATE` ne touche que les colonnes citees. Repli sur insertion si la
  /// ligne n'existe pas encore, pour rester sur d'un appelant qui se tromperait.
  Future<void> upsertClip(Clip clip) async {
    final db = await database;
    final map = clip.toMap();
    final rows = await db.update(
      'clips',
      map,
      where: 'id = ?',
      whereArgs: [clip.id],
    );
    if (rows == 0) {
      await db.insert('clips', map,
          conflictAlgorithm: ConflictAlgorithm.replace);
    }
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

  /// Lit le journal de classification d'un clip : quelle couche a tranche,
  /// avec quelle confiance et pourquoi. Lecture seule, aucun effet de bord.
  /// Sert au diagnostic depuis l'interface.
  Future<Map<String, Object?>?> getClassificationDiagnostic(
      String clipId) async {
    final db = await database;
    final rows = await db.query(
      'clips',
      columns: [
        'classification_category',
        'classification_confidence',
        'classification_reason',
        'classification_tags',
      ],
      where: 'id = ?',
      whereArgs: [clipId],
      limit: 1,
    );
    return rows.isEmpty ? null : rows.first;
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
    final maps = await db.query('categories', orderBy: 'position ASC');
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

  Future<List<Map<String, dynamic>>> getAllSubSubCategories() async {
    final db = await database;
    return db.query('subsubcategories', orderBy: 'position ASC');
  }

  Future<List<Map<String, dynamic>>> getSubSubCategories(
      String subCategoryId) async {
    final db = await database;
    return db.query('subsubcategories',
        where: 'subCategoryId = ?',
        whereArgs: [subCategoryId],
        orderBy: 'position ASC');
  }

  Future<void> insertSubSubCategory(Map<String, dynamic> subSub) async {
    final db = await database;
    await db.insert('subsubcategories', subSub,
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> deleteSubSubCategory(String id) async {
    final db = await database;
    await db.delete('subsubcategories', where: 'id = ?', whereArgs: [id]);
    await db.update('clips', {'subsubcategoryId': null},
        where: 'subsubcategoryId = ?', whereArgs: [id]);
  }

  Future<void> setClipSubSubcategory(
      String clipId, String? subSubcategoryId) async {
    final db = await database;
    await db.update('clips', {'subsubcategoryId': subSubcategoryId},
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

  /// Journal de classification de tous les clips, en une seule requete.
  /// Sert a l'export : pendant la relecture, savoir ce que la machine avait
  /// predit, avec quelle confiance et par quelle couche, permet de porter
  /// l'attention sur les cas ou elle hesitait plutot que de tout relire a plat.
  Future<Map<String, Map<String, Object?>>> getClassificationJournalAll() async {
    final db = await database;
    final maps = await db.query('clips', columns: [
      'id',
      'classification_category',
      'classification_confidence',
      'classification_reason',
    ]);
    return {for (final m in maps) m['id'] as String: m};
  }

  Future<Map<String, String>> getClipSubSubcategoryMapAll() async {
    final db = await database;
    final maps = await db.query('clips',
        columns: ['id', 'subsubcategoryId'],
        where: 'subsubcategoryId IS NOT NULL');
    return {
      for (final m in maps)
        m['id'] as String: m['subsubcategoryId'] as String
    };
  }
}
