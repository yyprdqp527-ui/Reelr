import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:reelr/services/thumbnail_resolver.dart';

/// « Image » valide = premier octet 1 ; « video » = 2 ; page d'erreur = 3.
Uint8List img(int kind) => Uint8List.fromList([kind, 1, 2, 3]);

Future<bool> usable(Uint8List b) async => b.first == 1;

Future<Uint8List> card() async => Uint8List.fromList([1, 9, 9, 9]);

void main() {
  test('image directe : une seule tentative', () async {
    final calls = <String>[];
    final r = ThumbnailResolver(
      fetch: (url, who) async {
        calls.add('$url/${who.name}');
        return img(1);
      },
      isUsable: usable,
    );
    final res = await r.resolve(imageUrl: 'https://a/x.jpg');
    expect(res!.source, 'image');
    expect(res.generated, isFalse);
    expect(calls, ['https://a/x.jpg/browser']);
  });

  test('cas Booking : le site refuse le navigateur, accepte le robot', () async {
    final r = ThumbnailResolver(
      fetch: (url, who) async =>
          who == FetchIdentity.previewBot ? img(1) : null,
      isUsable: usable,
    );
    final res = await r.resolve(imageUrl: 'https://cf.bstatic.com/h.jpg');
    expect(res!.source, 'image');
    expect(res.attempts.last, 'image/previewBot : ok');
  });

  test('le serveur Cloudflare passe quand le site bloque l\'app', () async {
    final r = ThumbnailResolver(
      fetch: (url, who) async => who == FetchIdentity.proxy ? img(1) : null,
      isUsable: usable,
    );
    final res = await r.resolve(imageUrl: 'https://x/y');
    expect(res!.attempts.last, 'image/proxy : ok');
  });

  test('cas Oh My Resto : une video est refusee, on prend l\'autre image',
      () async {
    final r = ThumbnailResolver(
      fetch: (url, who) async => url.contains('cover') ? img(2) : img(1),
      isUsable: usable,
    );
    final res = await r.resolve(
        imageUrl: 'https://assets/cover',
        alternatives: ['https://assets/cover', 'https://assets/photo.jpg']);
    expect(res!.source, 'autre image');
    expect(res.attempts.first, 'image/browser : illisible');
  });

  test('toutes les images echouent : apercu natif', () async {
    final r = ThumbnailResolver(
      fetch: (url, who) async => null,
      isUsable: usable,
      nativePreview: () async => img(1),
      screenshot: () async => fail('ne doit pas etre appele'),
    );
    final res = await r.resolve(imageUrl: 'https://x/y');
    expect(res!.source, 'apercu natif');
  });

  test('apercu natif vide : capture d\'ecran', () async {
    final r = ThumbnailResolver(
      fetch: (url, who) async => null,
      isUsable: usable,
      nativePreview: () async => null,
      screenshot: () async => img(1),
    );
    final res = await r.resolve(imageUrl: 'https://x/y');
    expect(res!.source, 'capture');
  });

  test('rien ne marche : carte dessinee, jamais vide', () async {
    final r = ThumbnailResolver(
      fetch: (url, who) async => img(3),
      isUsable: usable,
      nativePreview: () async => throw Exception('boom'),
      screenshot: () async => img(3),
      renderCard: card,
    );
    final res = await r.resolve(imageUrl: 'https://x/y');
    expect(res!.source, 'carte');
    expect(res.generated, isTrue);
  });

  test('sans carte (liens video) : null, l\'affichage garde le logo', () async {
    final r = ThumbnailResolver(
      fetch: (url, who) async => null,
      isUsable: usable,
    );
    expect(await r.resolve(imageUrl: 'https://x/y'), isNull);
  });

  test('aucune adresse d\'image : on passe aux etapes suivantes', () async {
    final r = ThumbnailResolver(
      fetch: (url, who) async => fail('aucun telechargement'),
      isUsable: usable,
      screenshot: () async => img(1),
    );
    final res = await r.resolve();
    expect(res!.source, 'capture');
  });

  test('exception et lenteur d\'un telechargement : on continue', () async {
    var n = 0;
    final r = ThumbnailResolver(
      fetch: (url, who) async {
        n++;
        if (n == 1) throw Exception('reseau coupe');
        if (n == 2) {
          await Future<void>.delayed(const Duration(milliseconds: 200));
          return img(1);
        }
        return img(1);
      },
      isUsable: usable,
      stepTimeout: const Duration(milliseconds: 50),
    );
    final res = await r.resolve(imageUrl: 'https://x/y');
    expect(res!.attempts, [
      'image/browser : erreur',
      'image/previewBot : trop lent',
      'image/proxy : ok',
    ]);
  });

  test('au plus 3 autres images essayees', () async {
    final seen = <String>[];
    final r = ThumbnailResolver(
      fetch: (url, who) async {
        seen.add(url);
        return null;
      },
      isUsable: usable,
    );
    await r.resolve(
        imageUrl: 'https://a/0',
        alternatives: List.generate(10, (i) => 'https://a/${i + 1}'));
    expect(seen.toSet(), {'https://a/0', 'https://a/1', 'https://a/2', 'https://a/3'});
  });
}
