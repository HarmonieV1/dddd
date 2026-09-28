<#
  GTA SOON - INSTALLEUR TOUT-EN-UN (remplace la recipe txAdmin qui bloque).
  Double-cliquer sur installer-serveur.bat. Durée : 5 à 15 min selon la connexion.
  1. Vérifie MariaDB et crée la base 'gtasoon' (identifiants de reparer-mariadb : identifiants-bdd.txt)
  2. Exécute la recipe officielle Qbox SANS l'API GitHub (pas de limite « rate limit »)
  3. Branche GTA SOON (ressources, config, secrets, items), met de côté les doublons
  4. Crée C:\GTASOON\server-data\DEMARRER.bat et lance le serveur
  NON TESTÉ sur une vraie machine Windows : en cas de souci, envoyer installer-log.txt (Bureau) à [DEV].
#>
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$RecipeUrl = 'https://raw.githubusercontent.com/Qbox-project/txAdminRecipe/main/qbox.yaml'
$Desktop = [Environment]::GetFolderPath('Desktop')
$LogFile = Join-Path $Desktop 'installer-log.txt'
"=== Installeur GTA SOON $(Get-Date) ===" | Set-Content -LiteralPath $LogFile -Encoding UTF8
function Log($m, $c = 'Gray') { Write-Host $m -ForegroundColor $c; Add-Content -LiteralPath $LogFile -Value $m -Encoding UTF8 }
function Fail($m) { Log "ERREUR : $m" 'Red'; Log "Envoie $LogFile à [DEV]." 'Red'; Read-Host 'Entrée pour quitter'; exit 1 }
Add-Type -AssemblyName System.Windows.Forms
function PickFolder($desc, $default) {
    $d = New-Object System.Windows.Forms.FolderBrowserDialog
    $d.Description = $desc
    if ($default -and (Test-Path -LiteralPath $default)) { $d.SelectedPath = $default }
    if ($d.ShowDialog() -ne 'OK') { Fail 'Annulé.' }
    return $d.SelectedPath
}

# --- 0. Où sont les fichiers ? ------------------------------------------------------------------------
$Repo = Resolve-Path (Join-Path $PSScriptRoot '..\..') -ErrorAction SilentlyContinue
if (-not $Repo -or -not (Test-Path -LiteralPath (Join-Path $Repo 'server\resources\[gtasoon]'))) {
    Log 'Choisis le dossier du projet GTA SOON (le dossier « gtasoon » extrait de la backup).' 'Cyan'
    $Repo = PickFolder 'Dossier du projet GTA SOON (contient server, docs, scripts)' $Desktop
}
if (-not (Test-Path -LiteralPath (Join-Path $Repo 'server\resources\[gtasoon]'))) { Fail "Projet introuvable dans $Repo (il faut le dossier qui contient 'server')." }
Log "Projet : $Repo" 'Green'

$FxExe = @('C:\FXServer\server\FXServer.exe', 'C:\FXServer\FXServer.exe') | Where-Object { Test-Path $_ } | Select-Object -First 1
if (-not $FxExe) {
    Log 'Choisis le dossier où tu as extrait server.7z (celui qui contient FXServer.exe).' 'Cyan'
    $FxExe = Join-Path (PickFolder 'Dossier contenant FXServer.exe' 'C:\FXServer') 'FXServer.exe'
}
if (-not (Test-Path -LiteralPath $FxExe)) { Fail "FXServer.exe introuvable ($FxExe)." }
Log "FXServer : $FxExe" 'Green'

$Data = 'C:\GTASOON\server-data'
if (Test-Path -LiteralPath $Data) {
    $old = "$Data-ancien-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
    Rename-Item -LiteralPath $Data -NewName (Split-Path $old -Leaf)
    Log "Ancienne installation mise de côté : $old" 'Yellow'
}
New-Item -ItemType Directory -Force -Path $Data | Out-Null
$Tmp = Join-Path $Data 'tmp'
New-Item -ItemType Directory -Force -Path $Tmp | Out-Null

# --- 1. Base de données ---------------------------------------------------------------------------------
Log "`n[1/4] Base de données" 'Cyan'
$svc = Get-CimInstance Win32_Service | Where-Object { $_.Name -match 'maria|mysql' -and $_.PathName -match 'mysqld|mariadbd' } | Select-Object -First 1
if (-not $svc) { Fail 'Service MariaDB introuvable.' }
if ((Get-Service $svc.Name).Status -ne 'Running') { Fail 'MariaDB est arrêté : lance reparer-mariadb.bat ou démarre le service.' }
$bin = Split-Path ([regex]::Match($svc.PathName, '^"?([^"]+?(mysqld|mariadbd)\.exe)').Groups[1].Value)
$Client = @('mariadb.exe', 'mysql.exe') | ForEach-Object { Join-Path $bin $_ } | Where-Object { Test-Path $_ } | Select-Object -First 1
$DbUser, $DbPass = 'gtasoon', $null
$idFile = Join-Path $Desktop 'identifiants-bdd.txt'
if (Test-Path -LiteralPath $idFile) {
    $m = Select-String -LiteralPath $idFile -Pattern 'Mot de passe\s*:\s*(\S+)' | Select-Object -First 1
    if ($m) { $DbPass = $m.Matches[0].Groups[1].Value }
}
if (-not $DbPass) { $DbPass = Read-Host 'Mot de passe de l''utilisateur gtasoon (voir identifiants-bdd.txt)' }
function Sql($query, $db) {
    $ErrorActionPreference = 'Continue'
    $env:MYSQL_PWD = $DbPass
    $a = @('-h', '127.0.0.1', '-P', '3306', '-u', $DbUser, '--default-character-set=utf8mb4', '--batch', '--skip-column-names')
    if ($db) { $a += $db }
    $out = $query | & $Client @a 2>&1
    Remove-Item Env:MYSQL_PWD -ErrorAction SilentlyContinue
    $code = $LASTEXITCODE
    $text = ($out | ForEach-Object { "$_" } | Where-Object { $_ -notmatch 'ssl-verify-server-cert' }) -join "`n"
    return @{ ok = ($code -eq 0); out = $text }
}
# Base neuve à chaque installation : si 'gtasoon' contient déjà des tables (install précédente), on en crée une datée
$DbName = 'gtasoon'
$r = Sql "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema = 'gtasoon';" $null
if (-not $r.ok) { Fail "Connexion à MariaDB avec 'gtasoon' impossible : $($r.out). Relance reparer-mariadb.bat." }
if ([int](($r.out -split "`n" | Where-Object { $_ -match '^\s*\d+\s*$' } | Select-Object -First 1)) -gt 0) {
    $DbName = 'gtasoon_' + (Get-Date -Format 'yyyyMMdd_HHmm')
    Log "  La base 'gtasoon' existe déjà (ancienne install, conservée) : nouvelle base '$DbName'." 'Yellow'
}
$r = Sql "CREATE DATABASE IF NOT EXISTS ``$DbName`` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;" $null
if (-not $r.ok) { Fail "Création de la base $DbName impossible : $($r.out). Relance reparer-mariadb.bat (droits de gtasoon)." }
Log "Base $DbName prête." 'Green'

# --- 2. Recipe officielle Qbox (sans API GitHub) ----------------------------------------------------------
Log "`n[2/4] Téléchargement de Qbox (recipe officielle)" 'Cyan'
# Les chemins de la recipe contiennent des crochets ([ox], [qbx]...) : sous PowerShell 5.1, Expand-Archive,
# -OutFile et New-Item -Path les prennent pour des jokers. On passe donc par .NET (chemins littéraux).
Add-Type -AssemblyName System.IO.Compression.FileSystem
function P($rel) { return Join-Path $Data (($rel -replace '^\./', '') -replace '/', '\') }
function MkDir($path) { [void][IO.Directory]::CreateDirectory($path) }
$script:tmpCount = 0
function TmpPath($ext) { $script:tmpCount++; return Join-Path $Tmp ("t$($script:tmpCount)$ext") }
function Download($url, $out) {
    MkDir (Split-Path $out)
    $tmpFile = TmpPath '.bin'
    for ($i = 1; $i -le 3; $i++) {
        try { Invoke-WebRequest -Uri $url -OutFile $tmpFile -UseBasicParsing -TimeoutSec 180; break }
        catch { if ($i -eq 3) { throw "Téléchargement impossible : $url ($($_.Exception.Message))" }; Start-Sleep -Seconds (3 * $i) }
    }
    [IO.File]::Copy($tmpFile, $out, $true)
    [IO.File]::Delete($tmpFile)
}
function CopyContents($src, $dest) {
    MkDir $dest
    Get-ChildItem -LiteralPath $src -Force | ForEach-Object { Copy-Item -LiteralPath $_.FullName -Destination $dest -Recurse -Force }
}
function Unzip($zip, $dest) {
    $x = TmpPath ''
    [IO.Compression.ZipFile]::ExtractToDirectory($zip, $x)
    CopyContents $x $dest
    Remove-Item -LiteralPath $x -Recurse -Force -ErrorAction SilentlyContinue
}

$yaml = (Invoke-WebRequest -Uri $RecipeUrl -UseBasicParsing).Content -split "`n"
$tasks = New-Object System.Collections.Generic.List[hashtable]
$cur = $null
foreach ($raw in $yaml) {
    $line = $raw.TrimEnd("`r")
    if ($line -match '^\s*-\s*action:\s*([a-z_]+)') { $cur = @{ action = $Matches[1] }; $tasks.Add($cur); continue }
    if ($cur -and $line -match '^\s{3,}([a-zA-Z_]+):\s*(.+?)\s*$') {
        $val = ($Matches[2] -replace '\s+#.*$', '').Trim('"', "'")
        $cur[$Matches[1]] = $val
    }
}
Log "$($tasks.Count) étapes à exécuter." 'Gray'
$n = 0
foreach ($t in $tasks) {
    $n++
    Write-Progress -Activity 'Installation Qbox' -Status "$n / $($tasks.Count) : $($t.action) $($t.src)$($t.url)" -PercentComplete ($n * 100 / $tasks.Count)
    try {
        switch ($t.action) {
            'download_github' {
                $m = [regex]::Match($t.src, 'github\.com/([^/]+)/([^/]+?)(\.git)?/?$')
                $owner, $repoName = $m.Groups[1].Value, $m.Groups[2].Value
                $zip = Join-Path $Tmp "gh-$n.zip"
                $refs = if ($t.ref) { @($t.ref) } else { @('main', 'master') }
                $got = $false
                foreach ($ref in $refs) {
                    try { Download "https://codeload.github.com/$owner/$repoName/zip/$ref" $zip; $got = $true; break } catch { if ($ref -eq $refs[-1]) { throw } }
                }
                $ex = Join-Path $Tmp "gh-$n"
                [IO.Compression.ZipFile]::ExtractToDirectory($zip, $ex)
                $root = Get-ChildItem -LiteralPath $ex -Directory | Select-Object -First 1
                $src = $root.FullName
                if ($t.subpath) { $src = Join-Path $src ($t.subpath -replace '/', '\') }
                CopyContents $src (P $t.dest)
                Remove-Item -LiteralPath $zip, $ex -Recurse -Force -ErrorAction SilentlyContinue
            }
            'download_file' { Download $t.url (P $t.path) }
            'unzip' { Unzip (P $t.src) (P $t.dest) }
            'move_path' {
                $s, $d = (P $t.src), (P $t.dest)
                if (Test-Path -LiteralPath $d) { if ($t.overwrite -eq 'true' -or -not (Test-Path -LiteralPath $d -PathType Container)) { Remove-Item -LiteralPath $d -Recurse -Force } }
                MkDir (Split-Path $d)
                Move-Item -LiteralPath $s -Destination $d -Force
            }
            'copy_path' {
                $d = P $t.dest
                MkDir (Split-Path $d)
                Copy-Item -LiteralPath (P $t.src) -Destination $d -Recurse -Force
            }
            'remove_path' { $p = P $t.path; if (Test-Path -LiteralPath $p) { Remove-Item -LiteralPath $p -Recurse -Force } }
            'ensure_dir' { MkDir (P $t.path) }
            'connect_database' { }
            'query_database' {
                $f = P $t.file
                if (Test-Path -LiteralPath $f) {
                    $q = Sql (Get-Content -LiteralPath $f -Raw -Encoding UTF8) $DbName
                    if (-not $q.ok) { Log "  SQL $($t.file) : $($q.out)" 'Yellow' }
                } else { Log "  SQL introuvable : $($t.file)" 'Yellow' }
            }
            'waste_time' { Start-Sleep -Seconds ([int]$t.seconds) }
            default { Log "  Étape inconnue ignorée : $($t.action)" 'Yellow' }
        }
        Add-Content -LiteralPath $LogFile -Value "OK $n $($t.action) $($t.src)$($t.url)$($t.path)" -Encoding UTF8
    } catch {
        Fail "étape $n ($($t.action) $($t.src)$($t.url)) : $($_.Exception.Message)"
    }
}
Write-Progress -Activity 'Installation Qbox' -Completed
Remove-Item -LiteralPath $Tmp -Recurse -Force -ErrorAction SilentlyContinue
Log 'Qbox installé.' 'Green'

# --- 3. Branchement GTA SOON ---------------------------------------------------------------------------------
Log "`n[3/4] Branchement GTA SOON" 'Cyan'
$Res = Join-Path $Data 'resources'
Copy-Item -LiteralPath (Join-Path $Repo 'server\resources\[gtasoon]') -Destination $Res -Recurse -Force
[void][IO.Directory]::CreateDirectory((Join-Path $Data 'cfg'))
Get-ChildItem -LiteralPath (Join-Path $Repo 'server\cfg') -File | Where-Object { $_.Name -ne 'secrets.cfg' } |
    ForEach-Object { Copy-Item -LiteralPath $_.FullName -Destination (Join-Path $Data 'cfg') -Force }
if (Test-Path -LiteralPath (Join-Path $Data 'server.cfg')) { Move-Item -LiteralPath (Join-Path $Data 'server.cfg') -Destination (Join-Path $Data 'server.cfg.qbox') -Force }
Copy-Item -LiteralPath (Join-Path $Repo 'server\server.cfg.example') -Destination (Join-Path $Data 'server.cfg') -Force

# Doublons mis de côté (conflits avec nos ressources)
$off = Join-Path $Data 'resources_desactivees'
foreach ($name in 'qbx_management', 'qbx_weathersync', 'Renewed-Weathersync', 'qbx_hud') {
    Get-ChildItem -LiteralPath $Res -Directory -Recurse -Filter $name -ErrorAction SilentlyContinue | ForEach-Object {
        MkDir $off
        Move-Item -LiteralPath $_.FullName -Destination (Join-Path $off $name) -Force
        Log "  $name mis de côté (doublon)" 'Yellow'
    }
}

# Secrets
# Clé : nettoyée (espaces, guillemets) et dédoublonnée si elle a été collée deux fois (cfxk_AAAcfxk_AAA)
function CleanKey($k) {
    $k = "$k" -replace '[\s"''<>]', ''
    $m = [regex]::Match($k, 'cfxk_.*?(?=cfxk_|$)')
    if ($m.Success) { return $m.Value } else { return $k }
}
$license = ''
try { $license = CleanKey (Get-Clipboard -Raw) } catch { }
if ($license -match '^cfxk_[A-Za-z0-9_\-]{10,}$') {
    Log "  Clé trouvée dans le presse-papiers : $($license.Substring(0, 9))...$($license.Substring($license.Length - 4))" 'Green'
} else { $license = '' }
while ($license -notmatch '^cfxk_[A-Za-z0-9_\-]{10,}$') {
    $license = CleanKey (Read-Host 'Colle ta clé de licence serveur UNE SEULE FOIS (commence par cfxk_, sur portal.cfx.re)')
}
$secrets = Get-Content -LiteralPath (Join-Path $Data 'cfg\secrets.cfg.example') -Raw -Encoding UTF8
$secrets = $secrets -replace 'sv_licenseKey "CHANGE_ME"', ('sv_licenseKey "' + $license.Replace('$', '$$') + '"')
$secrets = $secrets -replace 'set mysql_connection_string "[^"]*"', ('set mysql_connection_string "mysql://gtasoon:' + $DbPass.Replace('$', '$$') + '@127.0.0.1:3306/' + $DbName + '?charset=utf8mb4"')
[IO.File]::WriteAllText((Join-Path $Data 'cfg\secrets.cfg'), $secrets, (New-Object Text.UTF8Encoding $false))
Log '  secrets.cfg créé (licence + base de données)' 'Green'

# Items GTA SOON dans ox_inventory (seulement ceux qui manquent)
$items = Get-ChildItem -LiteralPath $Res -Recurse -Filter items.lua -ErrorAction SilentlyContinue | Where-Object { $_.FullName -match 'ox_inventory\\data\\items\.lua$' } | Select-Object -First 1
if ($items) {
    $content = Get-Content -LiteralPath $items.FullName -Raw -Encoding UTF8
    $add = @()
    foreach ($line in Get-Content -LiteralPath (Join-Path $Repo 'server\ox_items_gtasoon.lua') -Encoding UTF8) {
        if ($line -match "^\['([a-z_]+)'\]" -and $content -notmatch ("\['" + $Matches[1] + "'\]")) { $add += '    ' + $line }
    }
    if ($add.Count -gt 0) {
        $i = $content.LastIndexOf('}')
        $content = $content.Substring(0, $i) + "`n    -- GTA SOON`n" + ($add -join "`n") + "`n" + $content.Substring($i)
        [IO.File]::WriteAllText($items.FullName, $content, (New-Object Text.UTF8Encoding $false))
    }
    Log "  $($add.Count) item(s) GTA SOON ajouté(s) à ox_inventory" 'Green'
} else { Log '  items.lua d''ox_inventory introuvable : ajoute server\ox_items_gtasoon.lua à la main' 'Yellow' }

# Lanceur
$bat = "@echo off`r`ntitle Serveur GTA SOON`r`ncd /d `"%~dp0`"`r`n`"$FxExe`" +set onesync on +exec server.cfg`r`npause`r`n"
[IO.File]::WriteAllText((Join-Path $Data 'DEMARRER.bat'), $bat, (New-Object Text.ASCIIEncoding))

# --- 4. Lancement --------------------------------------------------------------------------------------------------
Log "`n[4/4] Lancement" 'Cyan'
Get-Process -Name FXServer -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
Start-Process -FilePath (Join-Path $Data 'DEMARRER.bat') -WorkingDirectory $Data
Log @"

INSTALLATION TERMINÉE.
 - Le serveur démarre dans une nouvelle fenêtre « Serveur GTA SOON » (garde-la ouverte).
 - Attends la ligne « Server license key authentication succeeded » puis « Started resource gs_... ».
 - Lance FiveM → F8 → connect localhost
 - Plus tard, pour redémarrer : C:\GTASOON\server-data\DEMARRER.bat
 - Envoie à [DEV] les lignes ROUGES / JAUNES de la fenêtre du serveur.
"@ 'Green'
Read-Host 'Entrée pour fermer cet installeur'
