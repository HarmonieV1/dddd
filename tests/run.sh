#!/usr/bin/env bash
# Syntaxe de tout le Lua, linter de config, tests de logique serveur. Nécessite lua5.4 et python3.
set -euo pipefail
cd "$(dirname "$0")/.."
find server/resources -name '*.lua' -print0 | xargs -0 -n1 luac5.4 -p
echo "Syntaxe OK"
python3 tests/check_cfg.py
python3 tests/check_links.py
for t in tests/test_*.lua; do
    echo "== $t"
    lua5.4 "$t"
done
