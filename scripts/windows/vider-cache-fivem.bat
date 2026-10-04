@echo off
setlocal
set "SRC="
for %%f in ("%~dp0vider-cache-fivem*.ps1") do if not defined SRC set "SRC=%%~ff"
if not defined SRC for %%f in ("%~dp0vider-cache-fivem*.txt") do if not defined SRC (
  copy /y "%%~ff" "%~dp0vider-cache-fivem.ps1" >nul
  set "SRC=%~dp0vider-cache-fivem.ps1"
)
if not defined SRC (
  echo Fichier vider-cache-fivem.ps1 introuvable.
  pause
  exit /b 1
)
powershell -NoProfile -ExecutionPolicy Bypass -File "%SRC%"

if errorlevel 1 pause
