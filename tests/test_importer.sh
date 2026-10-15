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
# V12.53 : config lisible d'un script compagnon (jeton absent d'ox_inventory → ajouté), ox_inventory du serveur
printf "Config = {}\nConfig.TokenItem = 'bowling_token'\nConfig.Price = 50\n-- exports.ox_inventory:AddItem(src, 'water', 1)\n" > "$B/pk/patoche_bowlinggame_script/config.lua"
mkdir -p "$R/server-data/resources/[ox]/ox_inventory/data"; printf "return {\n    ['water'] = { label = 'Eau', weight = 500 },\n}\n" > "$R/server-data/resources/[ox]/ox_inventory/data/items.lua"

mk pw patoche_wipeout_pack "fx_version 'cerulean'\nthis_is_a_map 'yes'\n"; mkdir -p "$B/pw/patoche_wipeout_pack/stream"; head -c 99 /dev/urandom > "$B/pw/patoche_wipeout_pack/stream/w.ymap"
mk ps patoche_wipeout_script "fx_version 'cerulean'\ndependency 'pas_installee'\n"; head -c 99 /dev/urandom > "$B/ps/patoche_wipeout_script/a.lua"
mk pl patoche_lonely_script "fx_version 'cerulean'\n"; head -c 99 /dev/urandom > "$B/pl/patoche_lonely_script/a.lua"
# Map retirée par décision (RETIRED_MAPS de maps.js), supprimée à la main, serveur pas encore redémarré : jamais réinstallée
mk pr patoche_plasmakart_map "fx_version 'cerulean'\nthis_is_a_map 'yes'\n"; mkdir -p "$B/pr/patoche_plasmakart_map/stream"; head -c 99 /dev/urandom > "$B/pr/patoche_plasmakart_map/stream/k.ymap"
# V12.36 : retraits par MOTIF (aucun de ces noms n'est dans RETIRED_MAPS) : map DLC2 du laser game, son script compagnon, pack Redline
mk pd patoche_plasmagame_dlc2_map "fx_version 'cerulean'\nthis_is_a_map 'yes'\n"; mkdir -p "$B/pd/patoche_plasmagame_dlc2_map/stream"; head -c 99 /dev/urandom > "$B/pd/patoche_plasmagame_dlc2_map/stream/d.ymap"
mk pg patoche_plasmagame_script "fx_version 'cerulean'\n"; head -c 99 /dev/urandom > "$B/pg/patoche_plasmagame_script/a.lua"
mk pe energy_redline_pack "fx_version 'cerulean'\nthis_is_a_map 'yes'\n"; mkdir -p "$B/pe/energy_redline_pack/stream"; head -c 99 /dev/urandom > "$B/pe/energy_redline_pack/stream/r.ymap"
# V12.48 : bibliothèque du vendeur livrée seule (modèles → rangée « map ») réclamée par un script : nom exact attendu
mk pc patoche_chalet_map "fx_version 'cerulean'\nthis_is_a_map 'yes'\n"; mkdir -p "$B/pc/patoche_chalet_map/stream"; head -c 99 /dev/urandom > "$B/pc/patoche_chalet_map/stream/c.ymap"
mk pcs patoche_chalet_script "fx_version 'cerulean'\ndependencies {\n 'ox_lib',\n 'patoche_interact'\n}\n"; head -c 99 /dev/urandom > "$B/pcs/patoche_chalet_script/a.lua"
mk pi patoche_interact "fx_version 'cerulean'\n"; mkdir -p "$B/pi/patoche_interact/stream"; head -c 99 /dev/urandom > "$B/pi/patoche_interact/stream/i.ydr"; head -c 99 /dev/urandom > "$B/pi/patoche_interact/c.lua"
mkdir -p "$R/server-data/resources/[addons]/gsa_patoche_interact_pack"; touch "$R/server-data/resources/[addons]/gsa_patoche_interact_pack/fxmanifest.lua"
# V12.48 : mod déjà converti (version ROADTRIP) mais livré avec un fxmanifest : plus démarré ; refus manuel
mkdir -p "$B/pn/natt_hair5_fivem/stream"; printf "fx_version 'cerulean'\n" > "$B/pn/natt_hair5_fivem/fxmanifest.lua"; head -c 99 /dev/urandom > "$B/pn/natt_hair5_fivem/stream/hair_000_u.ydd"
mkdir -p "$R/server-data/resources/[addons]/gsa_natt_hair5_fivem"; touch "$R/server-data/resources/[addons]/gsa_natt_hair5_fivem/fxmanifest.lua"
mkdir -p "$B/pa/afro"; head -c 99 /dev/urandom > "$B/pa/afro/hair_000_u.ydd"; head -c 99 /dev/urandom > "$B/pa/afro/hair_diff_000_a_uni.ytd"
# Script compagnon déjà installé (dossier présent) : sa ligne de addons.cfg était gardée tant que le dossier existait
mkdir -p "$R/server-data/resources/[addons]/patoche_plasmagame_script"; touch "$R/server-data/resources/[addons]/patoche_plasmagame_script/fxmanifest.lua"
# Noms d'archives comme ceux du portail Cfx (le nom d'une map installée vient de son archive)
for z in pr:patoche_plasmakart_pack pk:patoche_bowlinggame_pack pw:patoche_wipeout_pack ps:patoche_wipeout_script pl:patoche_lonely_script pd:patoche_plasmagame_dlc2_pack pg:patoche_plasmagame_script pe:energy_redline_pack pc:patoche_chalet_pack pcs:patoche_chalet_script pi:patoche_interact_pack pn:natt_hair5_fivem pa:afro_for_lamar_tykus; do (cd "$B/${z%%:*}" && zip -qr "$R/mods-a-trier/${z#*:}.zip" .); done
printf '# Mods retirés\npatoche_villa_bunker_pack\nmlo_willies_supermarket\n' > "$R/mods-retires.txt"
printf 'ensure gsa_ancienne_map\nensure script_disparu\nensure gsa_patoche_plasmakart_pack\nensure gsa_energy_redline_pack\nensure patoche_plasmagame_script\nensure gsa_patoche_interact_pack\nensure gsa_natt_hair5_fivem\n' > "$R/server-data/cfg/addons.cfg"
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
# V12.48
check 'bibliothèque réclamée installée sous le nom attendu (patoche_interact), son script compagnon aussi' 'grep -q "^ensure patoche_interact$" <<<"$CFG" && [ -d "$R/server-data/resources/[addons]/patoche_interact" ] && grep -q "^ensure patoche_chalet_script$" <<<"$CFG"'
check 'ancienne copie gsa_patoche_interact_pack plus démarrée' '! grep -q "gsa_patoche_interact_pack" <<<"$CFG"'
check 'mod déjà converti (natt_hair5_fivem) : pas installé, plus démarré' '! grep -q "natt_hair5" <<<"$CFG" && grep -A1 "^- natt_hair5_fivem" <<<"$REP" | grep -q "déjà converti"'
check 'refus manuel (afro de Lamar) : rejeté avec sa raison' 'grep -A1 "^- afro_for_lamar_tykus" <<<"$REP" | grep -q "Lamar"'
ITEMS=$(cat "$R/server-data/resources/[ox]/ox_inventory/data/items.lua")
check 'objet réclamé par un script ajouté à ox_inventory (une seule fois, objet existant non doublé)' 'grep -q "\[.bowling_token.\] = { label = .Jeton." <<<"$ITEMS" && [ "$(grep -c "\[.water.\]" <<<"$ITEMS")" = 1 ] && grep -q "bowling_token" <<<"$REP" && luac5.4 -p "$R/server-data/resources/[ox]/ox_inventory/data/items.lua"'
# V12.59 · « les mods à trier ne passent pas à chaque fois » : zips Google Drive coupés en morceaux, mod sans fxmanifest à
# côté de ressources, dossier déjà décompressé, archive en volumes, signature gardée seulement si tout est installé.
R2=$T/root2; B2=$T/build2; mkdir -p "$R2/mods-a-trier" "$R2/server-data/cfg" "$R2/server-data/resources/[qbx]/qbx_core/shared" "$B2"
touch "$R2/server-data/resources/[qbx]/qbx_core/fxmanifest.lua"; printf "return {\n    ['adder'] = {},\n}\n" > "$R2/server-data/resources/[qbx]/qbx_core/shared/vehicles.lua"
veh() { mkdir -p "$1/stream" "$1/data"; head -c 300 /dev/urandom > "$1/stream/$2.yft"; head -c 300 /dev/urandom > "$1/stream/$2.ytd"
    printf "<CVehicleModelInfo__InitDataList><InitDatas><Item><modelName>$2</modelName><vehicleClass>VC_SPORT</vehicleClass></Item></InitDatas></CVehicleModelInfo__InitDataList>" > "$1/data/vehicles.meta"
    printf "fx_version 'cerulean'\ngame 'gta5'\nfiles {'data/*.meta'}\ndata_file 'VEHICLE_METADATA_FILE' 'data/vehicles.meta'\n" > "$1/fxmanifest.lua"; }
veh "$B2/full/GTA/acheval" acheval; veh "$B2/d1/GTA/entier" entier
mkdir -p "$B2/d1/GTA/acheval" "$B2/d2/GTA/acheval"; cp -r "$B2/full/GTA/acheval/stream" "$B2/d1/GTA/acheval/"; cp -r "$B2/full/GTA/acheval/data" "$B2/full/GTA/acheval/fxmanifest.lua" "$B2/d2/GTA/acheval/"
(cd "$B2/d1" && zip -qr "$R2/mods-a-trier/GTA-20261014T101500Z-001.zip" .); (cd "$B2/d2" && zip -qr "$R2/mods-a-trier/GTA-20261014T101500Z-002.zip" .)
veh "$B2/mix/res_a" res_a; veh "$B2/mix/res_b" res_b; mkdir -p "$B2/mix/seule"; head -c 300 /dev/urandom > "$B2/mix/seule/seule.yft"; head -c 300 /dev/urandom > "$B2/mix/seule/seule.ytd"
(cd "$B2/mix" && zip -qr "$R2/mods-a-trier/melange.zip" .)
veh "$R2/mods-a-trier/deja_extrait" dejaextrait
veh "$B2/vol/envol" envol; (cd "$B2/vol" && "$SEVENZ" a -v20k "$R2/mods-a-trier/envol.7z" . >/dev/null)
run2() { GTASOON_ROOT=$R2 GTASOON_TEST=1 GTASOON_7Z=$SEVENZ GTASOON_TEXOPT=0 "$@" "$PWSH" -NoProfile -File "$REPO/scripts/windows/importer-mods.ps1" > "$T/log2.txt" 2>&1 || { cat "$T/log2.txt"; exit 1; }; }
run2 env
CFG2=$(cat "$R2/server-data/cfg/addons.cfg"); A2="$R2/server-data/resources/[addons]"
check 'zip Drive en 2 morceaux : le mod à cheval est installé entier (modèle + .meta)' 'grep -q "^ensure gsa_acheval$" <<<"$CFG2" && ls "$A2/gsa_acheval/stream" | grep -q acheval.yft && [ -n "$(find "$A2/gsa_acheval" -name vehicles.meta)" ] && grep -q "^ensure gsa_entier$" <<<"$CFG2"'
check 'mod sans fxmanifest à côté de 2 ressources : plus effacé' 'grep -q "^ensure gsa_res_a$" <<<"$CFG2" && grep -q "^ensure gsa_res_b$" <<<"$CFG2" && [ -n "$(find "$A2" -name seule.yft)" ]'
check 'dossier déjà décompressé dans mods-a-trier : importé' 'grep -q "^ensure gsa_deja_extrait$" <<<"$CFG2"'
check 'archive en volumes (.7z.001) : importée' 'grep -q "^ensure gsa_envol$" <<<"$CFG2"'
check 'import réussi : signature gardée, METTRE-A-JOUR ne refait rien' '[ -f "$R2/mods-tri/.derniere-signature" ] && run2 env GTASOON_CHAIN=1 && grep -q "rien de nouveau" "$T/log2.txt"'
check 'dossier modifié : réimporté par METTRE-A-JOUR' 'head -c 10 /dev/urandom > "$R2/mods-a-trier/deja_extrait/stream/x.ytd" && run2 env GTASOON_CHAIN=1 && ! grep -q "rien de nouveau" "$T/log2.txt"'
echo "importeur (scripts compagnons, retraits) : $ok réussis, $ko échoués"
[ "$ko" -eq 0 ]
