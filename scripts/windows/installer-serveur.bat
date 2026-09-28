@echo off
REM Installe tout le serveur GTA SOON (Qbox + nos ressources) sans la recipe txAdmin.
setlocal
set "SRC="
for %%f in ("%~dp0installer-serveur*.ps1") do if not defined SRC set "SRC=%%~ff"
if not defined SRC for %%f in ("%~dp0installer-serveur*.txt") do if not defined SRC (
  copy /y "%%~ff" "%~dp0installer-serveur.ps1" >nul
  set "SRC=%~dp0installer-serveur.ps1"
)
if not defined SRC (
  echo Fichier installer-serveur.ps1 introuvable a cote de ce .bat.
  pause
  exit /b 1
)
powershell -NoProfile -ExecutionPolicy Bypass -File "%SRC%"
pause
