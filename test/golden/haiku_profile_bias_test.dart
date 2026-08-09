// Mesure le COUT du biais de personnalisation injecte dans le prompt.
//
// `_buildUserText` ajoute aujourd'hui, des que le profil contient au moins
// une classification :
//
//     PROFIL CLIENT :
//     - Catégories les plus regardées : cat_diy, cat_business, cat_food
//     En cas d'ambiguïté, privilégie la catégorie que cet utilisateur
//     regarde le plus.
//
// Comme `categoryCount` s'incremente automatiquement a chaque classification
// confiante, sans intervention humaine, c'est une boucle fermee : une
// categorie dominante devient de plus en plus dominante.
//
// Ce test rejoue les 127 cas du jeu golden avec un profil simulant une
// utilisatrice dont le top est DIY / Business / Food, et compare le score
// a la reference SANS profil.
//
// Le profil est volontairement minimal : pas d'influenceurs, pas de
// corrections, pas de style de vie. On isole exactement deux lignes du
// prompt -- la liste des categories dominantes et la phrase "privilegie".
//
// Reference sans profil : 84,3 % (107/127).
//
//   REELR_GOLDEN_NETWORK=1 flutter test test/golden/haiku_profile_bias_test.dart
//
// Aucun fichier de lib/ n'est touche par ce test.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:reelr/models/client_profile.dart';
import 'package:reelr/services/classifier.dart';

import 'golden_data.dart';

const int _concurrency = 4;

/// Reference mesuree le 2026-08-09 avec `profile: null`.
const double _baselineWithoutProfile = 84.3;

/// Profil biaise : trois categories dominantes, rien d'autre.
final ClientProfile _biasedProfile = const ClientProfile(
  userId: 'golden_bias',
  categoryCount: {
    'cat_diy': 42,
    'cat_business': 31,
    'cat_food': 18,
    'cat_gaming': 4,
  },
  knownInfluencers: [],
  lifestyleCount: {},
  corrections: [],
  totalVideosClassified: 95,
);

class Outcome {
  final GoldenCase c;
  final String? catId;
  final int confiance;
  final String raison;
  final Object? error;
  const Outcome(this.c, this.catId, this.confiance, this.raison, this.error);
}

Future<Outcome> _classify(GoldenCase c) async {
  try {
    final r = await ClaudeClassifier.classify(
      video: VideoData(
        title: c.title,
        platform: c.platform,
        channel: c.channel,
      ),
      profile: _biasedProfile,
    );
    return Outcome(
        c, toCatId(r.categoriePrincipale), r.confiance, r.raison, null);
  } catch (e) {
    return Outcome(c, null, 0, '', e);
  }
}

Future<List<Outcome>> _runAll(List<GoldenCase> cases) async {
  final results = <Outcome>[];
  final queue = List<GoldenCase>.from(cases);
  Future<void> worker() async {
    while (queue.isNotEmpty) {
      results.add(await _classify(queue.removeAt(0)));
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
    test('biais de profil — ignore (mettre REELR_GOLDEN_NETWORK=1)', () {
      // ignore: avoid_print
      print('\nTest reseau ignore. Pour le lancer :\n'
          '  REELR_GOLDEN_NETWORK=1 flutter test '
          'test/golden/haiku_profile_bias_test.dart\n');
    });
    return;
  }

  final cases = loadGoldenCases();

  test('haiku avec profil biaise — cout de la personnalisation', () async {
    // ignore: avoid_print
    print('\n═══ HAIKU AVEC PROFIL BIAISE (DIY / Business / Food) ═══\n'
        '    ${cases.length} appels, concurrence $_concurrency');
    final results = await _runAll(cases);

    var correct = 0, wrong = 0, errors = 0, lowConf = 0;
    // Combien de clips ont ete aspires vers une des categories dominantes
    // ALORS QUE ce n'etait pas la bonne reponse ? C'est la mesure directe
    // de l'effet d'aspiration.
    const dominant = {'cat_diy', 'cat_business', 'cat_food'};
    var suckedIn = 0;
    final failures = <String>[];

    for (final o in results) {
      if (o.error != null) {
        errors++;
        failures.add('ERREUR ${o.c.id} "${o.c.title}" -> ${o.error}');
        continue;
      }
      final got = o.catId!;
      if (o.confiance < 40) lowConf++;

      if (o.c.expectsAbstention) {
        if (o.confiance < 40) {
          correct++;
        } else {
          wrong++;
          failures.add('TROP SUR ${o.c.id} "${o.c.title}" -> $got '
              '(confiance ${o.confiance})');
        }
        continue;
      }

      if (got == o.c.expectedCatId) {
        correct++;
      } else {
        wrong++;
        final aspire = dominant.contains(got) &&
            !dominant.contains(o.c.expectedCatId);
        if (aspire) suckedIn++;
        failures.add('${aspire ? "ASPIRE " : "FAUX   "}${o.c.id} '
            '"${o.c.title}"\n'
            '        obtenu  $got (confiance ${o.confiance})\n'
            '        attendu ${o.c.expectedCatId}\n'
            '        raison  "${o.raison}"');
      }
    }

    final total = results.length;
    final score = total == 0 ? 0.0 : 100 * correct / total;
    final delta = score - _baselineWithoutProfile;

    // ignore: avoid_print
    print('''

┌─ HAIKU AVEC PROFIL BIAISE
│  justes            $correct/$total   (${_pct(correct, total)})
│  faux              $wrong
│  erreurs reseau    $errors
│  confiance < 40    $lowConf
│
│  dont ASPIRES vers DIY / Business / Food : $suckedIn
│  (clips dont la bonne categorie etait ailleurs mais qui ont atterri
│   dans une des trois categories dominantes du profil)
│
│  sans profil : ${_baselineWithoutProfile.toStringAsFixed(1)}%
│  avec profil : ${score.toStringAsFixed(1)}%
└─ EFFET DU BIAIS : ${delta >= 0 ? '+' : ''}${delta.toStringAsFixed(1)} point(s)
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
  • EFFET DU BIAIS negatif => la personnalisation degrade le classement et
    la phrase "privilegie la categorie la plus regardee" doit sauter.
  • ASPIRES est le chiffre le plus parlant : chacun de ces clips a ete
    detourne vers une categorie dominante alors qu'il appartenait ailleurs.
    C'est exactement le symptome signale en prod (tout tombe dans DIY).
  • Si l'effet est nul ou positif, le diagnostic etait faux sur ce point et
    il ne faut PAS retirer la personnalisation.
''');
  }, timeout: const Timeout(Duration(minutes: 15)));
}
