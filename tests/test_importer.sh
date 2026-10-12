#!/usr/bin/env bash
# IMPORTER-MODS de bout en bout (PowerShell 7 + 7-Zip requis, sinon ignoré) : faux pack payant « map + script + librairie »,
# script dont une dépendance manque, map remise en service (mods-retires.txt). V12.31.
set -euo pipefail
PWSH=${PWSH:-$(command -v pwsh || true)}
SEVENZ=$(command -v 7z || true)
if [ -z "$PWSH" ] || [ -z "$SEVENZ" ] || ! command -v zip >/dev/null; then echo "Importeur : PowerShell 7 / 7-Zip / zip absents, test ignoré"; exit 0; fi
REPO=$(cd "$(dirname "$0")/.." && pwd)
T=${KEEP_T:-$(mktemp -d)}; [ -n "${KEEP_T:-}" ] || trap 'rm -rf "$T"' EXIT; mkdir -p "$T"
R=$T/root; B=$T/build
mkdir -p "$R/mods-a-trier" "$R/server-data/cfg" "$R/server-data/resources/[ox]/ox_lib" "$R/server-data/resources/[qbx]/qbx_core"
touch "$R/server-data/resources/[ox]/ox_lib/fxmanifest.lua" "$R/server-data/resources/[qbx]/qbx_core/fxmanifest.lua"
mk() { mkdir -p "$B/$1/$2"; printf '%b' "$3" > "$B/$1/$2/fxmanifest.lua"; head -c 64 /dev/urandom > "$B/$1/$2/.fxap"; }
mk pk patoche_bowlinggame_map "fx_version 'cerulean'\nthis_is_a_map 'yes'\n"; mkdir -p "$B/pk/patoche_bowlinggame_map/stream"; head -c 200 /dev/urandom > "$B/pk/patoche_bowlinggame_map/stream/pg.ymap"
mk pk patoche_bowlinggame_script "fx_version 'cerulean'\ndependencies {\n 'ox_lib',\n 'qb-core',\n 'patoche_lib',\n '/onesync'\n}\n"; head -c 99 /dev/urandom > "$B/pk/patoche_bowlinggame_script/client.lua"
mk pk patoche_lib "fx_version 'cerulean'\n"; head -c 99 /dev/urandom > "$B/pk/patoche_lib/c.lua"
mk pw patoche_wipeout_pack "fx_version 'cerulean'\nthis_is_a_map 'yes'\n"; mkdir -p "$B/pw/patoche_wipeout_pack/stream"; head -c 99 /dev/urandom > "$B/pw/patoche_wipeout_pack/stream/w.ymap"
mk ps patoche_wipeout_script "fx_version 'cerulean'\ndependency 'pas_installee'\n"; head -c 99 /dev/urandom > "$B/ps/patoche_wipeout_script/a.lua"
mk pl patoche_lonely_script "fx_version 'cerulean'\n"; head -c 99 /dev/urandom > "$B/pl/patoche_lonely_script/a.lua"
# Map retirée par décision (RETIRED_MAPS de maps.js), supprimée à la main, serveur pas encore redémarré : jamais réinstallée
mk pr patoche_plasmakart_map "fx_version 'cerulean'\nthis_is_a_map 'yes'\n"; mkdir -p "$B/pr/patoche_plasmakart_map/stream"; head -c 99 /dev/urandom > "$B/pr/patoche_plasmakart_map/stream/k.ymap"
# Noms d'archives comme ceux du portail Cfx (le nom d'une map installée vient de son archive)
for z in pr:patoche_plasmakart_pack pk:patoche_bowlinggame_pack pw:patoche_wipeout_pack ps:patoche_wipeout_script pl:patoche_lonely_script; do (cd "$B/${z%%:*}" && zip -qr "$R/mods-a-trier/${z#*:}.zip" .); done
printf '# Mods retirés\npatoche_villa_bunker_pack\nmlo_willies_supermarket\n' > "$R/mods-retires.txt"
printf 'ensure gsa_ancienne_map\nensure script_disparu\nensure gsa_patoche_plasmakart_pack\n' > "$R/server-data/cfg/addons.cfg"
GTASOON_ROOT=$R GTASOON_TEST=1 GTASOON_7Z=$SEVENZ GTASOON_TEXOPT=0 "$PWSH" -NoProfile -File "$REPO/scripts/windows/importer-mods.ps1" > "$T/log.txt" 2>&1 || { cat "$T/log.txt"; exit 1; }
CFG=$(cat "$R/server-data/cfg/addons.cfg"); REP=$(cat "$R/mods-tri/RAPPORT-MODS.txt")
ok=0; ko=0
check() { if eval "$2"; then ok=$((ok+1)); else ko=$((ko+1)); echo "ÉCHEC : $1"; fi; }
check 'map installée' 'grep -q "^ensure gsa_patoche_bowlinggame_map$" <<<"$CFG"'
check 'script compagnon installé sous son nom d origine' 'grep -q "^ensure patoche_bowlinggame_script$" <<<"$CFG" && [ -d "$R/server-data/resources/[addons]/patoche_bowlinggame_script" ]'
check 'librairie du vendeur (dépendance dans le même import) installée' 'grep -q "^ensure patoche_lib$" <<<"$CFG"'
check 'dépendance manquante : pas installé, raison dans le rapport' '! grep -q "patoche_wipeout_script" <<<"$CFG" && grep -q "il lui manque pas_installee" <<<"$REP"'
check 'script seul sans map : pas installé' '! grep -q "patoche_lonely_script" <<<"$CFG"'
check 'pas de note contradictoire sur un script installé' '! grep -A3 "^- patoche_bowlinggame_script" <<<"$REP" | grep -q "je le relis"'
check 'ancienne map gardée, ligne d un script disparu retirée' 'grep -q "^ensure gsa_ancienne_map$" <<<"$CFG" && ! grep -q "script_disparu" <<<"$CFG"'
check 'villa bunker sortie de mods-retires.txt, le reste gardé' '! grep -q villa_bunker "$R/mods-retires.txt" && grep -q mlo_willies "$R/mods-retires.txt"'
check 'map retirée (RETIRED_MAPS) jamais réinstallée, sa ligne de addons.cfg enlevée' '! grep -q plasmakart <<<"$CFG" && [ ! -d "$R/server-data/resources/[addons]/gsa_patoche_plasmakart_pack" ] && grep -q "RETIRED_MAPS" <<<"$REP"'
echo "importeur (scripts compagnons) : $ok réussis, $ko échoués"
[ "$ko" -eq 0 ]
