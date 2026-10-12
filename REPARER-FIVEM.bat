@echo off
REM ROADLINE : FiveM crashe au lancement "506. Failure connecting to the Rockstar Games Launcher", ou te deconnecte
REM de ton compte Rockstar. Double-clic : remet FiveM et le launcher Rockstar d'aplomb (rien n'est supprime de ton jeu).
net session >nul 2>&1
if errorlevel 1 (
  echo Droits administrateur necessaires : clique "Oui" dans la fenetre Windows.
  powershell -NoProfile -Command "Start-Process -FilePath '%~f0' -Verb RunAs"
  exit /b
)
powershell -NoProfile -ExecutionPolicy Bypass -Command "$t = Get-Content -LiteralPath '%~f0' -Raw; iex ($t.Substring($t.LastIndexOf('#DEBUT' + 'PS#') + 9))"
pause
exit /b
#DEBUTPS#
function Say($m, $c = 'Gray') { Write-Host $m -ForegroundColor $c }
Say 'REPARER-FIVEM : erreur 506 (launcher Rockstar), deconnexions du compte Rockstar' 'Cyan'
Say 'Ton jeu, tes sauvegardes et ton compte ne sont pas touches.' 'Gray'

Say "`n[1/7] Fermeture de FiveM, GTA, Rockstar" 'Cyan'
$names = 'FiveM', 'FiveM_*', 'GTA5', 'GTA5_Enhanced', 'PlayGTAV', 'Launcher', 'LauncherPatcher', 'RockstarService', 'RockstarErrorHandler', 'SocialClubHelper'
$procs = @(Get-Process -ErrorAction SilentlyContinue | Where-Object { $p = $_.ProcessName; @($names | Where-Object { $p -like $_ }).Count -gt 0 -and ($p -ne 'Launcher' -or "$($_.Path)" -match 'Rockstar') })
if ($procs.Count) { $procs | Stop-Process -Force -ErrorAction SilentlyContinue; Start-Sleep -Seconds 3; Say "  $($procs.Count) programme(s) ferme(s)" 'Green' } else { Say '  rien a fermer' 'Green' }
Stop-Service -Name 'Rockstar Service' -Force -ErrorAction SilentlyContinue

Say "`n[2/7] Mode administrateur (cause n.1 de l'erreur 506)" 'Cyan'
# FiveM et le launcher Rockstar doivent tourner avec les MEMES droits : si l'un est coche
# "Executer en tant qu'administrateur", ils ne se parlent plus (launcher : "Could not do OpenProcess").
$fixed = 0
foreach ($hive in 'HKCU:', 'HKLM:') {
    $key = "$hive\Software\Microsoft\Windows NT\CurrentVersion\AppCompatFlags\Layers"
    if (-not (Test-Path $key)) { continue }
    foreach ($exe in @((Get-Item $key).Property)) {
        if ($exe -notmatch '(?i)(FiveM|GTA5|PlayGTAV|Rockstar Games\\Launcher|SocialClub)') { continue }
        $val = (Get-ItemProperty -Path $key -Name $exe).$exe
        if ($val -notmatch 'RUNASADMIN') { continue }
        $new = (($val -split '\s+') | Where-Object { $_ -and $_ -ne 'RUNASADMIN' -and $_ -ne '~' }) -join ' '
        if ($new) { Set-ItemProperty -Path $key -Name $exe -Value ('~ ' + $new) } else { Remove-ItemProperty -Path $key -Name $exe }
        Say "  decoche : $exe" 'Green'; $fixed++
    }
}
if (-not $fixed) { Say '  aucun programme force en administrateur' 'Green' }

Say "`n[3/7] Licence Rockstar en cache (DigitalEntitlements)" 'Cyan'
$ent = Join-Path $env:LOCALAPPDATA 'DigitalEntitlements'
if (Test-Path -LiteralPath $ent) { Remove-Item -LiteralPath $ent -Recurse -Force -ErrorAction SilentlyContinue; Say '  supprimee (recreee toute seule au prochain lancement)' 'Green' } else { Say '  rien a supprimer' 'Green' }

Say "`n[4/7] Cache de FiveM (les fichiers de GTA sont gardes)" 'Cyan'
$data = Join-Path $env:LOCALAPPDATA 'FiveM\FiveM.app\data'
if (Test-Path -LiteralPath $data) {
    foreach ($d in 'server-cache', 'server-cache-priv') { $p = Join-Path $data $d; if (Test-Path -LiteralPath $p) { Remove-Item -LiteralPath $p -Recurse -Force -ErrorAction SilentlyContinue } }
    $cache = Join-Path $data 'cache'
    if (Test-Path -LiteralPath $cache) { Get-ChildItem -LiteralPath $cache -Force | Where-Object { $_.Name -ne 'game' } | Remove-Item -Recurse -Force -ErrorAction SilentlyContinue }
    Say '  vide' 'Green'
} else { Say "  FiveM introuvable ($data)" 'Yellow' }

Say "`n[5/7] Dossier Rockstar dans OneDrive" 'Cyan'
# Documents synchronises par OneDrive : les fichiers du profil Rockstar peuvent etre "en ligne seulement" ou
# verrouilles pendant la synchro, d'ou les deconnexions. On les garde toujours sur le PC (rien n'est deplace ni supprime).
$docs = [Environment]::GetFolderPath('MyDocuments')
$rg = Join-Path $docs 'Rockstar Games'
if ($docs -match '(?i)OneDrive' -and (Test-Path -LiteralPath $rg)) {
    & attrib.exe +P -U "$rg" 2>$null | Out-Null
    & attrib.exe +P -U "$rg\*" /S /D 2>$null | Out-Null
    Say "  $rg : toujours garde sur ce PC" 'Green'
    Say '  Conseil : pendant que tu joues, mets OneDrive en pause (nuage en bas a droite > Suspendre la synchronisation).' 'Yellow'
} else { Say '  pas concerne' 'Green' }

Say "`n[6/7] Heure de Windows (un decalage casse la connexion Rockstar)" 'Cyan'
Set-Service -Name w32time -StartupType Manual -ErrorAction SilentlyContinue
Start-Service -Name w32time -ErrorAction SilentlyContinue
& w32tm.exe /resync /force 2>$null | Out-Null
if ($LASTEXITCODE -eq 0) { Say '  heure synchronisee' 'Green' } else { Say '  synchro impossible : Parametres > Heure et langue > "Synchroniser maintenant"' 'Yellow' }

Say "`n[7/7] Version de GTA utilisee par FiveM" 'Cyan'
$ini = Join-Path $env:LOCALAPPDATA 'FiveM\FiveM.app\CitizenFX.ini'
$rgl = 'C:\Program Files\Rockstar Games\Games\Grand Theft Auto V'
$iv = ''
if (Test-Path -LiteralPath $ini) { $m = Select-String -LiteralPath $ini -Pattern '^IVPath=(.*)$' | Select-Object -First 1; if ($m) { $iv = $m.Matches[0].Groups[1].Value.Trim() } }
if ($iv) { Say "  FiveM lance GTA depuis : $iv" }
if ($iv -match '(?i)steamapps' -and (Test-Path -LiteralPath (Join-Path $rgl 'GTA5.exe'))) {
    Say "  GTA est installe par le launcher Rockstar ($rgl) mais FiveM pointe vers une installation Steam." 'Yellow'
    if ((Read-Host '  Faire pointer FiveM vers la version Rockstar ? (O/N)') -match '^[oOyY]') {
        Copy-Item -LiteralPath $ini -Destination "$ini.avant-reparation" -Force
        (Get-Content -LiteralPath $ini) -replace '^IVPath=.*$', "IVPath=$rgl" | Set-Content -LiteralPath $ini -Encoding ASCII
        Say '  corrige (ancien fichier garde : CitizenFX.ini.avant-reparation)' 'Green'
    }
} elseif (-not $iv) { Say '  chemin non trouve (FiveM le demandera au prochain lancement si besoin)' }
if (Get-Process -Name steam -ErrorAction SilentlyContinue) { Say '  Steam est ouvert : si ton GTA vient du launcher Rockstar, ferme Steam avant de lancer FiveM.' 'Yellow' }

Say "`nTermine. Maintenant, dans cet ordre :" 'Cyan'
Say '  1. Ouvre le Rockstar Games Launcher normalement (PAS en administrateur), connecte-toi, attends qu''il soit pret, puis ferme-le.'
Say '  2. Lance FiveM par un double-clic normal (PAS clic droit > administrateur).'
Say '  Si l''erreur 506 revient : desinstalle puis reinstalle le Rockstar Games Launcher (ton jeu reste installe).' 'Yellow'
