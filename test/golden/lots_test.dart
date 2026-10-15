// Lots de liens partages ensemble : methode ACTUELLE (un appel par lien)
// contre APPEL GROUPE (un appel par lot, vue d'ensemble).
//
// Fait de vrais appels reseau via ton Worker Cloudflare (Haiku). Quelques
// dizaines de centimes. Desactive par defaut.
//
//   REELR_GOLDEN_NETWORK=1 flutter test test/golden/lots_test.dart
//
// Donnees : test/golden/lots_golden.csv. Les liens decides par une REGLE
// locale (Twitch, Booking, enseignes) sont exclus : Claude ne les voit pas.
//
// Methode A : chaque lien classe seul, comme dans l'app (confiance >= 40).
// Methode B : un appel par lot, groupes de meme sujet ; un groupe n'est
//   applique que si sa confiance est >= 75, sinon le lien garde sa reponse A
//   (c'est le repli prevu dans l'app).
// Le prompt du lot reprend le prompt de production (lu dans classifier.dart)
// plus une consigne de lot ; il n'est pas ecrit pour ce test.

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:reelr/config/secrets.dart';
import 'package:reelr/services/classifier.dart';

import 'golden_data.dart';

const _customTiles = ['Cheveux', 'Liste de Noël'];
const _groupMinConfidence = 75;
const _model = String.fromEnvironment('REELR_MODEL',
    defaultValue: 'claude-haiku-4-5-20251001');
bool get _isGen5 =>
    _model.startsWith('claude-haiku-5') || _model.startsWith('claude-sonnet-5');

class LotItem {
  final String lot;
  final int order;
  final String title;
  final String channel;
  final String platform;
  final String host;
  final String expected;
  final String decidedBy;
  final String note;
  const LotItem(this.lot, this.order, this.title, this.channel, this.platform,
      this.host, this.expected, this.decidedBy, this.note);
}

class _Pred {
  final String cat;
  final int conf;
  const _Pred(this.cat, this.conf);
}

List<String> _splitCsv(String line) {
  final out = <String>[];
  final buf = StringBuffer();
  var inQuotes = false;
  for (var i = 0; i < line.length; i++) {
    final c = line[i];
    if (c == '"') {
      if (inQuotes && i + 1 < line.length && line[i + 1] == '"') {
        buf.write('"');
        i++;
      } else {
        inQuotes = !inQuotes;
      }
    } else if (c == ',' && !inQuotes) {
      out.add(buf.toString());
      buf.clear();
    } else {
      buf.write(c);
    }
  }
  out.add(buf.toString());
  return out;
}

List<LotItem> loadLots([String path = 'test/golden/lots_golden.csv']) {
  final lines = File(path).readAsLinesSync();
  final items = <LotItem>[];
  for (var i = 1; i < lines.length; i++) {
    if (lines[i].trim().isEmpty) continue;
    final f = _splitCsv(lines[i]);
    if (f.length < 8) continue;
    items.add(LotItem(f[0], int.tryParse(f[1]) ?? 0, f[2], f[3], f[4], f[5],
        f[6], f[7], f.length > 8 ? f[8] : ''));
  }
  return items;
}

String _normalize(String name) {
  final key = name.trim();
  if (key.toLowerCase().startsWith('cat_')) return key.toLowerCase();
  for (final t in _customTiles) {
    if (t.toLowerCase() == key.toLowerCase()) return 'tuile:$t';
  }
  return toCatId(key);
}

bool _isOk(LotItem it, String got) {
  if (got == it.expected) return true;
  if (it.note.contains('Ou la tuile Cheveux') && got == 'tuile:Cheveux') {
    return true;
  }
  return false;
}

Future<_Pred> _predictAlone(LotItem it) async {
  try {
    final r = await ClaudeClassifier.classify(
      video: VideoData(
        title: it.title,
        platform: it.platform,
        channel: it.channel.isEmpty ? null : it.channel,
        description: it.host.isEmpty ? null : 'Site : ${it.host}',
      ),
      profile: null,
      customCategories: _customTiles,
    );
    final cat =
        r.confiance < 40 ? 'a_trier' : _normalize(r.categoriePrincipale);
    return _Pred(cat, r.confiance);
  } catch (e) {
    return const _Pred('erreur', 0);
  }
}

/// Prompt de production, lu dans classifier.dart (aucune copie a maintenir).
String _productionSystemPrompt() {
  final src = File('lib/services/classifier.dart').readAsStringSync();
  const start = "static const String _systemPrompt = '''";
  final i = src.indexOf(start);
  if (i < 0) throw StateError('_systemPrompt introuvable dans classifier.dart');
  final from = i + start.length;
  final j = src.indexOf("''';", from);
  return src
      .substring(from, j)
      .replaceAll(r'\$', r'$')
      .replaceAll(r"\'", "'")
      .trim();
}

const _lotInstructions = '''
━━━ MODE LOT (prioritaire sur le format de réponse ci-dessus) ━━━
Tu reçois plusieurs liens partagés EN MÊME TEMPS par la même personne. Lis-les ensemble, comme une personne qui range sa liste.
1. Sépare-les en groupes de même sujet. Un lien sans rapport avec les autres forme un groupe à lui seul.
2. Les liens d'une même liste (mêmes objets : tapis, coupes de cheveux, recettes...) vont dans la MÊME catégorie, même si leurs titres n'ont aucun mot en commun ou sont dans des langues différentes.
3. Pour chaque groupe, donne une catégorie : un ID cat_xxx de la liste, ou le nom exact d'une tuile personnelle si elle correspond mieux.
4. Réponds UNIQUEMENT avec ce JSON, sans texte autour :
{"groupes":[{"liens":[1,2],"categorie":"cat_xxx","confiance":0-100,"raison":"courte"}]}
Chaque lien apparaît dans exactement un groupe. Mets une confiance basse si tu hésites.
''';

Future<Map<int, _Pred>> _predictGroup(
    List<LotItem> items, String systemPrompt) async {
  final numbered = StringBuffer();
  for (var i = 0; i < items.length; i++) {
    final it = items[i];
    final flat = it.title.replaceAll(RegExp(r'\s+'), ' ').trim();
    final short = flat.length > 90 ? '${flat.substring(0, 90)}…' : flat;
    numbered.writeln('${i + 1}. $short'
        '${it.host.isNotEmpty ? ' [${it.host}]' : ''}'
        '${it.channel.isNotEmpty ? ' (${it.channel})' : ''}');
  }
  final user = 'Lot de ${items.length} liens partagés en même temps :\n'
      '$numbered\n'
      'Tuiles personnelles de l\'utilisatrice : ${_customTiles.join(', ')}.';
  final body = jsonEncode({
    'model': _model,
    'max_tokens': 900,
    if (_isGen5) 'output_config': {'effort': 'low'} else 'temperature': 0,
    'system': [
      {
        'type': 'text',
        'text': systemPrompt,
        'cache_control': {'type': 'ephemeral'},
      },
      {'type': 'text', 'text': _lotInstructions},
    ],
    'messages': [
      {'role': 'user', 'content': user},
    ],
  });
  final resp = await http.post(
    Uri.parse(Secrets.reelrProxyUrl),
    headers: {
      'x-reelr-secret': Secrets.appSharedSecret,
      'anthropic-version': '2023-06-01',
      'anthropic-beta': 'prompt-caching-2024-07-31',
      'content-type': 'application/json',
    },
    body: body,
  ).timeout(const Duration(seconds: 40));
  if (resp.statusCode != 200) {
    throw StateError('HTTP ${resp.statusCode} : ${resp.body}');
  }
  final text = (jsonDecode(utf8.decode(resp.bodyBytes))['content'] as List)
      .map((b) => (b as Map)['text'] ?? '')
      .join();
  final a = text.indexOf('{');
  final b = text.lastIndexOf('}');
  final data = jsonDecode(text.substring(a, b + 1)) as Map<String, dynamic>;
  final out = <int, _Pred>{};
  for (final g in (data['groupes'] as List)) {
    final cat = _normalize(g['categorie'].toString());
    final conf = (g['confiance'] as num).toInt();
    for (final l in (g['liens'] as List)) {
      out[(l as num).toInt()] = _Pred(cat, conf);
    }
  }
  return out;
}

String _pct(num n, num d) =>
    d == 0 ? '—' : '${(100 * n / d).toStringAsFixed(0)}%';

void main() {
  if (Platform.environment['REELR_GOLDEN_NETWORK'] != '1') {
    test('lots — ignore (mettre REELR_GOLDEN_NETWORK=1)', () {
      // ignore: avoid_print
      print('\nTest reseau ignore. Pour le lancer :\n'
          '  REELR_GOLDEN_NETWORK=1 flutter test test/golden/lots_test.dart\n');
    });
    return;
  }

  test('lots — actuelle (A) contre groupe (B)', () async {
    final all = loadLots();
    final lots = <String, List<LotItem>>{};
    for (final it in all) {
      if (it.decidedBy != 'claude') continue;
      lots.putIfAbsent(it.lot, () => []).add(it);
    }
    final skipped = all.where((i) => i.decidedBy != 'claude').length;
    final systemPrompt = _productionSystemPrompt();

    var totalN = 0, aOk = 0, bOk = 0, aSure = 0, bSure = 0;
    final report = StringBuffer();
    final failures = <String>[];

    for (final entry in lots.entries) {
      final items = entry.value..sort((x, y) => x.order.compareTo(y.order));
      final alone = <_Pred>[];
      for (final it in items) {
        alone.add(await _predictAlone(it));
      }
      Map<int, _Pred> grouped = {};
      String? groupError;
      try {
        grouped = await _predictGroup(items, systemPrompt);
      } catch (e) {
        groupError = '$e';
      }
      var a = 0, b = 0;
      for (var i = 0; i < items.length; i++) {
        final it = items[i];
        final pa = alone[i];
        final pg = grouped[i + 1];
        final pb = (pg != null && pg.conf >= _groupMinConfidence) ? pg : pa;
        final okA = _isOk(it, pa.cat);
        final okB = _isOk(it, pb.cat);
        if (okA) a++;
        if (okB) b++;
        if (!okA && pa.conf >= 40 && pa.cat != 'a_trier') aSure++;
        if (!okB && pb.conf >= 40 && pb.cat != 'a_trier') bSure++;
        if (!okA || !okB) {
          failures.add('${entry.key} #${it.order} "${it.title.length > 60 ? it.title.substring(0, 60) : it.title}"\n'
              '      attendu ${it.expected} | A: ${pa.cat} (${pa.conf}) '
              '${okA ? "ok" : "FAUX"} | B: ${pb.cat} (${pb.conf}) '
              '${okB ? "ok" : "FAUX"}');
        }
      }
      totalN += items.length;
      aOk += a;
      bOk += b;
      report.writeln('${entry.key.padRight(20)} A $a/${items.length}   '
          'B $b/${items.length}'
          '${groupError != null ? "   (appel groupe en erreur : $groupError)" : ""}');
    }

    // ignore: avoid_print
    print('''

═══ LOTS : ${lots.length} lots, $totalN liens decides par Claude ($skipped par regle, exclus) ═══
${report.toString()}
┌─ A, methode actuelle (un appel par lien)
│  justes          $aOk/$totalN   (${_pct(aOk, totalN)})
│  erreurs sures   $aSure   (fausses avec confiance >= 40)
├─ B, appel groupe (groupe >= $_groupMinConfidence, sinon reponse A)
│  justes          $bOk/$totalN   (${_pct(bOk, totalN)})
└─ erreurs sures   $bSure
''');
    if (failures.isNotEmpty) {
      // ignore: avoid_print
      print('── liens ou A ou B se trompe ──');
      for (final f in failures) {
        // ignore: avoid_print
        print('  $f');
      }
    }
    // Mesure, pas un test de non-regression : pas d'assertion sur le score.
    expect(totalN, greaterThan(0));
  }, timeout: const Timeout(Duration(minutes: 10)));
}
