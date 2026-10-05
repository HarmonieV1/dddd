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
  systemctl daemon-reload
  systemctl enable roadline >/dev/null 2>&1
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

case "${1:-aide}" in
  etat) systemctl --no-pager status roadline | head -5; echo; df -h / | tail -1; free -h | sed -n 2p ;;
  diagnostic) need_root "$@"; diagnostic ;;
  logs) journalctl -u roadline -n "${2:-80}" --no-pager ;;
  pin) pin "${2:-}" ;;
  unite) need_root "$@"; unite "${2:-simple}" ;;
  terminer) need_root "$@"; terminer; echo "Installation terminée : serveur démarré, sauvegardes toutes les 6 h." ;;
  mode) need_root "$@"; unite "${2:-simple}"; systemctl enable roadline >/dev/null 2>&1; systemctl restart roadline
    if [ "$(cat "$BASE/.mode")" = "txadmin" ]; then sleep 20; echo "Mode txAdmin : ouvre http://IP-DU-VPS:40120"; pin; else echo "Mode simple : le serveur démarre tout seul."; fi ;;
  suivre) journalctl -u roadline -f ;;
  redemarrer) need_root "$@"; systemctl restart roadline; echo "Redémarré." ;;
  arreter) need_root "$@"; systemctl stop roadline; echo "Arrêté." ;;
  demarrer) need_root "$@"; systemctl start roadline; echo "Démarré." ;;
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
