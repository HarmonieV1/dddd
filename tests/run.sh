#!/usr/bin/env bash
# Vérifie la syntaxe de tout le Lua puis lance les tests de logique serveur. Nécessite lua5.4.
set -euo pipefail
cd "$(dirname "$0")/.."
find server/resources -name '*.lua' -print0 | xargs -0 -n1 luac5.4 -p
echo "Syntaxe OK"
lua5.4 tests/test_gs_jobs.lua
