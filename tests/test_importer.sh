#!/usr/bin/env bash
# IMPORTER-MODS de bout en bout (PowerShell 7 + 7-Zip requis, sinon ignoré) : faux pack payant « map + script + librairie »,
# script dont une dépendance manque, map remise en service (mods-retires.txt). V12.31.
# V12.36 : retraits par MOTIF (RETIRED_PATTERNS de maps.js) : plasmagame_dlc2 (nom absent de la liste exacte), pack Redline et le
# script compagnon du laser game ne sont jamais installés, leurs lignes de addons.cfg sont enlevées.
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
# V12.36 : retraits par MOTIF (aucun de ces noms n'est dans RETIRED_MAPS) : map DLC2 du laser game, son script compagnon, pack Redline
mk pd patoche_plasmagame_dlc2_map "fx_version 'cerulean'\nthis_is_a_map 'yes'\n"; mkdir -p "$B/pd/patoche_plasmagame_dlc2_map/stream"; head -c 99 /dev/urandom > "$B/pd/patoche_plasmagame_dlc2_map/stream/d.ymap"
mk pg patoche_plasmagame_script "fx_version 'cerulean'\n"; head -c 99 /dev/urandom > "$B/pg/patoche_plasmagame_script/a.lua"
mk pe energy_redline_pack "fx_version 'cerulean'\nthis_is_a_map 'yes'\n"; mkdir -p "$B/pe/energy_redline_pack/stream"; head -c 99 /dev/urandom > "$B/pe/energy_redline_pack/stream/r.ymap"
# Script compagnon déjà installé (dossier présent) : sa ligne de addons.cfg était gardée tant que le dossier existait
mkdir -p "$R/server-data/resources/[addons]/patoche_plasmagame_script"; touch "$R/server-data/resources/[addons]/patoche_plasmagame_script/fxmanifest.lua"
# Noms d'archives comme ceux du portail Cfx (le nom d'une map installée vient de son archive)
for z in pr:patoche_plasmakart_pack pk:patoche_bowlinggame_pack pw:patoche_wipeout_pack ps:patoche_wipeout_script pl:patoche_lonely_script pd:patoche_plasmagame_dlc2_pack pg:patoche_plasmagame_script pe:energy_redline_pack; do (cd "$B/${z%%:*}" && zip -qr "$R/mods-a-trier/${z#*:}.zip" .); done
printf '# Mods retirés\npatoche_villa_bunker_pack\nmlo_willies_supermarket\n' > "$R/mods-retires.txt"
printf 'ensure gsa_ancienne_map\nensure script_disparu\nensure gsa_patoche_plasmakart_pack\nensure gsa_energy_redline_pack\nensure patoche_plasmagame_script\n' > "$R/server-data/cfg/addons.cfg"
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
check 'map retirée (RETIRED_MAPS) jamais réinstallée, sa ligne de addons.cfg enlevée' '! grep -q plasmakart <<<"$CFG" && [ ! -d "$R/server-data/resources/[addons]/gsa_patoche_plasmakart_pack" ] && grep -q "RETIRED_MAPS" <<<"$REP"'
# V12.36 : motifs
check 'motif plasmagame : DLC2 du laser game jamais installé, raison « RETIRED_PATTERNS » dans le rapport' '! grep -q plasmagame_dlc2 <<<"$CFG" && [ ! -d "$R/server-data/resources/[addons]/gsa_patoche_plasmagame_dlc2_pack" ] && grep -q "RETIRED_PATTERNS" <<<"$REP"'
check 'motif redline : pack Redline jamais installé, sa ligne de addons.cfg enlevée' '! grep -q redline <<<"$CFG" && [ ! -d "$R/server-data/resources/[addons]/gsa_energy_redline_pack" ]'
check 'script compagnon du laser game : pas installé, sa ligne de addons.cfg enlevée malgré son dossier' '! grep -q patoche_plasmagame_script <<<"$CFG"'
check 'les maps gardées ne sont pas touchées par les motifs' 'grep -q "^ensure gsa_patoche_bowlinggame_map$" <<<"$CFG" && grep -q "^ensure gsa_ancienne_map$" <<<"$CFG"'
echo "importeur (scripts compagnons, retraits) : $ok réussis, $ko échoués"
[ "$ko" -eq 0 ]
