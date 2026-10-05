<#
  ROADLINE - GÉRER LE SERVEUR OVH DEPUIS LE PC (menu, aucun mot de passe : connexion par la clé de PREPARER-OVH).
  État, console, redémarrage, public/privé, sauvegardes, mode simple/txAdmin, retour à la version d'avant.
  Au lancement, la commande « roadline » du VPS est remise à jour (rien d'autre n'est modifié).
#>
$ErrorActionPreference = 'Stop'
function Say($m, $c = 'Gray') { Write-Host $m -ForegroundColor $c }
. (Join-Path $PSScriptRoot 'outils-ovh.ps1')
$Repo = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path

try {
    $vps = Get-Vps
    Initialize-SshKey $vps
    Say "`nMise à jour de la commande roadline sur le VPS (et fin d'installation si besoin)…" 'DarkGray'
    $tmp = Join-Path $env:TEMP 'roadline-outils'
    [void][IO.Directory]::CreateDirectory($tmp)
    $files = foreach ($f in 'roadline.sh', 'roadline-bdd.sh') { $d = Join-Path $tmp $f; Copy-Unix (Join-Path $Repo "scripts\linux\$f") $d; $d }
    Send-Vps $vps $files '/tmp/'
    Invoke-Vps $vps 'sudo install -m 755 /tmp/roadline.sh /tmp/roadline-bdd.sh /home/fivem/outils/ && sudo install -m 755 /home/fivem/outils/roadline.sh /usr/local/bin/roadline && rm -f /tmp/roadline.sh /tmp/roadline-bdd.sh && { [ -f /etc/systemd/system/roadline.service ] && sudo crontab -l 2>/dev/null | grep -q roadline-bdd || sudo roadline terminer; }'
    [IO.Directory]::Delete($tmp, $true)
} catch { Say "ERREUR : $($_.Exception.Message)" 'Red'; Read-Host 'Entrée pour quitter'; exit 1 }

$menu = [ordered]@{
    '1'  = @('État + diagnostic (pourquoi le serveur ne répond pas)', 'sudo roadline etat; echo; sudo roadline diagnostic')
    '2'  = @('Console (dernières lignes)', 'sudo roadline logs 60')
    '3'  = @('Redémarrer', 'sudo roadline redemarrer')
    '4'  = @('Ouvrir au PUBLIC (liste FiveM, 48 places)', 'sudo roadline public')
    '5'  = @('Repasser en PRIVÉ (tests, maintenance)', 'sudo roadline prive')
    '6'  = @('Sauvegarder la base maintenant', 'sudo roadline sauvegarde')
    '7'  = @('Liste des sauvegardes', 'sudo roadline sauvegardes')
    '8'  = @('Mode SIMPLE : le serveur démarre tout seul (recommandé)', 'sudo roadline mode simple')
    '9'  = @('Mode txAdmin : panneau web sur le port 40120 (avec code PIN)', 'sudo roadline mode txadmin')
    '10' = @('Revenir à la version précédente de RoadLine', 'sudo roadline retour')
    '11' = @('Ouvrir une console sur le VPS (taper « exit » pour revenir)', '')
}
while ($true) {
    Say "`n=========== ROADLINE · VPS $($vps.ip) ===========" 'Cyan'
    foreach ($k in $menu.Keys) { Say ('  {0,2}. {1}' -f $k, $menu[$k][0]) 'White' }
    Say '   0. Quitter' 'White'
    Say "  En jeu : F8 → connect $($vps.ip):30120" 'DarkGray'
    $c = (Read-Host 'Choix').Trim()
    if ($c -eq '0' -or $c -eq '') { break }
    if (-not $menu.Contains($c)) { Say 'Choix inconnu.' 'Yellow'; continue }
    if ($c -eq '10' -and (Read-Host 'Remettre la version précédente ? (O/N)') -notmatch '^[oOyY]') { continue }
    Say "`n→ $($menu[$c][0])" 'Cyan'
    if ($c -eq '11') { $a = SshArgs; & ssh @a "$($vps.user)@$($vps.ip)" }
    else { Invoke-Vps $vps $menu[$c][1] }
}
