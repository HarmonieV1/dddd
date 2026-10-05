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

case "${1:-aide}" in
  etat) systemctl --no-pager status roadline | head -5; echo; df -h / | tail -1; free -h | sed -n 2p ;;
  logs) journalctl -u roadline -n "${2:-80}" --no-pager ;;
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
roadline logs [N]          N dernières lignes de la console (défaut 80) · roadline suivre : en direct
roadline redemarrer        redémarrer (aussi : arreter, demarrer)
roadline public | prive    ouvrir au public / repasser en privé pour tester
roadline sauvegarde        sauvegarder la base maintenant (automatique toutes les 6 h)
roadline sauvegardes       liste des sauvegardes · roadline restaurer FICHIER · roadline restaurer-joueur FICHIER CID
roadline maj               installer la mise à jour envoyée par METTRE-A-JOUR-OVH.bat (base sauvegardée avant)
roadline retour            revenir à la version précédente de RoadLine (si une mise à jour pose problème)
roadline programme         mettre à jour le programme FiveM (version recommandée)
EOF
  ;;
esac
