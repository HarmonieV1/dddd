@echo off
setlocal
set "SRC="
for %%f in ("%~dp0mods-securite*.ps1") do if not defined SRC set "SRC=%%~ff"
if not defined SRC for %%f in ("%~dp0mods-securite*.txt") do if not defined SRC (
  copy /y "%%~ff" "%~dp0mods-securite.ps1" >nul
  set "SRC=%~dp0mods-securite.ps1"
)
if not defined SRC (
  echo Fichier mods-securite.ps1 introuvable.
  pause
  exit /b 1
)
powershell -NoProfile -ExecutionPolicy Bypass -File "%SRC%"
