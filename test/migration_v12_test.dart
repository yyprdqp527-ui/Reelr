import 'package:flutter_test/flutter_test.dart';
import 'helpers/old_db.dart';

// Client v12 avec deux categories qui designent la meme chose (FR/EN).
void main() {
  test('migration depuis la base v12 (doublons Food / Recette)', () async {
    await checkUpgrade(
      from: 12,
      categories: [
        {...cat('ai_food', 'Food'), 'position': 0},
        {...cat('rec1', 'Recette'), 'position': 1},
        {...cat('perso', 'Ma categorie perso'), 'position': 2},
      ],
      clips: [
        clip('b1', 'ai_food'),
        clip('b2', 'rec1'),
        clip('b3', 'rec1'),
        clip('b4', 'rec1'),
        clip('b5', 'perso'),
      ],
      extra: (db) async {
        final names = (await db.query('categories'))
            .map((r) => r['name'] as String)
            .toList();
        final food = names.where((n) => n == 'Food' || n == 'Recette');
        expect(food.length, 1, reason: 'doublons non fusionnes : $names');
        expect(names, contains('Ma categorie perso'));
      },
    );
  });
}
