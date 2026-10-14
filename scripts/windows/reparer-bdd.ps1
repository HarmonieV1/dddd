<#
  RoadLine RP - RÉPARER LA BASE (un seul double-clic sur REPARER-BDD.bat).
  Pour : « [oxmysql] Unable to establish a connection to the database (ECONNRESET / ECONNREFUSED / ETIMEDOUT) »,
  « Error -4077 / -4078 », personnages qui ne chargent pas, serveur bloqué au démarrage.
   1. trouve MariaDB, vérifie l'espace disque et qui occupe le port 3306 ;
   2. redémarre MariaDB et attend qu'elle réponde vraiment ;
   3. si elle refuse de démarrer : lit son journal (.err) et explique la cause (disque plein, port pris, fichiers Aria
      abîmés, InnoDB abîmé…), avec la réparation proposée (rien n'est supprimé : les fichiers abîmés sont renommés) ;
   4. teste la connexion avec les identifiants du serveur (secrets.cfg, jamais affichés) et répare les tables abîmées ;
   5. prévention : MariaDB démarre avec Windows et se relance toute seule si elle plante ;
   6. propose de relancer le serveur FiveM (oxmysql ne se reconnecte pas seul après un échec au démarrage).
  NON TESTÉ sur une vraie machine Windows. Ne supprime aucune base, aucun fichier.
#>
$ErrorActionPreference = 'Stop'

$admin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $admin) {
    Start-Process powershell -Verb RunAs -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`""
    exit
}

function Say($m, $c = 'Gray') { Write-Host $m -ForegroundColor $c }
function Good($m) { Say "  OK   $m" 'Green' }
function Warn($m) { Say "  !!   $m" 'Yellow' }
function Bad($m) { Say "  XX   $m" 'Red' }
function Ask($q) { (Read-Host "$q (O/N)") -match '^[oOyY]' }
function Quit($code) { Say ''; Read-Host 'Entrée pour fermer'; exit $code }

$Data = 'C:\GTASOON\server-data'
$secrets = Join-Path $Data 'cfg\secrets.cfg'
Say '=== RoadLine RP : réparation de la base de données ===' 'Cyan'

# 1. MariaDB : service, dossier, journal ---------------------------------------------------------------------
Say "`n[1/6] MariaDB" 'Cyan'
$svc = Get-CimInstance Win32_Service | Where-Object { $_.Name -match 'maria|mysql' -and $_.PathName -match 'mysqld|mariadbd' } | Select-Object -First 1
if (-not $svc) { Bad 'Service MariaDB introuvable : réinstalle MariaDB (.msi) avec la case « Install as service ».'; Quit 1 }
$exe = [regex]::Match($svc.PathName, '^"?([^"]+?(mysqld|mariadbd)\.exe)"?').Groups[1].Value
$bin = Split-Path $exe
$ini = [regex]::Match($svc.PathName, '--defaults-file="?([^"]+?\.ini)"?').Groups[1].Value
if (-not $ini) { $ini = Join-Path (Split-Path $bin) 'data\my.ini' }
$dataDir = Join-Path (Split-Path $bin) 'data'
if (Test-Path -LiteralPath $ini) {
    $m = [regex]::Match((Get-Content -LiteralPath $ini -Raw), '(?m)^\s*datadir\s*=\s*"?([^"\r\n]+)"?')
    if ($m.Success) { $dataDir = $m.Groups[1].Value.Trim() -replace '/', '\' }
}
$client = @('mariadb.exe', 'mysql.exe') | ForEach-Object { Join-Path $bin $_ } | Where-Object { Test-Path $_ } | Select-Object -First 1
$check = @('mariadb-check.exe', 'mysqlcheck.exe') | ForEach-Object { Join-Path $bin $_ } | Where-Object { Test-Path $_ } | Select-Object -First 1
Good "Service « $($svc.Name) » ($($svc.State)), données : $dataDir"

# 2. Disque et port 3306 ------------------------------------------------------------------------------------------
Say "`n[2/6] Espace disque et port 3306" 'Cyan'
$diskFull = $false
foreach ($letter in @(($dataDir.Substring(0, 1)), 'C') | Select-Object -Unique) {
    $d = Get-PSDrive -Name $letter -ErrorAction SilentlyContinue
    if (-not $d) { continue }
    $free = [math]::Round($d.Free / 1GB, 1)
    if ($free -lt 1) { $diskFull = $true; Bad "Disque $($letter): presque plein ($free Go libres) : MariaDB plante ou coupe les connexions. Lance REPARER-TOUT (libère de la place) ou vide la corbeille / Téléchargements." }
    elseif ($free -lt 5) { Warn "Disque $($letter): $free Go libres (garde au moins 5 Go)." }
    else { Good "Disque $($letter): $free Go libres" }
}
function PortOwner() {
    $c = Get-NetTCPConnection -LocalPort 3306 -State Listen -ErrorAction SilentlyContinue | Select-Object -First 1
    if (-not $c) { return $null }
    Get-Process -Id $c.OwningProcess -ErrorAction SilentlyContinue
}
$owner = PortOwner
if ($owner -and $owner.ProcessName -notmatch '^(mysqld|mariadbd)$') {
    Bad "Le port 3306 est pris par « $($owner.ProcessName) » (un autre serveur MySQL : XAMPP, WAMP, Laragon…). Le serveur FiveM parle à lui au lieu de MariaDB."
    if (Ask "Arrêter « $($owner.ProcessName) » maintenant (il redémarrera avec son logiciel si tu le relances) ?") {
        Stop-Process -Id $owner.Id -Force -ErrorAction SilentlyContinue; Start-Sleep -Seconds 2; Good 'Arrêté.'
    }
} elseif ($owner) { Good "Port 3306 tenu par MariaDB ($($owner.ProcessName))" }
else { Warn 'Rien n''écoute sur le port 3306 (MariaDB arrêtée ou plantée) : on la redémarre.' }

# 3. Redémarrage + attente ----------------------------------------------------------------------------------------
Say "`n[3/6] Redémarrage de MariaDB" 'Cyan'
function StartDb() {
    try { Restart-Service -Name $svc.Name -Force -ErrorAction Stop } catch { try { Start-Service -Name $svc.Name -ErrorAction Stop } catch { } }
    for ($i = 0; $i -lt 45; $i++) {
        Start-Sleep -Seconds 2
        $s = Get-Service -Name $svc.Name
        $o = PortOwner
        if ($s.Status -eq 'Running' -and $o -and $o.ProcessName -match '^(mysqld|mariadbd)$') { return $true }
        if ($s.Status -eq 'Stopped' -and $i -gt 3) { return $false }
    }
    return $false
}
function ErrLog() {
    $f = Get-ChildItem -LiteralPath $dataDir -Filter '*.err' -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending | Select-Object -First 1
    if ($f) { return @(Get-Content -LiteralPath $f.FullName -Tail 40 -ErrorAction SilentlyContinue) }
    return @()
}
$started = StartDb
if (-not $started) {
    Bad 'MariaDB refuse de démarrer. Lecture de son journal…'
    $log = ErrLog
    $text = $log -join "`n"
    $fixed = $false
    if ($diskFull -or $text -match 'No space left|Disk full|errno: 28|OS error code 112') {
        Bad 'Cause : disque plein. Libère de la place (REPARER-TOUT, corbeille), puis relance cet outil.'
    } elseif ($text -match "Bind on TCP/IP port|Address already in use|10048|Do you already have another (mysqld|mariadbd)") {
        Bad 'Cause : le port 3306 est déjà pris par un autre programme (autre MySQL). Ferme-le (XAMPP, WAMP, Laragon…) puis relance cet outil.'
    } elseif ($text -match 'Aria recovery failed|aria_log|Aria engine is not enabled') {
        Bad 'Cause : journaux Aria abîmés (souvent après une coupure de courant ou un arrêt brutal du PC).'
        if (Ask 'Les mettre de côté (renommés en .ancien, rien n''est supprimé) puis redémarrer ?') {
            Get-ChildItem -LiteralPath $dataDir -File | Where-Object { $_.Name -match '^aria_log' } | ForEach-Object {
                Rename-Item -LiteralPath $_.FullName -NewName ($_.Name + '.ancien-' + (Get-Date -Format 'yyyyMMdd_HHmm'))
            }
            $fixed = StartDb
        }
    } elseif ($text -match 'tc\.log|tc_heuristic_recover|Can''t init tc log') {
        Bad 'Cause : fichier tc.log abîmé (arrêt brutal).'
        if (Ask 'Le mettre de côté (renommé, rien n''est supprimé) puis redémarrer ?') {
            $tc = Join-Path $dataDir 'tc.log'
            if (Test-Path -LiteralPath $tc) { Rename-Item -LiteralPath $tc -NewName ('tc.log.ancien-' + (Get-Date -Format 'yyyyMMdd_HHmm')) }
            $fixed = StartDb
        }
    } elseif ($text -match 'InnoDB.*(corrupt|Plugin initialization aborted|Database page corruption|Unable to lock)') {
        Bad 'Cause : fichiers InnoDB abîmés (arrêt brutal, disque). Réparation : RESTAURER-BDD.bat avec la dernière sauvegarde (C:\GTASOON\sauvegardes\bdd).'
        $last = Get-ChildItem -LiteralPath 'C:\GTASOON\sauvegardes\bdd' -Filter '*.sql' -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending | Select-Object -First 1
        if ($last) { Say "       Dernière sauvegarde : $($last.Name) ($($last.LastWriteTime))" 'Yellow' } else { Warn 'Aucune sauvegarde trouvée : envoie le journal ci-dessous à Claude avant de toucher à quoi que ce soit.' }
    } else {
        Bad 'Cause non reconnue automatiquement.'
    }
    if (-not $fixed) {
        Say "`n--- Fin du journal MariaDB (à envoyer à Claude si besoin) ---" 'DarkGray'
        $log | Select-Object -Last 20 | ForEach-Object { Say "  $_" 'DarkGray' }
        Quit 1
    }
}
Good 'MariaDB tourne et écoute sur le port 3306'

# 4. Connexion avec les identifiants du serveur + tables -------------------------------------------------------
Say "`n[4/6] Connexion du serveur à la base" 'Cyan'
$connOk = $false
if (-not (Test-Path -LiteralPath $secrets)) { Warn "Introuvable : $secrets (connexion non testée)." }
elseif (-not $client) { Warn "Client mariadb introuvable dans $bin (connexion non testée)." }
else {
    $content = Get-Content -LiteralPath $secrets -Raw -Encoding UTF8
    $cs = [regex]::Match($content, 'mysql_connection_string\s+"mysql:/{2}([^:]+):(.*)@([^:/@]+)(?::(\d+))?/([^?"]+)')
    if (-not $cs.Success) { Bad 'mysql_connection_string illisible dans secrets.cfg : relance INSTALLER.bat ou REPARER-MARIADB.bat.' }
    else {
        $user, $pass, $dbHost, $port, $db = $cs.Groups[1].Value, $cs.Groups[2].Value, $cs.Groups[3].Value, $cs.Groups[4].Value, $cs.Groups[5].Value
        if (-not $port) { $port = '3306' }
        if ($dbHost -eq 'localhost') {
            Warn 'secrets.cfg utilise « localhost » : sous Windows, ça peut viser IPv6 (::1) et couper la connexion. 127.0.0.1 est plus sûr.'
            if (Ask 'Remplacer localhost par 127.0.0.1 dans secrets.cfg (copie de sécurité gardée à côté) ?') {
                Copy-Item -LiteralPath $secrets -Destination ($secrets + '.avant-reparer-bdd') -Force
                $new = $content -replace '(mysql_connection_string\s+"mysql:/{2}[^@"]*@)localhost', '${1}127.0.0.1'
                [IO.File]::WriteAllText($secrets, $new, (New-Object Text.UTF8Encoding($false)))
                $dbHost = '127.0.0.1'; Good 'secrets.cfg corrigé.'
            }
        }
        $env:MYSQL_PWD = $pass
        $ErrorActionPreference = 'Continue'
        $out = & $client -h $dbHost -P $port -u $user --connect-timeout=10 -N -e "SELECT 1; SELECT @@max_connections;" $db 2>&1
        $code = $LASTEXITCODE
        $ErrorActionPreference = 'Stop'
        $msg = ($out | ForEach-Object { "$_" } | Where-Object { $_ -notmatch 'ssl|Warning' }) -join ' '
        if ($code -eq 0) {
            $connOk = $true
            Good "Connexion réussie (utilisateur $user, base $db)"
            $max = 0; [void][int]::TryParse((@($out)[-1] -as [string]), [ref]$max)
            if ($max -gt 0 -and $max -lt 100) { Warn "max_connections = $max (bas) : ajoute « max_connections=200 » sous [mysqld] dans $ini." }
            if ($check) {
                $ErrorActionPreference = 'Continue'
                $rep = & $check -h $dbHost -P $port -u $user --auto-repair --silent $db 2>&1 | ForEach-Object { "$_" } | Where-Object { $_ -notmatch 'ssl|Warning' }
                $ErrorActionPreference = 'Stop'
                if ($rep) { Warn 'Tables vérifiées, remarques :'; $rep | Select-Object -First 10 | ForEach-Object { Say "       $_" 'Yellow' } } else { Good 'Tables vérifiées : aucune abîmée' }
            }
        } elseif ($msg -match 'Access denied|1045|authentication') {
            Bad 'Identifiants refusés : lance REPARER-MARIADB.bat (recrée l''utilisateur du serveur), puis relance cet outil.'
        } elseif ($msg -match 'Unknown database|1049') {
            Bad "La base « $db » n'existe pas : relance INSTALLER.bat, ou RESTAURER-BDD.bat avec une sauvegarde."
        } else {
            Bad "Connexion impossible : $msg"
        }
        Remove-Item Env:MYSQL_PWD -ErrorAction SilentlyContinue
    }
}

# 5. Prévention : démarrage automatique + relance si plantage --------------------------------------------------
Say "`n[5/6] Prévention" 'Cyan'
$ErrorActionPreference = 'Continue'
& sc.exe config $svc.Name start= auto | Out-Null
& sc.exe failure $svc.Name reset= 86400 actions= restart/5000/restart/10000/restart/30000 | Out-Null
$ErrorActionPreference = 'Stop'
Good 'MariaDB démarre avec Windows et se relance toute seule si elle plante (5 s, 10 s, 30 s)'

# 6. Serveur FiveM -------------------------------------------------------------------------------------------------
Say "`n[6/6] Serveur FiveM" 'Cyan'
$fx = Get-Process -ErrorAction SilentlyContinue | Where-Object { $_.ProcessName -match '^FXServer' }
$start = Join-Path $Data 'DEMARRER.bat'
if (-not $connOk) { Warn 'Connexion non validée : règle d''abord le point rouge ci-dessus, puis relance cet outil.'; Quit 1 }
if ($fx) {
    Say '  Le serveur tourne, mais oxmysql ne se reconnecte pas tout seul après un échec au démarrage.' 'Gray'
    if (Ask 'Redémarrer le serveur FiveM maintenant (les joueurs connectés seront déconnectés) ?') {
        $fx | Stop-Process -Force -ErrorAction SilentlyContinue; Start-Sleep -Seconds 3
        if (Test-Path -LiteralPath $start) { Start-Process -FilePath $start -WorkingDirectory $Data; Good 'Serveur relancé.' }
        else { Warn "DEMARRER.bat introuvable dans $Data : relance le serveur depuis txAdmin." }
    } else { Say '  Pense à faire « Restart » dans txAdmin.' 'Yellow' }
} elseif (Test-Path -LiteralPath $start) {
    if (Ask 'Le serveur FiveM est arrêté. Le démarrer maintenant ?') { Start-Process -FilePath $start -WorkingDirectory $Data; Good 'Serveur démarré.' }
}
Say "`nTerminé. Dans la console du serveur, tu dois voir « [oxmysql] Database server connection established »." 'Green'
Quit 0
