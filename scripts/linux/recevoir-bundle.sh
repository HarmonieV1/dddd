#!/usr/bin/env bash
# RoadLine · RECEVOIR UN PAQUET DE COMMITS (git bundle) venu de l'autre poste, puis pousser sur GitHub.
# Usage : bash scripts/linux/recevoir-bundle.sh chemin/vers/ROADLINE-commits.bundle
# Le paquet contient les commits du poste Windows AVEC leur historique (pas une copie des fichiers) :
# plus de commit « Synchronisation » géant, plus de conflits de fins de ligne, plus de doublons.
# Règle : jamais de force. Si les deux côtés ont avancé, on fusionne (git merge), on relance les tests, puis on pousse.
set -e
BUNDLE="$1"
MAIN=feature/phase1-bridge
TWIN=claude/gta-rp-architecture-stack-pbvdxz
if [ -z "$BUNDLE" ] || [ ! -f "$BUNDLE" ]; then echo "Usage : $0 ROADLINE-commits.bundle"; exit 1; fi
cd "$(dirname "$0")/../.."
echo "== Vérification du paquet"
git bundle verify "$BUNDLE"
echo "== Lecture des commits du paquet"
git fetch "$BUNDLE" "$MAIN:refs/bundles/$MAIN"
echo "== Récupération de GitHub"
git fetch origin --prune
git checkout -q "$MAIN"
git merge --ff-only "origin/$MAIN" 2>/dev/null || echo "(la branche locale a déjà des commits : on continue)"
if git merge-base --is-ancestor "refs/bundles/$MAIN" HEAD; then
    echo "== Le paquet est déjà intégré : rien à faire."
elif git merge-base --is-ancestor HEAD "refs/bundles/$MAIN"; then
    echo "== Avance rapide : le paquet contient tout ce qui est ici, plus la suite."
    git merge --ff-only "refs/bundles/$MAIN"
else
    echo "== Les deux côtés ont avancé : fusion (les conflits éventuels sont à résoudre, puis : git add -A && git commit)"
    git merge --no-ff "refs/bundles/$MAIN" -m "Fusion du paquet de commits du poste Windows"
fi
echo "== Tests"
bash tests/run.sh
echo "== Envoi sur GitHub ($MAIN puis $TWIN)"
git push origin "$MAIN:$MAIN"
git push origin "$MAIN:$TWIN"
echo "== Terminé : $(git log -1 --format='%h %s')"
