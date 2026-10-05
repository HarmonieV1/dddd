#!/usr/bin/env bash
# RoadLine RP · commande « roadline » sur le VPS (installée par installer-ovh.sh). « roadline aide » pour la liste.
set -euo pipefail
BASE=/home/fivem; FX=$BASE/fxserver; DATA=$BASE/server-data; TOOLS=$BASE/outils
need_root() { [ "$(id -u)" -eq 0 ] || exec sudo "$0" "$@"; }

profil() { # prive | public
  local cfg="$DATA/server.cfg"
  case "$1" in
    public) sed -i -E 's|^exec cfg/dev\.cfg|# exec cfg/dev.cfg|; s|^#\s*exec cfg/prod\.cfg|exec cfg/prod.cfg|' "$cfg" ;;
    prive)  sed -i -E 's|^exec cfg/prod\.cfg|# exec cfg/prod.cfg|; s|^#\s*exec cfg/dev\.cfg|exec cfg/dev.cfg|' "$cfg" ;;
    *) echo "profil : prive ou public"; exit 1 ;;
  esac
  echo "$1" > "$BASE/.profil"
}

maj() { # archive envoyée par METTRE-A-JOUR-OVH.bat
  local zip="${1:?archive ?}" st; st=$(mktemp -d)
  [ -f "$zip" ] || { echo "Introuvable : $zip"; exit 1; }
  unzip -q "$zip" -d "$st"
  [ -d "$st/gtasoon" ] || { echo "Archive de mise à jour invalide."; rm -rf "$st"; exit 1; }
  echo "Sauvegarde de la base…"; "$TOOLS/roadline-bdd.sh" sauvegarde
  systemctl stop roadline
  local old="$BASE/anciens/gtasoon-$(date +%Y%m%d_%H%M%S)"
  [ -d "$DATA/resources/[gtasoon]" ] && mv "$DATA/resources/[gtasoon]" "$old"
  rsync -a "$st/gtasoon/" "$DATA/resources/[gtasoon]/"
  [ -d "$st/extra" ] && rsync -a "$st/extra/" "$DATA/"
  for f in "$st"/cfg/*.cfg; do
    [ -e "$f" ] || continue
    case "$(basename "$f")" in secrets.cfg|permissions.cfg) ;; *) install -m 644 "$f" "$DATA/cfg/" ;; esac
  done
  [ -f "$st/server.cfg" ] && install -m 644 "$st/server.cfg" "$DATA/server.cfg" && profil "$(cat "$BASE/.profil" 2>/dev/null || echo prive)"
  ls -1dt "$BASE"/anciens/gtasoon-* 2>/dev/null | tail -n +4 | xargs -r rm -rf # garde les 3 dernières versions
  chown -R fivem:fivem "$DATA"
  rm -rf "$st" "$zip"
  systemctl start roadline
  echo "Mise à jour installée : $(grep -oE 'gs_version "[^"]+"' "$DATA/server.cfg" | cut -d'"' -f2). Ancienne version : $old"
}

retour() { # remet la version précédente de [gtasoon]
  local last; last=$(ls -1dt "$BASE"/anciens/gtasoon-* 2>/dev/null | head -1)
  [ -n "$last" ] || { echo "Aucune version précédente."; exit 1; }
  systemctl stop roadline
  mv "$DATA/resources/[gtasoon]" "$BASE/anciens/gtasoon-annulee-$(date +%Y%m%d_%H%M%S)"
  mv "$last" "$DATA/resources/[gtasoon]"
  systemctl start roadline
  echo "Version précédente remise ($last)."
}

pin() { # code PIN de txAdmin (première configuration)
  local p
  p=$(journalctl -u roadline --no-pager -n 400 2>/dev/null | grep -A4 -i 'pin' | grep -oE '\b[0-9]{4}\b' | tail -1)
  if [ "${1:-}" = "--brut" ]; then [ -n "$p" ] && echo "$p"; return 0; fi
  if [ -n "$p" ]; then echo "Code PIN txAdmin : $p   (à taper sur http://IP-DU-VPS:40120)"
  else echo "Pas de PIN dans les journaux : txAdmin est peut-être déjà configuré (connecte-toi avec ton compte), ou attends 30 s et réessaie."; fi
}

# Service systemd : « simple » = le serveur démarre directement (OneSync activé, rien à configurer) ;
# « txadmin » = panneau web txAdmin sur le port 40120 (PIN et configuration au premier lancement).
unite() {
  local mode="${1:-simple}" exec wd desc
  if [ "$mode" = "txadmin" ]; then
    exec="$FX/run.sh +set txAdminPort 40120 +set txDataPath $BASE/txData"; wd="$BASE"; desc="RoadLine RP (FiveM + txAdmin)"
  else
    mode="simple"; exec="$FX/run.sh +set onesync on +exec server.cfg"; wd="$DATA"; desc="RoadLine RP (FiveM)"
  fi
  # FXServer lit sa console : sans clavier (service), il lit « fin » et croit à un Ctrl-C → il s'arrête.
  # On lui donne une entrée qui ne se termine jamais.
  exec="/bin/sh -c 'tail -f /dev/null | exec $exec'"
  cat > /etc/systemd/system/roadline.service <<UNIT
[Unit]
Description=$desc
After=network-online.target mariadb.service
Wants=network-online.target

[Service]
User=fivem
WorkingDirectory=$wd
ExecStart=$exec
Restart=on-failure
RestartSec=10
LimitNOFILE=65535

[Install]
WantedBy=multi-user.target
UNIT
  echo "$mode" > "$BASE/.mode"
  systemctl daemon-reload
}

terminer() { # fin d'installation : service, commande roadline, sauvegardes auto, démarrage (relançable sans risque)
  local before; before=$(md5sum /etc/systemd/system/roadline.service 2>/dev/null || true)
  unite "$(cat "$BASE/.mode" 2>/dev/null || echo simple)" # service toujours à jour
  [ "$before" = "$(md5sum /etc/systemd/system/roadline.service)" ] || systemctl stop roadline 2>/dev/null || true
  # copie (et non lien) : /home/fivem est fermé aux autres comptes ; remplacement atomique (ce script peut être en cours)
  install -m 755 "$TOOLS/roadline.sh" /usr/local/bin/roadline.new && mv -f /usr/local/bin/roadline.new /usr/local/bin/roadline
  chown -R fivem:fivem "$BASE"
  [ -f "$TOOLS/.env" ] && chmod 600 "$TOOLS/.env"
  { crontab -l 2>/dev/null || true; } | grep -q roadline-bdd || "$TOOLS/roadline-bdd.sh" programmer >/dev/null
  # V11 : heure de Paris (sauvegardes, redémarrage quotidien, journaux), veille toutes les 2 min, redémarrage 06:00
  [ "$(timedatectl show -p Timezone --value 2>/dev/null)" = "Europe/Paris" ] || { timedatectl set-timezone Europe/Paris 2>/dev/null && systemctl restart cron 2>/dev/null || true; }
  { crontab -l 2>/dev/null || true; } | grep -q 'roadline veille' || { { crontab -l 2>/dev/null || true; }; echo "*/2 * * * * /usr/local/bin/roadline veille"; } | crontab -
  { crontab -l 2>/dev/null || true; } | grep -q 'roadline redemarrer-auto' || grep -q '^setr gs_restart "off"' "$DATA/cfg/secrets.cfg" 2>/dev/null || redemarrage_auto 06:00 >/dev/null
  systemctl daemon-reload
  systemctl enable roadline >/dev/null 2>&1
  rm -f "$BASE/.maintenance"
  systemctl is-active --quiet roadline || systemctl start roadline
}

diagnostic() { # pourquoi le serveur ne répond pas, en clair
  # seulement depuis le dernier démarrage (sinon d'anciens plantages déjà réglés seraient encore signalés)
  local since log; since=$(systemctl show -p ExecMainStartTimestamp --value roadline 2>/dev/null || true)
  if [ -n "$since" ] && [ "$since" != "n/a" ]; then log=$(journalctl -u roadline --since "$since" --no-pager 2>/dev/null || true)
  else log=$(journalctl -u roadline -n 400 --no-pager 2>/dev/null || true); fi
  echo "== Service =="
  if systemctl is-active --quiet roadline; then echo "  en marche (mode $(cat "$BASE/.mode" 2>/dev/null || echo ?), plantages depuis le dernier démarrage du VPS : $(systemctl show -p NRestarts --value roadline))"
  else echo "  ARRÊTÉ ($(systemctl show -p Result --value roadline))"; fi
  echo "== Port du jeu 30120 =="
  if ss -lntu 2>/dev/null | grep -q ':30120 '; then echo "  ouvert : le serveur écoute"; else echo "  FERMÉ : le serveur n'écoute pas (arrêté, en plantage, ou encore en démarrage)"; fi
  echo "== Causes repérées dans la console =="
  local n=0
  hint() { if grep -qiE "$1" <<<"$log"; then echo "  - $2"; n=$((n+1)); fi; }
  hint 'Ctrl-C pressed' "Le serveur s'arrête tout seul (« Ctrl-C ») : relance GERER-OVH.bat, il corrige le service automatiquement."
  hint 'license key authentication failed|No license key|invalid license|license key.*(invalid|rejected)' "Clé de licence FiveM refusée : mets une clé valide (keymaster.fivem.net) dans cfg/secrets.cfg (sv_licenseKey), puis Redémarrer."
  hint 'Address already in use|bind.*30120' "Le port 30120 est déjà pris par un autre programme : Redémarrer (ou redémarrer le VPS)."
  hint 'Permission denied' "Problème de droits sur les fichiers : lance « sudo roadline terminer »."
  hint 'No such file or directory.*(run\.sh|FXServer|ld-musl)' "Programme FiveM absent ou abîmé : lance « sudo roadline programme »."
  hint "Couldn't find resource|Could not find resource|Failed to start resource" "Des ressources ne démarrent pas (Linux respecte les majuscules dans les noms de dossiers) : voir Console."
  hint 'ER_ACCESS_DENIED|ECONNREFUSED.*3306|Unknown database|oxmysql.*(error|failed)' "La connexion à la base échoue : relance PREPARER-OVH (la base sera reconfigurée)."
  hint 'onesync|OneSync is not enabled' "OneSync manquant : choisis Mode SIMPLE dans GERER-OVH."
  hint 'Segmentation fault|core dumped|crashed|SIGSEGV' "Le programme FiveM a planté : « sudo roadline programme » (mise à jour), puis Redémarrer."
  [ "$n" -eq 0 ] && echo "  aucune cause connue repérée : voir les dernières lignes ci-dessous"
  echo "== Dernières lignes =="
  journalctl -u roadline -n 25 --no-pager -o cat 2>/dev/null | tail -25
}

erreurs() { # erreurs de scripts depuis le dernier démarrage, regroupées par ressource
  local since log; since=$(systemctl show -p ExecMainStartTimestamp --value roadline 2>/dev/null || true)
  [ -n "$since" ] && [ "$since" != "n/a" ] || since="-1h"
  log=$(journalctl -u roadline --since "$since" --no-pager -o cat 2>/dev/null || true)
  local errs; errs=$(grep -E 'SCRIPT ERROR|\^1Error|\[ERROR\]|Failed to (load|start)|Couldn.t (load|start)|stack traceback' <<<"$log" || true)
  if [ -z "$errs" ]; then echo "Aucune erreur de script depuis le démarrage ($since)."; return 0; fi
  echo "Erreurs depuis le démarrage : $(wc -l <<<"$errs") ligne(s). Par ressource :"
  grep -oE '@[a-zA-Z0-9_-]+/|script:[a-zA-Z0-9_-]+|resource [a-zA-Z0-9_-]+' <<<"$errs" | sed -E 's/^@//; s#/$##; s/^script://; s/^resource //' | sort | uniq -c | sort -rn | head -15
  echo; echo "Dernières (sans doublons) :"; awk '!vu[$0]++' <<<"$errs" | tail -15
}

secrets() { # réglages du PC (Discord, codes staff, licence…) sans toucher à la connexion de la base du VPS
  local f="${1:?fichier}" keep
  [ -f "$f" ] || { echo "Introuvable : $f"; exit 1; }
  keep=$(grep -E '^setr? (mysql_connection_string|gs_admin_txadmin|gs_restart|gs_admin_web) ' "$DATA/cfg/secrets.cfg" || true)
  cp "$DATA/cfg/secrets.cfg" "$BASE/anciens/secrets-$(date +%Y%m%d_%H%M%S).cfg" 2>/dev/null || true
  tr -d '\r' < "$f" | grep -vE '^setr? (mysql_connection_string|gs_admin_txadmin|gs_restart|gs_admin_web) ' > "$DATA/cfg/secrets.cfg"
  [ -n "$keep" ] && echo "$keep" >> "$DATA/cfg/secrets.cfg"
  chown fivem:fivem "$DATA/cfg/secrets.cfg"; chmod 600 "$DATA/cfg/secrets.cfg"; rm -f "$f"
  systemctl restart roadline
  echo "Réglages du PC appliqués (connexion à la base du VPS gardée), serveur redémarré."
}

discord() { # bot + webhooks : réglés ? connectés ? (aucune valeur secrète affichée)
  local sec="$DATA/cfg/secrets.cfg" v name code
  val() { grep -E "^set $1 " "$sec" 2>/dev/null | head -1 | sed -E 's/^set [^ ]+ "?([^"]*)"?.*/\1/'; }
  echo "== Bot Discord =="
  if [ -n "$(val gs_discord_bot_token)" ]; then
    if journalctl -u roadline --since "$(systemctl show -p ExecMainStartTimestamp --value roadline)" --no-pager -o cat 2>/dev/null | grep -q 'Bot Discord connecté'; then echo "  connecté"
    elif journalctl -u roadline -n 2000 --no-pager -o cat 2>/dev/null | grep -q 'Jeton du bot refusé'; then echo "  jeton REFUSÉ par Discord : relance CONFIGURER-DISCORD.bat sur le PC, puis GERER-OVH → 12"
    else echo "  jeton présent, mais pas encore connecté (attends 1 min après le démarrage, ou voir Console)"; fi
  else echo "  pas de jeton (CONFIGURER-DISCORD.bat sur le PC, puis GERER-OVH → 12)"; fi
  echo "== Salons (webhooks) : un message de test est envoyé dans chacun =="
  for name in gs_webhook_status gs_webhook_annonces gs_staff_webhook gs_webhook_sanctions gs_webhook_anticheat gs_webhook_jobs gs_webhook_social gs_webhook_boutique; do
    v=$(val "$name")
    if [ -z "$v" ]; then printf '  %-22s non réglé\n' "$name"; continue; fi
    code=$(curl -s -o /dev/null -w '%{http_code}' -H 'Content-Type: application/json' \
      -d '{"username":"RoadLine","content":"✅ Test du VPS : ce salon est bien relié au serveur."}' "$v" || echo 000)
    case "$code" in 2*) printf '  %-22s OK\n' "$name" ;; 401|403|404) printf '  %-22s REFUSÉ (webhook supprimé ou mal copié)\n' "$name" ;; *) printf '  %-22s erreur %s\n' "$name" "$code" ;; esac
  done
  if [ -z "$(val gs_connect)" ]; then
    local ip; ip=$(curl -fsS4 --max-time 5 https://api.ipify.org 2>/dev/null || hostname -I | awk '{print $1}')
    sed -i '/^set gs_connect /d' "$sec"; echo "set gs_connect \"$ip:30120\"" >> "$sec"
    echo "== Adresse de connexion (/rejoindre) réglée sur $ip:30120 (pris en compte au prochain redémarrage) =="
  fi
}

hook() { # message Discord (salon staff, sinon statut) : $1 = texte
  local sec="$DATA/cfg/secrets.cfg" url
  url=$(grep -E '^set (gs_staff_webhook|gs_webhook_status) ' "$sec" 2>/dev/null | sed -E 's/^set [^ ]+ "?([^"]*)"?.*/\1/' | grep -m1 '^https://')
  [ -n "$url" ] || return 0
  curl -s -o /dev/null -m 10 -H 'Content-Type: application/json' -d "{\"username\":\"RoadLine · VPS\",\"content\":\"$1\"}" "$url" || true
}

veille() { # cron toutes les 2 min : serveur tombé → alerte Discord + relance ; revenu → message
  local st=/run/roadline-veille n=0
  [ -f "$BASE/.maintenance" ] && return 0 # arrêté volontairement (GERER-OVH → Arrêter)
  # Mode txAdmin : c'est txAdmin qui lance / relance le jeu (et le port 30120 reste fermé tant que l'assistant n'est pas fini) :
  # on surveille seulement que txAdmin lui-même tourne (port 40120), sinon on relancerait le service en pleine configuration.
  local port=30120; [ "$(cat "$BASE/.mode" 2>/dev/null)" = "txadmin" ] && port=40120
  if systemctl is-active --quiet roadline && ss -lntu 2>/dev/null | grep -q ":$port "; then
    if [ -f "$st" ] && [ "$(cat "$st")" -ge 2 ]; then hook "🟢 Serveur de nouveau en ligne ($(date '+%H:%M'))."; fi
    rm -f "$st"; return 0
  fi
  # 1er contrôle raté : peut-être un démarrage en cours, on attend le suivant (2 min) avant d'agir
  n=$(( $(cat "$st" 2>/dev/null || echo 0) + 1 )); echo "$n" > "$st"
  if [ "$n" -eq 2 ]; then
    hook "🔴 Serveur injoignable depuis 4 min ($(date '+%H:%M')) : redémarrage automatique en cours."
    systemctl restart roadline
  elif [ "$n" -eq 6 ]; then
    hook "⚠️ Le serveur ne repart pas tout seul : GERER-OVH → 1 (diagnostic)."
  fi
}

redemarrage_auto() { # HH:MM | off : redémarrage quotidien (annoncé en jeu 15, 5 et 1 min avant par gs_admin)
  local when="${1:?HH:MM ou off}" sec="$DATA/cfg/secrets.cfg"
  local cur; cur=$( { crontab -l 2>/dev/null || true; } | grep -v 'roadline redemarrer-auto' || true)
  sed -i '/^setr gs_restart /d' "$sec"
  if [ "$when" = "off" ]; then echo "$cur" | crontab -; echo 'setr gs_restart "off"' >> "$sec"; echo "Redémarrage quotidien désactivé."; return 0; fi
  [[ "$when" =~ ^([01][0-9]|2[0-3]):[0-5][0-9]$ ]] || { echo "Heure invalide (ex : 06:00)."; exit 1; }
  { echo "$cur"; echo "$((10#${when#*:})) $((10#${when%:*})) * * * /usr/local/bin/roadline redemarrer-auto"; } | grep -v '^$' | crontab -
  echo "setr gs_restart \"$when\"" >> "$sec"
  echo "Redémarrage quotidien à $when (heure de Paris), annoncé en jeu 15, 5 et 1 min avant (actif après le prochain redémarrage)."
}

publicip() { curl -fsS4 --max-time 5 https://api.ipify.org 2>/dev/null || hostname -I | awk '{print $1}'; }

https_on() { # adresse https gratuite (certificat automatique) : panneau staff en appli + carte en direct du site
  local ip host; ip=$(publicip); host="${ip//./-}.sslip.io" # sslip.io : nom qui pointe tout seul vers l'IP du VPS
  if ! command -v caddy >/dev/null; then echo "Installation de Caddy (serveur https)…"; apt-get update -qq; apt-get install -y -qq caddy >/dev/null; fi
  cat > /etc/caddy/Caddyfile <<EOF
# RoadLine (roadline https) : seules ces deux adresses du serveur FiveM sont publiées en https
$host {
	redir /gs_admin /gs_admin/
	handle /gs_admin/* {
		reverse_proxy 127.0.0.1:30120
	}
	handle /gs_city/* {
		reverse_proxy 127.0.0.1:30120
	}
	handle {
		respond "RoadLine RP" 200
	}
}
EOF
  ufw allow 80/tcp >/dev/null; ufw allow 443/tcp >/dev/null
  systemctl enable caddy >/dev/null 2>&1; systemctl restart caddy
  echo "$host" > "$BASE/.https"
  sleep 8
  if curl -fsS --max-time 20 "https://$host/" >/dev/null 2>&1; then echo "Adresse https prête (certificat obtenu)."
  else echo "Certificat en cours d'obtention (1 à 2 min) : réessaie l'adresse un peu plus tard."; fi
  cat <<EOF
 Panneau staff (appli) : https://$host/gs_admin/
 Carte en direct du site : https://$host/gs_city/ville.json   (à mettre dans CONFIG.cityUrl du site)
EOF
}

staffweb() { # codes du panneau staff : liste | ajouter PSEUDO | retirer PSEUDO (redémarre le serveur pour appliquer)
  local sec="$DATA/cfg/secrets.cfg" cur action="${1:-liste}" who="${2:-}" code
  cur=$(grep -E '^set gs_admin_web ' "$sec" 2>/dev/null | sed -E 's/^set gs_admin_web "?([^"]*)"?.*/\1/' || true)
  case "$action" in
    liste)
      if [ -z "$cur" ]; then echo "Aucun code : le panneau est fermé."; else echo "Membres du staff avec un code :"; tr ',' '\n' <<<"$cur" | cut -d: -f1 | sed 's/^/  - /'; fi
      return 0 ;;
    ajouter)
      [[ "$who" =~ ^[A-Za-z0-9_-]{2,20}$ ]] || { echo "Pseudo : 2 à 20 lettres, chiffres, - ou _ (sans espace)."; exit 1; }
      cur=$(tr ',' '\n' <<<"$cur" | grep -v "^$who:" | grep -v '^$' | paste -sd, - || true)
      code=$(openssl rand -hex 8)
      cur="${cur:+$cur,}$who:$code" ;;
    retirer)
      cur=$(tr ',' '\n' <<<"$cur" | grep -v "^$who:" | grep -v '^$' | paste -sd, - || true) ;;
    *) echo "staffweb liste | ajouter PSEUDO | retirer PSEUDO"; exit 1 ;;
  esac
  sed -i '/^set gs_admin_web /d' "$sec"; echo "set gs_admin_web \"$cur\"" >> "$sec"
  chown fivem:fivem "$sec"; chmod 600 "$sec"
  systemctl restart roadline
  if [ "$action" = "ajouter" ]; then
    local url; url=$( [ -f "$BASE/.https" ] && echo "https://$(cat "$BASE/.https")/gs_admin/" || echo "http://$(publicip):30120/gs_admin/")
    echo "Code de $who (à lui donner en privé, il ne sera plus affiché) : $code"
    echo "Adresse : $url   (serveur redémarré, prêt dans 1 min)"
  else echo "Code de $who retiré (serveur redémarré)."; fi
}

case "${1:-aide}" in
  etat) [ -f "$BASE/.https" ] && echo "Panneau staff : https://$(cat "$BASE/.https")/gs_admin/"
    echo "Version RoadLine : $(grep -oE 'gs_version "[^"]+"' "$DATA/server.cfg" 2>/dev/null | cut -d'"' -f2) · profil $(cat "$BASE/.profil" 2>/dev/null || echo ?)"
    systemctl --no-pager status roadline | head -5; echo; df -h / | tail -1; free -h | sed -n 2p ;;
  diagnostic) need_root "$@"; diagnostic ;;
  erreurs) need_root "$@"; erreurs ;;
  discord) need_root "$@"; discord ;;
  https) need_root "$@"; https_on ;;
  staffweb) need_root "$@"; staffweb "${2:-liste}" "${3:-}" ;;
  secrets) need_root "$@"; secrets "${2:-/tmp/secrets-pc.cfg}" ;;
  copie-sauvegarde) need_root "$@" # dernière sauvegarde → /tmp, lisible par le compte SSH (pour la garder aussi sur le PC)
    f=$(ls -1t "$BASE"/sauvegardes/*.sql.gz 2>/dev/null | head -1); [ -n "$f" ] || { echo "Aucune sauvegarde."; exit 1; }
    install -m 600 -o "${SUDO_USER:-root}" "$f" /tmp/roadline-sauvegarde.sql.gz; echo "$(basename "$f")" ;;
  logs) journalctl -u roadline -n "${2:-80}" --no-pager ;;
  pin) pin "${2:-}" ;;
  unite) need_root "$@"; unite "${2:-simple}" ;;
  terminer) need_root "$@"; terminer; echo "Installation terminée : serveur démarré, sauvegardes toutes les 6 h." ;;
  mode) need_root "$@"; unite "${2:-simple}"; systemctl enable roadline >/dev/null 2>&1
    sec="$DATA/cfg/secrets.cfg"; sed -i '/^set gs_admin_txadmin /d' "$sec" 2>/dev/null || true
    if [ "$(cat "$BASE/.mode")" = "txadmin" ]; then
      ip=$(curl -fsS4 --max-time 5 https://api.ipify.org 2>/dev/null || hostname -I | awk '{print $1}')
      echo "set gs_admin_txadmin \"http://$ip:40120\"" >> "$sec" # bouton « Ouvrir txAdmin » du panneau staff web
      systemctl restart roadline; sleep 20
      cat <<EOF
Mode txAdmin : le panneau web prend la main sur le serveur.
 1. Ouvre http://$ip:40120 et entre le code PIN ci-dessous, puis connecte-toi avec ton compte Cfx.re.
 2. Choisis « Existing server data » : dossier /home/fivem/server-data , fichier server.cfg
 3. Settings → FXServer → OneSync : On, puis Save et Start.
 (Pour revenir au démarrage automatique : GERER-OVH → Mode simple.)
EOF
      pin
    else systemctl restart roadline; echo "Mode simple : le serveur démarre tout seul."; fi ;;
  suivre) journalctl -u roadline -f ;;
  redemarrer) need_root "$@"; rm -f "$BASE/.maintenance"; systemctl restart roadline; echo "Redémarré." ;;
  redemarrer-auto) need_root "$@"; rm -f "$BASE/.maintenance"; systemctl restart roadline; logger -t roadline "redémarrage quotidien" ;;
  veille) need_root "$@"; veille ;;
  redemarrage-auto) need_root "$@"; redemarrage_auto "${2:-}" ;;
  arreter) need_root "$@"; touch "$BASE/.maintenance"; systemctl stop roadline; echo "Arrêté (la veille ne le relance pas ; Démarrer pour reprendre)." ;;
  demarrer) need_root "$@"; rm -f "$BASE/.maintenance"; systemctl start roadline; echo "Démarré." ;;
  public) need_root "$@"; profil public; systemctl restart roadline; echo "Serveur PUBLIC (liste FiveM, 48 places, protections prod)." ;;
  prive) need_root "$@"; profil prive; systemctl restart roadline; echo "Serveur PRIVÉ (caché, pour tester)." ;;
  profil) need_root "$@"; profil "${2:?prive ou public}" ;;
  sauvegarde) need_root "$@"; "$TOOLS/roadline-bdd.sh" sauvegarde ;;
  sauvegardes) need_root "$@"; "$TOOLS/roadline-bdd.sh" liste ;;
  restaurer) need_root "$@"; "$TOOLS/roadline-bdd.sh" restaurer "${2:?fichier}" ;;
  restaurer-joueur) need_root "$@"; "$TOOLS/roadline-bdd.sh" restaurer-joueur "${2:?fichier}" "${3:?citizenid}" ;;
  maj) need_root "$@"; maj "${2:-/tmp/roadline-maj.zip}" ;;
  retour) need_root "$@"; retour ;;
  programme) need_root "$@"
    URL=$(curl -fsSL https://changelogs-live.fivem.net/api/changelog/versions/linux/server | jq -r '.recommended_download')
    systemctl stop roadline; mv "$FX" "$BASE/anciens/fxserver-$(date +%Y%m%d_%H%M%S)"; mkdir -p "$FX"
    curl -fsSL "$URL" | tar -xJ -C "$FX"; chown -R fivem:fivem "$FX"; systemctl start roadline; echo "Programme FiveM mis à jour." ;;
  *) cat <<'EOF'
roadline etat              état du serveur, disque, mémoire
roadline diagnostic        pourquoi le serveur ne répond pas (causes en clair + dernières lignes)
roadline erreurs           erreurs de scripts depuis le démarrage, par ressource (backtest)
roadline discord           bot connecté ? message de test dans chaque salon Discord relié
roadline https             adresse https gratuite (panneau staff en appli, carte en direct du site)
roadline staffweb liste|ajouter PSEUDO|retirer PSEUDO   codes du panneau staff
roadline redemarrage-auto HH:MM|off  redémarrage quotidien annoncé en jeu (défaut 06:00, heure de Paris)
roadline secrets FICHIER   appliquer le secrets.cfg du PC (garde la base du VPS)
roadline mode simple|txadmin  démarrage direct (par défaut, rien à configurer) ou avec le panneau web txAdmin
roadline pin               code PIN de txAdmin (première configuration)
roadline logs [N]          N dernières lignes de la console (défaut 80) · roadline suivre : en direct
roadline redemarrer        redémarrer (aussi : arreter, demarrer)
roadline public | prive    ouvrir au public / repasser en privé pour tester
roadline sauvegarde        sauvegarder la base maintenant (automatique toutes les 6 h)
roadline sauvegardes       liste des sauvegardes · roadline restaurer FICHIER · roadline restaurer-joueur FICHIER CID
roadline maj               installer la mise à jour envoyée par METTRE-A-JOUR-OVH.bat (base sauvegardée avant)
roadline retour            revenir à la version précédente de RoadLine (si une mise à jour pose problème)
roadline programme         mettre à jour le programme FiveM (version recommandée)
roadline terminer          finir une installation interrompue (service, sauvegardes auto, démarrage)
EOF
  ;;
esac
