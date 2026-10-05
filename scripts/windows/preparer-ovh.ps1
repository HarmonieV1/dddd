<#
  ROADLINE - MISE EN LIGNE SUR LE VPS OVH (première fois, ou pour renvoyer toute la base).
  1) sauvegarde la base du PC  2) prépare le serveur (sans cache)  3) l'envoie sur le VPS (SSH, inclus dans Windows)
  4) lance l'installation automatique sur le VPS (MariaDB, FiveM, pare-feu, sauvegardes, commande roadline).
  Rien n'est modifié sur le PC. Mots de passe : jamais affichés ; celui de la base du VPS est créé là-bas.
#>
$ErrorActionPreference = 'Stop'
function Say($m, $c = 'Gray') { Write-Host $m -ForegroundColor $c }
function Fail($m) { Say "ERREUR : $m" 'Red'; Read-Host 'Entrée pour quitter'; exit 1 }
. (Join-Path $PSScriptRoot 'outils-ovh.ps1')

$Root = 'C:\GTASOON'
$Data = Join-Path $Root 'server-data'
$Repo = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$Out = Join-Path $Root 'ovh'
$Stage = Join-Path $Out 'envoi'
if (-not (Test-Path -LiteralPath (Join-Path $Data 'server.cfg'))) { Fail "Serveur introuvable ($Data). Lance d'abord INSTALLER.bat / METTRE-A-JOUR.bat." }
if (Get-Process -Name FXServer -ErrorAction SilentlyContinue) { Fail 'Le serveur du PC tourne : ferme-le d''abord (la base doit être figée pour la copie).' }
$vps = Get-Vps
Initialize-SshKey $vps # connexion sans mot de passe (clé), avant tout le reste
Say "`nVPS : $($vps.user)@$($vps.ip)" 'Cyan'

Say '[1/4] Sauvegarde de la base du PC' 'Cyan'
if (Test-Path -LiteralPath $Stage) { [IO.Directory]::Delete($Stage, $true) }
[void][IO.Directory]::CreateDirectory($Stage)
$sql = Join-Path $Stage 'base.sql'
if (Export-LocalDb $Data $sql) { Say ('  base.sql : {0} Mo' -f [math]::Round((Get-Item $sql).Length / 1MB, 1)) 'Green' }
else {
    Say '  Base non sauvegardée (MariaDB arrêté ?).' 'Yellow'
    if ((Read-Host '  Continuer SANS envoyer la base (le VPS garde la sienne) ? (O/N)') -notmatch '^[oOyY]') { exit 1 }
}

Say '[2/4] Préparation du serveur (sans cache ni journaux)' 'Cyan'
$copiedAt = Get-Date
$sd = Join-Path $Stage 'server-data'
robocopy $Data $sd /E /NFL /NDL /NJH /NJS /NP /XD "$Data\cache" "$Data\crashes" "$Data\txData" "$Data\logs" .git node_modules /XF *.log *.dmp DEMARRER.bat | Out-Null
foreach ($f in 'installer-ovh.sh', 'roadline.sh', 'roadline-bdd.sh') { Copy-Unix (Join-Path $Repo "scripts\linux\$f") (Join-Path $Stage $f) }
$zip = Join-Path $Out 'roadline-ovh.zip'
New-UnixZip $Stage $zip
Say ('  {0} ({1} Mo)' -f $zip, [math]::Round((Get-Item $zip).Length / 1MB)) 'Green'

Say '[3/4] Envoi sur le VPS (mot de passe du VPS demandé si pas de clé SSH)' 'Cyan'
Send-Vps $vps @($zip, (Join-Path $Stage 'installer-ovh.sh')) '/tmp/'
[IO.Directory]::Delete($Stage, $true) # ne garde pas de copie de la base / des secrets en clair sur le PC
Say '  envoyé' 'Green'

Say '[4/4] Installation sur le VPS (5 à 10 min la première fois)' 'Cyan'
Invoke-Vps $vps 'sudo bash /tmp/installer-ovh.sh /tmp/roadline-ovh.zip && rm -f /tmp/roadline-ovh.zip /tmp/installer-ovh.sh'
if ($LASTEXITCODE -ne 0) { Fail 'L''installation sur le VPS a signalé une erreur (voir au-dessus). Rien n''est perdu : relance cet outil.' }
Remove-Item -LiteralPath $zip -Force -ErrorAction SilentlyContinue
[IO.File]::WriteAllText((Join-Path $Out 'dernier-envoi.txt'), $copiedAt.ToString('o', [Globalization.CultureInfo]::InvariantCulture))
Say "`nTerminé : le serveur démarre tout seul sur le VPS (rien à configurer)." 'Green'
Say "  En jeu : F8 → connect $($vps.ip):30120" 'Green'
Say '  Pour piloter le serveur : GERER-OVH.bat · Pour les mises à jour : METTRE-A-JOUR-OVH.bat' 'Green'
Read-Host 'Entrée pour fermer'
