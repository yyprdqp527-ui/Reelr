#!/bin/bash
# sync_ext_version.sh — aligne la version de la Share Extension Reelrshare
# sur celle de pubspec.yaml (version: X.Y.Z+N).
#
# A LANCER AVANT CHAQUE `flutter build ipa`.
#   ./sync_ext_version.sh
#
# Pourquoi : la target Reelrshare a GENERATE_INFOPLIST_FILE = YES, sa version
# vient donc de MARKETING_VERSION / CURRENT_PROJECT_VERSION dans le pbxproj.
# Ces valeurs ne suivent PAS pubspec.yaml automatiquement (la target n'a pas
# de baseConfigurationReference vers Generated.xcconfig). Si elles divergent
# de l'app, Apple renvoie l'avertissement ITMS-90473 a l'upload.

set -euo pipefail
cd "$(dirname "$0")"

PBX="ios/Runner.xcodeproj/project.pbxproj"
[ -f pubspec.yaml ] || { echo "pubspec.yaml introuvable"; exit 1; }
[ -f "$PBX" ]       || { echo "$PBX introuvable"; exit 1; }

RAW=$(grep -m1 '^version:' pubspec.yaml | awk '{print $2}')
NAME="${RAW%%+*}"
NUM="${RAW##*+}"

if [ -z "$NAME" ] || [ -z "$NUM" ] || [ "$NAME" = "$NUM" ]; then
  echo "Version pubspec illisible : '$RAW' (attendu X.Y.Z+N)"; exit 1
fi

echo "pubspec : $NAME ($NUM)"

# Etat avant
echo "--- AVANT ---"
grep -n 'MARKETING_VERSION\|CURRENT_PROJECT_VERSION' "$PBX" | grep -v '= 1.0;' | grep -v '= 1;'

# On ne touche QUE les 3 configs Reelrshare : les valeurs des autres targets
# sont differentes (RunnerTests = 1.0 / 1, Runner = $(FLUTTER_BUILD_*)).
perl -0pi -e "s/MARKETING_VERSION = (?!1\.0;)[0-9][^;]*;/MARKETING_VERSION = $NAME;/g" "$PBX"
perl -0pi -e "s/CURRENT_PROJECT_VERSION = (?!1;|\"\\\$)[0-9][^;]*;/CURRENT_PROJECT_VERSION = $NUM;/g" "$PBX"

echo "--- APRES ---"
grep -n 'MARKETING_VERSION\|CURRENT_PROJECT_VERSION' "$PBX" | grep -v '= 1.0;' | grep -v '= 1;'

# Garde-fou : 3 configs attendues (Debug / Release / Profile)
M=$(grep -c "MARKETING_VERSION = $NAME;" "$PBX")
C=$(grep -c "CURRENT_PROJECT_VERSION = $NUM;" "$PBX")
if [ "$M" -ne 3 ] || [ "$C" -ne 3 ]; then
  echo "ECHEC : attendu 3+3, obtenu $M+$C — verifie 'git diff $PBX' et annule si besoin."
  exit 1
fi

echo "OK — Reelrshare aligne sur $NAME ($NUM)."
