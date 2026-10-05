#!/usr/bin/env bash
# RoadLine RP · installation sur un VPS Linux (OVH : Ubuntu 22.04 / 24.04 ou Debian 12). Lancé par PREPARER-OVH.bat
# depuis le PC (ou à la main : sudo bash installer-ovh.sh /tmp/roadline-ovh.zip).
#   - installe MariaDB, le programme FiveM (FXServer Linux, version recommandée) et txAdmin ;
#   - pose le serveur préparé sur le PC (ressources, réglages, secrets.cfg) dans /home/fivem/server-data ;
#   - crée la base et son mot de passe (aléatoire, jamais affiché), importe la base du PC — si le VPS a déjà des
#     personnages, il DEMANDE avant d'écraser (et sauvegarde d'abord) ;
#   - pare-feu (SSH, 30120 jeu, 40120 txAdmin), service qui redémarre tout seul, sauvegardes toutes les 6 h ;
#   - installe la commande « roadline » (état, logs, redémarrer, public/privé, sauvegarde, mise à jour).
# Ne supprime jamais rien : une ancienne installation est mise de côté dans /home/fivem/anciens/.
set -euo pipefail
[ "$(id -u)" -eq 0 ] || exec sudo bash "$0" "$@"
ZIP="${1:-/tmp/roadline-ovh.zip}"
BASE=/home/fivem; FX=$BASE/fxserver; DATA=$BASE/server-data; TOOLS=$BASE/outils
STAGE=$(mktemp -d)
say() { printf '\n\033[1;36m%s\033[0m\n' "$*"; }
ok() { printf '  \033[32m%s\033[0m\n' "$*"; }
warn() { printf '  \033[33m%s\033[0m\n' "$*"; }
trap 'rm -rf "$STAGE"' EXIT

[ -f "$ZIP" ] || { echo "Archive introuvable : $ZIP (lance PREPARER-OVH.bat sur le PC)"; exit 1; }
. /etc/os-release
case "$ID" in ubuntu|debian) ;; *) echo "Système non prévu ($ID) : Ubuntu 22.04/24.04 ou Debian 12 recommandés."; exit 1 ;; esac

say "[1/8] Paquets (MariaDB, outils)"
export DEBIAN_FRONTEND=noninteractive
apt-get update -qq
apt-get install -y -qq mariadb-server unzip xz-utils curl jq ufw rsync openssl ca-certificates >/dev/null
systemctl enable --now mariadb >/dev/null
ok "MariaDB prêt"

say "[2/8] Utilisateur fivem"
id fivem >/dev/null 2>&1 || useradd -m -s /bin/bash fivem
mkdir -p "$FX" "$DATA" "$TOOLS" "$BASE/anciens" "$BASE/txData"
ok "/home/fivem"

say "[3/8] Programme FiveM (FXServer Linux, version recommandée)"
if [ ! -x "$FX/run.sh" ]; then
  URL=$(curl -fsSL https://changelogs-live.fivem.net/api/changelog/versions/linux/server | jq -r '.recommended_download')
  [ -n "$URL" ] && [ "$URL" != "null" ] || { echo "Impossible de trouver la version recommandée de FiveM."; exit 1; }
  curl -fsSL "$URL" | tar -xJ -C "$FX"
  ok "installé"
else
  ok "déjà présent (mise à jour du programme : roadline programme)"
fi

say "[4/8] Serveur RoadLine (préparé sur le PC)"
unzip -q "$ZIP" -d "$STAGE"
[ -f "$STAGE/server-data/server.cfg" ] || { echo "Archive incomplète (server-data/server.cfg manquant)."; exit 1; }
systemctl stop roadline 2>/dev/null || true
if [ -f "$DATA/server.cfg" ]; then
  OLD="$BASE/anciens/server-data-$(date +%Y%m%d_%H%M%S)"
  mv "$DATA" "$OLD"; mkdir -p "$DATA"
  warn "ancienne installation mise de côté : $OLD"
fi
rsync -a "$STAGE/server-data/" "$DATA/"
for f in roadline-bdd.sh roadline.sh; do [ -f "$STAGE/$f" ] && install -m 755 "$STAGE/$f" "$TOOLS/$f"; done
ok "$(du -sh "$DATA" | cut -f1) en place"

# Noms de clés étrangères rendus uniques (« 1 », « 2 »… : acceptés par MariaDB du PC, refusés par celui du VPS)
fix_fk() { awk '
  /^CREATE TABLE `/ { t=$0; sub(/^CREATE TABLE `/, "", t); sub(/`.*/, "", t) }
  /^[ \t]*CONSTRAINT `[^`]*` FOREIGN KEY/ { n=$0; sub(/^[ \t]*CONSTRAINT `/, "", n); sub(/`.*/, "", n)
    sub(/CONSTRAINT `[^`]*`/, "CONSTRAINT `" substr("fk_" t "_" n, 1, 64) "`") }
  { print }'; }
say "[5/8] Base de données"
ENV="$TOOLS/.env"
if [ ! -f "$ENV" ]; then
  PASS=$(openssl rand -hex 18)
  mysql -e "CREATE DATABASE IF NOT EXISTS gtasoon CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
    CREATE USER IF NOT EXISTS 'gtasoon'@'127.0.0.1' IDENTIFIED BY '$PASS';
    CREATE USER IF NOT EXISTS 'gtasoon'@'localhost' IDENTIFIED BY '$PASS';
    ALTER USER 'gtasoon'@'127.0.0.1' IDENTIFIED BY '$PASS'; ALTER USER 'gtasoon'@'localhost' IDENTIFIED BY '$PASS';
    GRANT ALL PRIVILEGES ON gtasoon.* TO 'gtasoon'@'127.0.0.1'; GRANT ALL PRIVILEGES ON gtasoon.* TO 'gtasoon'@'localhost'; FLUSH PRIVILEGES;"
  umask 077
  printf 'DB_NAME=gtasoon\nDB_USER=gtasoon\nDB_PASS=%s\nDB_HOST=127.0.0.1\nDB_PORT=3306\nBACKUP_DIR=%s/sauvegardes\nBACKUP_KEEP=30\n' "$PASS" "$BASE" > "$ENV"
  umask 022
  ok "base « gtasoon » créée (mot de passe aléatoire, gardé dans $ENV)"
fi
set -a; . "$ENV"; set +a
CHARS=$(mysql -N -B -e "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema='gtasoon' AND table_name='players';")
[ "$CHARS" = "1" ] && CHARS=$(mysql -N -B -e "SELECT COUNT(*) FROM gtasoon.players;") || CHARS=0
if [ -f "$STAGE/base.sql" ]; then
  DO=1
  [ -f "$BASE/.base-ok" ] || CHARS=0 # aucun import réussi jusqu'ici : la base du VPS n'est qu'un essai inachevé
  if [ "$CHARS" -gt 0 ]; then
    warn "La base du VPS contient déjà $CHARS personnage(s)."
    read -r -p "  Tape ECRASER pour la remplacer par celle du PC (sauvegardée avant), ou Entrée pour GARDER celle du VPS : " a
    [ "$a" = "ECRASER" ] || DO=0
    [ "$DO" = 1 ] && "$TOOLS/roadline-bdd.sh" sauvegarde avant-import >/dev/null && ok "sauvegarde faite avant import"
  fi
  if [ "$DO" = 1 ]; then
    # base repartie de zéro (celle du VPS est vide ou déjà sauvegardée) : un import raté peut être relancé proprement
    mysql -e "DROP DATABASE IF EXISTS gtasoon; CREATE DATABASE gtasoon CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;"
    { echo "SET FOREIGN_KEY_CHECKS=0;"; fix_fk < "$STAGE/base.sql"; echo "SET FOREIGN_KEY_CHECKS=1;"; } | mysql --default-character-set=utf8mb4 gtasoon
    touch "$BASE/.base-ok"
    ok "base du PC importée ($(mysql -N -B -e 'SELECT COUNT(*) FROM gtasoon.players;' 2>/dev/null || echo 0) personnage(s))"
  else
    ok "base du VPS gardée"
  fi
else
  warn "pas de base.sql dans l'archive : le serveur démarre avec la base actuelle du VPS"
fi
# Connexion du serveur à la base locale du VPS (le mot de passe du PC ne sert plus)
CONN="mysql:""//${DB_USER}"":${DB_PASS}@${DB_HOST}/${DB_NAME}?charset=utf8mb4" # (assemblé : jamais de mot de passe écrit en dur)
sed -i -E "s|^set mysql_connection_string \"[^\"]*\"|set mysql_connection_string \"${CONN}\"|" "$DATA/cfg/secrets.cfg"
chmod 600 "$DATA/cfg/secrets.cfg"

say "[6/8] Profil (privé pour tester / public pour ouvrir)"
PROFILE=$(cat "$BASE/.profil" 2>/dev/null || echo prive)
"$TOOLS/roadline.sh" profil "$PROFILE" >/dev/null
ok "profil : $PROFILE (changer : roadline public / roadline prive)"

say "[7/8] Pare-feu"
ufw allow OpenSSH >/dev/null; ufw allow 30120 >/dev/null; ufw allow 40120/tcp >/dev/null
ufw --force enable >/dev/null
ok "ouverts : SSH, 30120 (jeu), 40120 (txAdmin)"

say "[8/8] Service, sauvegardes, commande roadline"
# Mode SIMPLE par défaut : le serveur démarre tout seul (OneSync activé), aucun PIN ni configuration web.
# txAdmin reste disponible plus tard : « roadline mode txadmin » (ou GERER-OVH.bat sur le PC).
"$TOOLS/roadline.sh" unite "$(cat "$BASE/.mode" 2>/dev/null || echo simple)"
ln -sf "$TOOLS/roadline.sh" /usr/local/bin/roadline
chown -R fivem:fivem "$BASE"
chmod 600 "$ENV"
crontab -l 2>/dev/null | grep -q roadline-bdd || "$TOOLS/roadline-bdd.sh" programmer >/dev/null
systemctl daemon-reload
systemctl enable --now roadline >/dev/null
ok "service lancé (redémarre tout seul), sauvegardes toutes les 6 h"

IP=$(curl -fsS4 https://api.ipify.org 2>/dev/null || hostname -I | awk '{print $1}')
sleep 15
if systemctl is-active --quiet roadline; then STATE="en ligne"; else STATE="en démarrage (vérifie avec GERER-OVH.bat → État)"; fi
cat <<EOF

==================================================================================
 RoadLine RP est installé sur le VPS : serveur $STATE.
 En jeu : F8 →  connect $IP:30120
 Tout se pilote depuis ton PC avec GERER-OVH.bat (état, logs, redémarrer, public / privé, sauvegardes…).
==================================================================================
EOF
