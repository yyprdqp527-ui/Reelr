import 'package:flutter_test/flutter_test.dart';
import 'helpers/old_db.dart';

// Une passe de nettoyage qui plante (ici : l'ajout de cat_business est
// refuse) ne doit PAS empecher l'ouverture : la base passe en v19 et les
// clips restent intacts.
void main() {
  test('une migration de nettoyage en echec ne bloque pas l\'ouverture',
      () async {
    await checkUpgrade(
      from: 16,
      categories: [
        {...cat('cat_entrepreneuriat', 'Entrepreneuriat'), 'position': 0},
      ],
      clips: [
        clip('d1', 'cat_entrepreneuriat'),
        clip('d2', 'cat_entrepreneuriat'),
      ],
      beforeUpgrade: (old) async {
        await old.execute('CREATE TRIGGER boom BEFORE INSERT ON categories '
            "WHEN NEW.id = 'cat_business' "
            "BEGIN SELECT RAISE(ABORT, 'boom'); END");
      },
      extra: (db) async {
        final rows = await db.query('clips',
            where: 'categoryId = ?', whereArgs: ['cat_entrepreneuriat']);
        expect(rows.length, 2, reason: 'les clips doivent rester ranges');
      },
    );
  });
}
