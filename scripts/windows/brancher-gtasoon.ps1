<#
  GTA SOON - branche nos ressources sur un serveur installé par la recipe Qbox de txAdmin.
  A lancer APRES la recipe (le dossier du serveur contient server.cfg et resources\).

  Ce que fait le script :
   1. sauvegarde le server.cfg de la recipe (server.cfg.recipe-AAAAMMJJ-HHMM)
   2. copie nos ressources [gtasoon] et le dossier cfg\
   3. crée cfg\secrets.cfg en reprenant la licence et la connexion MySQL de la recipe
   4. met de côté les ressources en doublon (qbx_management, qbx_weathersync) dans resources_desactivees\
   5. installe notre server.cfg
   6. liste les ressources présentes mais non démarrées (à décider avec [DEV])
  Rien n'est supprimé : tout est sauvegardé ou déplacé.

  Usage : double-cliquer sur brancher-gtasoon.bat (ou .\brancher-gtasoon.ps1 -ServerData "C:\...")
  NON TESTE sur une vraie machine Windows : lire la sortie, signaler toute ligne rouge.
#>
param([string]$ServerData)

$ErrorActionPreference = 'Stop'
$Repo = Resolve-Path (Join-Path $PSScriptRoot '..\..')

function Say($msg, $color = 'Cyan') { Write-Host $msg -ForegroundColor $color }

# Dossier du serveur : paramètre ou sélection graphique
if (-not $ServerData) {
    Add-Type -AssemblyName System.Windows.Forms
    $dlg = New-Object System.Windows.Forms.FolderBrowserDialog
    $dlg.Description = 'Choisis le dossier du serveur (celui qui contient server.cfg et resources)'
    if ($dlg.ShowDialog() -ne 'OK') { Say 'Annulé.' 'Yellow'; exit 1 }
    $ServerData = $dlg.SelectedPath
}
$Cfg = Join-Path $ServerData 'server.cfg'
$Resources = Join-Path $ServerData 'resources'
if (-not (Test-Path -LiteralPath $Cfg) -or -not (Test-Path -LiteralPath $Resources)) {
    Say "Pas de server.cfg ou de dossier resources dans $ServerData. Lance d'abord la recipe Qbox dans txAdmin." 'Red'
    exit 1
}

# 1. Sauvegarde
$stamp = Get-Date -Format 'yyyyMMdd-HHmm'
$recipeCfg = "$Cfg.recipe-$stamp"
Copy-Item -LiteralPath $Cfg -Destination $recipeCfg
Say "1/6 server.cfg de la recipe sauvegardé : $recipeCfg"

# 2. Copie des ressources et de la config
Copy-Item -LiteralPath (Join-Path $Repo 'server\resources\[gtasoon]') -Destination $Resources -Recurse -Force
$cfgDir = Join-Path $ServerData 'cfg'
New-Item -ItemType Directory -Force $cfgDir | Out-Null
Get-ChildItem -LiteralPath (Join-Path $Repo 'server\cfg') -File | Where-Object { $_.Name -ne 'secrets.cfg' } |
    Copy-Item -Destination $cfgDir -Force
Say '2/6 ressources [gtasoon] et cfg\ copiées'

# 3. secrets.cfg (jamais écrasé s'il existe déjà)
$secrets = Join-Path $cfgDir 'secrets.cfg'
if (Test-Path -LiteralPath $secrets) {
    Say '3/6 cfg\secrets.cfg existe déjà : conservé tel quel' 'Yellow'
} else {
    $recipe = Get-Content -LiteralPath $recipeCfg -Raw
    $content = Get-Content -LiteralPath (Join-Path $cfgDir 'secrets.cfg.example') -Raw
    $license = [regex]::Match($recipe, 'sv_licenseKey\s+"?([^"\r\n]+)"?').Groups[1].Value
    $mysql = [regex]::Match($recipe, 'mysql_connection_string\s+"([^"]+)"').Groups[1].Value
    # .Replace('$', '$$') : un $ dans le mot de passe ne doit pas être lu comme une référence regex
    if ($license) { $content = $content -replace 'sv_licenseKey "CHANGE_ME"', ('sv_licenseKey "' + $license.Replace('$', '$$') + '"') }
    if ($mysql) { $content = $content -replace 'set mysql_connection_string "[^"]*"', ('set mysql_connection_string "' + $mysql.Replace('$', '$$') + '"') }
    # UTF-8 SANS BOM : FXServer lirait le BOM comme une commande inconnue
    [System.IO.File]::WriteAllText($secrets, $content, (New-Object System.Text.UTF8Encoding $false))
    if ($license -and $mysql) { Say '3/6 cfg\secrets.cfg créé (licence + MySQL repris de la recipe)' }
    else { Say '3/6 cfg\secrets.cfg créé mais licence ou MySQL introuvable : ouvre-le et remplis les CHANGE_ME' 'Yellow' }
}

# 4. Doublons mis de côté
$disabled = Join-Path $ServerData 'resources_desactivees'
foreach ($name in 'qbx_management', 'qbx_weathersync') {
    Get-ChildItem -LiteralPath $Resources -Directory -Recurse -Filter $name -ErrorAction SilentlyContinue | ForEach-Object {
        New-Item -ItemType Directory -Force $disabled | Out-Null
        Move-Item -LiteralPath $_.FullName -Destination (Join-Path $disabled $name) -Force
        Say "4/6 $name déplacé dans resources_desactivees\ (doublon)"
    }
}

# 5. Notre server.cfg
Copy-Item -LiteralPath (Join-Path $Repo 'server\server.cfg.example') -Destination $Cfg -Force
Say '5/6 server.cfg GTA SOON installé'

# 6. Ressources présentes mais non démarrées
$ensured = Get-ChildItem -LiteralPath $cfgDir -Filter *.cfg | ForEach-Object { Get-Content -LiteralPath $_.FullName } |
    Where-Object { $_ -match '^\s*ensure\s+(\S+)' } | ForEach-Object { $Matches[1] }
$present = Get-ChildItem -LiteralPath $Resources -Recurse -Filter fxmanifest.lua | ForEach-Object { $_.Directory.Name }
$missing = $ensured | Where-Object { $present -notcontains $_ }
$unused = $present | Where-Object { $ensured -notcontains $_ } | Sort-Object -Unique
if ($missing) { Say ("Ressources démarrées mais ABSENTES (à installer) : " + ($missing -join ', ')) 'Yellow' }
if ($unused) { Say ("Ressources présentes mais NON démarrées (envoie la liste à [DEV]) : " + ($unused -join ', ')) 'Yellow' }

Say "`nTerminé. Reste à faire :" 'Green'
Say " - ajouter ton identifiant license: en group.admin dans cfg\secrets.cfg (voir docs\INSTALL.md)" 'Green'
Say " - redémarrer le serveur depuis txAdmin et vérifier la console (aucune ligne rouge)" 'Green'
