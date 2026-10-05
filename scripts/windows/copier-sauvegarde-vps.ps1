<#
  ROADLINE - COPIE QUOTIDIENNE DE LA SAUVEGARDE DU VPS SUR CE PC (tâche planifiée, sans fenêtre ni question).
  Installée par GERER-OVH.bat → « Copie automatique chaque jour ». Garde les 14 dernières dans C:\GTASOON\ovh\sauvegardes-vps.
  Connexion par la clé de PREPARER-OVH (aucun mot de passe). Journal : C:\GTASOON\ovh\sauvegardes-vps\copie.log
#>
$ErrorActionPreference = 'Continue'
$dir = 'C:\GTASOON\ovh\sauvegardes-vps'
$log = Join-Path $dir 'copie.log'
[void][IO.Directory]::CreateDirectory($dir)
function Log($m) { Add-Content -LiteralPath $log -Value ('{0:yyyy-MM-dd HH:mm} {1}' -f (Get-Date), $m) }
$vpsTxt = 'C:\GTASOON\ovh\vps.txt'
$key = Join-Path $env:USERPROFILE '.ssh\roadline_ovh'
if (-not (Test-Path -LiteralPath $vpsTxt) -or -not (Test-Path -LiteralPath $key)) { Log 'VPS ou clé introuvable (lance PREPARER-OVH une fois).'; exit 1 }
$target = (Get-Content -LiteralPath $vpsTxt -Raw).Trim()
$name = (& ssh -i $key -o BatchMode=yes -o ConnectTimeout=20 $target 'sudo roadline copie-sauvegarde' 2>$null | Out-String).Trim()
if ($name -notmatch '^[\w.-]+\.sql\.gz$') { Log "Pas de sauvegarde à copier ($name)."; exit 1 }
$dest = Join-Path $dir $name
if (Test-Path -LiteralPath $dest) { Log "$name déjà copiée." }
else {
    & scp -i $key -o BatchMode=yes "${target}:/tmp/roadline-sauvegarde.sql.gz" $dest 2>$null
    if (Test-Path -LiteralPath $dest) { Log ("$name copiée ({0} Ko)." -f [math]::Round((Get-Item $dest).Length / 1KB)) } else { Log "Échec de la copie de $name." }
}
& ssh -i $key -o BatchMode=yes $target 'rm -f /tmp/roadline-sauvegarde.sql.gz' 2>$null | Out-Null
Get-ChildItem -LiteralPath $dir -Filter *.sql.gz | Sort-Object LastWriteTime -Descending | Select-Object -Skip 14 | Remove-Item -Force
