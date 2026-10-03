<#
  GTA SOON - ALLÉGER LES VOITURES : réimporte les mods avec l'optimiseur de textures (tools\textures), puis réactive
  ceux qui passent sous la limite (48 Mo de textures par fichier). Les autres restent en pause.
  Ferme le serveur avant. En cas de souci : MODS-SECURITE.bat (choix 1) remet l'état stable.
#>
function Say($m, $c = 'Gray') { Write-Host $m -ForegroundColor $c }
Get-Process -Name FXServer -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
Say '[1/2] Réimport des mods avec optimisation des textures (quelques minutes)' 'Cyan'
$env:GTASOON_TEST = '1'
& (Join-Path $PSScriptRoot 'importer-mods.ps1')
$report = 'C:\GTASOON\mods-tri\RAPPORT-MODS.txt'
if (Test-Path -LiteralPath $report) { Get-Content -LiteralPath $report | Where-Object { $_ -match 'allégées|indisponible|impossible' } | ForEach-Object { Say $_ 'Green' } }
Say '[2/2] Réactivation des voitures devenues assez légères' 'Cyan'
$env:GTASOON_CHOICE = '1'
& (Join-Path $PSScriptRoot 'mods-securite.ps1')
Say "`nTerminé. Lance le serveur (DEMARRER.bat) puis connecte-toi. Voitures : concession, catégorie « Imports RoadLine »." 'Green'
Say 'Crash ? MODS-SECURITE.bat choix 1 = retour à l''état stable, et envoie-moi la capture.' 'Yellow'
Read-Host 'Entrée pour fermer'
