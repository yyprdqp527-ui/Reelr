#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Étape 2 (corrigée) :
Modifie lib/screens/settings_screen.dart pour que les entrées
"Privacy Policy" et "Terms of Use" naviguent vers LegalDocumentScreen avec
le contenu de lib/models/legal_content.dart, au lieu d'ouvrir une URL externe.

legal_document_screen.dart a déjà été créé à l'étape précédente, on n'y touche pas.
Ne touche à rien d'autre dans settings_screen.dart. Aucune autre logique modifiée.
"""
import sys

SETTINGS_PATH = "lib/screens/settings_screen.dart"

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

# 2) Remplacer l'onTap de Privacy Policy (indentation réelle: 20 espaces pour _SettingsRow)
OLD_PRIVACY = """                    _SettingsRow(
                      icon: Icons.privacy_tip_outlined,
                      label: l.t('settings_privacy_policy'),
                      trailing: const Icon(Icons.chevron_right_rounded),
                      onTap: () =>
                          _launchUrl('https://www.privacypolicies.com/live/c2a22de0-c99c-487c-8f55-75e7958bd439'),
                    ),"""
NEW_PRIVACY = """                    _SettingsRow(
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
    print(f"ERREUR: bloc Privacy Policy trouvé {settings.count(OLD_PRIVACY)} fois (attendu 1). Aucune modification effectuée.")
    sys.exit(1)
settings = settings.replace(OLD_PRIVACY, NEW_PRIVACY)

# 3) Remplacer l'onTap de Terms of Use (même indentation: 20 espaces)
OLD_TERMS = """                    _SettingsRow(
                      icon: Icons.gavel_outlined,
                      label: l.t('settings_terms'),
                      trailing: const Icon(Icons.chevron_right_rounded),
                      onTap: () =>
                          _launchUrl('https://www.privacypolicies.com/live/b85682de-7528-4a66-a716-f94c0eab9d3d'),
                    ),"""
NEW_TERMS = """                    _SettingsRow(
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
    print(f"ERREUR: bloc Terms of Use trouvé {settings.count(OLD_TERMS)} fois (attendu 1). Aucune modification effectuée.")
    sys.exit(1)
settings = settings.replace(OLD_TERMS, NEW_TERMS)

with open(SETTINGS_PATH, "w", encoding="utf-8") as f:
    f.write(settings)

print(f"OK: {SETTINGS_PATH} modifié avec succès (Privacy Policy + Terms of Use -> écrans internes).")
