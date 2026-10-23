import 'package:flutter_test/flutter_test.dart';
import 'helpers/old_db.dart';

// Tres vieux client (base v3) -> version actuelle.
void main() {
  test('migration depuis la base v3', () async {
    await checkUpgrade(
      from: 3,
      categories: [
        cat('default_food', 'Food'),
        cat('default_yoga', 'Yoga'),
        cat('mine1', 'Mes recettes'),
      ],
      clips: [
        clip('a1', 'default_food'),
        clip('a2', 'default_yoga'),
        clip('a3', 'mine1'),
        clip('a4', 'mine1'),
        clip('a5', null),
      ],
    );
  });
}
