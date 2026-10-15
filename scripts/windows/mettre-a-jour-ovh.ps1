<#
  ROADLINE - ENVOYER LA MISE À JOUR SUR LE VPS OVH (la base du VPS n'est JAMAIS touchée, juste sauvegardée avant).
  Ordre : 1) METTRE-A-JOUR.bat sur le PC (et un test rapide en local)  2) ce fichier.
  Envoie : RoadLine ([gtasoon] complet), les fichiers des autres ressources modifiés depuis le dernier envoi (réglages
  Qbox, nouveaux mods), les cfg, permissions.cfg compris (V12.36 : groupes et ACE Qbox, dont « admin » pour /optin ; jamais secrets.cfg du VPS) ; puis « roadline maj » sur le VPS.
  En cas de souci : « roadline retour » sur le VPS remet la version d'avant.
#>
$ErrorActionPreference = 'Stop'
function Say($m, $c = 'Gray') { Write-Host $m -ForegroundColor $c }
function Fail($m) { Say "ERREUR : $m" 'Red'; Read-Host 'Entrée pour quitter'; exit 1 }
. (Join-Path $PSScriptRoot 'outils-ovh.ps1')

$Data = 'C:\GTASOON\server-data'
$Res = Join-Path $Data 'resources'
$Out = 'C:\GTASOON\ovh'
$Stamp = Join-Path $Out 'dernier-envoi.txt'
$Stage = Join-Path $Out 'maj'
if (-not (Test-Path -LiteralPath (Join-Path $Res '[gtasoon]'))) { Fail "RoadLine introuvable sur le PC ($Res). Lance d'abord METTRE-A-JOUR.bat." }
$ver = [regex]::Match((Get-Content -LiteralPath (Join-Path $Data 'server.cfg') -Raw), 'setr gs_version "([^"]+)"').Groups[1].Value
# Le PC doit avoir la version de CE zip : sinon on enverrait l'ancienne au VPS
$Repo = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$zipVer = [regex]::Match((Get-Content -LiteralPath (Join-Path $Repo 'server\server.cfg.example') -Raw), 'setr gs_version "([^"]+)"').Groups[1].Value
if ($zipVer -and $ver -ne $zipVer) {
    Say "Le serveur du PC est en $ver, mais ce dossier contient la $zipVer." 'Yellow'
    if ((Read-Host "  Mettre d'abord le PC en $zipVer (METTRE-A-JOUR), puis envoyer au VPS ? (O/N)") -notmatch '^[oOyY]') { exit 1 }
    & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot 'mettre-a-jour.ps1')
    $ver = [regex]::Match((Get-Content -LiteralPath (Join-Path $Data 'server.cfg') -Raw), 'setr gs_version "([^"]+)"').Groups[1].Value
    if ($ver -ne $zipVer) { Fail "Le PC est toujours en $ver : la mise à jour du PC n'a pas abouti (voir sa fenêtre)." }
}
Say "Version à envoyer : $ver" 'Cyan'
$vps = Get-Vps
Initialize-SshKey $vps # connexion sans mot de passe (clé), avant tout le reste

# V12.36 · la commande « roadline » du VPS doit être celle de cette version (c'est elle qui installe permissions.cfg) :
# on la pousse comme le fait GERER-OVH, avant la mise à jour.
Say 'Mise à jour de la commande roadline sur le VPS…' 'DarkGray'
$tmpOutils = Join-Path $env:TEMP 'roadline-outils'
[void][IO.Directory]::CreateDirectory($tmpOutils)
$outils = foreach ($f in 'roadline.sh', 'roadline-bdd.sh') { $d = Join-Path $tmpOutils $f; Copy-Unix (Join-Path $Repo "scripts\linux\$f") $d; $d }
Send-Vps $vps $outils '/tmp/'
Invoke-Vps $vps 'sudo install -m 755 /tmp/roadline.sh /tmp/roadline-bdd.sh /home/fivem/outils/ && sudo install -m 755 /home/fivem/outils/roadline.sh /usr/local/bin/roadline && rm -f /tmp/roadline.sh /tmp/roadline-bdd.sh'
if ($LASTEXITCODE -ne 0) { Fail 'Impossible de mettre à jour la commande roadline sur le VPS (voir au-dessus).' }
[IO.Directory]::Delete($tmpOutils, $true)

# V12.62 · Envoi interrompu (coupure pendant l'installation) : l'archive est restée sur le PC, souvent aussi sur le VPS.
# On la reprend au lieu de tout repréparer et de renvoyer 1 Go.
$zip = Join-Path $Out 'roadline-maj.zip'
$reuse = $false; $onVps = $false
if ((Test-Path -LiteralPath $zip) -and (Get-Item -LiteralPath $zip).LastWriteTime -gt (Get-Date).AddHours(-24)) {
    $z = Get-Item -LiteralPath $zip
    Say ('Envoi interrompu trouvé : archive de {0} Mo du {1}.' -f [math]::Round($z.Length / 1MB, 1), $z.LastWriteTime.ToString('dd/MM HH:mm')) 'Yellow'
    # V12.62 : déjà installée (l'outil avait mal lu la réponse du VPS) ? On note l'envoi comme fait, sans rien renvoyer.
    $done = Get-VpsOutput $vps "sudo journalctl -u 'roadline-maj-*' --no-pager -o cat 2>/dev/null | tail -n 200 | grep -a 'jour install' | tail -n 1"
    if ($ver -and $done -match [regex]::Escape(": $ver.")) {
        $started = if (Test-Path -LiteralPath "$zip.debut") { [datetime]::Parse((Get-Content -LiteralPath "$zip.debut" -Raw).Trim(), [Globalization.CultureInfo]::InvariantCulture) } else { $z.LastWriteTime }
        [IO.File]::WriteAllText($Stamp, $started.ToString('o', [Globalization.CultureInfo]::InvariantCulture))
        Remove-Item -LiteralPath $zip, "$zip.debut" -Force -ErrorAction SilentlyContinue
        Say "  Cette archive est déjà installée sur le VPS ($ver) : rien à renvoyer. C'est bon !" 'Green'
        Read-Host 'Entrée pour fermer'; exit 0
    }
    if ((Read-Host '  La reprendre (O) ou tout repréparer (N) ?') -notmatch '^[nN]') {
        $reuse = $true
        $onVps = (Get-VpsOutput $vps "stat -c %s /tmp/roadline-maj.zip 2>/dev/null") -eq "$($z.Length)"
        if ($onVps) { Say '  Elle est déjà entière sur le VPS : pas de nouvel envoi.' 'Green' }
    }
}
if (-not $reuse) {
Say '[1/3] Préparation' 'Cyan'
if (Test-Path -LiteralPath $Stage) { [IO.Directory]::Delete($Stage, $true) }
[void][IO.Directory]::CreateDirectory($Stage)
robocopy (Join-Path $Res '[gtasoon]') (Join-Path $Stage 'gtasoon') /E /NFL /NDL /NJH /NJS /NP /XD node_modules | Out-Null
$since = if (Test-Path -LiteralPath $Stamp) { [datetime]::Parse((Get-Content -LiteralPath $Stamp -Raw).Trim(), [Globalization.CultureInfo]::InvariantCulture) } else { (Get-Date).AddDays(-30) }
# V12.63 : on demande au VPS la liste de ses fichiers (taille) : un gros fichier déjà présent à l'identique n'est plus renvoyé
# (avant : tout ce qui avait été modifié depuis le dernier envoi RÉUSSI repartait, ~1 Go de mods déjà en ligne après un
# envoi terminé en erreur). Les petits fichiers (< 1 Mo : réglages, scripts) modifiés repartent toujours, même taille ou non.
$onServer = @{}
$oldEnc = [Console]::OutputEncoding
try {
    [Console]::OutputEncoding = [Text.Encoding]::UTF8 # noms de fichiers accentués lus correctement
    $list = Get-VpsOutput $vps "cd /home/fivem/server-data 2>/dev/null && find resources -path 'resources/[[]gtasoon[]]' -prune -o -type f -printf '%s\t%p\n' 2>/dev/null"
    foreach ($l in ($list -split "`n")) { $p = $l.TrimEnd("`r").Split("`t", 2); if ($p.Count -eq 2 -and $p[0] -match '^\d+$') { $onServer[$p[1]] = [int64]$p[0] } }
} catch { $onServer = @{} } finally { try { [Console]::OutputEncoding = $oldEnc } catch {} }
$n = 0; $skip = 0; $skipMb = 0
foreach ($f in Get-ChildItem -LiteralPath $Res -Recurse -File -Force | Where-Object { $_.LastWriteTime -gt $since -and $_.FullName -notmatch '\\\[gtasoon\]\\|\\cache\\|\\node_modules\\' }) {
    $rel = $f.FullName.Substring($Data.Length + 1)
    $r = $onServer[$rel.Replace('\', '/')]
    if ($null -ne $r -and $r -eq $f.Length -and $f.Length -ge 1MB) { $skip++; $skipMb += $f.Length / 1MB; continue } # déjà sur le VPS
    $dest = Join-Path (Join-Path $Stage 'extra') $rel
    [void][IO.Directory]::CreateDirectory((Split-Path $dest))
    Copy-Item -LiteralPath $f.FullName -Destination $dest -Force   # -Force : fichiers cachés compris (.fxap des maps payantes)
    $n++
}
[void][IO.Directory]::CreateDirectory((Join-Path $Stage 'cfg'))
Get-ChildItem -LiteralPath (Join-Path $Data 'cfg') -Filter *.cfg -File | Where-Object { $_.Name -ne 'secrets.cfg' } |
    ForEach-Object { Copy-Item -LiteralPath $_.FullName -Destination (Join-Path $Stage 'cfg') }
Copy-Item -LiteralPath (Join-Path $Data 'server.cfg') -Destination (Join-Path $Stage 'server.cfg')
New-UnixZip $Stage $zip
[IO.Directory]::Delete($Stage, $true)
Say ('  RoadLine + {0} fichier(s) modifié(s) ailleurs · {1} Mo' -f $n, [math]::Round((Get-Item $zip).Length / 1MB, 1)) 'Green'
if ($skip) { Say ('  {0} fichier(s) déjà identiques sur le VPS, pas renvoyés ({1} Mo économisés)' -f $skip, [math]::Round($skipMb)) 'Green' }
[IO.File]::WriteAllText("$zip.debut", (Get-Date).ToString('o', [Globalization.CultureInfo]::InvariantCulture)) # date de préparation (reprise)
}

$started = if (Test-Path -LiteralPath "$zip.debut") { [datetime]::Parse((Get-Content -LiteralPath "$zip.debut" -Raw).Trim(), [Globalization.CultureInfo]::InvariantCulture) } else { Get-Date }
if (-not $onVps) {
    Say '[2/3] Envoi' 'Cyan'
    Send-Vps $vps @($zip) '/tmp/roadline-maj.zip'
}
# V12.62 : l'installation tourne EN TÂCHE DE FOND sur le VPS (systemd-run) : une coupure de la connexion ne l'interrompt plus
# (avant : « client_loop: send disconnect » pendant la décompression d'1 Go = installation arrêtée en route). On suit son avancée.
Say '[3/3] Installation sur le VPS (base sauvegardée avant, ~30 s de coupure du serveur)' 'Cyan'
$unit = 'roadline-maj-' + (Get-Date -Format 'yyyyMMddHHmmss')
Invoke-Vps $vps "sudo systemd-run --unit=$unit --collect --quiet /usr/local/bin/roadline maj /tmp/roadline-maj.zip"
if ($LASTEXITCODE -ne 0) { Fail 'Impossible de lancer l''installation sur le VPS (voir au-dessus). Relance l''outil : l''archive sera reprise.' }
$t0 = Get-Date; $blank = 0
while ($true) {
    Start-Sleep -Seconds 10
    $st = Get-VpsOutput $vps "systemctl is-active $unit 2>/dev/null || true"
    if ($st -eq '') { $blank++; if ($blank -ge 30) { break } ; continue } # VPS injoignable un moment : on réessaie (5 min au plus)
    $blank = 0
    if ($st -notmatch '^(active|activating|reloading)$') { break }
    Write-Host ('  … installation en cours ({0} min)' -f [math]::Floor(((Get-Date) - $t0).TotalMinutes)) -ForegroundColor DarkGray
}
$log = Get-VpsOutput $vps "sudo journalctl -u $unit --no-pager -o cat 2>/dev/null | tail -n 25"
if ($log) { $log -split "`n" | ForEach-Object { Say "  $_" 'DarkGray' } }
# Les accents de la réponse du VPS peuvent arriver mal décodés (« install├®e ») : on cherche sans eux
if ($log -notmatch ('jour install\S*\s*:\s*' + [regex]::Escape($ver))) {
    Fail ('L''installation ne s''est pas terminée sur le VPS (voir au-dessus). Rien n''est perdu : la base est sauvegardée. ' +
        'Relance METTRE-A-JOUR-OVH (l''archive est reprise, pas renvoyée) ; si le serveur ne redémarre pas : GERER-OVH → 13 (version précédente).')
}
[IO.File]::WriteAllText($Stamp, $started.ToString('o', [Globalization.CultureInfo]::InvariantCulture))
Remove-Item -LiteralPath "$zip.debut" -Force -ErrorAction SilentlyContinue
Remove-Item -LiteralPath $zip -Force -ErrorAction SilentlyContinue
Say "`nMise à jour $ver en ligne. Vérifie avec GERER-OVH.bat → Console." 'Green'
Read-Host 'Entrée pour fermer'
