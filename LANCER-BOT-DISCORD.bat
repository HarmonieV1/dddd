@echo off
REM RoadLine : lance le bot Discord (presence + /statut). Installe-le d'abord avec CONFIGURER-DISCORD.bat.
if not exist "C:\GTASOON\discord-bot\config.json" (
  echo Bot non configure : lance d'abord CONFIGURER-DISCORD.bat.
  pause
  exit /b 1
)
title RoadLine bot Discord
node "C:\GTASOON\discord-bot\bot.mjs"
pause
