// Mesure HAIKU seul sur le jeu golden, via ton Worker Cloudflare.
// Fait de vrais appels reseau et coute quelques centimes -> desactive par
// defaut pour ne pas partir a chaque `flutter test`.
//
// Pour le lancer :
//   REELR_GOLDEN_NETWORK=1 flutter test test/golden/haiku_classifier_test.dart
//
// Profil volontairement absent : on mesure Haiku SANS le biais
// "privilegie la categorie la plus regardee". C'est la reference propre.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:reelr/services/classifier.dart';

import 'golden_data.dart';

const int _concurrency = 4;

class Outcome {
  final GoldenCase c;
  final String? catId;
  final int confiance;
  final String raison;
  final Object? error;
  final int ms;
  const Outcome(this.c, this.catId, this.confiance, this.raison, this.error,
      [this.ms = 0]);
}

Future<Outcome> _classify(GoldenCase c) async {
  final sw = Stopwatch()..start();
  try {
    final r = await ClaudeClassifier.classify(
      video: VideoData(
        title: c.title,
        platform: c.platform,
        channel: c.channel,
      ),
      // Pas de profil : reference sans biais de personnalisation.
      profile: null,
    );
    return Outcome(c, toCatId(r.categoriePrincipale), r.confiance, r.raison,
        null, sw.elapsedMilliseconds);
  } catch (e) {
    return Outcome(c, null, 0, '', e);
  }
}

Future<List<Outcome>> _runAll(List<GoldenCase> cases) async {
  final results = <Outcome>[];
  final queue = List<GoldenCase>.from(cases);
  Future<void> worker() async {
    while (queue.isNotEmpty) {
      final c = queue.removeAt(0);
      results.add(await _classify(c));
      // ignore: avoid_print
      stdout.write('.');
    }
  }

  await Future.wait(List.generate(_concurrency, (_) => worker()));
  // ignore: avoid_print
  print('');
  return results;
}

String _pct(num n, num d) =>
    d == 0 ? '—' : '${(100 * n / d).toStringAsFixed(1)}%';

void main() {
  if (Platform.environment['REELR_GOLDEN_NETWORK'] != '1') {
    test('haiku golden — ignore (mettre REELR_GOLDEN_NETWORK=1)', () {
      // ignore: avoid_print
      print('\nTest reseau ignore. Pour le lancer :\n'
          '  REELR_GOLDEN_NETWORK=1 flutter test '
          'test/golden/haiku_classifier_test.dart\n');
    });
    return;
  }

  final cases = loadGoldenCases();

  test('haiku seul — rapport de precision', () async {
    // ignore: avoid_print
    print('\n═══ HAIKU SEUL : ${cases.length} appels, concurrence '
        '$_concurrency ═══');
    final results = await _runAll(cases);

    var correct = 0, wrong = 0, errors = 0, invented = 0;
    var lowConf = 0, lowConfCorrect = 0;
    final failures = <String>[];
    final abstentionCases = <String>[];

    for (final o in results) {
      if (o.error != null) {
        errors++;
        failures.add('ERREUR ${o.c.id} "${o.c.title}" -> ${o.error}');
        continue;
      }
      final got = o.catId!;
      final ok = got == o.c.expectedCatId;

      if (o.confiance < 40) {
        lowConf++;
        if (ok) lowConfCorrect++;
      }

      if (o.c.expectsAbstention) {
        // Bonne reponse attendue : confiance basse. La categorie importe peu.
        if (o.confiance < 40) {
          correct++;
        } else {
          wrong++;
          failures.add('TROP SUR ${o.c.id} "${o.c.title}" -> $got '
              '(confiance ${o.confiance}, aurait du douter)');
        }
        continue;
      }

      if (got.startsWith('unknown:')) {
        invented++;
        wrong++;
        failures.add('HORS TAXONOMIE ${o.c.id} "${o.c.title}" -> $got');
        continue;
      }

      if (ok) {
        correct++;
      } else {
        wrong++;
        failures.add('FAUX ${o.c.id} "${o.c.title}"\n'
            '        obtenu  $got (confiance ${o.confiance})\n'
            '        attendu ${o.c.expectedCatId}\n'
            '        raison  "${o.raison}"');
      }
      if (o.confiance < 40) abstentionCases.add('${o.c.id} "${o.c.title}"');
    }

    final total = results.length;
    // ignore: avoid_print
    print('''

┌─ HAIKU SEUL (sans profil)
│  justes            $correct/$total   (${_pct(correct, total)})
│  faux              $wrong
│  hors taxonomie    $invented
│  erreurs reseau    $errors
│  confiance < 40    $lowConf  (dont justes : $lowConfCorrect)
└─ PRECISION GLOBALE : ${_pct(correct, total)}
''');

    // ── Mesures ajoutees le 2026-10-03 ──
    // Duree des appels reussis : c'est le temps d'attente reel du
    // classement, hors extraction des metadonnees.
    final durees = results
        .where((o) => o.error == null)
        .map((o) => o.ms)
        .toList()
      ..sort();
    int quantile(double q) => durees.isEmpty
        ? 0
        : durees[((durees.length - 1) * q).round()];
    // Erreur « sure d'elle » : fausse ET confiance >= 40, donc appliquee
    // dans l'app. C'est le chiffre a ramener a zero ; une confiance
    // < 40 part dans « A trier », ce n'est pas une tuile fausse.
    var sures = 0;
    var enTotal = 0, enJustes = 0, frTotal = 0, frJustes = 0;
    for (final o in results) {
      if (o.error != null || o.c.expectsAbstention) continue;
      final ok = o.catId == o.c.expectedCatId;
      if (!ok && o.confiance >= 40) sures++;
      if (o.c.note.contains('anglais')) {
        enTotal++;
        if (ok) enJustes++;
      } else {
        frTotal++;
        if (ok) frJustes++;
      }
    }
    // ignore: avoid_print
    print('''
┌─ MESURES
│  francais          $frJustes/$frTotal   (${_pct(frJustes, frTotal)})
│  anglais           $enJustes/$enTotal   (${_pct(enJustes, enTotal)})
│  ERREURS SURES     $sures   (fausses avec confiance >= 40)
│  duree mediane     ${quantile(0.5)} ms
│  duree p90         ${quantile(0.9)} ms
└─ duree max        ${durees.isEmpty ? 0 : durees.last} ms
''');

    if (failures.isNotEmpty) {
      // ignore: avoid_print
      print('── erreurs ──');
      for (final f in failures) {
        // ignore: avoid_print
        print('  $f');
      }
    }

    // ignore: avoid_print
    print('''

Lecture :
  • "confiance < 40" = les clips qui iraient dans "A trier" apres l'etape 4.
    Un chiffre eleve n'est pas mauvais : c'est le systeme qui reconnait son
    doute au lieu d'inventer.
  • "TROP SUR" = les cas opaques ou Haiku aurait du douter et ne l'a pas fait.
    C'est la ligne a surveiller pour calibrer le seuil.
  • Compare la PRECISION GLOBALE ici a la PRECISION QUAND ELLE REPOND du test
    local. L'ecart chiffre le prix reel des court-circuits actuels.
''');
  }, timeout: const Timeout(Duration(minutes: 15)));
}
