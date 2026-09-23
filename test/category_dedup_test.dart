import 'package:flutter_test/flutter_test.dart';
import 'package:reelr/core/l10n.dart';

String? c(String label) => AppL10n.canonicalCategoryId(label);

void same(String a, String b) {
  expect(c(a), isNotNull, reason: '"$a" non reconnu');
  expect(c(a), c(b), reason: 'devraient etre la meme categorie : "$a" / "$b"');
}

void different(String a, String b) {
  final ca = c(a), cb = c(b);
  expect(ca != null && ca == cb, isFalse,
      reason: 'NE doivent PAS etre fusionnees : "$a" / "$b" ($ca)');
}

void main() {
  test('Accents, casse, pluriels', () {
    same('Beauté', 'Beaute');
    same('Actualités', 'Actualité');
    same('Bien-être', 'bien etre');
    same('Recettes', 'Recette');
    same('Voyages', 'Voyage');
    same('Jeux vidéo', 'Gaming');
  });

  test('Francais / anglais et synonymes stricts', () {
    same('Food', 'Recette');
    same('Cuisine', 'Food');
    same('Workout', 'Fitness');
    same('Actu', 'Actualités');
    same('News', 'Actualités');
    same('Maquillage', 'Beauté');
    same('Humor', 'Humour');
    same('Wellness', 'Bien-être');
    same('Music', 'Musique');
    same('Animaux', 'Pets');
  });

  test('Voisins volontairement separes', () {
    different('Sport', 'Fitness');
    different('Nutrition', 'Food');
    different('Couture', 'Tricot');
    different('Santé', 'Bien-être');
    different('Bébé', 'Famille');
    different('Mode', 'Beauté');
    different('Actualités', 'Société');
    different('DIY', 'Déco');
  });

  test('Categories personnelles non reconnues', () {
    expect(c('Tricot bébé'), isNull);
    expect(c('Idées cadeaux'), isNull);
  });

  test('Normalisation', () {
    expect(AppL10n.normalizeCategoryLabel('  Bien-Être  '), 'bien etre');
    expect(AppL10n.normalizeCategoryLabel('Jeux Vidéo'), 'jeu video');
    expect(AppL10n.normalizeCategoryLabel('Tricot bébé'),
        AppL10n.normalizeCategoryLabel('tricot bebe'));
  });
}
