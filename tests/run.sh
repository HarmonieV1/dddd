#!/usr/bin/env bash
# Syntaxe de tout le Lua, linter de config, tests de logique serveur. Nécessite lua5.4 et python3.
set -euo pipefail
cd "$(dirname "$0")/.."
find server/resources -name node_modules -prune -o -name '*.lua' -print0 | xargs -0 -n1 luac5.4 -p
echo "Syntaxe OK"
python3 tests/check_cfg.py
python3 tests/check_labels.py
python3 tests/check_links.py
python3 tests/check_honeypot.py
python3 tests/check_crimes.py
# Fusion des fichiers d'occlusion de deux maps (tools/maps/fusion_occlusion.py) ; -B : pas de cache Python (piège des mutations)
python3 -B tests/test_fusion_occlusion.py
python3 tests/check_perf.py
# Liste des marques refusées : identique dans l'importeur et dans NETTOYER-MARQUES.bat
for v in BrandBlock BrandStrong; do
    a=$(grep -m1 "^\$$v = " scripts/windows/importer-mods.ps1 | tr -d '\r'); b=$(grep -m1 "^\$$v = " NETTOYER-MARQUES.bat | tr -d '\r')
    [ -n "$a" ] && [ "$a" = "$b" ] || { echo "ERREUR : \$$v différent entre importer-mods.ps1 et NETTOYER-MARQUES.bat"; exit 1; }
done
echo "Marques OK"
# Site de documentation (docs/hub/index.html) : régénéré à chaque passage, doit se construire sans document manquant
python3 -B tools/doc_hub.py
# DLL de l'optimiseur de textures : un vrai fichier Windows (signature « PE » intacte). Une conversion de fins de ligne
# les avait abîmées (V12.17 : « Le module était censé contenir un manifeste de l'assembly »).
python3 - <<'EOF'
import glob, struct, sys
for f in sorted(glob.glob('tools/textures/*.dll')):
    b = open(f, 'rb').read()
    pe = struct.unpack_from('<I', b, 0x3c)[0] if len(b) > 0x40 else 0
    if b[:2] != b'MZ' or b[pe:pe + 4] != b'PE\0\0':
        sys.exit('ERREUR : ' + f + ' abîmée (fins de ligne ?) : la restaurer et la garder en « binary » dans .gitattributes')
print('DLL textures OK')
EOF
# Faux positif « minigolf » (V12.18) : la marque Golf ne doit pas attraper une map de minigolf
python3 - <<'EOF'
import re, sys
line = [l for l in open('scripts/windows/importer-mods.ps1', encoding='utf-8-sig') if l.startswith('$BrandBlock = ')][0]
block = re.compile(line.split("'")[1])
if block.search('patoche_minigolf_pacific') or not block.search('vw_golf_gti'):
    sys.exit('ERREUR : $BrandBlock (golf / minigolf)')
EOF
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
# Piège Lua : « cond and nil or x » renvoie toujours x (bug trouvé 3 fois à l'audit V10)
if grep -rn --include=*.lua "and nil or" server/resources/\[gtasoon\] ; then echo "ERREUR : « and nil or » ne marche pas en Lua (utiliser un if)"; exit 1; fi
# Piège PowerShell 5.1 : « schtasks … 2>$null » sous ErrorActionPreference=Stop arrête tout le script (METTRE-A-JOUR V10)
if grep -n "schtasks" scripts/windows/*.ps1 | grep -v "cmd /c" | grep -v "try {" | grep -v "^[^:]*:[0-9]*:\s*#" ; then echo "ERREUR : schtasks doit passer par « cmd /c » ou être dans un try"; exit 1; fi
echo "Pièges Lua OK"
for t in tests/test_*.lua; do
    echo "== $t"
    lua5.4 "$t"
done
# Bot Discord intégré au serveur (gs_discord/server/bot.js) : syntaxe, trames, vraie connexion WebSocket locale, logique
if command -v node >/dev/null; then
    node --check "server/resources/[gtasoon]/gs_discord/server/bot.js" && node tests/test_discord_bot.js
    # Lecteur de maps (gs_admin/server/maps.js, F11 → Mappings installés) : emplacement lu dans les .ymap, conflits entre maps
    node --check "server/resources/[gtasoon]/gs_admin/server/maps.js" && node tests/test_gs_maps.js
    # V12.63 · tous les .js d'une ressource partagent un contexte FiveM : pas deux fois le même nom au premier niveau
    node tests/check_js_scope.js
fi
# IMPORTER-MODS de bout en bout (scripts compagnons des maps payantes, V12.31) : seulement si PowerShell 7 est installé
bash tests/test_importer.sh
# V12.60 · DIAGNOSTIC-MODS (vêtements en conflit, voitures en double, fichiers abîmés) : seulement si PowerShell 7 est installé
bash tests/test_diagnostic_mods.sh
# V12.57 · ENVOYER-PLACEMENTS : le VPS n'accepte que les tables de placements, sauvegarde avant
bash tests/test_placements.sh
# V12.61 · screenshot-basic est livré compilé : ses fichiers dist/ doivent être suivis par git (sinon absents du zip)
for f in client.js server.js ui.html; do git ls-files --error-unmatch "server/resources/[gtasoon]/screenshot-basic/dist/$f" >/dev/null 2>&1 || { echo "screenshot-basic : dist/$f absent du dépôt"; exit 1; }; done && echo "screenshot-basic livré compilé OK"
for s in scripts/linux/*.sh; do bash -n "$s" || exit 1; done && echo "Scripts Linux OK (sauvegardes, installation OVH, commande roadline)"
