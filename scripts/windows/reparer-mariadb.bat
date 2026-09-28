@echo off
REM Double-clic : cree l utilisateur gtasoon compatible txAdmin (et reinitialise root si besoin).
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0reparer-mariadb.ps1"
pause
