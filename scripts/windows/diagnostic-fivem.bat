@echo off
REM Double-clic : diagnostic + reparation FiveM. Clic droit > Executer en tant qu administrateur si besoin.
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0diagnostic-fivem.ps1"
pause
