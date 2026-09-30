@echo off
setlocal
set "SRC="
for %%f in ("%~dp0reparer-tout*.ps1") do if not defined SRC set "SRC=%%~ff"
if not defined SRC for %%f in ("%~dp0reparer-tout*.txt") do if not defined SRC (
  copy /y "%%~ff" "%~dp0reparer-tout.ps1" >nul
  set "SRC=%~dp0reparer-tout.ps1"
)
if not defined SRC (
  echo Fichier reparer-tout.ps1 introuvable.
  pause
  exit /b 1
)
powershell -NoProfile -ExecutionPolicy Bypass -File "%SRC%"
