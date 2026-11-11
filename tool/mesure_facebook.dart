// ignore_for_file: avoid_print
// Mesure la lecture des balises Open Graph de liens Facebook, comme l'appli
// (meme User-Agent, meme delai de 10 s). A lancer depuis la racine du projet :
//
//   dart run tool/mesure_facebook.dart URL1 URL2 ...
//
// Pour chaque lien : 3 lectures a la suite, avec un client neuf a chaque fois
// (premiere lecture « a froid »). Affiche la duree, le code HTTP et si un
// og:title est present. Sert a comparer avant / apres un changement.
import 'dart:async';
import 'package:http/http.dart' as http;

Future<void> main(List<String> urls) async {
  if (urls.isEmpty) {
    print('Usage : dart run tool/mesure_facebook.dart URL [URL...]');
    return;
  }
  for (final url in urls) {
    print('\n$url');
    for (var i = 1; i <= 3; i++) {
      final client = http.Client();
      final sw = Stopwatch()..start();
      try {
        final r = await client.get(Uri.parse(url), headers: const {
          'User-Agent': 'Mozilla/5.0 (compatible; Reelr/1.0)',
          'Accept': 'text/html,application/xhtml+xml',
        }).timeout(const Duration(seconds: 10));
        final hasTitle = r.body.contains('og:title');
        print('  essai $i : ${r.statusCode} en ${sw.elapsedMilliseconds} ms, '
            'og:title ${hasTitle ? "oui" : "NON"}');
      } on TimeoutException {
        print('  essai $i : DELAI DEPASSE (${sw.elapsedMilliseconds} ms)');
      } catch (e) {
        print('  essai $i : erreur $e');
      } finally {
        client.close();
      }
    }
  }
}
