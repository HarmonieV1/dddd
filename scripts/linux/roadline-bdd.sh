#!/usr/bin/env bash
# RoadLine RP · sauvegarde / retour en arrière de la base sur un hébergeur Linux (VPS).
#   ./roadline-bdd.sh sauvegarde                      → dump compressé (30 gardés)
#   ./roadline-bdd.sh liste                           → sauvegardes disponibles
#   ./roadline-bdd.sh restaurer FICHIER               → toute la base revient à l'heure du fichier (serveur ARRÊTÉ)
#   ./roadline-bdd.sh restaurer-joueur FICHIER CID    → un seul joueur (perso + véhicules) revient à l'heure du fichier
#   ./roadline-bdd.sh programmer                      → cron : sauvegarde toutes les 6 h (5 h, 11 h, 17 h, 23 h)
# Identifiants : fichier .env à côté du script (DB_NAME, DB_USER, DB_PASS, DB_HOST, DB_PORT, BACKUP_DIR). Jamais affichés.
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
[ -f "$HERE/.env" ] && set -a && . "$HERE/.env" && set +a
: "${DB_NAME:?DB_NAME manquant dans .env}" "${DB_USER:?DB_USER manquant}" "${DB_PASS:?DB_PASS manquant}"
DB_HOST="${DB_HOST:-127.0.0.1}"; DB_PORT="${DB_PORT:-3306}"
DIR="${BACKUP_DIR:-$HERE/sauvegardes}"; KEEP="${BACKUP_KEEP:-30}"
export MYSQL_PWD="$DB_PASS"
DUMP="$(command -v mariadb-dump || command -v mysqldump)"
CLIENT="$(command -v mariadb || command -v mysql)"
sql() { "$CLIENT" -h "$DB_HOST" -P "$DB_PORT" -u "$DB_USER" --default-character-set=utf8mb4 -N -B "$@"; }

backup() {
  mkdir -p "$DIR"
  local out="$DIR/${DB_NAME}_$(date +%Y%m%d_%H%M%S)${1:+-$1}.sql.gz"
  "$DUMP" -h "$DB_HOST" -P "$DB_PORT" -u "$DB_USER" --single-transaction --routines --default-character-set=utf8mb4 "$DB_NAME" | gzip > "$out"
  [ "$(stat -c %s "$out")" -gt 500 ] || { echo "ERREUR : sauvegarde vide ($out)"; rm -f "$out"; exit 1; }
  ls -1t "$DIR"/"${DB_NAME}"_*.sql.gz | tail -n +$((KEEP + 1)) | xargs -r rm -f
  echo "OK : $out"
}

# Noms de clés étrangères rendus uniques (« 1 », « 2 »… : acceptés par MariaDB du PC, refusés par celui du VPS)
fix_fk() { awk '
  /^CREATE TABLE `/ { t=$0; sub(/^CREATE TABLE `/, "", t); sub(/`.*/, "", t) }
  /^[ \t]*CONSTRAINT `[^`]*` FOREIGN KEY/ { n=$0; sub(/^[ \t]*CONSTRAINT `/, "", n); sub(/`.*/, "", n)
    sub(/CONSTRAINT `[^`]*`/, "CONSTRAINT `" substr("fk_" t "_" n, 1, 64) "`") }
  { print }'; }
import_into() { # base fichier
  { echo "SET FOREIGN_KEY_CHECKS=0;"; gunzip -c "$2" | fix_fk; echo "SET FOREIGN_KEY_CHECKS=1;"; } | sql "$1"
}

confirm() { read -r -p "$1 Tape OUI : " a; [ "$a" = "OUI" ] || { echo "Annulé."; exit 1; }; }

case "${1:-}" in
  sauvegarde) backup ;;
  liste) ls -1t "$DIR"/*.sql.gz 2>/dev/null | head -30 || echo "Aucune sauvegarde." ;;
  restaurer)
    f="${2:?fichier ?}"; [ -f "$f" ] || { echo "Introuvable : $f"; exit 1; }
    if pgrep -f FXServer >/dev/null || pgrep -f run.sh >/dev/null; then echo "Le serveur FiveM tourne : arrête-le d'abord."; exit 1; fi
    confirm "TOUTE la base '$DB_NAME' va revenir à l'état de $(basename "$f")."
    backup avant-restauration
    import_into "$DB_NAME" "$f"
    echo "Restauration terminée. Pour annuler : restaurer la sauvegarde « avant-restauration »." ;;
  restaurer-joueur)
    f="${2:?fichier ?}"; cid="$(echo "${3:?citizenid ?}" | tr '[:lower:]' '[:upper:]')"
    [[ "$cid" =~ ^[A-Z0-9]{3,16}$ ]] || { echo "citizenid invalide."; exit 1; }
    [ -f "$f" ] || { echo "Introuvable : $f"; exit 1; }
    confirm "Le joueur $cid (perso + véhicules) va revenir à l'état de $(basename "$f") (il doit être DÉCONNECTÉ)."
    backup avant-restauration
    rb="${DB_NAME}_retour"
    sql -e "DROP DATABASE IF EXISTS \`$rb\`; CREATE DATABASE \`$rb\` CHARACTER SET utf8mb4;"
    import_into "$rb" "$f"
    if [ "$(sql -e "SELECT COUNT(*) FROM \`$rb\`.players WHERE citizenid = '$cid';")" = "0" ]; then
      sql -e "DROP DATABASE \`$rb\`;"; echo "Ce joueur n'existait pas dans cette sauvegarde. Rien n'a été modifié."; exit 1
    fi
    sql -e "SET FOREIGN_KEY_CHECKS=0; START TRANSACTION;
      REPLACE INTO \`$DB_NAME\`.players SELECT * FROM \`$rb\`.players WHERE citizenid = '$cid';
      DELETE FROM \`$DB_NAME\`.player_vehicles WHERE citizenid = '$cid';
      INSERT INTO \`$DB_NAME\`.player_vehicles SELECT * FROM \`$rb\`.player_vehicles WHERE citizenid = '$cid';
      COMMIT; SET FOREIGN_KEY_CHECKS=1;"
    sql -e "DROP DATABASE \`$rb\`;"
    echo "Joueur $cid restauré. Il peut se reconnecter." ;;
  programmer)
    line="0 5,11,17,23 * * * $HERE/roadline-bdd.sh sauvegarde >> $DIR/sauvegarde.log 2>&1"
    mkdir -p "$DIR"
    # (VPS neuf : pas encore de crontab, « crontab -l » échoue → ne doit pas arrêter le script)
    { { crontab -l 2>/dev/null || true; } | { grep -v 'roadline-bdd.sh sauvegarde' || true; }; echo "$line"; } | crontab -
    echo "Programmé : toutes les 6 h (5 h, 11 h, 17 h, 23 h)." ;;
  *) sed -n '2,8p' "$0" ;;
esac
