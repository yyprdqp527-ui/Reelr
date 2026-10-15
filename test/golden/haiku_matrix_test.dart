// Enregistre les reponses de Haiku (golden FR + anglais + inedits) dans un
// CSV, pour calculer la matrice de confusion avec tool/confusion.py.
// Vrais appels reseau (quelques centimes) : desactive par defaut.
//
//   REELR_GOLDEN_NETWORK=1 flutter test test/golden/haiku_matrix_test.dart
//
// Sortie : test/golden/out/predictions.csv (id,titre,attendu,obtenu,confiance)

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:reelr/services/classifier.dart';

import 'golden_data.dart';

const int _concurrency = 4;

String _q(String s) => '"${s.replaceAll('"', '""')}"';

void main() {
  if (Platform.environment['REELR_GOLDEN_NETWORK'] != '1') {
    test('matrice — ignore (mettre REELR_GOLDEN_NETWORK=1)', () {});
    return;
  }

  final cases = <GoldenCase>[
    ...loadGoldenCases(),
    ...loadGoldenCases('test/golden/english_2026-10-13.csv'),
    ...loadGoldenCases('test/golden/inedits_2026-10-06.csv'),
  ];

  test('haiku — predictions pour la matrice de confusion', () async {
    final rows = <String>['id,titre,attendu,obtenu,confiance,erreur'];
    final queue = List<GoldenCase>.from(cases);
    Future<void> worker() async {
      while (queue.isNotEmpty) {
        final c = queue.removeAt(0);
        try {
          final r = await ClaudeClassifier.classify(
            video: VideoData(
                title: c.title, platform: c.platform, channel: c.channel),
            profile: null,
          );
          rows.add('${c.id},${_q(c.title)},${c.expectedCatId},'
              '${toCatId(r.categoriePrincipale)},${r.confiance},');
        } catch (e) {
          rows.add('${c.id},${_q(c.title)},${c.expectedCatId},,0,'
              '${_q(e.toString())}');
        }
        stdout.write('.');
      }
    }

    await Future.wait(List.generate(_concurrency, (_) => worker()));
    Directory('test/golden/out').createSync(recursive: true);
    File('test/golden/out/predictions.csv').writeAsStringSync(rows.join('\n'));
    // ignore: avoid_print
    print('\n${rows.length - 1} cas ecrits dans test/golden/out/predictions.csv');
  }, timeout: const Timeout(Duration(minutes: 20)));
}
