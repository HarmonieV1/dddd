@echo off
setlocal
set "SRC="
for %%f in ("%~dp0restaurer-bdd*.ps1") do if not defined SRC set "SRC=%%~ff"
if not defined SRC for %%f in ("%~dp0restaurer-bdd*.txt") do if not defined SRC (
  copy /y "%%~ff" "%~dp0restaurer-bdd.ps1" >nul
  set "SRC=%~dp0restaurer-bdd.ps1"
)
if not defined SRC (
  echo Fichier restaurer-bdd.ps1 introuvable.
  pause
  exit /b 1
)
powershell -NoProfile -ExecutionPolicy Bypass -File "%SRC%"
