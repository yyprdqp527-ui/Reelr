import 'package:flutter_test/flutter_test.dart';
import 'package:reelr/core/l10n.dart';
import 'package:reelr/core/tile_families.dart';

void main() {
  group('Table des tuiles meres', () {
    test('33 themes repartis dans 17 tuiles meres', () {
      expect(TileFamilies.parentOf.length, 33);
      expect(TileFamilies.parentOf.values.toSet().length, 17);
    });

    test('pas de chaine : une tuile mere n\'est jamais un theme', () {
      for (final parent in TileFamilies.parentOf.values) {
        expect(TileFamilies.parentOf.containsKey(parent), isFalse,
            reason: '$parent est a la fois mere et theme');
      }
    });

    test('tous les ids ont un nom dans le catalogue', () {
      for (final e in TileFamilies.parentOf.entries) {
        expect(AppL10n.standardCategoryName(e.key), isNotNull, reason: e.key);
        expect(AppL10n.standardCategoryName(e.value), isNotNull,
            reason: e.value);
      }
      for (final id in TileFamilies.extraParents) {
        expect(AppL10n.standardCategoryName(id), isNotNull, reason: id);
        expect(AppL10n.categoryColors.containsKey(id), isTrue, reason: id);
        expect(AppL10n.categoryIcons.containsKey(id), isTrue, reason: id);
      }
    });

    test('les tuiles qui restent seules ne sont pas dans la table', () {
      const singles = [
        'cat_restaurant', 'cat_jardin', 'cat_immo', 'cat_deco', 'cat_photo',
        'cat_religion', 'cat_travel', 'cat_nature', 'cat_pets', 'cat_shopping',
        'cat_gaming', 'cat_humour', 'cat_musique', 'cat_tech',
      ];
      for (final id in singles) {
        expect(TileFamilies.parentOf.containsKey(id), isFalse, reason: id);
      }
    });

    test('exemples de la liste validee', () {
      expect(TileFamilies.parentIdOf('cat_patisserie'), 'cat_food');
      expect(TileFamilies.parentIdOf('cat_cosplay'), 'cat_manga');
      expect(TileFamilies.parentIdOf('cat_design'), 'cat_art');
      expect(TileFamilies.parentIdOf('cat_societe'), 'cat_actu');
      expect(TileFamilies.parentIdOf('cat_food'), isNull);
      expect(TileFamilies.themesOf('cat_food'),
          ['cat_patisserie', 'cat_boissons']);
    });

    test('les noms reconnus (FR et EN) pointent vers le bon id', () {
      expect(AppL10n.canonicalCategoryId('Pâtisserie'), 'cat_patisserie');
      expect(AppL10n.canonicalCategoryId('Maison'), 'cat_maison');
      expect(AppL10n.canonicalCategoryId('Home'), 'cat_maison');
      expect(AppL10n.canonicalCategoryId('Spiritualité'), 'cat_spiritualite');
      expect(AppL10n.canonicalCategoryId('Spirituality'), 'cat_spiritualite');
      expect(AppL10n.canonicalCategoryId('Manga'), 'cat_manga');
    });
  });
}
