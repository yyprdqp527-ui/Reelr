#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Ajoute le lien "Gérer mon abonnement" requis par Apple (Guideline 3.1.2)
pour toute app avec auto-renewable subscription.

1) Ajoute la clé de traduction 'settings_manage_subscription' en FR et EN
   dans lib/core/l10n.dart.
2) Ajoute une entrée _SettingsRow dans lib/screens/settings_screen.dart,
   section "Mes données", qui ouvre apps.apple.com/account/subscriptions.

Ne touche à rien d'autre.
"""
import sys

L10N_PATH = "lib/core/l10n.dart"
SETTINGS_PATH = "lib/screens/settings_screen.dart"

# --- 1) l10n.dart ---

with open(L10N_PATH, "r", encoding="utf-8") as f:
    l10n = f.read()

OLD_FR = """      'settings_delete_all_confirm_sub':
          'Cette action supprimera définitivement tous vos clips.',
      'settings_legal_section': 'Légal',"""
NEW_FR = """      'settings_delete_all_confirm_sub':
          'Cette action supprimera définitivement tous vos clips.',
      'settings_manage_subscription': 'Gérer mon abonnement',
      'settings_legal_section': 'Légal',"""

OLD_EN = """      'settings_delete_all_confirm_sub':
          'This will permanently delete all your clips.',
      'settings_legal_section': 'Legal',"""
NEW_EN = """      'settings_delete_all_confirm_sub':
          'This will permanently delete all your clips.',
      'settings_manage_subscription': 'Manage my subscription',
      'settings_legal_section': 'Legal',"""

for label, old, new in [("FR", OLD_FR, NEW_FR), ("EN", OLD_EN, NEW_EN)]:
    if old not in l10n:
        print(f"ERREUR: bloc {label} introuvable dans l10n.dart. Aucune modification effectuée.")
        sys.exit(1)
    count = l10n.count(old)
    if count != 1:
        print(f"ERREUR: bloc {label} trouvé {count} fois (attendu 1). Aucune modification effectuée.")
        sys.exit(1)

l10n = l10n.replace(OLD_FR, NEW_FR)
l10n = l10n.replace(OLD_EN, NEW_EN)

with open(L10N_PATH, "w", encoding="utf-8") as f:
    f.write(l10n)

print(f"OK: {L10N_PATH} modifié (clé settings_manage_subscription ajoutée en FR + EN).")

# --- 2) settings_screen.dart ---

with open(SETTINGS_PATH, "r", encoding="utf-8") as f:
    settings = f.read()

OLD_ROW = """                      _SettingsRow(
                        icon: Icons.delete_outline,
                        label: l.t('settings_delete_all_data'),
                        labelStyle: const TextStyle(color: Colors.red),
                        trailing: const Icon(Icons.chevron_right_rounded,
                            color: Colors.red),
                        onTap: () => _deleteAllData(context),
                      ),"""
NEW_ROW = """                      _SettingsRow(
                        icon: Icons.delete_outline,
                        label: l.t('settings_delete_all_data'),
                        labelStyle: const TextStyle(color: Colors.red),
                        trailing: const Icon(Icons.chevron_right_rounded,
                            color: Colors.red),
                        onTap: () => _deleteAllData(context),
                      ),
                      _SettingsRow(
                        icon: Icons.card_membership_outlined,
                        label: l.t('settings_manage_subscription'),
                        trailing: const Icon(Icons.chevron_right_rounded),
                        onTap: () => _launchUrl(
                            'https://apps.apple.com/account/subscriptions'),
                      ),"""

if OLD_ROW not in settings:
    print("ERREUR: bloc 'Supprimer toutes les données' introuvable dans settings_screen.dart. Aucune modification effectuée.")
    sys.exit(1)
count = settings.count(OLD_ROW)
if count != 1:
    print(f"ERREUR: bloc trouvé {count} fois (attendu 1) dans settings_screen.dart. Aucune modification effectuée.")
    sys.exit(1)

settings = settings.replace(OLD_ROW, NEW_ROW)

with open(SETTINGS_PATH, "w", encoding="utf-8") as f:
    f.write(settings)

print(f"OK: {SETTINGS_PATH} modifié (entrée 'Gérer mon abonnement' ajoutée).")
