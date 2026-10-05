@echo off
REM GTA SOON : envoie la mise a jour sur le VPS OVH (la base du VPS n est jamais touchee, sauvegardee avant).
if not exist "%~dp0scripts\windows\mettre-a-jour-ovh.bat" (
  echo.
  echo ERREUR : dossier "scripts" introuvable a cote de ce fichier.
  echo Tu lances surement ce .bat depuis l'interieur du zip, sans l'avoir extrait.
  echo 1. Clic droit sur le zip RoadLine, puis "Extraire tout..."
  echo 2. Ouvre le dossier extrait, puis le dossier "gtasoon"
  echo 3. Relance ce .bat depuis ce dossier.
  echo.
  pause
  exit /b 1
)
call "%~dp0scripts\windows\mettre-a-jour-ovh.bat"
