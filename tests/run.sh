#!/usr/bin/env bash
# Syntaxe de tout le Lua, linter de config, tests de logique serveur. Nécessite lua5.4 et python3.
set -euo pipefail
cd "$(dirname "$0")/.."
find server/resources -name node_modules -prune -o -name '*.lua' -print0 | xargs -0 -n1 luac5.4 -p
echo "Syntaxe OK"
python3 tests/check_cfg.py
python3 tests/check_links.py
python3 tests/check_perf.py
# Liste des marques refusées : identique dans l'importeur et dans NETTOYER-MARQUES.bat
for v in BrandBlock BrandStrong; do
    a=$(grep -m1 "^\$$v = " scripts/windows/importer-mods.ps1 | tr -d '\r'); b=$(grep -m1 "^\$$v = " NETTOYER-MARQUES.bat | tr -d '\r')
    [ -n "$a" ] && [ "$a" = "$b" ] || { echo "ERREUR : \$$v différent entre importer-mods.ps1 et NETTOYER-MARQUES.bat"; exit 1; }
done
echo "Marques OK"
# Correctifs Qbox (outils-communs.ps1) : jamais d'apostrophe doublée dans une chaîne Lua écrite par un correctif
# (dans une chaîne PowerShell entre "…", '' reste '' et casse le fichier Lua — bug qbx_garages de la V7)
python3 - <<'PYEOF'
import re, sys
s = open('scripts/windows/outils-communs.ps1', encoding='utf-8-sig').read()
bad = [m.group(1) for m in re.finditer(r'=\s*"(\'[^"]*\')"', s) if "''" in m.group(1)]
if bad:
    print('ERREUR : correctif Qbox avec apostrophe doublée :', bad); sys.exit(1)
print('Correctifs Qbox OK')
PYEOF
for t in tests/test_*.lua; do
    echo "== $t"
    lua5.4 "$t"
done
# Bot Discord intégré au serveur (gs_discord/server/bot.js) : syntaxe, trames, vraie connexion WebSocket locale, logique
if command -v node >/dev/null; then
    node --check "server/resources/[gtasoon]/gs_discord/server/bot.js" && node tests/test_discord_bot.js
fi
bash -n scripts/linux/roadline-bdd.sh && echo "Script Linux BDD OK"
