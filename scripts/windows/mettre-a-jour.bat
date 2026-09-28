@echo off
setlocal
set "SRC="
for %%f in ("%~dp0mettre-a-jour*.ps1") do if not defined SRC set "SRC=%%~ff"
if not defined SRC for %%f in ("%~dp0mettre-a-jour*.txt") do if not defined SRC (
  copy /y "%%~ff" "%~dp0mettre-a-jour.ps1" >nul
  set "SRC=%~dp0mettre-a-jour.ps1"
)
if not defined SRC (
  echo Fichier mettre-a-jour.ps1 introuvable.
  pause
  exit /b 1
)
powershell -NoProfile -ExecutionPolicy Bypass -File "%SRC%"
