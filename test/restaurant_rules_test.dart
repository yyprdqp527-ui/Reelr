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
