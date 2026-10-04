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
# Marques réelles (risque Cfx.re) : les mods de marques encore installés sont retirés à chaque mise à jour (NETTOYER-MARQUES.bat)
$purge = Join-Path $Repo 'NETTOYER-MARQUES.bat'
if (Test-Path -LiteralPath $purge) {
    try {
        $t = Get-Content -LiteralPath $purge -Raw
        $env:GTASOON_MARQUES_AUTO = '1'
        & ([scriptblock]::Create($t.Substring($t.LastIndexOf('#DEBUT' + 'PS#') + 9)))
    } catch { Say "  Nettoyage des marques : $($_.Exception.Message)" 'Yellow' }
    finally { Remove-Item Env:GTASOON_MARQUES_AUTO -ErrorAction SilentlyContinue }
}
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
# Version : l'ancienne (server.cfg en place) et celle du zip, pour être sûr d'avoir lancé le bon dossier
$verOf = { param($f) if (Test-Path -LiteralPath $f) { $m = [regex]::Match((Get-Content -LiteralPath $f -Raw), 'setr gs_version "([^"]+)"'); if ($m.Success) { $m.Groups[1].Value } else { 'avant V8.1' } } else { 'aucune' } }
$oldVer = & $verOf (Join-Path $Data 'server.cfg')
$newVer = & $verOf (Join-Path $Repo 'server\server.cfg.example')
Say "  Version installée : $oldVer  →  nouvelle : $newVer" 'Green'
if ($oldVer -eq $newVer) { Say "  (même version : si tu attendais du nouveau, vérifie que tu as extrait le DERNIER zip)" 'Yellow' }
if (Test-Path -LiteralPath $Ours) { [IO.Directory]::Delete($Ours, $true) } # retire aussi les fichiers supprimés
Copy-Item -LiteralPath (Join-Path $Repo 'server\resources\[gtasoon]') -Destination $Res -Recurse -Force
# [addons] (tes véhicules / mods) : copié seulement s'il n'existe pas encore, jamais écrasé
if (-not (Test-Path -LiteralPath (Join-Path $Res '[addons]'))) { Copy-Item -LiteralPath (Join-Path $Repo 'server\resources\[addons]') -Destination $Res -Recurse -Force }
Get-ChildItem -LiteralPath (Join-Path $Repo 'server\cfg') -File | Where-Object { $_.Name -ne 'secrets.cfg' } |
    ForEach-Object { Copy-Item -LiteralPath $_.FullName -Destination (Join-Path $Data 'cfg') -Force }
Copy-Item -LiteralPath (Join-Path $Repo 'server\server.cfg.example') -Destination (Join-Path $Data 'server.cfg') -Force
# cfg\addons.cfg (mods importés) : créé vide s'il n'existe pas, pour que « exec cfg/addons.cfg » ne râle pas.
$addonsCfg = Join-Path $Data 'cfg\addons.cfg'
if (-not (Test-Path -LiteralPath $addonsCfg)) { [IO.File]::WriteAllText($addonsCfg, "## Mods importés par IMPORTER-MODS.bat`r`n", (New-Object Text.UTF8Encoding $false)) }
Say '  Ressources GTA SOON + config remplacées (secrets.cfg et base de données intacts)' 'Green'

$r = Merge-GtaSoonItems $Res $Repo
if ($r) { Say "  ox_inventory : $($r.added) item(s) ajouté(s), $($r.replaced) amélioré(s)" 'Green' }
else { Say '  items.lua d''ox_inventory introuvable : items GTA SOON non ajoutés' 'Yellow' }
Say '  Réglages Qbox (spawn, magasins, hôpital) :' 'Cyan'
Set-QboxOverrides $Res $Repo { param($m, $c) Say $m $c }

# Lanceur : on garde le chemin de FXServer.exe de l'installation
$batPath = Join-Path $Data 'DEMARRER.bat'
$fx = Find-FxServer $Data
$fx = Move-FxServerOutOfOneDrive $fx ${function:Say}
if (-not $fx) { Fail 'FXServer.exe introuvable : extrais server.7z (artefacts FiveM) dans C:\FXServer\server puis relance.' }
Say "  FXServer : $fx" 'Green'
Write-Launcher $Data $fx

# 3b. Mods posés dans C:\GTASOON\mods-a-trier (ou Google Drive pour ordinateur) : importés automatiquement
$importer = Join-Path $PSScriptRoot 'importer-mods.ps1'
if (Test-Path -LiteralPath $importer) {
    Say "`n[3b] Import des mods (si C:\GTASOON\mods-a-trier contient des archives)" 'Cyan'
    $env:GTASOON_CHAIN = '1'
    # processus séparé : une erreur de l'import n'arrête jamais la mise à jour
    $ps = (Get-Process -Id $PID).Path
    try { & $ps -NoProfile -ExecutionPolicy Bypass -File $importer } catch { Say "  Import des mods : $($_.Exception.Message) (relance IMPORTER-MODS.bat seul)" 'Yellow' }
    Remove-Item Env:\GTASOON_CHAIN -ErrorAction SilentlyContinue
}

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
