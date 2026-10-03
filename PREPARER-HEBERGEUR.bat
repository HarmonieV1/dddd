@echo off
REM RoadLine RP : prepare le serveur pour un hebergeur (panel Pterodactyl, ex. Sentrohost).
REM Double-clic : 1) sauvegarde ta base de donnees  2) copie le serveur (sans cache)  3) regle le port et la base
REM de l'hebergeur  4) envoie ta base chez l'hebergeur (si possible)  5) cree ROADLINE-serveur.zip a envoyer.
REM Rien n'est modifie sur ton PC : tout est prepare dans C:\GTASOON\hebergeur.
powershell -NoProfile -ExecutionPolicy Bypass -Command "$t = Get-Content -LiteralPath '%~f0' -Raw; iex ($t.Substring($t.LastIndexOf('#DEBUT' + 'PS#') + 9))"
pause
exit /b
#DEBUTPS#
function Say($m, $c = 'Gray') { Write-Host $m -ForegroundColor $c }
function Fail($m) { Say "ERREUR : $m" 'Red'; return }
$Root = 'C:\GTASOON'
$Data = Join-Path $Root 'server-data'
$Out = Join-Path $Root 'hebergeur'
$Stage = Join-Path $Out 'serveur'
if (-not (Test-Path -LiteralPath (Join-Path $Data 'server.cfg'))) { Fail "Serveur introuvable ($Data). Lance d'abord INSTALLER.bat / METTRE-A-JOUR.bat."; return }
if (Get-Process -ErrorAction SilentlyContinue | Where-Object { $_.ProcessName -match '^FXServer' }) {
    Say 'Le serveur local tourne : ferme-le d''abord (fenetre « Serveur GTA SOON »), puis relance cet outil.' 'Yellow'; return
}

Say "`nInfos a recopier depuis ton panel (rien n'est envoye ailleurs que chez ton hebergeur) :" 'Cyan'
Say '  - Port : en haut de la page Console (ex. 123.45.67.89:30120 -> 30120) ou onglet Network.'
Say '  - Base de donnees : onglet Databases -> New Database (nom : roadtrip), puis l''oeil pour voir le mot de passe.'
$port = Read-Host "`nPort du serveur (Entree = 30120)"
if (-not $port) { $port = '30120' }
if ($port -notmatch '^\d{2,5}$') { Fail 'Port invalide.'; return }
$dbHost = Read-Host 'Base : Endpoint / Host (sans le :port)'
$dbPort = Read-Host 'Base : Port (Entree = 3306)'
if (-not $dbPort) { $dbPort = '3306' }
$dbName = Read-Host 'Base : Database name (ex. s12_roadtrip)'
$dbUser = Read-Host 'Base : Username (ex. u12_xxxx)'
$dbPass = Read-Host 'Base : Password'
if (-not ($dbHost -and $dbName -and $dbUser -and $dbPass)) { Fail 'Infos de base incompletes.'; return }

# 1. Sauvegarde de la base locale ---------------------------------------------------------------------------------
Say "`n[1/5] Sauvegarde de ta base locale" 'Cyan'
[void][IO.Directory]::CreateDirectory($Out)
$secrets = Get-Content -LiteralPath (Join-Path $Data 'cfg\secrets.cfg') -Raw -Encoding UTF8
$cs = [regex]::Match($secrets, 'mysql_connection_string\s+"mysql:/{2}([^:]+):(.*)@([^:/@]+)(?::(\d+))?/([^?"]+)')
$svc = Get-CimInstance Win32_Service | Where-Object { $_.Name -match 'maria|mysql' -and $_.PathName -match 'mysqld|mariadbd' } | Select-Object -First 1
$bin = if ($svc) { Split-Path ([regex]::Match($svc.PathName, '^"?([^"]+?(mysqld|mariadbd)\.exe)').Groups[1].Value) }
$dump = if ($bin) { @('mariadb-dump.exe', 'mysqldump.exe') | ForEach-Object { Join-Path $bin $_ } | Where-Object { Test-Path $_ } | Select-Object -First 1 }
$client = if ($bin) { @('mariadb.exe', 'mysql.exe') | ForEach-Object { Join-Path $bin $_ } | Where-Object { Test-Path $_ } | Select-Object -First 1 }
$sql = Join-Path $Out 'base.sql'
if ($cs.Success -and $dump) {
    $env:MYSQL_PWD = $cs.Groups[2].Value
    $p = if ($cs.Groups[4].Value) { $cs.Groups[4].Value } else { '3306' }
    & $dump -h $cs.Groups[3].Value -P $p -u $cs.Groups[1].Value --single-transaction --routines --default-character-set=utf8mb4 --result-file="$sql" $cs.Groups[5].Value 2>$null
    Remove-Item Env:MYSQL_PWD -ErrorAction SilentlyContinue
}
if (Test-Path -LiteralPath $sql) { Say ("  base.sql : {0} Mo" -f [math]::Round((Get-Item $sql).Length / 1MB, 1)) 'Green' }
else { Say '  Sauvegarde impossible (MariaDB arrete ?) : le serveur heberge partira d''une base vide.' 'Yellow' }

# 2. Copie du serveur (sans cache ni journaux) --------------------------------------------------------------------
Say '[2/5] Copie du serveur (sans cache, sans journaux)' 'Cyan'
if (Test-Path -LiteralPath $Stage) { Remove-Item -LiteralPath $Stage -Recurse -Force }
robocopy $Data $Stage /E /NFL /NDL /NJH /NJS /NP /XD cache crashes txData logs .git node_modules /XF *.log *.dmp | Out-Null
$size = [math]::Round(((Get-ChildItem -LiteralPath $Stage -Recurse -File -Force | Measure-Object Length -Sum).Sum) / 1MB)
Say "  $size Mo copies" 'Green'

# 3. Réglages pour l'hébergeur (port, base, profil) ----------------------------------------------------------------
Say '[3/5] Reglages hebergeur (port, base de donnees)' 'Cyan'
$cfg = Join-Path $Stage 'server.cfg'
$t = Get-Content -LiteralPath $cfg -Raw -Encoding UTF8
$t = $t -replace 'endpoint_add_tcp\s+"[^"]*"', "endpoint_add_tcp `"0.0.0.0:$port`"" -replace 'endpoint_add_udp\s+"[^"]*"', "endpoint_add_udp `"0.0.0.0:$port`""
[IO.File]::WriteAllText($cfg, $t, (New-Object Text.UTF8Encoding $false))
$sec = Join-Path $Stage 'cfg\secrets.cfg'
$enc = [uri]::EscapeDataString($dbPass)
$conn = ('mysql' + '://{0}:{1}@{2}:{3}/{4}?charset=utf8mb4') -f $dbUser, $enc, $dbHost, $dbPort, $dbName # (rempli avec tes infos)
$s = Get-Content -LiteralPath $sec -Raw -Encoding UTF8
$s = [regex]::Replace($s, 'set\s+mysql_connection_string\s+"[^"]*"', "set mysql_connection_string `"$conn`"")
[IO.File]::WriteAllText($sec, $s, (New-Object Text.UTF8Encoding $false))
Say "  port $port, base $dbName sur $dbHost" 'Green'

# 4. Envoi de la base chez l'hébergeur -----------------------------------------------------------------------------
Say '[4/5] Envoi de ta base chez l''hebergeur' 'Cyan'
$imported = $false
if ((Test-Path -LiteralPath $sql) -and $client) {
    $env:MYSQL_PWD = $dbPass
    $res = cmd /c "`"$client`" -h $dbHost -P $dbPort -u $dbUser --default-character-set=utf8mb4 $dbName < `"$sql`" 2>&1"
    $imported = $LASTEXITCODE -eq 0
    Remove-Item Env:MYSQL_PWD -ErrorAction SilentlyContinue
    if ($imported) { Say '  Base envoyee : persos, argent, inventaires, gangs… tout est la-bas.' 'Green' }
    else { Say ("  Envoi direct refuse : " + (($res | Select-Object -First 2) -join ' ')) 'Yellow'
           Say '  -> importe base.sql a la main (panel : Databases -> phpMyAdmin -> Importer), voir LISEZMOI.' 'Yellow' }
}

# 5. Archive à envoyer ---------------------------------------------------------------------------------------------
Say '[5/5] Creation de ROADLINE-serveur.zip' 'Cyan'
$zip = Join-Path $Out 'ROADLINE-serveur.zip'
if (Test-Path -LiteralPath $zip) { Remove-Item -LiteralPath $zip -Force }
$7z = @('C:\Program Files\7-Zip\7z.exe', 'C:\Program Files (x86)\7-Zip\7z.exe') | Where-Object { Test-Path $_ } | Select-Object -First 1
if ($7z) { & $7z a -tzip -mx=5 $zip "$Stage\*" | Out-Null } else { Compress-Archive -Path "$Stage\*" -DestinationPath $zip -CompressionLevel Optimal }
Say ("  {0} ({1} Mo)" -f $zip, [math]::Round((Get-Item $zip).Length / 1MB)) 'Green'

$readme = @"
RoadLine RP - mise en ligne sur l'hebergeur (panel Pterodactyl)

1. Panel -> Console : arrete le serveur (Stop).
2. Panel -> Files : supprime les dossiers « resources » et le fichier « server.cfg » d'origine s'ils existent
   (garde le dossier alpine / les fichiers du programme FiveM).
3. Upload : si ROADLINE-serveur.zip fait moins de la limite du panel, Files -> Upload ; sinon par SFTP (FileZilla) avec
   les infos de l'onglet Settings (adresse sftp://..., port, utilisateur ; mot de passe = celui du panel).
   Puis clic droit sur le zip -> Unarchive. server.cfg, cfg/ et resources/ doivent etre a la racine.
4. Base de donnees : $(if ($imported) { 'deja envoyee par l''outil.' } else { 'Databases -> phpMyAdmin -> Importer -> base.sql (C:\GTASOON\hebergeur).' })
5. Panel -> Startup : licence FiveM (sv_licenseKey) si demandee ; « Server artifact » = recommended ;
   txAdmin desactive (ou garde-le, mais alors le serveur demarre depuis txAdmin avec ce server.cfg).
6. Console -> Start. Pas de ligne rouge = c'est bon. Connexion : F8 -> connect ADRESSE:$port
"@
[IO.File]::WriteAllText((Join-Path $Out 'LISEZMOI.txt'), $readme, (New-Object Text.UTF8Encoding $true))
Say "`nTermine. Le dossier s'ouvre : envoie ROADLINE-serveur.zip sur le panel (voir LISEZMOI.txt)." 'Green'
Start-Process explorer.exe $Out
