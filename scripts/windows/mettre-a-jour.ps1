<#
  GTA SOON - METTRE À JOUR le serveur installé (sans tout réinstaller, sans toucher à la base ni aux secrets).
  1. Extrais le nouveau zip GTA SOON  2. Double-clic sur METTRE-A-JOUR.bat (à la racine du dossier extrait)
  Sauvegarde l'ancienne version (C:\GTASOON\sauvegardes), remplace [gtasoon] + cfg + server.cfg,
  ajoute les items manquants, réécrit DEMARRER.bat, relance le serveur.
  Retour arrière : dézipper la dernière sauvegarde dans C:\GTASOON\server-data (voir fin du script).
#>
$ErrorActionPreference = 'Stop'
function Say($m, $c = 'Gray') { Write-Host $m -ForegroundColor $c }
function Fail($m) { Say "ERREUR : $m" 'Red'; Read-Host 'Entrée pour quitter'; exit 1 }
Add-Type -AssemblyName System.IO.Compression.FileSystem
$common = Join-Path $PSScriptRoot 'outils-communs.ps1'
if (-not (Test-Path -LiteralPath $common)) { Fail "outils-communs.ps1 manquant à côté de ce script : réextrais le zip GTA SOON complet." }
. $common

$Repo = Resolve-Path (Join-Path $PSScriptRoot '..\..') -ErrorAction SilentlyContinue
$Data = 'C:\GTASOON\server-data'
if (-not $Repo -or -not (Test-Path -LiteralPath (Join-Path $Repo 'server\resources\[gtasoon]'))) { Fail "Lance ce script depuis le dossier GTA SOON extrait (METTRE-A-JOUR.bat à la racine)." }
if (-not (Test-Path -LiteralPath (Join-Path $Data 'cfg\secrets.cfg'))) { Fail "Pas de serveur installé dans $Data : lance d'abord INSTALLER.bat." }
$Res = Join-Path $Data 'resources'
$Ours = Join-Path $Res '[gtasoon]'
Say "Nouvelle version : $Repo" 'Green'

# 1. Arrêt du serveur
Say "`n[1/4] Arrêt du serveur" 'Cyan'
Get-Process -Name FXServer -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
Start-Sleep -Seconds 2

# 2. Sauvegarde de la version actuelle (ressources maison + config, sans les secrets)
Say "[2/4] Sauvegarde de la version actuelle" 'Cyan'
$Backups = 'C:\GTASOON\sauvegardes'
$stamp = Get-Date -Format 'yyyyMMdd_HHmmss'
$stage = Join-Path $env:TEMP "gtasoon-maj-$stamp"
[void][IO.Directory]::CreateDirectory((Join-Path $stage 'resources'))
[void][IO.Directory]::CreateDirectory((Join-Path $stage 'cfg'))
if (Test-Path -LiteralPath $Ours) { Copy-Item -LiteralPath $Ours -Destination (Join-Path $stage 'resources') -Recurse -Force }
Get-ChildItem -LiteralPath (Join-Path $Data 'cfg') -File | Where-Object { $_.Name -ne 'secrets.cfg' } |
    ForEach-Object { Copy-Item -LiteralPath $_.FullName -Destination (Join-Path $stage 'cfg') -Force }
foreach ($f in 'server.cfg', 'DEMARRER.bat') {
    if (Test-Path -LiteralPath (Join-Path $Data $f)) { Copy-Item -LiteralPath (Join-Path $Data $f) -Destination $stage -Force }
}
[void][IO.Directory]::CreateDirectory($Backups)
$zip = Join-Path $Backups "avant-maj-$stamp.zip"
[IO.Compression.ZipFile]::CreateFromDirectory($stage, $zip)
[IO.Directory]::Delete($stage, $true)
Say "  Sauvegarde : $zip" 'Green'

# 3. Nouvelle version
Say "[3/4] Installation de la nouvelle version" 'Cyan'
if (Test-Path -LiteralPath $Ours) { [IO.Directory]::Delete($Ours, $true) } # retire aussi les fichiers supprimés
Copy-Item -LiteralPath (Join-Path $Repo 'server\resources\[gtasoon]') -Destination $Res -Recurse -Force
# [addons] (tes véhicules / mods) : copié seulement s'il n'existe pas encore, jamais écrasé
if (-not (Test-Path -LiteralPath (Join-Path $Res '[addons]'))) { Copy-Item -LiteralPath (Join-Path $Repo 'server\resources\[addons]') -Destination $Res -Recurse -Force }
Get-ChildItem -LiteralPath (Join-Path $Repo 'server\cfg') -File | Where-Object { $_.Name -ne 'secrets.cfg' } |
    ForEach-Object { Copy-Item -LiteralPath $_.FullName -Destination (Join-Path $Data 'cfg') -Force }
Copy-Item -LiteralPath (Join-Path $Repo 'server\server.cfg.example') -Destination (Join-Path $Data 'server.cfg') -Force
Say '  Ressources GTA SOON + config remplacées (secrets.cfg et base de données intacts)' 'Green'

$r = Merge-GtaSoonItems $Res $Repo
if ($r) { Say "  ox_inventory : $($r.added) item(s) ajouté(s), $($r.replaced) amélioré(s)" 'Green' }
else { Say '  items.lua d''ox_inventory introuvable : items GTA SOON non ajoutés' 'Yellow' }
Say '  Réglages Qbox (spawn, magasins, hôpital) :' 'Cyan'
Set-QboxOverrides $Res $Repo { param($m, $c) Say $m $c }

# Lanceur : on garde le chemin de FXServer.exe de l'installation
$batPath = Join-Path $Data 'DEMARRER.bat'
$fx = if (Test-Path -LiteralPath $batPath) { [regex]::Match((Get-Content -LiteralPath $batPath -Raw), '"([^"]*FXServer\.exe)"').Groups[1].Value } else { '' }
if (-not $fx) { $fx = @('C:\FXServer\server\FXServer.exe', 'C:\FXServer\FXServer.exe') | Where-Object { Test-Path $_ } | Select-Object -First 1 }
if (-not $fx) { Fail 'FXServer.exe introuvable (DEMARRER.bat illisible).' }
$bat = "@echo off`r`ntitle Serveur GTA SOON`r`ncd /d `"%~dp0`"`r`n`"$fx`" +set onesync on +exec server.cfg`r`npause`r`n"
[IO.File]::WriteAllText($batPath, $bat, (New-Object Text.ASCIIEncoding))

# 4. Relance
Say "[4/4] Relance du serveur" 'Cyan'
Start-Process -FilePath $batPath -WorkingDirectory $Data
Say @"

MISE À JOUR TERMINÉE.
 - Vérifie dans la fenêtre « Serveur GTA SOON » : pas de ligne ROUGE, puis F8 → connect localhost.
 - En cas de problème, retour arrière : ferme le serveur, dézippe
   $zip
   dans $Data (remplacer les fichiers), puis DEMARRER.bat.
"@ 'Green'
Read-Host 'Entrée pour fermer'
