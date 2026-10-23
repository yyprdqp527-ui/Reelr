import 'package:flutter_test/flutter_test.dart';
import 'helpers/old_db.dart';

// Client des versions 1.0.7 / 1.0.8 (base v16) -> version actuelle.
void main() {
  test('migration depuis la base v16 (Entrepreneuriat -> Business)', () async {
    await checkUpgrade(
      from: 16,
      categories: [
        {...cat('cat_entrepreneuriat', 'Entrepreneuriat'), 'position': 0},
        {...cat('cat_food', 'Recette'), 'position': 1},
      ],
      clips: [
        clip('c1', 'cat_entrepreneuriat'),
        clip('c2', 'cat_entrepreneuriat'),
        clip('c3', 'cat_food'),
      ],
      extra: (db) async {
        final ids = (await db.query('categories'))
            .map((r) => r['id'] as String)
            .toList();
        expect(ids, isNot(contains('cat_entrepreneuriat')));
        expect(ids, contains('cat_business'));
        final moved = await db
            .query('clips', where: 'categoryId = ?', whereArgs: ['cat_business']);
        expect(moved.length, 2);
      },
    );
  });
}
