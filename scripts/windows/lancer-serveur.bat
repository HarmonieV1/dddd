@echo off
REM Lance lancer-serveur.ps1 meme si le navigateur l a renomme (ex : "lancer-serveur (1).ps1" ou ".ps1.txt").
setlocal
set "SRC="
for %%f in ("%~dp0lancer-serveur*.ps1") do if not defined SRC set "SRC=%%~ff"
if not defined SRC for %%f in ("%~dp0lancer-serveur*.txt") do if not defined SRC (
  copy /y "%%~ff" "%~dp0lancer-serveur.ps1" >nul
  set "SRC=%~dp0lancer-serveur.ps1"
)
if not defined SRC (
  echo Fichier lancer-serveur.ps1 introuvable a cote de ce .bat.
  echo Mets les 2 fichiers dans le MEME dossier, puis relance.
  pause
  exit /b 1
)
powershell -NoProfile -ExecutionPolicy Bypass -File "%SRC%"
pause
