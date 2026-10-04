<#
  GTA SOON - SAUVEGARDE DE LA BASE DE DONNÉES (persos, argent, inventaires, gangs, progression…).
  Double-clic sur SAUVEGARDER-BDD.bat : sauvegarde maintenant, et propose de la programmer toutes les 6 h (dont 5 h du matin).
  Fichiers : C:\GTASOON\sauvegardes\bdd\ (les 30 plus récentes sont gardées, soit ~1 semaine).
  Restauration / retour en arrière : RESTAURER-BDD.bat (toute la base, ou un seul joueur).
#>
param([switch]$Auto, [string]$Label = '')
$ErrorActionPreference = 'Stop'
function Say($m, $c = 'Gray') { if (-not $Auto) { Write-Host $m -ForegroundColor $c } }
function Fail($m) { Say "ERREUR : $m" 'Red'; if (-not $Auto) { Read-Host 'Entrée pour quitter' }; exit 1 }

$Data = 'C:\GTASOON\server-data'
$secrets = Join-Path $Data 'cfg\secrets.cfg'
if (-not (Test-Path -LiteralPath $secrets)) { Fail "Introuvable : $secrets (lance d'abord INSTALLER.bat)." }
$content = Get-Content -LiteralPath $secrets -Raw -Encoding UTF8
$cs = [regex]::Match($content, 'mysql_connection_string\s+"mysql:/{2}([^:]+):(.*)@([^:/@]+)(?::(\d+))?/([^?"]+)')
if (-not $cs.Success) { Fail 'mysql_connection_string illisible dans secrets.cfg.' }
$user, $pass, $dbHost, $port, $db = $cs.Groups[1].Value, $cs.Groups[2].Value, $cs.Groups[3].Value, $cs.Groups[4].Value, $cs.Groups[5].Value
if (-not $port) { $port = '3306' }

$svc = Get-CimInstance Win32_Service | Where-Object { $_.Name -match 'maria|mysql' -and $_.PathName -match 'mysqld|mariadbd' } | Select-Object -First 1
if (-not $svc) { Fail 'Service MariaDB introuvable.' }
$bin = Split-Path ([regex]::Match($svc.PathName, '^"?([^"]+?(mysqld|mariadbd)\.exe)').Groups[1].Value)
$Dump = @('mariadb-dump.exe', 'mysqldump.exe') | ForEach-Object { Join-Path $bin $_ } | Where-Object { Test-Path $_ } | Select-Object -First 1
if (-not $Dump) { Fail "Outil de sauvegarde introuvable dans $bin." }

$dir = 'C:\GTASOON\sauvegardes\bdd'
[void][IO.Directory]::CreateDirectory($dir)
$suffix = if ($Label -match '^[a-z0-9-]{1,24}$') { "-$Label" } else { '' }
$file = Join-Path $dir ("$db-" + (Get-Date -Format 'yyyyMMdd_HHmm') + $suffix + '.sql')
Say "Sauvegarde de la base '$db'…" 'Cyan'
$env:MYSQL_PWD = $pass
$ErrorActionPreference = 'Continue'
$out = & $Dump -h $dbHost -P $port -u $user --single-transaction --routines --default-character-set=utf8mb4 --result-file="$file" $db 2>&1
$code = $LASTEXITCODE
$ErrorActionPreference = 'Stop'
Remove-Item Env:MYSQL_PWD -ErrorAction SilentlyContinue
if ($code -ne 0 -or -not (Test-Path -LiteralPath $file) -or (Get-Item -LiteralPath $file).Length -lt 1000) {
    Fail ("Sauvegarde échouée : " + (($out | ForEach-Object { "$_" } | Where-Object { $_ -notmatch 'ssl-verify-server-cert' }) -join ' '))
}
$size = [math]::Round((Get-Item -LiteralPath $file).Length / 1MB, 2)
Say "OK : $file ($size Mo)" 'Green'

# Garder les 30 plus récentes
Get-ChildItem -LiteralPath $dir -Filter '*.sql' | Sort-Object LastWriteTime -Descending | Select-Object -Skip 30 | Remove-Item -Force

if ($Auto) { exit 0 }

# Programmation (tâche Windows toutes les 6 h à partir de 5 h, pour ton compte)
$task = 'RoadLine - sauvegarde BDD'
$exists = $false
cmd /c "schtasks /Query /TN `"$task`" >nul 2>&1"; $exists = ($LASTEXITCODE -eq 0)
if ($exists) {
    Say "La sauvegarde automatique est déjà programmée (toutes les 6 h : 5 h, 11 h, 17 h, 23 h)." 'Green'
} else {
    $a = Read-Host 'Programmer cette sauvegarde automatiquement toutes les 6 h (5 h, 11 h, 17 h, 23 h) ? (O/N)'
    if ($a -match '^[oOyY]') {
        # Copie stable du script (le dossier du zip peut être supprimé plus tard)
        $tools = 'C:\GTASOON\outils'
        [void][IO.Directory]::CreateDirectory($tools)
        $stable = Join-Path $tools 'sauvegarder-bdd.ps1'
        Copy-Item -LiteralPath $PSCommandPath -Destination $stable -Force
        $cmd = "powershell -NoProfile -ExecutionPolicy Bypass -File `"$stable`" -Auto"
        Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'restaurer-bdd.ps1') -Destination (Join-Path $tools 'restaurer-bdd.ps1') -Force -ErrorAction SilentlyContinue
        try { schtasks /Create /TN $task /SC HOURLY /MO 6 /ST 05:00 /TR $cmd /F 2>&1 | Out-Null } catch { }
        if ($LASTEXITCODE -eq 0) {
            cmd /c "schtasks /Delete /TN `"GTA SOON - sauvegarde BDD`" /F >nul 2>&1" # ancienne tâche (1 fois par nuit) remplacée
            Say 'Programmé : toutes les 6 h (le PC doit être allumé).' 'Green'
        }
        else { Say 'Programmation refusée par Windows : relance ce fichier en clic droit → Exécuter en tant qu''administrateur.' 'Yellow' }
    }
}
Say @"

RETOUR EN ARRIÈRE (gros bug, crash, triche) : double-clic sur RESTAURER-BDD.bat
 - toute la base revient à l'heure choisie, ou
 - un seul joueur (perso + véhicules) revient à l'heure choisie, le reste du serveur ne bouge pas.
 L'état actuel est toujours sauvegardé avant, on peut donc annuler.
"@ 'Cyan'
Read-Host 'Entrée pour fermer'
