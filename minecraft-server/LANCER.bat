@echo off
REM Minecraft : double-clic pour demarrer le serveur (fenetre = console, "stop" pour arreter).
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\start.ps1"
pause
