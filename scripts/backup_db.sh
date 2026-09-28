#!/usr/bin/env bash
# Dump MariaDB compressé + rotation. À lancer via cron avant chaque déploiement.
set -euo pipefail
[ -f .env ] && set -a && . ./.env && set +a
: "${DB_NAME:?}" "${DB_USER:?}" "${DB_PASS:?}"
DIR="${BACKUP_DIR:-./backups}"; KEEP="${BACKUP_KEEP_DAYS:-14}"
mkdir -p "$DIR"
OUT="$DIR/${DB_NAME}_$(date +%Y%m%d_%H%M%S).sql.gz"
MYSQL_PWD="$DB_PASS" mysqldump -h "${DB_HOST:-127.0.0.1}" -u "$DB_USER" --single-transaction --routines "$DB_NAME" | gzip > "$OUT"
find "$DIR" -name "${DB_NAME}_*.sql.gz" -mtime +"$KEEP" -delete
echo "OK: $OUT"
# Restore : gunzip -c FICHIER.sql.gz | mysql -u USER -p DB_NAME
