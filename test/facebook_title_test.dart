// Decoupage des titres Facebook « compteur | titre | createur ».
//   flutter test test/facebook_title_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:reelr/services/oembed.dart';

void main() {
  test('compteur francais, titre et createur', () {
    final r = OEmbedService.splitFacebookTitle(
        '90 K vues · 2,2 K réactions | Ta vacha al marchès | smilyjayce');
    expect(r?.title, 'Ta vacha al marchès');
    expect(r?.creator, 'smilyjayce');
  });

  test('compteur anglais', () {
    final r = OEmbedService.splitFacebookTitle(
        '1.2M views · 34K reactions | Best pasta ever | Chef Max');
    expect(r?.title, 'Best pasta ever');
    expect(r?.creator, 'Chef Max');
  });

  test('compteur et titre seul : pas de createur invente', () {
    final r = OEmbedService.splitFacebookTitle('61 K vues | Mon titre');
    expect(r?.title, 'Mon titre');
    expect(r?.creator, isNull);
  });

  test('titre sans compteur : rien ne change', () {
    expect(OEmbedService.splitFacebookTitle('Recette | Tarte aux pommes'), isNull);
    expect(OEmbedService.splitFacebookTitle('Simple titre'), isNull);
    expect(OEmbedService.splitFacebookTitle('2024 | Rétrospective | Mairie'), isNull);
  });
}
