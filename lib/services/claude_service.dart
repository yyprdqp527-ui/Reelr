import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../config/secrets.dart';

class ClaudeService {
  static const String _url = Secrets.reelrProxyUrl;

  static Future<String?> classifyTitle({
    required String title,
    required List<String> categoryNames,
    String? platform,
  }) async {
    if (title.trim().isEmpty) return null;
    try {
      final catList = categoryNames.isEmpty ? 'aucune' : categoryNames.join(', ');
      final platformLine = platform != null ? 'Plateforme : "$platform"\n' : '';
      final response = await http.post(
        Uri.parse(_url),
        headers: {
          'Content-Type': 'application/json',
          'x-reelr-secret': Secrets.appSharedSecret,
          'anthropic-version': '2023-06-01',
        },
        body: jsonEncode({
          'model': 'claude-haiku-4-5',
          'max_tokens': 20,
          'messages': [
            {
              'role': 'user',
              'content': '''Tu es un expert en classification de contenu vidéo.

Titre de la vidéo : "$title"
${platformLine}Catégories existantes : $catList

Ta mission en 2 étapes :

ÉTAPE 1 — Identifie le thème principal de cette vidéo en UN MOT ou GROUPE DE MOTS court (ex: "Cuisine", "True Crime", "Développement personnel", "Astrologie").
Sois précis et universel.

ÉTAPE 2 — Cherche si ce thème correspond à une catégorie existante (correspondance approchée acceptée).
- Si OUI → réponds avec le nom EXACT de la catégorie existante
- Si NON → réponds avec le nom du thème que tu as identifié à l'étape 1 (ce sera une nouvelle catégorie créée)

Règles absolues :
- Réponse = UN SEUL nom, rien d'autre
- Jamais "Non classé"
- Toujours trouver quelque chose
- Maximum 3 mots'''
            }
          ],
        }),
      ).timeout(const Duration(seconds: 8));

      if (response.statusCode != 200) {
        debugPrint('CLAUDE ERROR: ${response.statusCode} ${response.body}');
        return null;
      }
      final data = jsonDecode(response.body);
      final result = (data['content'][0]['text'] as String).trim();
      debugPrint('CLAUDE REPONSE: "$result"');
      return result.isEmpty ? null : result;
    } catch (e) {
      debugPrint('CLAUDE ERREUR: $e');
      return null;
    }
  }
}
