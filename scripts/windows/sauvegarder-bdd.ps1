<#
  GTA SOON - SAUVEGARDE DE LA BASE DE DONNÉES (persos, argent, inventaires, gangs, progression…).
  Double-clic sur SAUVEGARDER-BDD.bat : sauvegarde maintenant, et propose de la programmer chaque nuit à 5 h.
  Fichiers : C:\GTASOON\sauvegardes\bdd\ (les 14 plus récentes sont gardées).
  Restauration : voir la fin de ce fichier (RESTAURER).
#>
param([switch]$Auto)
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
$file = Join-Path $dir ("$db-" + (Get-Date -Format 'yyyyMMdd_HHmm') + '.sql')
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

# Garder les 14 plus récentes
Get-ChildItem -LiteralPath $dir -Filter '*.sql' | Sort-Object LastWriteTime -Descending | Select-Object -Skip 14 | Remove-Item -Force

if ($Auto) { exit 0 }

# Programmation quotidienne (tâche Windows à 5 h, pour ton compte)
$task = 'GTA SOON - sauvegarde BDD'
$exists = $false
try { schtasks /Query /TN $task 2>$null | Out-Null; $exists = ($LASTEXITCODE -eq 0) } catch { }
if ($exists) {
    Say "La sauvegarde automatique est déjà programmée chaque nuit à 5 h." 'Green'
} else {
    $a = Read-Host 'Programmer cette sauvegarde automatiquement chaque nuit à 5 h ? (O/N)'
    if ($a -match '^[oOyY]') {
        # Copie stable du script (le dossier du zip peut être supprimé plus tard)
        $tools = 'C:\GTASOON\outils'
        [void][IO.Directory]::CreateDirectory($tools)
        $stable = Join-Path $tools 'sauvegarder-bdd.ps1'
        Copy-Item -LiteralPath $PSCommandPath -Destination $stable -Force
        $cmd = "powershell -NoProfile -ExecutionPolicy Bypass -File `"$stable`" -Auto"
        schtasks /Create /TN $task /SC DAILY /ST 05:00 /TR $cmd /F | Out-Null
        if ($LASTEXITCODE -eq 0) { Say 'Programmé : tous les jours à 5 h (le PC doit être allumé).' 'Green' }
        else { Say 'Programmation refusée par Windows : relance ce fichier en clic droit → Exécuter en tant qu''administrateur.' 'Yellow' }
    }
}
Say @"

RESTAURER une sauvegarde (en cas de problème) :
 1. Arrête le serveur.
 2. Ouvre HeidiSQL (installé avec MariaDB), connecte-toi, sélectionne la base '$db'.
 3. Fichier → Exécuter un fichier SQL → choisis la sauvegarde dans $dir.
 4. Relance le serveur.
"@ 'Cyan'
Read-Host 'Entrée pour fermer'
