@echo off
setlocal
set "SRC="
for %%f in ("%~dp0importer-mods*.ps1") do if not defined SRC set "SRC=%%~ff"
if not defined SRC for %%f in ("%~dp0importer-mods*.txt") do if not defined SRC (
  copy /y "%%~ff" "%~dp0importer-mods.ps1" >nul
  set "SRC=%~dp0importer-mods.ps1"
)
if not defined SRC (
  echo Fichier importer-mods.ps1 introuvable.
  pause
  exit /b 1
)
powershell -NoProfile -ExecutionPolicy Bypass -File "%SRC%"

if errorlevel 1 pause
