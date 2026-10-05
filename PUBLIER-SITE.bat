@echo off
REM RoadLine : publier le site vitrine (docs\site) sur Netlify, par glisser-deposer.
if not exist "%~dp0docs\site\index.html" (
  echo ERREUR : dossier docs\site introuvable a cote de ce fichier. Extrais d'abord le zip RoadLine.
  pause
  exit /b 1
)
echo.
echo  1. Une fenetre s'ouvre sur le dossier du site, et Netlify s'ouvre dans le navigateur.
echo  2. Sur Netlify : ton site (roadlinerp) puis l'onglet "Deploys".
echo  3. Glisse le DOSSIER "site" (celui qui contient index.html) dans la zone "Drag and drop your site output folder here".
echo  4. 20 secondes plus tard, le site est a jour (Ctrl+F5 pour recharger sans cache).
echo.
start "" explorer "%~dp0docs"
start "" "https://app.netlify.com/"
pause
