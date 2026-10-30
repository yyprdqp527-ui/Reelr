import 'package:flutter_test/flutter_test.dart';
import 'package:reelr/services/restaurant_rules.dart';

String? r({String? t, String? c, String? u}) =>
    RestaurantRules.reason(title: t, channel: c, url: u);

void main() {
  test('Le mot restaurant dans le titre', () {
    expect(r(t: 'Les 10 meilleurs restaurants de Lyon'), isNotNull);
    expect(r(t: 'Best Restaurant in Paris'), isNotNull);
    expect(r(t: 'Resto italien à Nice'), isNotNull);
    expect(r(t: 'Bistrot de quartier'), isNotNull);
  });

  test('Enseignes France et Etats-Unis', () {
    for (final t in [
      "McDonald's menu", 'McDonalds', 'Mcdo à 1 euro', 'Starbucks Noël',
      'Burger King vs Quick burger', 'KFC bucket', "Domino's pizza",
      'Five Guys', 'Flunch', 'Buffalo Grill', 'Hippopotamus',
      "Chick-fil-A", 'Taco Bell', 'Brioche Dorée', 'McDonald’s',
    ]) {
      expect(r(t: t), isNotNull, reason: t);
    }
  });

  test('Sites de restaurants', () {
    for (final u in [
      'https://www.thefork.fr/restaurant/x-r123',
      'https://www.ubereats.com/fr/store/x',
      'https://deliveroo.fr/fr/menu/paris/x',
      'https://guide.michelin.com/fr/fr/restaurant/x',
      'https://www.mcdonalds.fr/',
      'https://www.tripadvisor.fr/Restaurant_Review-g187265-d1-Reviews-X.html',
    ]) {
      expect(r(t: 'Page', u: u), isNotNull, reason: u);
    }
  });

  test('Page qui se declare restaurant', () {
    const u = 'https://www.exemple-inconnu.fr/adresses/chez-marcel/';
    expect(r(t: 'Chez Marcel', u: u), isNull);
    expect(
        RestaurantRules.looksLikeRestaurantPage(
            '<script type="application/ld+json">{"@type":"Restaurant"}</script>',
            ''),
        isTrue);
    expect(RestaurantRules.looksLikeRestaurantPage('<p>x</p>', 'restaurant.restaurant'), isTrue);
    RestaurantRules.markPage(u);
    expect(r(t: 'Chez Marcel', u: 'https://exemple-inconnu.fr/adresses/chez-marcel'), isNotNull);
  });

  test('Legende longue : le mot au milieu du texte ne decide pas', () {
    final longue = '38 K vues · 4,7 K réactions | Jour 894 +70km jusqu\'au bout '
        'du monde sans moteur. Une belle journée de passée, elle était très '
        'difficile, car les camions et la route enneigée me renvoient des '
        'flaques d\'eau toutes les 30 secondes. Le soir, j\'arrive à poser '
        'mon campement dans le terrain vague d\'un petit café, (resto ), et '
        'je rencontre le patron Dima | Beyond The Capes';
    expect(r(t: longue), isNull);
    expect(r(t: 'Resto italien à Nice. ${'x' * 400}'), isNotNull);
  });

  test('Pas de faux positifs', () {
    expect(r(t: 'Recette de la vraie carbonara', u: 'https://youtube.com/watch?v=1'), isNull);
    expect(r(t: 'Hôtel à Rome', u: 'https://www.booking.com/hotel/it/x.html'), isNull);
    expect(r(t: 'Hôtel Restaurant du Lac', u: 'https://www.booking.com/hotel/fr/lac.html'), isNull);
    expect(r(t: 'Restaurant sur place', u: 'https://www.airbnb.fr/rooms/123'), isNull);
    expect(r(t: 'Hotel Restaurant', u: 'https://www.agoda.com/fr-fr/x'), isNull);
    expect(r(t: 'Restaurer un meuble ancien'), isNull);
    expect(r(t: 'Quick workout 10 minutes'), isNull);
    expect(r(t: 'Paul Pogba highlights'), isNull);
    expect(r(t: 'Tripadvisor Rome', u: 'https://www.tripadvisor.fr/Hotel_Review-g1-d2-X.html'), isNull);
  });
}
