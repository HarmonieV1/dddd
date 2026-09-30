@echo off
REM Double-clic = ajouter un ami a la whitelist + lancer playit.gg pour qu'il se connecte de chez lui.
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\amis.ps1"
pause
