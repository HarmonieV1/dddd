#!/usr/bin/env bash
# V12.57 · ENVOYER-PLACEMENTS : sur le VPS, « roadline-bdd.sh placements » n'accepte QUE les tables de placements,
# sauvegarde la base avant, puis importe. MariaDB simulé (faux mariadb / mariadb-dump qui notent leurs appels).
set -euo pipefail
cd "$(dirname "$0")/.."
T=$(mktemp -d); trap 'rm -rf "$T"' EXIT
mkdir -p "$T/bin" "$T/outils"
cp scripts/linux/roadline-bdd.sh "$T/outils/"
printf 'DB_NAME=roadline\nDB_USER=u\nDB_PASS=p\nBACKUP_DIR=%s/sauv\n' "$T" > "$T/outils/.env"
cat > "$T/bin/mariadb-dump" <<'S'
#!/usr/bin/env bash
printf 'CREATE TABLE `players` (x int);\n'; head -c 3000 /dev/urandom | base64
S
cat > "$T/bin/mariadb" <<S
#!/usr/bin/env bash
cat >> "$T/import.sql"
S
chmod +x "$T/bin/"*
export PATH="$T/bin:$PATH"
ok=0; ko=0
check() { if eval "$2"; then ok=$((ok + 1)); else ko=$((ko + 1)); echo "ÉCHEC : $1" >&2; fi; }

printf 'DROP TABLE IF EXISTS `ox_doorlock`;\nCREATE TABLE `ox_doorlock` (id int);\nINSERT INTO `ox_doorlock` VALUES (1);\nCREATE TABLE `gs_builder_objects` (id int);\n' | gzip > "$T/bon.sql.gz"
printf 'CREATE TABLE `ox_doorlock` (id int);\nCREATE TABLE `players` (citizenid varchar(9));\n' | gzip > "$T/piege.sql.gz"
printf -- '-- vide\n' | gzip > "$T/vide.sql.gz"

out=$("$T/outils/roadline-bdd.sh" placements "$T/piege.sql.gz" 2>&1 || true)
check 'table « players » refusée' '[[ "$out" == *REFUSÉ*players* ]] && [ ! -f "$T/import.sql" ]'
out=$("$T/outils/roadline-bdd.sh" placements "$T/vide.sql.gz" 2>&1 || true)
check 'fichier sans table refusé' '[[ "$out" == *REFUSÉ* ]] && [ ! -f "$T/import.sql" ]'
out=$("$T/outils/roadline-bdd.sh" placements "$T/bon.sql.gz" 2>&1)
check 'placements importés' '[[ "$out" == *"ox_doorlock gs_builder_objects"* ]] && grep -q "INSERT INTO \`ox_doorlock\`" "$T/import.sql"'
check 'base sauvegardée avant' 'ls "$T/sauv/"roadline_*-avant-placements.sql.gz >/dev/null 2>&1'
check 'clés étrangères neutralisées pendant l import' 'head -1 "$T/import.sql" | grep -q "FOREIGN_KEY_CHECKS=0"'
# La liste du PC (envoyer-placements.ps1) = celle du VPS
pc=$(grep -o "'[a-z_]*'" scripts/windows/envoyer-placements.ps1 | grep -E "ox_doorlock|gs_" | tr -d "'" | sort | tr '\n' ' ')
vps=$(grep -m1 '^PLACEMENTS=' scripts/linux/roadline-bdd.sh | cut -d'"' -f2 | tr ' ' '\n' | sort | tr '\n' ' ')
check 'même liste de tables PC / VPS' '[ "$pc" = "$vps" ]'
echo "test_placements : $ok OK, $ko échec(s)"
[ "$ko" -eq 0 ]
