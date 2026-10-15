/// Regle « Restaurant » (decision d'Anne, 2026-10-14).
///
/// Un clip va dans la categorie Restaurant, sans appeler Claude, quand :
///   1. son titre ou sa chaine contient le mot restaurant (ou resto,
///      brasserie, bistrot, pizzeria, trattoria) ;
///   2. son site est un site qui repertorie ou reserve des restaurants
///      (TheFork, Uber Eats, Deliveroo, Michelin...) ;
///   3. il parle d'une enseigne de restauration (McDonald's, Starbucks,
///      Flunch, Buffalo Grill...) ;
///   4. la page elle-meme se declare restaurant (og:type restaurant ou
///      donnees structurees schema.org Restaurant), ce qui attrape les
///      sites qu'aucune liste ne connait.
///
/// Les listes ci-dessous sont des donnees : pour ajouter un site ou une
/// enseigne, il suffit d'ajouter un nom dans l'expression reguliere.
class RestaurantRules {
  RestaurantRules._();

  static final RegExp _word = RegExp(
    r"\b(restaurants?|restos?|brasseries?|bistrots?|bistros?|"
    r"pizzerias?|trattorias?)\b",
  );

  /// Enseignes de restauration (France et Etats-Unis). Les noms qui sont
  /// aussi des mots courants (Quick, Paul, Subway seul) sont volontairement
  /// absents ou precises.
  static final RegExp _chain = RegExp(
    r"(^|[^a-z0-9])("
    r"mc ?donald'?s?|mcdo|starbucks|burger ?king|kfc|domino'?s|five guys|"
    r"pizza hut|taco bell|popeyes|wendy'?s|chipotle|shake shack|in-n-out|"
    r"chick-?fil-?a|dunkin'?|panera|olive garden|nando'?s|subway sandwich|"
    r"buffalo grill|hippopotamus|courtepaille|flunch|brioche dor[ée]e|"
    r"big mamma|o'?tacos|pitaya|class'?croute|columbus caf[ée]|"
    r"pret a manger|quick burger|five guys|le relais de l'entrecote|"
    r"leon de bruxelles|léon de bruxelles"
    r")($|[^a-z0-9])",
  );

  /// Sites de reservation, d'annuaire ou de livraison de restaurants, et
  /// sites officiels des grandes enseignes.
  static final RegExp _host = RegExp(
    r"(^|\.)("
    r"thefork\.[a-z.]+|lafourchette\.[a-z.]+|ubereats\.com|deliveroo\.[a-z.]+|"
    r"just-?eat\.[a-z.]+|opentable\.[a-z.]+|resy\.com|zenchef\.com|"
    r"guide\.michelin\.com|yelp\.[a-z.]+|bookatable\.[a-z.]+|"
    r"quandjemangerai\.com|restaurantguru\.com|foodora\.[a-z.]+|"
    r"doordash\.com|grubhub\.com|seamless\.com|"
    r"mcdonalds\.[a-z.]+|kfc\.[a-z.]+|burgerking\.[a-z.]+|"
    r"starbucks\.[a-z.]+|dominos\.[a-z.]+|fiveguys\.[a-z.]+|"
    r"pizzahut\.[a-z.]+|flunch\.[a-z.]+|buffalo-grill\.[a-z.]+|"
    r"hippopotamus\.[a-z.]+|quick\.[a-z.]+"
    r")$",
  );

  /// Pages de restaurants sur un site de voyage (Tripadvisor classe sinon
  /// en Voyage).
  static final RegExp _tripadvisorRestaurantPath =
      RegExp(r"/(restaurants?(_review)?|restaurant_review)[-_/]", caseSensitive: false);

  /// Pages qui se declarent restaurant : og:type ou JSON-LD schema.org.
  static final RegExp _structured = RegExp(
    r'"@type"\s*:\s*\[?\s*"(Restaurant|FoodEstablishment|FastFoodRestaurant|'
    r'CafeOrCoffeeShop|BarOrPub|Bakery|IceCreamShop|Brewery|Winery)"',
  );

  /// Sites de reservation d'hotels et de voyages : TOUJOURS Voyage (regle
  /// d'Anne, 2026-10-14), meme si le titre contient « restaurant » (ex.
  /// « Hotel Restaurant du Lac »). Tripadvisor est traite a part : ses
  /// pages restaurant restent Restaurant.
  static final RegExp hotelBookingHost = RegExp(
    r"(^|\.)(booking\.com|hotels\.com|airbnb\.[a-z.]+|expedia\.[a-z.]+|"
    r"trivago\.[a-z.]+|agoda\.com|kayak\.[a-z.]+|hotelscombined\.[a-z.]+|"
    r"lastminute\.[a-z.]+|abritel\.[a-z.]+|vrbo\.com|hrs\.[a-z.]+|"
    r"ebookers\.[a-z.]+|opodo\.[a-z.]+|edreams\.[a-z.]+|momondo\.[a-z.]+|"
    r"trip\.com|hostelworld\.com|logitravel\.[a-z.]+|"
    r"hotelscan\.com|ibis\.com|accor\.com|all\.accor\.com)$",
  );

  static final Set<String> _learnedPages = <String>{};

  static String _pageKey(String url) {
    final u = Uri.tryParse(url);
    if (u == null) return url;
    var host = u.host.toLowerCase();
    if (host.startsWith('www.')) host = host.substring(4);
    var path = u.path;
    if (path.endsWith('/')) path = path.substring(0, path.length - 1);
    return '$host$path';
  }

  /// Retient qu'une page s'est declaree restaurant (appele a l'extraction
  /// des metadonnees, avant le classement).
  static void markPage(String url) => _learnedPages.add(_pageKey(url));

  /// Vrai si le corps HTML ou le og:type decrit un restaurant.
  static bool looksLikeRestaurantPage(String body, String ogType) =>
      ogType.toLowerCase().contains('restaurant') || _structured.hasMatch(body);

  static String _norm(String s) => s.toLowerCase().replaceAll('’', "'");

  /// Explication de la regle qui s'applique, ou null si aucune.
  static String? reason({String? title, String? channel, String? url}) {
    final u = url == null ? null : Uri.tryParse(url);
    // Site de reservation d'hotel : jamais Restaurant.
    if (u != null && hotelBookingHost.hasMatch(u.host.toLowerCase())) {
      return null;
    }
    final text = _norm('${title ?? ''} ${channel ?? ''}');
    if (_word.hasMatch(text)) return 'le titre parle de restaurant';
    if (_chain.hasMatch(text)) return 'enseigne de restauration reconnue';
    if (u != null && u.host.isNotEmpty) {
      final host = u.host.toLowerCase();
      if (_host.hasMatch(host)) return 'site de restaurants ($host)';
      if (RegExp(r'(^|\.)tripadvisor\.[a-z.]+$').hasMatch(host) &&
          _tripadvisorRestaurantPath.hasMatch(u.path)) {
        return 'page restaurant Tripadvisor';
      }
      if (_learnedPages.contains(_pageKey(url!))) {
        return 'la page se déclare restaurant';
      }
    }
    return null;
  }
}
