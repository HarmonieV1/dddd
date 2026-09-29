@echo off
setlocal
set "SRC="
for %%f in ("%~dp0sauvegarder-bdd*.ps1") do if not defined SRC set "SRC=%%~ff"
if not defined SRC for %%f in ("%~dp0sauvegarder-bdd*.txt") do if not defined SRC (
  copy /y "%%~ff" "%~dp0sauvegarder-bdd.ps1" >nul
  set "SRC=%~dp0sauvegarder-bdd.ps1"
)
if not defined SRC (
  echo Fichier sauvegarder-bdd.ps1 introuvable.
  pause
  exit /b 1
)
powershell -NoProfile -ExecutionPolicy Bypass -File "%SRC%"
