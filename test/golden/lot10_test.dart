// Lecture groupee du lot sur 12 liens avec images (4 nov. 2026) : verifie
// que la reponse n'est plus coupee depuis max_tokens 4000.
//
//   REELR_GOLDEN_NETWORK=1 flutter test test/golden/lot10_test.dart
//
// Un seul appel reseau, quelques centimes. Lire dans la sortie :
//   [lot] arret=end_turn tokens=...   puis la liste des groupes.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:reelr/services/classifier.dart';

const _liens = <List<String>>[
  ['FEMININE ...PAS FEMINISTE ! [youtube.com]', 'MKG5KeZ-lLw'],
  ['Marine - Tricheur (Clip officiel) [youtube.com]', '5KLgnnnl3RQ'],
  ["'Predator' Posing as 14-Year-Old to Have Sex With Teen Boys Has More Victims: Police [youtube.com]", 'arJYzrMV0hg'],
  ['Tous les bienfaits Sante du Yoga en 30 mn ! [youtube.com]', 'JpKS4lbQf1U'],
  ["Video Shows 'Predator' Posing as 14-Year-Old Girl To Have Sex With Teens: Prosecutor [youtube.com]", 'HIKlnaax358'],
  ['Astrologie 2026-2028 : preparez-vous au grand basculement [youtube.com]', 'gSt7_DGKqYY'],
  ['Le signe le plus PUISSANT mentalement #astro #astrologie [youtube.com]', 'FcywnsIv8zY'],
  ['Les 3 couples de signes astro inseparables [youtube.com]', 'VPavjG1589g'],
  ['Guidance Astro signe par signe du lundi 2/11 au dimanche 8/11 [youtube.com]', 'kqMaCkkITig'],
  ['I Woke Up at 3 AM to Capture Saturn, Mars & Andromeda Galaxy! [youtube.com]', 'zFwEVGNA4lA'],
  ['Claude IA : le tutoriel facile pour debutant [youtube.com]', 'nHXND_R4Jy8'],
  ['Comment creer INSTANTANEMENT des automatisations n8n avec Claude [youtube.com]', 'txUiv1NY8eA'],
];

void main() {
  if (Platform.environment['REELR_GOLDEN_NETWORK'] != '1') {
    test('lot10 — ignore (mettre REELR_GOLDEN_NETWORK=1)', () {});
    return;
  }

  test('lot10 — lecture groupee de 12 liens avec images', () async {
    final groups = await ClaudeClassifier.classifyLot(
      [for (final l in _liens) l[0]],
      const ['Vibe coding'],
      [for (final l in _liens) 'https://img.youtube.com/vi/${l[1]}/mqdefault.jpg'],
      const {
        'Vibe coding': [
          'Claude Code : les 10 MCP que tout bon dev branche',
          'Comment cree un assistant IA qui connait toute votre entreprise',
        ],
      },
    );
    print('');
    print('RESULTAT : ${groups == null ? 'ECHEC (aucun groupe)' : '${groups.length} groupe(s)'}');
    for (final g in groups ?? const []) {
      print('  liens ${g.links} -> ${g.category} (${g.confidence}) : ${g.reason}');
    }
    expect(groups, isNotNull);
  }, timeout: const Timeout(Duration(minutes: 2)));
}
