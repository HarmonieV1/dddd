#!/usr/bin/env bash
# DIAGNOSTIC-MODS (V12.60) de bout en bout (PowerShell 7 requis, sinon ignoré) : fichier abîmé, vêtements en conflit (dlcName),
# voitures en double, fichiers en double, lignes mortes de addons.cfg ; corrections sûres (pause + ligne enlevée) avec copie.
set -euo pipefail
PWSH=${PWSH:-$(command -v pwsh || true)}
if [ -z "$PWSH" ]; then echo "Diagnostic des mods : PowerShell 7 absent, test ignoré"; exit 0; fi
REPO=$(cd "$(dirname "$0")/.." && pwd)
T=${KEEP_T:-$(mktemp -d)}; [ -n "${KEEP_T:-}" ] || trap 'rm -rf "$T"' EXIT
A="$T/server-data/resources/[addons]"; mkdir -p "$A" "$T/server-data/cfg"
rsc() { mkdir -p "$(dirname "$1")"; { printf 'RSC7'; head -c 200 /dev/urandom; } > "$1"; }
meta() { mkdir -p "$(dirname "$1")"; printf '%s' "$2" > "$1"; }
# 1. voiture saine + voiture abîmée (en-tête illisible)
rsc "$A/gsa_bonne/stream/bonne.yft"; meta "$A/gsa_bonne/data/vehicles.meta" '<Item><modelName>bonne</modelName></Item>'
mkdir -p "$A/gsa_cassee/stream"; head -c 300 /dev/urandom > "$A/gsa_cassee/stream/cassee.yft"
# 2. deux packs de vêtements avec la même collection
rsc "$A/gsa_robes_a/stream/x.ydd"; meta "$A/gsa_robes_a/stream/mp_f_freemode_01_gsarobes.ymt" ''
rsc "$A/gsa_robes_b/stream/y.ydd"; meta "$A/gsa_robes_b/data/shop_ped_apparel.meta" '<dlcName>gsarobes</dlcName>'
# 3. même voiture dans deux mods + même fichier (contenu différent)
rsc "$A/gsa_double1/stream/sultan9.yft"; meta "$A/gsa_double1/data/vehicles.meta" '<modelName>sultan9</modelName>'
rsc "$A/gsa_double2/stream/sultan9.yft"; meta "$A/gsa_double2/data/vehicles.meta" '<modelName>sultan9</modelName>'
rsc "$A/gsa_double1/stream/sultan9_livery1.yft"   # V12.62 : gsa_double1 est la copie la plus complète (gardée)
# V12.62 : 3e copie, mais avec une voiture qu'on ne trouve nulle part ailleurs : jamais mise en pause
rsc "$A/gsa_double3/stream/sultan9.yft"; meta "$A/gsa_double3/data/vehicles.meta" '<modelName>sultan9</modelName><modelName>unique9</modelName>'
# 4. pack protégé (chiffré) : jamais signalé abîmé
mkdir -p "$A/gsa_payant/stream"; head -c 300 /dev/urandom > "$A/gsa_payant/stream/map.ydr"; head -c 30 /dev/urandom > "$A/gsa_payant/.fxap"
# 5. V12.63 : copies complètes (même octets) : la copie « _1 » et le mod inclus dans un autre passent en pause ; un pack protégé copié aussi
rsc "$A/gsa_comet/stream/comet.yft"; meta "$A/gsa_comet/data/vehicles.meta" '<modelName>cometx</modelName>'; cp -r "$A/gsa_comet" "$A/gsa_comet_1"
rsc "$A/gsa_comet/stream/comet_livery1.yft"   # gsa_comet = plus complet
mkdir -p "$A/gsa_pat/stream"; head -c 400 /dev/urandom > "$A/gsa_pat/stream/pat.ydr"; head -c 30 /dev/urandom > "$A/gsa_pat/.fxap"; cp -r "$A/gsa_pat" "$A/gsa_pat_pack_1"
rsc "$A/gsa_proche/stream/proche.yft"; cp -r "$A/gsa_proche" "$A/gsa_proche_b"; printf 'x' >> "$A/gsa_proche_b/stream/proche.yft" # presque pareil : gardé
# 6. V12.63 : même map en deux versions (octets différents, mêmes noms de fichiers) : « _1 » en pause, l'original gardé ;
# jamais si l'original est retiré (mods-retires.txt ou RETIRED_MAPS de maps.js : « _1 » est alors son retour) ; mods différents : rien
rsc "$A/gsa_animalerie/stream/petshop.ymap"; rsc "$A/gsa_animalerie/stream/petshop.ytyp"; cp -r "$A/gsa_animalerie" "$A/gsa_animalerie_1"
rsc "$A/gsa_animalerie_1/stream/petshop.ymap"; rsc "$A/gsa_animalerie_1/stream/petshop_v2.ytyp"
rsc "$A/gsa_shadow/stream/shadow.ymap"; rsc "$A/gsa_shadow_1/stream/shadow.ymap"
rsc "$A/gsa_bunker/stream/bunker.ymap"; rsc "$A/gsa_bunker_1/stream/bunker.ymap"
rsc "$A/gsa_garage/stream/garage.ymap"; rsc "$A/gsa_garage_1/stream/autre.ymap"
printf '# retirés\nshadow\n' > "$T/mods-retires.txt"
mkdir -p "$T/server-data/resources/[gtasoon]/gs_admin/server"
printf "const RETIRED_MAPS = [\n  'gsa_bunker', // test\n];\n" > "$T/server-data/resources/[gtasoon]/gs_admin/server/maps.js"
printf 'ensure gsa_comet\nensure gsa_comet_1\nensure gsa_pat\nensure gsa_pat_pack_1\nensure gsa_proche\nensure gsa_proche_b\n' > "$T/copies.cfg"
printf 'ensure gsa_animalerie\nensure gsa_animalerie_1\nensure gsa_shadow\nensure gsa_shadow_1\nensure gsa_bunker\nensure gsa_bunker_1\nensure gsa_garage\nensure gsa_garage_1\n' >> "$T/copies.cfg"
printf 'ensure gsa_bonne\nensure gsa_cassee\nensure gsa_robes_a\nensure gsa_robes_b\nensure gsa_double1\nensure gsa_double2\nensure gsa_double3\nensure gsa_payant\nensure gsa_disparu\n# ensure gsa_pause\n' > "$T/server-data/cfg/addons.cfg"
cat "$T/copies.cfg" >> "$T/server-data/cfg/addons.cfg"
GTASOON_ROOT=$T GTASOON_TEST=1 "$PWSH" -NoProfile -File "$REPO/scripts/windows/diagnostic-mods.ps1" -Fix > "$T/log.txt" 2>&1 || { cat "$T/log.txt"; exit 1; }
REP=$(cat "$T/mods-tri/DIAGNOSTIC-MODS.txt"); CFG=$(cat "$T/server-data/cfg/addons.cfg")
ok=0; ko=0
check() { if eval "$2"; then ok=$((ok+1)); else ko=$((ko+1)); echo "ÉCHEC : $1"; fi; }
check 'fichier abîmé signalé' 'grep -q "gsa_cassee : cassee.yft" <<<"$REP"'
check 'mod sain et pack protégé jamais signalés abîmés' '! grep -q "gsa_bonne :" <<<"$REP" && ! grep -q "gsa_payant :" <<<"$REP"'
check 'vêtements : même collection dans deux packs' 'grep -q "« gsarobes » dans : gsa_robes_a, gsa_robes_b" <<<"$REP"'
check 'voiture en double' 'grep -q "sultan9 dans : gsa_double1, gsa_double2" <<<"$REP"'
check 'fichier en double (contenu différent)' 'grep -q "sultan9.yft : gsa_double1, gsa_double2" <<<"$REP"'
check 'correction sûre : mod abîmé mis en pause avec la raison' 'grep -q "^# ensure gsa_cassee$" <<<"$CFG" && grep -q "## gsa_cassee : désactivé par sécurité" <<<"$CFG"'
check 'correction sûre : ligne d un dossier disparu enlevée' '! grep -q "gsa_disparu" <<<"$CFG"'
check 'les autres lignes ne bougent pas (y compris celles en pause)' 'grep -q "^ensure gsa_bonne$" <<<"$CFG" && grep -q "^# ensure gsa_pause$" <<<"$CFG"'
check 'V12.62 : voiture en double : copie la plus complète gardée, l autre en pause avec la raison' 'grep -q "^ensure gsa_double1$" <<<"$CFG" && grep -q "^# ensure gsa_double2$" <<<"$CFG" && grep -q "## gsa_double2 : en pause (voiture en double, gardée dans gsa_double1" <<<"$CFG"'
check 'V12.62 : rapport : copie mise en pause et copie gardée nommées' 'grep -q "mises en pause : gsa_double2 (gardé : gsa_double1)" <<<"$REP"'
check 'V12.62 : copie qui contient une voiture unique : jamais mise en pause' 'grep -q "^ensure gsa_double3$" <<<"$CFG"'
check 'V12.63 : copie complète (_1) en pause, le plus complet gardé' 'grep -q "^ensure gsa_comet$" <<<"$CFG" && grep -q "^# ensure gsa_comet_1$" <<<"$CFG" && grep -q "## gsa_comet_1 : en pause (copie en double, tout est déjà dans gsa_comet" <<<"$CFG"'
check 'V12.63 : pack protégé copié : la copie en pause' 'grep -q "^ensure gsa_pat$" <<<"$CFG" && grep -q "^# ensure gsa_pat_pack_1$" <<<"$CFG"'
check 'V12.63 : mods presque pareils (un octet de différence) : jamais touchés' 'grep -q "^ensure gsa_proche$" <<<"$CFG" && grep -q "^ensure gsa_proche_b$" <<<"$CFG"'
check 'V12.63 : rapport : section copies en double' 'grep -q "gsa_comet_1 (tout est déjà dans gsa_comet)" <<<"$REP"'
check 'V12.63 : même map en deux versions : « _1 » en pause, l original gardé' 'grep -q "^ensure gsa_animalerie$" <<<"$CFG" && grep -q "^# ensure gsa_animalerie_1$" <<<"$CFG" && grep -q "## gsa_animalerie_1 : en pause (même map en deux versions, gardé : gsa_animalerie" <<<"$CFG"'
check 'V12.63 : original retiré (mods-retires.txt, RETIRED_MAPS) : la version « _1 » reste' 'grep -q "^ensure gsa_shadow_1$" <<<"$CFG" && grep -q "^ensure gsa_bunker_1$" <<<"$CFG"'
check 'V12.63 : mêmes noms de dossier mais maps différentes : rien' 'grep -q "^ensure gsa_garage$" <<<"$CFG" && grep -q "^ensure gsa_garage_1$" <<<"$CFG"'
check 'V12.63 : rapport : section même map en deux versions' 'grep -q "gsa_animalerie_1 (version de gsa_animalerie, gardée)" <<<"$REP"'
check 'copie de sécurité de addons.cfg' '[ -f "$T/server-data/cfg/addons.cfg.avant-diagnostic" ] && grep -q "gsa_disparu" "$T/server-data/cfg/addons.cfg.avant-diagnostic"'
# 2e passage : plus rien à corriger, rien ne change
cp "$T/server-data/cfg/addons.cfg" "$T/avant.cfg"
GTASOON_ROOT=$T GTASOON_TEST=1 "$PWSH" -NoProfile -File "$REPO/scripts/windows/diagnostic-mods.ps1" -Fix > "$T/log2.txt" 2>&1
check '2e passage : addons.cfg identique (idempotent)' 'cmp -s "$T/avant.cfg" "$T/server-data/cfg/addons.cfg"'
echo "diagnostic des mods : $ok réussis, $ko échoués"
[ "$ko" -eq 0 ]
