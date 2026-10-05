<#
  ROADLINE - ENVOYER LA MISE À JOUR SUR LE VPS OVH (la base du VPS n'est JAMAIS touchée, juste sauvegardée avant).
  Ordre : 1) METTRE-A-JOUR.bat sur le PC (et un test rapide en local)  2) ce fichier.
  Envoie : RoadLine ([gtasoon] complet), les fichiers des autres ressources modifiés depuis le dernier envoi (réglages
  Qbox, nouveaux mods), les cfg (jamais secrets.cfg ni permissions.cfg du VPS) ; puis « roadline maj » sur le VPS.
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
Say "Version à envoyer (celle du PC) : $ver" 'Cyan'
Say '  (as-tu bien lancé METTRE-A-JOUR.bat avant ? sinon ferme cette fenêtre)' 'DarkGray'
$vps = Get-Vps
Initialize-SshKey $vps # connexion sans mot de passe (clé), avant tout le reste

Say '[1/3] Préparation' 'Cyan'
if (Test-Path -LiteralPath $Stage) { [IO.Directory]::Delete($Stage, $true) }
[void][IO.Directory]::CreateDirectory($Stage)
robocopy (Join-Path $Res '[gtasoon]') (Join-Path $Stage 'gtasoon') /E /NFL /NDL /NJH /NJS /NP /XD node_modules | Out-Null
$since = if (Test-Path -LiteralPath $Stamp) { [datetime]::Parse((Get-Content -LiteralPath $Stamp -Raw).Trim(), [Globalization.CultureInfo]::InvariantCulture) } else { (Get-Date).AddDays(-30) }
$n = 0
foreach ($f in Get-ChildItem -LiteralPath $Res -Recurse -File -Force | Where-Object { $_.LastWriteTime -gt $since -and $_.FullName -notmatch '\\\[gtasoon\]\\|\\cache\\|\\node_modules\\' }) {
    $rel = $f.FullName.Substring($Data.Length + 1)
    $dest = Join-Path (Join-Path $Stage 'extra') $rel
    [void][IO.Directory]::CreateDirectory((Split-Path $dest))
    Copy-Item -LiteralPath $f.FullName -Destination $dest
    $n++
}
[void][IO.Directory]::CreateDirectory((Join-Path $Stage 'cfg'))
Get-ChildItem -LiteralPath (Join-Path $Data 'cfg') -Filter *.cfg -File | Where-Object { $_.Name -notin 'secrets.cfg', 'permissions.cfg' } |
    ForEach-Object { Copy-Item -LiteralPath $_.FullName -Destination (Join-Path $Stage 'cfg') }
Copy-Item -LiteralPath (Join-Path $Data 'server.cfg') -Destination (Join-Path $Stage 'server.cfg')
$zip = Join-Path $Out 'roadline-maj.zip'
New-UnixZip $Stage $zip
[IO.Directory]::Delete($Stage, $true)
Say ('  RoadLine + {0} fichier(s) modifié(s) ailleurs · {1} Mo' -f $n, [math]::Round((Get-Item $zip).Length / 1MB, 1)) 'Green'

Say '[2/3] Envoi' 'Cyan'
$started = Get-Date
Send-Vps $vps @($zip) '/tmp/roadline-maj.zip'
Say '[3/3] Installation sur le VPS (base sauvegardée avant, ~30 s de coupure)' 'Cyan'
Invoke-Vps $vps 'sudo roadline maj /tmp/roadline-maj.zip'
if ($LASTEXITCODE -ne 0) { Fail 'La mise à jour a échoué sur le VPS (voir au-dessus). Rien n''est perdu : « roadline retour » sur le VPS si besoin.' }
[IO.File]::WriteAllText($Stamp, $started.ToString('o', [Globalization.CultureInfo]::InvariantCulture))
Remove-Item -LiteralPath $zip -Force -ErrorAction SilentlyContinue
Say "`nMise à jour $ver en ligne. Vérifie la console dans txAdmin (http://$($vps.ip):40120)." 'Green'
Read-Host 'Entrée pour fermer'
