#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Étape 2 :
1) Crée lib/screens/legal_document_screen.dart (écran générique d'affichage
   d'un document légal avec rendu markdown minimal, sans dépendance externe).
2) Modifie lib/screens/settings_screen.dart pour que les entrées
   "Privacy Policy" et "Terms of Use" naviguent vers cet écran avec le
   contenu de lib/models/legal_content.dart, au lieu d'ouvrir une URL externe.

Ne touche à rien d'autre. Aucune autre logique modifiée.
"""
import sys

SCREEN_PATH = "lib/screens/legal_document_screen.dart"
SETTINGS_PATH = "lib/screens/settings_screen.dart"

SCREEN_CONTENT = '''import 'package:flutter/material.dart';

/// Écran générique pour afficher un document légal (Privacy Policy, CGU/CGV)
/// directement dans l'application, sans dépendre d'une URL externe.
///
/// Le contenu est passé en paramètre sous forme de texte avec une syntaxe
/// markdown minimale :
///   - une ligne commençant par "# " est un titre principal
///   - une ligne commençant par "## " est un sous-titre
///   - une ligne commençant par "### " est un sous-sous-titre
///   - une ligne entourée de "**...**" est mise en gras
///   - une ligne commençant par "- " est un item de liste
///   - les lignes vides créent un espacement entre paragraphes
class LegalDocumentScreen extends StatelessWidget {
  final String title;
  final String content;

  const LegalDocumentScreen({
    super.key,
    required this.title,
    required this.content,
  });

  List<Widget> _buildBlocks(BuildContext context) {
    final lines = content.split('\\n');
    final blocks = <Widget>[];
    final theme = Theme.of(context);

    for (final rawLine in lines) {
      final line = rawLine.trimRight();
      if (line.isEmpty) {
        blocks.add(const SizedBox(height: 12));
        continue;
      }
      if (line.startsWith('# ')) {
        blocks.add(Padding(
          padding: const EdgeInsets.only(bottom: 8, top: 4),
          child: Text(
            line.substring(2),
            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 22),
          ),
        ));
        continue;
      }
      if (line.startsWith('## ')) {
        blocks.add(Padding(
          padding: const EdgeInsets.only(bottom: 6, top: 14),
          child: Text(
            line.substring(3),
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 17),
          ),
        ));
        continue;
      }
      if (line.startsWith('### ')) {
        blocks.add(Padding(
          padding: const EdgeInsets.only(bottom: 4, top: 10),
          child: Text(
            line.substring(4),
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
          ),
        ));
        continue;
      }
      if (line.startsWith('**') && line.endsWith('**') && line.length > 4) {
        blocks.add(Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Text(
            line.substring(2, line.length - 2),
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
          ),
        ));
        continue;
      }
      if (line.startsWith('- ')) {
        blocks.add(Padding(
          padding: const EdgeInsets.only(left: 8, bottom: 4),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('\\u2022  ', style: TextStyle(fontSize: 14)),
              Expanded(
                child: Text(line.substring(2),
                    style: const TextStyle(fontSize: 14, height: 1.4)),
              ),
            ],
          ),
        ));
        continue;
      }
      blocks.add(Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Text(
          line,
          style: TextStyle(
            fontSize: 14,
            height: 1.4,
            color: theme.textTheme.bodyMedium?.color,
          ),
        ),
      ));
    }
    return blocks;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: _buildBlocks(context),
          ),
        ),
      ),
    );
  }
}
'''

with open(SCREEN_PATH, "w", encoding="utf-8") as f:
    f.write(SCREEN_CONTENT)
print(f"OK: {SCREEN_PATH} créé.")

# --- Modification de settings_screen.dart ---

with open(SETTINGS_PATH, "r", encoding="utf-8") as f:
    settings = f.read()

# 1) Ajouter les imports nécessaires (après l'import existant de glass_card.dart)
OLD_IMPORTS = "import '../widgets/glass_card.dart';\n"
NEW_IMPORTS = (
    "import '../widgets/glass_card.dart';\n"
    "import '../models/legal_content.dart';\n"
    "import 'legal_document_screen.dart';\n"
)
if OLD_IMPORTS not in settings:
    print("ERREUR: bloc d'imports introuvable. Aucune modification effectuée.")
    sys.exit(1)
if settings.count(OLD_IMPORTS) != 1:
    print("ERREUR: bloc d'imports trouvé plusieurs fois. Aucune modification effectuée.")
    sys.exit(1)
settings = settings.replace(OLD_IMPORTS, NEW_IMPORTS)

# 2) Remplacer l'onTap de Privacy Policy
OLD_PRIVACY = """                      _SettingsRow(
                        icon: Icons.privacy_tip_outlined,
                        label: l.t('settings_privacy_policy'),
                        trailing: const Icon(Icons.chevron_right_rounded),
                        onTap: () =>
                            _launchUrl('https://www.privacypolicies.com/live/c2a22de0-c99c-487c-8f55-75e7958bd439'),
                      ),"""
NEW_PRIVACY = """                      _SettingsRow(
                        icon: Icons.privacy_tip_outlined,
                        label: l.t('settings_privacy_policy'),
                        trailing: const Icon(Icons.chevron_right_rounded),
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => LegalDocumentScreen(
                              title: l.t('settings_privacy_policy'),
                              content: legalPrivacyPolicyFr,
                            ),
                          ),
                        ),
                      ),"""
if OLD_PRIVACY not in settings:
    print("ERREUR: bloc Privacy Policy introuvable. Aucune modification effectuée.")
    sys.exit(1)
if settings.count(OLD_PRIVACY) != 1:
    print("ERREUR: bloc Privacy Policy trouvé plusieurs fois. Aucune modification effectuée.")
    sys.exit(1)
settings = settings.replace(OLD_PRIVACY, NEW_PRIVACY)

# 3) Remplacer l'onTap de Terms of Use
OLD_TERMS = """                      _SettingsRow(
                        icon: Icons.gavel_outlined,
                        label: l.t('settings_terms'),
                        trailing: const Icon(Icons.chevron_right_rounded),
                        onTap: () =>
                            _launchUrl('https://www.privacypolicies.com/live/b85682de-7528-4a66-a716-f94c0eab9d3d'),
                      ),"""
NEW_TERMS = """                      _SettingsRow(
                        icon: Icons.gavel_outlined,
                        label: l.t('settings_terms'),
                        trailing: const Icon(Icons.chevron_right_rounded),
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => LegalDocumentScreen(
                              title: l.t('settings_terms'),
                              content: legalTermsFr,
                            ),
                          ),
                        ),
                      ),"""
if OLD_TERMS not in settings:
    print("ERREUR: bloc Terms of Use introuvable. Aucune modification effectuée.")
    sys.exit(1)
if settings.count(OLD_TERMS) != 1:
    print("ERREUR: bloc Terms of Use trouvé plusieurs fois. Aucune modification effectuée.")
    sys.exit(1)
settings = settings.replace(OLD_TERMS, NEW_TERMS)

with open(SETTINGS_PATH, "w", encoding="utf-8") as f:
    f.write(settings)

print(f"OK: {SETTINGS_PATH} modifié avec succès (Privacy Policy + Terms of Use -> écrans internes).")
