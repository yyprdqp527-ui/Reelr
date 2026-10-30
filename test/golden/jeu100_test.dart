// Mesure Claude SEUL (sans regles locales) sur ton jeu de 100 liens
// etiquete a la main, avec et sans exemples de tuiles.
//
//   REELR_GOLDEN_NETWORK=1 flutter test test/golden/jeu100_test.dart
//
// Ecrit test/golden/out/jeu100_resultats.csv. Vrais appels reseau (2 x ~90),
// quelques centimes. Les liens du jeu ne servent jamais d'exemples.

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:reelr/services/classifier.dart';

const int _concurrency = 4;

String _csv(Object? v) {
  final s = (v ?? '').toString().replaceAll('\n', ' ');
  return (s.contains(',') || s.contains('"'))
      ? '"${s.replaceAll('"', '""')}"'
      : s;
}

void main() {
  if (Platform.environment['REELR_GOLDEN_NETWORK'] != '1') {
    test('jeu100 — ignore (mettre REELR_GOLDEN_NETWORK=1)', () {});
    return;
  }

  test('jeu100 — Claude seul, sans puis avec exemples de tuiles', () async {
    final data = jsonDecode(File('test/golden/jeu100.json').readAsStringSync())
        as Map<String, dynamic>;
    final tuiles = (data['tuiles_personnelles'] as List).cast<String>();
    final exemples = (data['exemples'] as Map<String, dynamic>)
        .map((k, v) => MapEntry(k, (v as List).cast<String>()));
    final cas = (data['cas'] as List).cast<Map<String, dynamic>>();

    Future<List<String>> run(Map<String, List<String>> ex) async {
      final out = List<String>.filled(cas.length, ',');
      final queue = List<int>.generate(cas.length, (i) => i);
      Future<void> worker() async {
        while (queue.isNotEmpty) {
          final i = queue.removeAt(0);
          final c = cas[i];
          try {
            final r = await ClaudeClassifier.classify(
              video: VideoData(
                title: c['title'] as String,
                platform: c['platform'] as String,
                channel: c['channel'] as String?,
                description: c['description'] as String?,
              ),
              profile: null,
              customCategories: tuiles,
              customExamples: ex,
            );
            out[i] = '${_csv(r.categoriePrincipale)},${r.confiance}';
          } catch (e) {
            out[i] = 'ERREUR,0';
          }
          stdout.write('.');
        }
      }

      await Future.wait(List.generate(_concurrency, (_) => worker()));
      print('');
      return out;
    }

    final sans = await run(const {});
    final avec = await run(exemples);

    final buf = StringBuffer(
        'n,ta_reponse,couche_actuelle,predite_actuelle,claude_sans_ex,conf_sans,claude_avec_ex,conf_avec,titre\n');
    for (var i = 0; i < cas.length; i++) {
      final c = cas[i];
      buf.writeln([
        c['n'],
        _csv(c['ta_reponse']),
        _csv(c['couche_actuelle']),
        _csv(c['predite_actuelle']),
        sans[i],
        avec[i],
        _csv((c['title'] as String).length > 80
            ? (c['title'] as String).substring(0, 80)
            : c['title']),
      ].join(','));
    }
    Directory('test/golden/out').createSync(recursive: true);
    File('test/golden/out/jeu100_resultats.csv')
        .writeAsStringSync(buf.toString());
    print('Ecrit : test/golden/out/jeu100_resultats.csv');
  }, timeout: const Timeout(Duration(minutes: 15)));
}
