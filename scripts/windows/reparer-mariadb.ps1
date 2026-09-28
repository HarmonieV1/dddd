<#
  GTA SOON - Réparation MariaDB pour txAdmin (« does not accept the required authentication method » / accès refusé).
  Double-cliquer sur reparer-mariadb.bat (il se relance en administrateur tout seul).
  - Crée l'utilisateur 'gtasoon' (méthode mysql_native_password, compatible txAdmin) avec un mot de passe généré.
  - Si tu ne connais plus le mot de passe root : le réinitialise (redémarrage temporaire de MariaDB).
  - Teste la connexion et écrit les identifiants sur le Bureau : identifiants-bdd.txt
  NON TESTÉ sur une vraie machine Windows. Ne supprime aucune base.
#>
$ErrorActionPreference = 'Stop'

# Relance en administrateur si besoin (arrêt / démarrage du service)
$admin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $admin) {
    Start-Process powershell -Verb RunAs -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`""
    exit
}

function Say($m, $c = 'Gray') { Write-Host $m -ForegroundColor $c }
function NewPassword() {
    $chars = 'abcdefghijkmnopqrstuvwxyzABCDEFGHJKLMNPQRSTUVWXYZ23456789'
    -join (1..16 | ForEach-Object { $chars[(Get-Random -Maximum $chars.Length)] })
}

# 1. Trouver MariaDB (service + dossier bin)
$svc = Get-CimInstance Win32_Service | Where-Object { $_.Name -match 'maria|mysql' -and $_.PathName -match 'mysqld|mariadbd' } | Select-Object -First 1
if (-not $svc) { Say 'Service MariaDB introuvable : installe MariaDB (.msi) avec « Install as service ».' 'Red'; Read-Host 'Entrée pour quitter'; exit 1 }
$exe = [regex]::Match($svc.PathName, '^"?([^"]+?(mysqld|mariadbd)\.exe)"?').Groups[1].Value
$defaults = [regex]::Match($svc.PathName, '--defaults-file="?([^"]+?\.ini)"?').Groups[1].Value
$bin = Split-Path $exe
$client = @('mariadb.exe', 'mysql.exe') | ForEach-Object { Join-Path $bin $_ } | Where-Object { Test-Path $_ } | Select-Object -First 1
Say "MariaDB trouvé : $bin (service $($svc.Name))" 'Green'
if (-not $client) { Say 'Client mysql introuvable dans le dossier bin.' 'Red'; Read-Host 'Entrée pour quitter'; exit 1 }

$userPwd = NewPassword
$createUser = @"
DROP USER IF EXISTS 'gtasoon'@'localhost';
DROP USER IF EXISTS 'gtasoon'@'127.0.0.1';
CREATE USER 'gtasoon'@'localhost' IDENTIFIED VIA mysql_native_password USING PASSWORD('$userPwd');
CREATE USER 'gtasoon'@'127.0.0.1' IDENTIFIED VIA mysql_native_password USING PASSWORD('$userPwd');
GRANT ALL PRIVILEGES ON *.* TO 'gtasoon'@'localhost' WITH GRANT OPTION;
GRANT ALL PRIVILEGES ON *.* TO 'gtasoon'@'127.0.0.1' WITH GRANT OPTION;
FLUSH PRIVILEGES;
"@

function RunSql($sql, $extraArgs) {
    # 'Continue' : sous PowerShell 5.1, une sortie d'erreur du client ne doit pas stopper le script
    $ErrorActionPreference = 'Continue'
    $out = $sql | & $client @extraArgs 2>&1
    return @{ ok = ($LASTEXITCODE -eq 0); out = ($out | Out-String) }
}

# 2. Mode A : mot de passe root connu
Say "`nTape ton mot de passe root MariaDB (celui de l'installation)." 'Cyan'
Say 'Tu ne t''en souviens plus ? Appuie juste sur Entrée : je le réinitialise.' 'Cyan'
$rootPwd = Read-Host 'Mot de passe root'
$done = $false
if ($rootPwd) {
    $env:MYSQL_PWD = $rootPwd
    $r = RunSql $createUser @('-h', '127.0.0.1', '-P', '3306', '-u', 'root')
    Remove-Item Env:MYSQL_PWD -ErrorAction SilentlyContinue
    if ($r.ok) { $done = $true; Say 'Utilisateur gtasoon créé.' 'Green' }
    else { Say "Connexion root refusée : passage à la réinitialisation.`n$($r.out)" 'Yellow' }
}

# 3. Mode B : réinitialisation (MariaDB redémarré temporairement sans contrôle des mots de passe, en local seulement)
if (-not $done) {
    $newRoot = NewPassword
    Say "`nRéinitialisation : arrêt du service $($svc.Name)..." 'Cyan'
    Stop-Service $svc.Name -Force
    $srvArgs = @('--skip-grant-tables', '--skip-networking', '--enable-named-pipe', '--socket=GTASOON_RESET')
    if ($defaults) { $srvArgs = @("--defaults-file=`"$defaults`"") + $srvArgs }
    $proc = Start-Process -FilePath $exe -ArgumentList $srvArgs -PassThru -WindowStyle Hidden
    Start-Sleep -Seconds 6
    $sql = "FLUSH PRIVILEGES;`nALTER USER 'root'@'localhost' IDENTIFIED VIA mysql_native_password USING PASSWORD('$newRoot');`n" + $createUser
    $r = RunSql $sql @('--protocol=PIPE', '--socket=GTASOON_RESET', '-u', 'root')
    Stop-Process -Id $proc.Id -Force -ErrorAction SilentlyContinue
    Start-Sleep -Seconds 3
    Start-Service $svc.Name
    Start-Sleep -Seconds 3
    if (-not $r.ok) { Say "Échec de la réinitialisation :`n$($r.out)" 'Red'; Say 'Envoie cette fenêtre à [DEV] (capture).' 'Red'; Read-Host 'Entrée pour quitter'; exit 1 }
    $rootPwd = $newRoot
    Say 'Mot de passe root réinitialisé + utilisateur gtasoon créé.' 'Green'
}

# 4. Test de la connexion avec gtasoon (exactement comme txAdmin)
$env:MYSQL_PWD = $userPwd
$t = RunSql 'SELECT 1;' @('-h', '127.0.0.1', '-P', '3306', '-u', 'gtasoon')
Remove-Item Env:MYSQL_PWD -ErrorAction SilentlyContinue
$status = if ($t.ok) { 'CONNEXION TESTÉE : OK' } else { 'Test de connexion en échec : ' + $t.out }

$text = @"
=== Base de données GTA SOON ($(Get-Date -Format 'dd/MM/yyyy HH:mm')) ===
$status

À taper dans txAdmin (écran Database) :
  Hôte         : 127.0.0.1
  Port         : 3306
  Utilisateur  : gtasoon
  Mot de passe : $userPwd
  Base         : laisser le nom proposé

Mot de passe root MariaDB (à garder précieusement) : $rootPwd
Ne partage jamais ce fichier.
"@
$file = Join-Path ([Environment]::GetFolderPath('Desktop')) 'identifiants-bdd.txt'
Set-Content -LiteralPath $file -Value $text -Encoding UTF8
Write-Host "`n$text" -ForegroundColor $(if ($t.ok) { 'Green' } else { 'Red' })
Write-Host "Enregistré dans : $file" -ForegroundColor Cyan
Read-Host 'Entrée pour fermer'
