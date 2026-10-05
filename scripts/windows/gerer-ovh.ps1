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
    Invoke-Vps $vps 'sudo install -m 755 /tmp/roadline.sh /tmp/roadline-bdd.sh /home/fivem/outils/ && sudo install -m 755 /home/fivem/outils/roadline.sh /usr/local/bin/roadline && rm -f /tmp/roadline.sh /tmp/roadline-bdd.sh && sudo roadline terminer'
    [IO.Directory]::Delete($tmp, $true)
} catch { Say "ERREUR : $($_.Exception.Message)" 'Red'; Read-Host 'Entrée pour quitter'; exit 1 }

$menu = [ordered]@{
    '1'  = @('État + diagnostic (version, pourquoi le serveur ne répond pas)', 'sudo roadline etat; echo; sudo roadline diagnostic')
    '2'  = @('Console (dernières lignes)', 'sudo roadline logs 60')
    '3'  = @('Erreurs de scripts depuis le démarrage (backtest)', 'sudo roadline erreurs')
    '4'  = @('Redémarrer', 'sudo roadline redemarrer')
    '5'  = @('Arrêter le serveur', 'sudo roadline arreter')
    '6'  = @('Démarrer le serveur', 'sudo roadline demarrer')
    '7'  = @('Ouvrir au PUBLIC (liste FiveM, 48 places)', 'sudo roadline public')
    '8'  = @('Repasser en PRIVÉ (caché, pour tester)', 'sudo roadline prive')
    '9'  = @('Sauvegarder la base maintenant', 'sudo roadline sauvegarde')
    '10' = @('Liste des sauvegardes', 'sudo roadline sauvegardes')
    '11' = @('Copier la dernière sauvegarde du VPS sur ce PC (sécurité)', '')
    '12' = @('Envoyer mes réglages du PC au VPS (Discord, codes staff… : cfg\secrets.cfg)', '')
    '13' = @('Revenir à la version précédente de RoadLine', 'sudo roadline retour')
    '14' = @('Mode SIMPLE : le serveur démarre tout seul (recommandé)', 'sudo roadline mode simple')
    '15' = @('Mode txAdmin : panneau web sur le port 40120 (avec code PIN)', 'sudo roadline mode txadmin')
    '16' = @('Ouvrir une console sur le VPS (taper « exit » pour revenir)', '')
}
$confirm = @{ '5' = 'Arrêter le serveur (les joueurs sont déconnectés) ?'; '13' = 'Remettre la version précédente ?'; '12' = 'Remplacer les réglages du VPS par ceux du PC (la base du VPS est gardée) ?' }
while ($true) {
    Say "`n=========== ROADLINE · VPS $($vps.ip) ===========" 'Cyan'
    foreach ($k in $menu.Keys) { Say ('  {0,2}. {1}' -f $k, $menu[$k][0]) 'White' }
    Say '   0. Quitter' 'White'
    Say "  En jeu : F8 → connect $($vps.ip):30120" 'DarkGray'
    $c = (Read-Host 'Choix').Trim()
    if ($c -eq '0' -or $c -eq '') { break }
    if (-not $menu.Contains($c)) { Say 'Choix inconnu.' 'Yellow'; continue }
    if ($confirm.ContainsKey($c) -and (Read-Host "$($confirm[$c]) (O/N)") -notmatch '^[oOyY]') { continue }
    Say "`n→ $($menu[$c][0])" 'Cyan'
    try {
        switch ($c) {
            '16' { $a = SshArgs; & ssh @a "$($vps.user)@$($vps.ip)" }
            '11' {
                $name = Get-VpsOutput $vps 'sudo roadline copie-sauvegarde'
                if ($name -notmatch '\.sql\.gz$') { Say "  $name" 'Yellow'; break }
                $dir = 'C:\GTASOON\ovh\sauvegardes-vps'; [void][IO.Directory]::CreateDirectory($dir)
                $a = SshArgs
                & scp @a "$($vps.user)@$($vps.ip):/tmp/roadline-sauvegarde.sql.gz" (Join-Path $dir $name)
                [void](Get-VpsOutput $vps 'rm -f /tmp/roadline-sauvegarde.sql.gz')
                Say "  Copiée : $(Join-Path $dir $name)" 'Green'
            }
            '12' {
                $src = 'C:\GTASOON\server-data\cfg\secrets.cfg'
                if (-not (Test-Path -LiteralPath $src)) { Say "  Introuvable : $src" 'Yellow'; break }
                Send-Vps $vps @($src) '/tmp/secrets-pc.cfg'
                Invoke-Vps $vps 'sudo roadline secrets /tmp/secrets-pc.cfg'
            }
            default { Invoke-Vps $vps $menu[$c][1] }
        }
    } catch { Say "ERREUR : $($_.Exception.Message)" 'Red' }
}
