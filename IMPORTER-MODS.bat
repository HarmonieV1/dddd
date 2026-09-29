@echo off
REM GTA SOON : trie et installe les mods (vehicules, vetements, maps) poses dans C:\GTASOON\mods-a-trier
if not exist "%~dp0scripts\windows\importer-mods.bat" (
  echo.
  echo ERREUR : dossier "scripts" introuvable a cote de ce fichier.
  echo Tu lances surement ce .bat depuis l'interieur du zip, sans l'avoir extrait.
  echo 1. Clic droit sur le zip ROADTRIP, puis "Extraire tout..."
  echo 2. Ouvre le dossier extrait, puis le dossier "gtasoon"
  echo 3. Relance ce .bat depuis ce dossier.
  echo.
  pause
  exit /b 1
)
call "%~dp0scripts\windows\importer-mods.bat"
