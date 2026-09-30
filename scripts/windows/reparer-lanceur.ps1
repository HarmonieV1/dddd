<#
  GTA SOON - RÉPARER LE LANCEUR : « Le chemin d'accès spécifié est introuvable » dans la fenêtre du serveur.
  Retrouve FXServer.exe (ou te le fait choisir), réécrit C:\GTASOON\server-data\DEMARRER.bat, vérifie l'essentiel
  (server.cfg, secrets.cfg, MariaDB) puis relance le serveur.
#>
$ErrorActionPreference = 'Stop'
function Say($m, $c = 'Gray') { Write-Host $m -ForegroundColor $c }
function Fail($m) { Say "ERREUR : $m" 'Red'; Read-Host 'Entrée pour quitter'; exit 1 }
$common = Join-Path $PSScriptRoot 'outils-communs.ps1'
if (-not (Test-Path -LiteralPath $common)) { Fail "outils-communs.ps1 manquant : réextrais le zip GTA SOON complet." }
. $common

$Data = 'C:\GTASOON\server-data'
if (-not (Test-Path -LiteralPath (Join-Path $Data 'server.cfg'))) { Fail "Pas de serveur dans $Data : lance INSTALLER.bat." }
if (-not (Test-Path -LiteralPath (Join-Path $Data 'cfg\secrets.cfg'))) { Fail "cfg\secrets.cfg manquant dans $Data : relance INSTALLER.bat (la base n'est pas touchée)." }

Say '[1/3] Recherche de FXServer.exe' 'Cyan'
$fx = Find-FxServer $Data
$fx = Move-FxServerOutOfOneDrive $fx ${function:Say}
if (-not $fx) { Fail 'FXServer.exe introuvable : télécharge les artefacts serveur FiveM (server.7z), extrais-les dans C:\FXServer\server, puis relance.' }
Say "  FXServer : $fx" 'Green'
if (-not (Test-Path -LiteralPath (Join-Path (Split-Path $fx) 'citizen'))) { Say '  Attention : dossier citizen absent à côté de FXServer.exe (extraction incomplète ?)' 'Yellow' }

Say '[2/3] Réécriture de DEMARRER.bat + vérifications' 'Cyan'
Write-Launcher $Data $fx
Say "  $Data\DEMARRER.bat réécrit" 'Green'
$db = Get-Service -ErrorAction SilentlyContinue | Where-Object { $_.Name -match 'maria|mysql' } | Select-Object -First 1
if (-not $db) { Say '  MariaDB : service introuvable (si le serveur affiche une erreur oxmysql : REPARER-MARIADB.bat)' 'Yellow' }
elseif ($db.Status -ne 'Running') { try { Start-Service $db.Name; Say "  MariaDB démarré ($($db.Name))" 'Green' } catch { Say "  MariaDB arrêté : lance REPARER-MARIADB.bat" 'Yellow' } }
else { Say "  MariaDB : OK ($($db.Name))" 'Green' }

Say '[3/3] Lancement du serveur' 'Cyan'
Get-Process -Name FXServer -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
Start-Process -FilePath (Join-Path $Data 'DEMARRER.bat') -WorkingDirectory $Data
Say "`nC'est reparti : regarde la fenêtre « Serveur GTA SOON ». Si une ligne ROUGE apparaît, fais-moi une capture." 'Green'
Read-Host 'Entrée pour fermer'
