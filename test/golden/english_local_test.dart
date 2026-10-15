// Mesure les couches LOCALES de classification sur le jeu golden.
// Hors ligne, deterministe, aucun appel reseau, aucun cout.
//
//   flutter test test/golden/local_classifier_test.dart
//
// Ce test ne "passe" ou "echoue" sur rien : il MESURE et imprime un rapport.
// La seule assertion est qu'aucune couche ne doit crasher (voir plus bas).

import 'package:flutter_test/flutter_test.dart';
import 'package:reelr/services/classifier.dart';

import 'golden_data.dart';

/// Resultat d'une couche pour un cas : soit une categorie, soit rien,
/// soit une exception.
class LayerOutcome {
  final String? catId; // null = la couche s'abstient
  final Object? crash;
  const LayerOutcome(this.catId, [this.crash]);
  bool get answered => catId != null;
  bool get crashed => crash != null;
}

LayerOutcome _run(String? Function() f) {
  try {
    final name = f();
    return LayerOutcome(name == null ? null : toCatId(name));
  } catch (e) {
    return LayerOutcome(null, e);
  }
}

class Tally {
  int answered = 0;
  int correct = 0;
  int wrong = 0;
  int abstained = 0;
  int crashed = 0;
  int invented = 0; // a renvoye un nom inconnu -> creerait un doublon
  final List<String> failures = [];

  /// Precision quand la couche repond. C'est LE chiffre qui autorise
  /// (ou non) une couche a court-circuiter le modele.
  double get precision => answered == 0 ? 0 : correct / answered;

  /// Part des cas ou la couche accepte de se prononcer.
  double coverage(int total) => total == 0 ? 0 : answered / total;
}

String _pct(double v) => '${(v * 100).toStringAsFixed(1)}%';

void _report(String label, Tally t, int total) {
  // ignore: avoid_print
  print('''

┌─ $label
│  couverture      ${t.answered}/$total  (${_pct(t.coverage(total))})
│  justes          ${t.correct}
│  faux            ${t.wrong}
│  noms inventes   ${t.invented}
│  abstentions     ${t.abstained}
│  CRASHS          ${t.crashed}
└─ PRECISION QUAND ELLE REPOND : ${_pct(t.precision)}''');
  if (t.failures.isNotEmpty) {
    // ignore: avoid_print
    print('   erreurs :');
    for (final f in t.failures.take(40)) {
      // ignore: avoid_print
      print('     $f');
    }
    if (t.failures.length > 40) {
      // ignore: avoid_print
      print('     … et ${t.failures.length - 40} autres');
    }
  }
}

void _score(Tally t, GoldenCase c, LayerOutcome o) {
  if (o.crashed) {
    t.crashed++;
    t.failures.add('CRASH  ${c.id} "${c.title}" -> ${o.crash}');
    return;
  }
  if (!o.answered) {
    t.abstained++;
    // S'abstenir sur un cas volontairement opaque est la BONNE reponse,
    // mais on ne le compte pas comme "juste" ici : cette couche n'a pas
    // vocation a trancher les cas ambigus, seulement a ne pas les abimer.
    return;
  }
  t.answered++;
  final got = o.catId!;
  if (got.startsWith('unknown:')) {
    t.invented++;
    t.wrong++;
    t.failures.add('INVENTE ${c.id} "${c.title}" -> $got');
    return;
  }
  if (c.expectsAbstention) {
    t.wrong++;
    t.failures.add(
        'BAVARD ${c.id} "${c.title}" -> $got (aurait du s\'abstenir)');
    return;
  }
  if (got == c.expectedCatId) {
    t.correct++;
  } else {
    t.wrong++;
    t.failures.add('FAUX   ${c.id} "${c.title}" -> $got (attendu ${c.expectedCatId})');
  }
}

void main() {
  final cases = loadGoldenCases('test/golden/english_2026-10-13.csv');

  test('couches locales — rapport de precision', () {
    expect(cases.length, greaterThan(100),
        reason: 'le CSV golden n\'a pas ete charge correctement');

    final strong = Tally();
    final keywords = Tally();
    final combined = Tally();

    for (final c in cases) {
      final s = _run(() =>
          CategoryClassifier.detectStrongMatch(c.title, channel: c.channel));
      final k = _run(() =>
          CategoryClassifier.detectByKeywords(c.title, kAllCategoryNames));

      _score(strong, c, s);
      _score(keywords, c, k);
      // Combine = ce que fait l'app aujourd'hui : couche forte, puis filet.
      _score(combined, c, s.answered ? s : k);
    }

    final total = cases.length;
    // ignore: avoid_print
    print('\n═══ JEU ANGLAIS + PIEGES : $total cas ═══');
    _report('COUCHE 1 — detectStrongMatch (court-circuite Claude)', strong, total);
    _report('FILET   — detectByKeywords (confiance < 40 ou echec reseau)',
        keywords, total);
    _report('LOCAL COMBINE — ce que l\'app decide sans Claude', combined, total);

    // ignore: avoid_print
    print('''

Lecture :
  • "PRECISION QUAND ELLE REPOND" est le seul chiffre qui autorise une couche
    a court-circuiter le modele. En dessous de ~95%, court-circuiter revient a
    degrader volontairement le classement pour gagner quelques centaines de ms.
  • Un CRASH n'est pas une opinion : c'est le bug `_suggestions[best]!` sur les
    15 buckets orphelins. Il est avale plus haut par le catch "Claude failed"
    et declenche un retour reseau inutile.
''');

    // Seule assertion dure : une couche de classification n'a pas le droit
    // de lever une exception. Ce test DOIT echouer tant que les 15 buckets
    // orphelins ne sont pas resynchronises.
    expect(strong.crashed + keywords.crashed, 0,
        reason: 'une couche locale a crashe — voir les lignes CRASH ci-dessus');
  });
}
