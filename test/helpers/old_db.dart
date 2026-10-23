import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:reelr/services/database.dart';
import 'package:sqflite/sqflite.dart' as sq;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Colonnes attendues apres migration (identiques a _onCreate).
const Map<String, Set<String>> expectedColumns = {
  'clips': {
    'id', 'url', 'title', 'platform', 'categoryId', 'tags', 'addedAt',
    'thumbnailUrl', 'position', 'subcategoryId', 'subsubcategoryId',
    'classification_category', 'classification_confidence',
    'classification_reason', 'classification_tags', 'toBuy',
    'classification_alt', 'channel', 'description',
  },
  'categories': {'id', 'name', 'color', 'icon', 'position'},
  'subcategories': {'id', 'name', 'categoryId', 'color', 'icon', 'position'},
  'subsubcategories': {
    'id', 'name', 'subCategoryId', 'color', 'icon', 'position'
  },
};

Future<void> _createSchema(Database db, int v) async {
  final clipsCols = <String>[
    'id TEXT PRIMARY KEY',
    'url TEXT NOT NULL',
    'title TEXT NOT NULL',
    'platform TEXT NOT NULL',
    'categoryId TEXT',
    'tags TEXT',
    'addedAt TEXT NOT NULL',
    'thumbnailUrl TEXT',
    if (v >= 4) 'position INTEGER DEFAULT 0',
    if (v >= 5) 'subcategoryId TEXT',
    if (v >= 8) 'classification_category TEXT',
    if (v >= 8) 'classification_confidence INTEGER',
    if (v >= 8) 'classification_reason TEXT',
    if (v >= 8) 'classification_tags TEXT',
    if (v >= 11) 'channel TEXT',
    if (v >= 12) 'subsubcategoryId TEXT',
    if (v >= 13) 'description TEXT',
    if (v >= 18) 'toBuy INTEGER DEFAULT 0',
    if (v >= 19) 'classification_alt TEXT',
  ];
  await db.execute('CREATE TABLE clips (${clipsCols.join(', ')})');
  await db.execute('CREATE TABLE categories (id TEXT PRIMARY KEY, '
      'name TEXT NOT NULL, color INTEGER NOT NULL, icon INTEGER NOT NULL'
      '${v >= 9 ? ', position INTEGER DEFAULT 0' : ''})');
  if (v >= 5) {
    await db.execute('CREATE TABLE subcategories (id TEXT PRIMARY KEY, '
        'name TEXT NOT NULL, categoryId TEXT NOT NULL, color INTEGER NOT NULL, '
        'icon INTEGER NOT NULL, position INTEGER DEFAULT 0)');
  }
  if (v >= 12) {
    await db.execute('CREATE TABLE subsubcategories (id TEXT PRIMARY KEY, '
        'name TEXT NOT NULL, subCategoryId TEXT NOT NULL, '
        'color INTEGER NOT NULL, icon INTEGER NOT NULL, '
        'position INTEGER DEFAULT 0)');
  }
}

Map<String, Object?> cat(String id, String name) =>
    {'id': id, 'name': name, 'color': 0xFF7C3AED, 'icon': 0xe2a3};

Map<String, Object?> clip(String id, String? categoryId) => {
      'id': id,
      'url': 'https://example.com/$id',
      'title': 'Titre $id',
      'platform': 'youtube',
      'categoryId': categoryId,
      'addedAt': '2026-01-01T00:00:00.000',
    };

/// Cree une base a l'ancienne version [from], y met des donnees, puis
/// ouvre la base avec le code ACTUEL (migrations) et verifie que rien n'est
/// perdu ni casse. [extra] permet des verifications propres a un scenario.
Future<void> checkUpgrade({
  required int from,
  required List<Map<String, Object?>> categories,
  required List<Map<String, Object?>> clips,
  Future<void> Function(Database db)? extra,
}) async {
  sqfliteFfiInit();
  sq.databaseFactory = databaseFactoryFfi;
  final dir = await Directory.systemTemp.createTemp('reelr_mig_');
  await databaseFactoryFfi.setDatabasesPath(dir.path);
  final file = p.join(dir.path, 'clips.db');

  // 1) Base « telle que l'avait un client de l'epoque ».
  final old = await databaseFactoryFfi.openDatabase(
    file,
    options: OpenDatabaseOptions(
      version: from,
      onCreate: (db, _) => _createSchema(db, from),
    ),
  );
  for (final c in categories) {
    final row = Map<String, Object?>.from(c);
    if (from < 9) row.remove('position');
    await old.insert('categories', row);
  }
  for (final c in clips) {
    await old.insert('clips', c);
  }
  await old.close();

  // 2) Ouverture par le code actuel = migrations.
  final db = await DatabaseHelper.instance.database;
  expect(await db.getVersion(), 19);

  // Aucun clip perdu.
  final countRows = await db.rawQuery('SELECT COUNT(*) AS n FROM clips');
  final count = countRows.first['n'] as int;
  expect(count, clips.length, reason: 'des clips ont disparu');

  // Memes colonnes qu'une installation neuve.
  for (final entry in expectedColumns.entries) {
    final info = await db.rawQuery('PRAGMA table_info(${entry.key})');
    final cols = info.map((r) => r['name'] as String).toSet();
    expect(cols, entry.value, reason: 'colonnes de ${entry.key}');
  }

  // Aucun clip orphelin (categorie inexistante).
  final orphans = await db.rawQuery('SELECT id FROM clips WHERE '
      'categoryId IS NOT NULL AND categoryId NOT IN (SELECT id FROM categories)');
  expect(orphans, isEmpty, reason: 'clips orphelins');

  // L'appli sait relire tous les clips.
  final all = await DatabaseHelper.instance.getAllClips();
  expect(all.length, clips.length);

  if (extra != null) await extra(db);
  await db.close();
}
