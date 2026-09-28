@echo off
REM Double-clic : lance brancher-gtasoon.ps1 sans changer la politique d execution du PC.
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0brancher-gtasoon.ps1"
pause
