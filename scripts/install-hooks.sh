#!/usr/bin/env bash
# Installe les hooks git du projet (une fois par clone) : les tests tournent avant chaque push.
cd "$(dirname "$0")/.."
git config core.hooksPath scripts/hooks
chmod +x scripts/hooks/*
echo "Hooks installés : ./tests/run.sh sera lancé avant chaque git push."
