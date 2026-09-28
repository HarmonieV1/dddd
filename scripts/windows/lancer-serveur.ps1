<#
  GTA SOON - Lanceur + diagnostic du serveur (FXServer / txAdmin).
  Double-cliquer sur lancer-serveur.bat, choisir le dossier où tu as extrait le serveur (celui avec FXServer.exe).
  Vérifie : MariaDB, fichiers du serveur, extraction, ports, runtime Visual C++, puis lance FXServer et ouvre txAdmin.
  Écrit un rapport sur le Bureau : rapport-serveur.txt → à envoyer à [DEV] si ça bloque.
  NON TESTÉ sur une vraie machine Windows. Ne supprime rien.
#>
$ErrorActionPreference = 'Continue'
$report = New-Object System.Collections.Generic.List[string]
function Say($msg, $color = 'Gray') { Write-Host $msg -ForegroundColor $color; $report.Add($msg) }
$problems = 0
function Bad($msg) { $script:problems++; Say "  [X] $msg" 'Red' }
function Good($msg) { Say "  [OK] $msg" 'Green' }

Say "=== Lanceur serveur GTA SOON - $(Get-Date -Format 'dd/MM/yyyy HH:mm') ===" 'Cyan'

# 1. MariaDB ------------------------------------------------------------------------------------------
Say "`n[1] MariaDB" 'Cyan'
$db = Get-Service -ErrorAction SilentlyContinue | Where-Object { $_.Name -match 'maria|mysql' -or $_.DisplayName -match 'maria|mysql' }
if (-not $db) { Bad "Aucun service MariaDB/MySQL : lance l'installeur .msi (case 'Install as service' cochée)." }
else {
    foreach ($s in $db) {
        if ($s.Status -eq 'Running') { Good "$($s.DisplayName) démarré" }
        else {
            Say "  Service $($s.DisplayName) arrêté : démarrage..." 'Yellow'
            try { Start-Service $s.Name -ErrorAction Stop; Good "$($s.DisplayName) démarré" } catch { Bad "Impossible de démarrer $($s.DisplayName) (relance ce script en administrateur)." }
        }
    }
}
if (Get-NetTCPConnection -LocalPort 3306 -State Listen -ErrorAction SilentlyContinue) { Good 'Port 3306 (base de données) ouvert en local' }
else { Bad 'Rien n''écoute sur le port 3306 : MariaDB ne tourne pas.' }

# 2. Dossier du serveur ----------------------------------------------------------------------------------
Say "`n[2] Fichiers du serveur" 'Cyan'
Add-Type -AssemblyName System.Windows.Forms
$dlg = New-Object System.Windows.Forms.FolderBrowserDialog
$dlg.Description = 'Choisis le dossier qui contient FXServer.exe (là où tu as extrait server.7z)'
if ($dlg.ShowDialog() -ne 'OK') { Say 'Annulé.' 'Yellow'; exit 1 }
$dir = $dlg.SelectedPath
$exe = Join-Path $dir 'FXServer.exe'
if (-not (Test-Path -LiteralPath $exe)) {
    $found = Get-ChildItem -LiteralPath $dir -Recurse -Depth 3 -Filter FXServer.exe -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($found) { $exe = $found.FullName; $dir = $found.DirectoryName; Say "  FXServer.exe trouvé dans un sous-dossier : $dir" 'Yellow' }
}
if (-not (Test-Path -LiteralPath $exe)) { Bad "Pas de FXServer.exe dans $dir. Extrais server.7z (clic droit > Extraire tout) puis relance." }
else {
    Good "FXServer.exe : $exe"
    if (-not (Test-Path -LiteralPath (Join-Path $dir 'citizen'))) { Bad "Dossier 'citizen' absent à côté de FXServer.exe : extraction incomplète, réextrais TOUT server.7z." }
    else { Good 'Extraction complète (dossier citizen présent)' }
    if ($dir -match 'Program Files|OneDrive|Temp|\\AppData\\') { Bad "Dossier déconseillé ($dir) : déplace le serveur dans C:\FXServer\server (droits / synchronisation)." }
    $zone = Get-Item -LiteralPath $exe -Stream Zone.Identifier -ErrorAction SilentlyContinue
    if ($zone) {
        Say '  Fichiers marqués « téléchargés d''Internet » : déblocage...' 'Yellow'
        Get-ChildItem -LiteralPath $dir -Recurse -File -ErrorAction SilentlyContinue | Unblock-File -ErrorAction SilentlyContinue
        Good 'Fichiers débloqués'
    }
}

# 3. Runtime Visual C++ (requis par FXServer) ---------------------------------------------------------------
Say "`n[3] Microsoft Visual C++ 2015-2022 (x64)" 'Cyan'
$vc = Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\VisualStudio\14.0\VC\Runtimes\x64' -ErrorAction SilentlyContinue
if ($vc -and $vc.Installed -eq 1) { Good "installé ($($vc.Version))" }
else { Bad 'Absent : installe « Microsoft Visual C++ Redistributable x64 » depuis learn.microsoft.com (vc_redist.x64.exe).' }

# 4. Ports ---------------------------------------------------------------------------------------------------
Say "`n[4] Ports" 'Cyan'
foreach ($port in 40120, 30120) {
    $busy = Get-NetTCPConnection -LocalPort $port -State Listen -ErrorAction SilentlyContinue
    if ($busy) {
        $proc = (Get-Process -Id $busy[0].OwningProcess -ErrorAction SilentlyContinue).ProcessName
        if ($proc -match 'FXServer') { Say "  Port $port déjà utilisé par FXServer : le serveur tourne déjà." 'Yellow' }
        else { Bad "Port $port pris par '$proc' : ferme ce programme." }
    } else { Good "Port $port libre" }
}

# 5. Lancement ------------------------------------------------------------------------------------------------
Say "`n[5] Lancement" 'Cyan'
$running = Get-Process -Name FXServer -ErrorAction SilentlyContinue
if ((Test-Path -LiteralPath $exe) -and -not $running) {
    Start-Process -FilePath $exe -WorkingDirectory $dir
    Say '  FXServer lancé (fenêtre noire). Garde-la ouverte : le code PIN txAdmin s''y affiche.' 'Green'
    Start-Sleep -Seconds 12
}
$up = Get-NetTCPConnection -LocalPort 40120 -State Listen -ErrorAction SilentlyContinue
if ($up) {
    Good 'txAdmin répond : ouverture du navigateur sur http://localhost:40120'
    Start-Process 'http://localhost:40120'
} else {
    Bad 'txAdmin ne répond pas encore. Regarde la fenêtre noire : si une erreur rouge apparaît, copie-la dans le rapport pour [DEV].'
}

$file = Join-Path ([Environment]::GetFolderPath('Desktop')) 'rapport-serveur.txt'
$report | Set-Content -LiteralPath $file -Encoding UTF8
Write-Host "`n$problems problème(s). Rapport : $file (envoie-le à [DEV] si besoin)." -ForegroundColor Cyan
