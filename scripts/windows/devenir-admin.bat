@echo off
setlocal
set "SRC="
for %%f in ("%~dp0devenir-admin*.ps1") do if not defined SRC set "SRC=%%~ff"
if not defined SRC for %%f in ("%~dp0devenir-admin*.txt") do if not defined SRC (
  copy /y "%%~ff" "%~dp0devenir-admin.ps1" >nul
  set "SRC=%~dp0devenir-admin.ps1"
)
if not defined SRC (
  echo Fichier devenir-admin.ps1 introuvable.
  pause
  exit /b 1
)
powershell -NoProfile -ExecutionPolicy Bypass -File "%SRC%"

if errorlevel 1 pause
