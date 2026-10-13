@echo off
REM RoadLine : envoyer les commits du PC sur GitHub (les deux branches), apres les tests. Jamais de force.
if not exist "%~dp0scripts\windows\pousser-github.bat" (
  echo.
  echo ERREUR : dossier "scripts" introuvable a cote de ce fichier.
  echo Ce .bat se lance depuis le dossier du depot clone (celui qui contient .git),
  echo pas depuis le zip d'installation.
  echo.
  pause
  exit /b 1
)
call "%~dp0scripts\windows\pousser-github.bat"
