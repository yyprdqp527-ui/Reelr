import 'package:flutter_test/flutter_test.dart';
import 'package:reelr/services/oembed.dart';

String? t(String url) => OEmbedService.titleFromUrlPath(url);

void main() {
  test('Fiche produit : titre tire du chemin, identifiant ignore', () {
    expect(t('https://www.fnac.com/a23256587/Rebecca-Yarros-Fourth-wing-titre-a-venir'),
        'Rebecca Yarros Fourth wing titre a venir');
  });

  test('Extension et encodage retires', () {
    expect(t('https://exemple.com/blog/mon-super-article.html'),
        'Mon super article');
    expect(t('https://exemple.com/recettes/tarte%20aux%20pommes'),
        'Tarte aux pommes');
  });

  test('Rien d\'exploitable : null', () {
    expect(t('https://www.fnac.com/livre.asp'), isNull);
    expect(t('https://exemple.com/'), isNull);
    expect(t('https://exemple.com/p/26Q62X45A1CD'), isNull);
  });
}
