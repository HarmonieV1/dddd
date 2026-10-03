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
for t in tests/test_*.lua; do
    echo "== $t"
    lua5.4 "$t"
done
