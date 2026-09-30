@echo off
REM Double-clic = tout faire (installer, demarrer, s'ajouter admin) et afficher l'adresse.
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\jouer.ps1"
pause
