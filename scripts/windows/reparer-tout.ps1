<#
  GTA SOON - RÉPARER TOUT (un seul double-clic) :
   1. ferme le serveur et FiveM ;
   2. sort FXServer de OneDrive (copie dans C:\FXServer\server) et réécrit DEMARRER.bat ;
   3. désactive seulement les mods LOURDS (textures > 48 Mo) et les vêtements non testés (MODS-SECURITE, choix 1) :
      les autres mods restent ; libère de la place disque (fichiers temporaires d'import, vieilles sauvegardes) ;
      affiche la RAM et l'espace libre (crash « bad_alloc » = mémoire du PC saturée) ;
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

Say '[3/5] + [4/5] Mods lourds désactivés (les autres restent), caches vidés' 'Cyan'
$env:GTASOON_CHOICE = '1'
& (Join-Path $PSScriptRoot 'mods-securite.ps1')

Say '[+] Place disque et mémoire' 'Cyan'
$tmp = 'C:\GTASOON\mods-tri\_extraction'   # copie temporaire des archives décompressées (recréée à chaque import)
if (Test-Path -LiteralPath $tmp) { Remove-Item -LiteralPath $tmp -Recurse -Force -ErrorAction SilentlyContinue; Say '  fichiers temporaires d''import supprimés' 'Green' }
$bk = @(Get-ChildItem -LiteralPath 'C:\GTASOON\sauvegardes' -Filter 'avant-maj-*.zip' -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending)
if ($bk.Count -gt 3) { $bk | Select-Object -Skip 3 | Remove-Item -Force -ErrorAction SilentlyContinue; Say "  $($bk.Count - 3) vieilles sauvegardes de mise à jour supprimées (3 gardées)" 'Green' }
$c = Get-PSDrive C -ErrorAction SilentlyContinue
$os = Get-CimInstance Win32_OperatingSystem -ErrorAction SilentlyContinue
if ($c) { $free = [math]::Round($c.Free / 1GB, 1); Say "  Disque C: libre : $free Go" $(if ($free -lt 20) { 'Red' } else { 'Green' }); if ($free -lt 20) { Say '  -> MOINS DE 20 Go : c''est probablement la cause des crashs (Windows ne peut plus agrandir sa mémoire). Libère de la place (Corbeille, Téléchargements, jeux inutilisés).' 'Red' } }
if ($os) { $ram = [math]::Round($os.TotalVisibleMemorySize / 1MB, 1); $freeRam = [math]::Round($os.FreePhysicalMemory / 1MB, 1); Say "  RAM : $ram Go (libre : $freeRam Go)" $(if ($ram -lt 16) { 'Yellow' } else { 'Green' }); if ($ram -lt 16) { Say '  -> moins de 16 Go : serveur + jeu sur le même PC, c''est juste. Ferme navigateur, Discord vidéo, Armoury Crate avant de jouer.' 'Yellow' } }

Say '[5/5] Relance du serveur' 'Cyan'
$db = Get-Service -ErrorAction SilentlyContinue | Where-Object { $_.Name -match 'maria|mysql' } | Select-Object -First 1
if ($db -and $db.Status -ne 'Running') { try { Start-Service $db.Name } catch { } }
Start-Process -FilePath (Join-Path $Data 'DEMARRER.bat') -WorkingDirectory $Data
Say "`nTERMINÉ. Attends que la fenêtre « Serveur GTA SOON » soit prête, puis lance FiveM et connecte-toi." 'Green'
Say 'Mods lourds en pause (rien n''est supprimé) : on les remettra allégés.' 'Green'
Read-Host 'Entrée pour fermer'
