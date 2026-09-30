<#
  GTA SOON - RÉPARER TOUT (un seul double-clic) :
   1. ferme le serveur et FiveM ;
   2. sort FXServer de OneDrive (copie dans C:\FXServer\server) et réécrit DEMARRER.bat ;
   3. désactive les mods lourds + vêtements non testés (MODS-SECURITE, choix 1) ;
   4. vide le cache FiveM et celui du serveur ;
   5. relance le serveur.
#>
$ErrorActionPreference = 'Stop'
function Say($m, $c = 'Gray') { Write-Host $m -ForegroundColor $c }
function Fail($m) { Say "ERREUR : $m" 'Red'; Read-Host 'Entrée pour quitter'; exit 1 }
. (Join-Path $PSScriptRoot 'outils-communs.ps1')
$Data = 'C:\GTASOON\server-data'
if (-not (Test-Path -LiteralPath (Join-Path $Data 'server.cfg'))) { Fail "Pas de serveur dans $Data : lance INSTALLER.bat." }

Say '[1/5] Arrêt du serveur et de FiveM' 'Cyan'
Get-Process -ErrorAction SilentlyContinue | Where-Object { $_.ProcessName -match '^(FXServer|FiveM)' } | Stop-Process -Force -ErrorAction SilentlyContinue
Start-Sleep -Seconds 3

Say '[2/5] Emplacement du serveur (FXServer)' 'Cyan'
$fx = Find-FxServer $Data
$fx = Move-FxServerOutOfOneDrive $fx ${function:Say}
if (-not $fx) { Fail 'FXServer.exe introuvable : extrais server.7z (artefacts FiveM) dans C:\FXServer\server puis relance.' }
Write-Launcher $Data $fx
Say "  FXServer : $fx" 'Green'

Say '[3/5] + [4/5] Mods lourds désactivés, caches vidés' 'Cyan'
$env:GTASOON_CHOICE = '1'
& (Join-Path $PSScriptRoot 'mods-securite.ps1')

Say '[5/5] Relance du serveur' 'Cyan'
$db = Get-Service -ErrorAction SilentlyContinue | Where-Object { $_.Name -match 'maria|mysql' } | Select-Object -First 1
if ($db -and $db.Status -ne 'Running') { try { Start-Service $db.Name } catch { } }
Start-Process -FilePath (Join-Path $Data 'DEMARRER.bat') -WorkingDirectory $Data
Say "`nTERMINÉ. Attends que la fenêtre « Serveur GTA SOON » soit prête, puis lance FiveM et connecte-toi." 'Green'
Say 'Plus de crash ? Plus tard, MODS-SECURITE.bat choix 3 réactive les mods lourds.' 'Green'
Read-Host 'Entrée pour fermer'
