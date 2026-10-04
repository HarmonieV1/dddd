<#
  ROADLINE - CAPTURER LES ERREURS DU DÉMARRAGE.
  Lance le serveur 2 minutes en enregistrant toute la console dans un fichier, l'arrête, puis ouvre seulement les
  lignes d'erreur (C:\GTASOON\logs\erreurs.txt). Il suffit d'envoyer ce fichier (ou de copier son contenu).
#>
$ErrorActionPreference = 'Stop'
function Say($m, $c = 'Gray') { Write-Host $m -ForegroundColor $c }
function Fail($m) { Say "ERREUR : $m" 'Red'; Read-Host 'Entrée pour quitter'; exit 1 }

$Data = 'C:\GTASOON\server-data'
$launcher = Join-Path $Data 'DEMARRER.bat'
if (-not (Test-Path -LiteralPath $launcher)) { Fail "Introuvable : $launcher (lance d'abord INSTALLER.bat ou METTRE-A-JOUR.bat)." }
$fx = ([regex]::Match((Get-Content -LiteralPath $launcher -Raw), '"([^"]*FXServer\.exe)"\s+\+set')).Groups[1].Value
if (-not $fx -or -not (Test-Path -LiteralPath $fx)) { Fail 'FXServer.exe introuvable : lance REPARER-LANCEUR.bat.' }
if (Get-Process -Name FXServer -ErrorAction SilentlyContinue) {
    if ((Read-Host 'Le serveur tourne déjà. L''arrêter pour faire la capture ? (O/N)') -notmatch '^[oOyY]') { exit 0 }
    Get-Process -Name FXServer | Stop-Process -Force
    Start-Sleep -Seconds 3
}

$logs = 'C:\GTASOON\logs'
[void][IO.Directory]::CreateDirectory($logs)
$full = Join-Path $logs 'console-complete.txt'
$errs = Join-Path $logs 'erreurs.txt'
Say 'Démarrage du serveur pendant 2 minutes (ne ferme pas cette fenêtre)…' 'Cyan'
$p = Start-Process -FilePath $fx -ArgumentList '+set onesync on +exec server.cfg' -WorkingDirectory $Data -NoNewWindow -PassThru `
    -RedirectStandardOutput $full -RedirectStandardError (Join-Path $logs 'console-erreurs-brutes.txt')
$null = $p.Handle # garde le code de sortie lisible
for ($i = 120; $i -gt 0; $i -= 10) { Say "  … encore $i s" 'DarkGray'; Start-Sleep -Seconds 10; if ($p.HasExited) { break } }
if (-not $p.HasExited) { Stop-Process -Id $p.Id -Force }
Start-Sleep -Seconds 2

$all = @()
foreach ($f in @($full, (Join-Path $logs 'console-erreurs-brutes.txt'))) { if (Test-Path -LiteralPath $f) { $all += Get-Content -LiteralPath $f -Encoding UTF8 } }
# Lignes d'erreur + 3 lignes de contexte après (pile d'appels)
$out = New-Object System.Collections.Generic.List[string]
for ($i = 0; $i -lt $all.Count; $i++) {
    $l = ($all[$i] -replace '\x1b\[[0-9;]*m', '')
    if ($l -match '(?i)(script error|error|erreur|failed|couldn''t|could not|warning: resource|attempt to|stack traceback|not found|is not defined)') {
        $out.Add($l)
        for ($k = 1; $k -le 3 -and ($i + $k) -lt $all.Count; $k++) { $out.Add('    ' + ($all[$i + $k] -replace '\x1b\[[0-9;]*m', '')) }
        $out.Add('')
    }
}
# Toujours : comment le serveur s'est terminé, les 80 dernières lignes de la console et les rapports de plantage récents
$head = New-Object System.Collections.Generic.List[string]
if ($p.HasExited -and $p.ExitCode -ne $null -and $p.ExitCode -ne 0 -and $p.ExitCode -ne -1) { $head.Add(('LE SERVEUR S''EST FERMÉ TOUT SEUL (code {0}).' -f $p.ExitCode)) }
elseif ($all.Count -lt 5) { $head.Add('La console est presque vide : le serveur s''est arrêté avant d''écrire quoi que ce soit.') }
$head.Add("Lignes de console : $($all.Count)")
$fxDir = Split-Path -Parent $fx
foreach ($d in @((Join-Path $fxDir 'crashes'), (Join-Path $Data 'crashes'))) {
    if (Test-Path -LiteralPath $d) {
        Get-ChildItem -LiteralPath $d -File | Where-Object { $_.LastWriteTime -gt (Get-Date).AddMinutes(-5) } |
            ForEach-Object { $head.Add('Rapport de plantage : ' + $_.FullName) }
    }
}
$head.Add('')
if ($out.Count -eq 0) { $head.Add('Aucune ligne « erreur » trouvée.') }
$out.InsertRange(0, $head)
$out.Add('===== 80 DERNIÈRES LIGNES DE LA CONSOLE =====')
foreach ($l in ($all | Select-Object -Last 80)) { $out.Add(($l -replace '\x1b\[[0-9;]*m', '')) }
[IO.File]::WriteAllLines($errs, $out, (New-Object Text.UTF8Encoding $false))
Say "Fait. Erreurs : $errs" 'Green'
Say "Console complète : $full" 'Green'
Start-Process notepad.exe $errs
Read-Host 'Entrée pour fermer'
