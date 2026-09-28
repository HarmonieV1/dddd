<#
  GTA SOON - DEVENIR ADMIN (groupe god) sans chercher son identifiant.
  1. Connecte-toi une fois au serveur (F8 → connect localhost), puis déconnecte-toi
  2. Double-clic sur DEVENIR-ADMIN.bat : choisis ton nom, c'est écrit dans cfg\secrets.cfg, le serveur redémarre
  Lit les derniers joueurs connectés dans la base (table users de Qbox).
#>
$ErrorActionPreference = 'Stop'
function Say($m, $c = 'Gray') { Write-Host $m -ForegroundColor $c }
function Fail($m) { Say "ERREUR : $m" 'Red'; Read-Host 'Entrée pour quitter'; exit 1 }
$Data = 'C:\GTASOON\server-data'
$secrets = Join-Path $Data 'cfg\secrets.cfg'
if (-not (Test-Path -LiteralPath $secrets)) { Fail "Introuvable : $secrets (lance d'abord INSTALLER.bat)." }
$content = Get-Content -LiteralPath $secrets -Raw -Encoding UTF8

# Connexion BDD : celle du serveur (utilisateur, mot de passe, hôte, port, base lus dans secrets.cfg)
$cs = [regex]::Match($content, 'mysql_connection_string\s+"mysql:/{2}([^:]+):(.*)@([^:/@]+)(?::(\d+))?/([^?"]+)')
if (-not $cs.Success) { Fail 'mysql_connection_string illisible dans secrets.cfg.' }
$user, $pass, $dbHost, $port, $db = $cs.Groups[1].Value, $cs.Groups[2].Value, $cs.Groups[3].Value, $cs.Groups[4].Value, $cs.Groups[5].Value
if (-not $port) { $port = '3306' }
$svc = Get-CimInstance Win32_Service | Where-Object { $_.Name -match 'maria|mysql' -and $_.PathName -match 'mysqld|mariadbd' } | Select-Object -First 1
if (-not $svc) { Fail 'Service MariaDB introuvable.' }
$bin = Split-Path ([regex]::Match($svc.PathName, '^"?([^"]+?(mysqld|mariadbd)\.exe)').Groups[1].Value)
$Client = @('mariadb.exe', 'mysql.exe') | ForEach-Object { Join-Path $bin $_ } | Where-Object { Test-Path $_ } | Select-Object -First 1
if (-not $Client) { Fail "Client MariaDB introuvable dans $bin." }
function Sql($query) {
    $ErrorActionPreference = 'Continue'
    $env:MYSQL_PWD = $pass
    $out = $query | & $Client -h $dbHost -P $port -u $user --default-character-set=utf8mb4 --batch --skip-column-names $db 2>&1
    $code = $LASTEXITCODE
    Remove-Item Env:MYSQL_PWD -ErrorAction SilentlyContinue
    return @{ ok = ($code -eq 0); lines = @($out | ForEach-Object { "$_" } | Where-Object { $_ -and $_ -notmatch 'ssl-verify-server-cert' }) }
}

# Derniers joueurs (users : license/license2, sinon players : license)
$rows = @()
$r = Sql 'SELECT username, license, license2 FROM users ORDER BY userId DESC LIMIT 8;'
if (-not $r.ok) { $r = Sql 'SELECT name, license, NULL FROM players ORDER BY last_updated DESC LIMIT 8;' }
if (-not $r.ok) { Fail "Lecture des joueurs impossible : $($r.lines -join ' ')" }
foreach ($l in $r.lines) {
    $c = $l -split "`t"
    $ids = @($c[1], $c[2]) | Where-Object { $_ -and $_ -ne 'NULL' -and $_ -match '^license2?:[0-9a-f]+$' }
    if ($ids) { $rows += [pscustomobject]@{ Name = $c[0]; Ids = $ids } }
}
if ($rows.Count -eq 0) { Fail "Aucun joueur dans la base '$db'. Connecte-toi une fois au serveur (F8 → connect localhost), puis relance cet outil." }

Say 'Derniers joueurs connectés :' 'Cyan'
for ($i = 0; $i -lt $rows.Count; $i++) {
    $id = $rows[$i].Ids[0]
    Say ("  {0}. {1}  (…{2})" -f ($i + 1), $rows[$i].Name, $id.Substring($id.Length - 6))
}
$pick = 0
if ($rows.Count -gt 1) {
    $a = Read-Host "Numéro de TON compte (Entrée = 1)"
    if ($a -match '^\d+$' -and [int]$a -ge 1 -and [int]$a -le $rows.Count) { $pick = [int]$a - 1 }
}
$me = $rows[$pick]
$label = ($me.Name -replace '[^\w \-]', '').Trim()

# Écriture dans secrets.cfg (une ligne par identifiant, sans doublon)
$added = 0
foreach ($id in $me.Ids) {
    $line = "add_principal identifier.$id group.god"
    if ($content -notmatch [regex]::Escape($line)) {
        $content = $content.TrimEnd() + "`r`n$line   # $label (DEVENIR-ADMIN)`r`n"
        $added++
    }
}
if ($added -eq 0) { Say "$label est déjà admin (god) dans secrets.cfg." 'Yellow' }
else {
    [IO.File]::WriteAllText($secrets, $content, (New-Object Text.UTF8Encoding $false))
    Say "$label ajouté au groupe god (admin complet)." 'Green'
}

Get-Process -Name FXServer -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
Start-Sleep -Seconds 2
Start-Process -FilePath (Join-Path $Data 'DEMARRER.bat') -WorkingDirectory $Data
Say "`nServeur relancé. Reconnecte-toi (F8 → connect localhost) : F10 = panel staff, /builder = mapping." 'Cyan'
Read-Host 'Entrée pour fermer'
