<#
  Outils communs aux scripts OVH (PREPARER-OVH, METTRE-A-JOUR-OVH) : adresse du VPS, archive au format Linux,
  envoi et commandes par SSH (ssh / scp inclus dans Windows 10 et 11), copie de la base du PC.
#>
$VpsFile = 'C:\GTASOON\ovh\vps.txt' # adresse et utilisateur du VPS (pas de mot de passe)

function Get-Vps {
    $saved = if (Test-Path -LiteralPath $VpsFile) { (Get-Content -LiteralPath $VpsFile -Raw).Trim() } else { '' }
    if ($saved -match '^([\w.-]+)@([\w.:-]+)$') {
        $a = Read-Host "VPS : $saved — Entrée pour garder, ou nouvelle adresse"
        if (-not $a) { return @{ user = $Matches[1]; ip = $Matches[2] } }
        $ip = $a
    } else {
        Write-Host "`nAdresse IP du VPS (mail d'OVH « Votre VPS est prêt », ou espace client → Bare Metal Cloud → VPS)" -ForegroundColor Cyan
        $ip = Read-Host 'IP du VPS'
    }
    if ($ip -notmatch '^[\w.:-]+$') { throw 'Adresse invalide.' }
    $user = Read-Host 'Utilisateur SSH (Entrée = ubuntu ; « debian » sur une image Debian)'
    if (-not $user) { $user = 'ubuntu' }
    if ($user -notmatch '^[\w.-]+$') { throw 'Utilisateur invalide.' }
    [void][IO.Directory]::CreateDirectory((Split-Path $VpsFile))
    [IO.File]::WriteAllText($VpsFile, "$user@$ip")
    return @{ user = $user; ip = $ip }
}

function Test-Ssh {
    if (-not (Get-Command ssh -ErrorAction SilentlyContinue) -or -not (Get-Command scp -ErrorAction SilentlyContinue)) {
        throw 'ssh / scp introuvables : Paramètres Windows → Applications → Fonctionnalités facultatives → « Client OpenSSH ».'
    }
}

#--- Clé de connexion : AUCUN mot de passe à taper. La clé est créée sur ce PC (dossier .ssh de Windows, la partie
#    secrète ne quitte jamais le PC) ; sa partie publique est donnée à OVH lors de la réinstallation du VPS (copiée
#    automatiquement, il suffit de la coller). Ensuite l'envoi, l'installation et les mises à jour se font tout seuls.
$script:KeyReady = $false
function Test-KeyLogin($key, $vps) {
    $target = "$($vps.user)@$($vps.ip)"
    cmd /c "ssh -i `"$key`" -o BatchMode=yes -o StrictHostKeyChecking=accept-new -o ConnectTimeout=10 $target exit >nul 2>&1"
    return $LASTEXITCODE -eq 0
}
# Pourquoi la connexion par clé échoue, en clair (au lieu d'attendre sans rien dire)
function Get-SshReason($key, $vps) {
    $target = "$($vps.user)@$($vps.ip)"
    $out = (cmd /c "ssh -v -i `"$key`" -o BatchMode=yes -o StrictHostKeyChecking=accept-new -o ConnectTimeout=10 $target exit 2>&1") -join "`n"
    if ($out -match 'Authenticated to') { return @('ok', 'Connexion OK.') }
    if ($out -match 'UNPROTECTED|bad permissions') { return @('droits', 'Windows refuse d''utiliser la clé (droits du fichier) : correction automatique.') }
    if ($out -match 'IDENTIFICATION HAS CHANGED|Host key verification failed') { return @('empreinte', 'Ancienne empreinte du VPS : effacée automatiquement.') }
    if ($out -match 'Permission denied') {
        $auth = [regex]::Match($out, 'Authentications that can continue: ([\w,-]+)').Groups[1].Value
        $pw = if ($auth -match 'password') { ' (le VPS accepte le mot de passe)' } else { '' }
        return @('refus', "Le VPS est EN LIGNE mais refuse la clé de ce PC pour l'utilisateur « $($vps.user) »$pw.")
    }
    if ($out -match 'timed out|Connection refused|No route|unreachable|Could not resolve') {
        return @('injoignable', 'Le VPS ne répond pas encore (réinstallation en cours, ou mauvaise IP).')
    }
    return @('autre', (($out -split "`n" | Where-Object { $_ -notmatch '^debug1' } | Select-Object -Last 3) -join ' / '))
}
# Dernier recours : installer la clé avec le mot de passe reçu par mail d'OVH (une seule fois)
function Install-KeyWithPassword($key, $vps) {
    Write-Host ''
    Write-Host '  On installe la clé avec le mot de passe du VPS, UNE SEULE FOIS (ensuite plus jamais).' -ForegroundColor Cyan
    Write-Host '  Mot de passe : celui du dernier mail OVH (réinstallation). Copie-le dans le mail, puis dans cette' -ForegroundColor White
    Write-Host '  fenêtre fais un CLIC DROIT (ça colle) et Entrée. Rien ne s''affiche quand tu colles : c''est normal.' -ForegroundColor White
    $pub = (Get-Content -LiteralPath "$key.pub" -Raw).Trim()
    $cmd = "mkdir -p ~/.ssh && chmod 700 ~/.ssh && grep -qxF '$pub' ~/.ssh/authorized_keys 2>/dev/null || echo '$pub' >> ~/.ssh/authorized_keys; chmod 600 ~/.ssh/authorized_keys"
    & ssh -o StrictHostKeyChecking=accept-new -o PubkeyAuthentication=no -o PreferredAuthentications=password,keyboard-interactive "$($vps.user)@$($vps.ip)" $cmd
}
function Show-ReinstallHelp($pub) {
    try { Set-Clipboard -Value $pub } catch { }
    Write-Host ''
    Write-Host '  La clé de ce PC vient d''être COPIÉE (presse-papiers). Dans l''espace client OVH :' -ForegroundColor White
    Write-Host '   1. Bare Metal Cloud  >  Serveurs privés virtuels (VPS)  >  ton VPS' -ForegroundColor White
    Write-Host '   2. Onglet Accueil, encadré « Votre VPS », ligne OS / Distribution : bouton « ... »  >  Réinstaller mon VPS' -ForegroundColor White
    Write-Host '   3. Choisis Ubuntu 24.04, et dans le champ « Clé SSH » : clic droit > Coller (Ctrl+V)' -ForegroundColor White
    Write-Host '   4. Confirmer. La réinstallation prend 5 à 10 min (le VPS est vide : rien n''est perdu).' -ForegroundColor White
    Write-Host '  (la clé, si besoin de la recopier :)' -ForegroundColor DarkGray
    Write-Host "  $pub" -ForegroundColor DarkGray
}
# Diagnostic en clair + fichier C:\GTASOON\ovh\diagnostic-ssh.txt (aucun secret dedans : adresse, port, réponse du VPS)
function Show-SshDiagnostic($key, $vps) {
    cmd /c "ssh-keygen -R $($vps.ip) >nul 2>&1"
    $port = $false
    try { $port = Test-NetConnection -ComputerName $vps.ip -Port 22 -InformationLevel Quiet -WarningAction SilentlyContinue } catch { }
    $r = Get-SshReason $key $vps
    if ($r[0] -eq 'droits') { cmd /c "icacls `"$key`" /inheritance:r /grant:r `"%USERNAME%`":F >nul 2>&1"; $r = Get-SshReason $key $vps }
    Write-Host ''
    Write-Host "  ---------- DIAGNOSTIC · $($vps.user)@$($vps.ip) ----------" -ForegroundColor Cyan
    if ($port) { Write-Host '  Le VPS répond sur le réseau (port 22 ouvert).' -ForegroundColor Green }
    else { Write-Host '  Le VPS ne répond PAS sur le réseau (port 22) : VPS éteint, en réinstallation, ou IP fausse.' -ForegroundColor Yellow }
    $color = if ($r[0] -eq 'ok') { 'Green' } else { 'Yellow' }
    Write-Host "  $($r[1])" -ForegroundColor $color
    try {
        $raw = (cmd /c "ssh -v -i `"$key`" -o BatchMode=yes -o ConnectTimeout=10 $($vps.user)@$($vps.ip) exit 2>&1") -join "`r`n"
        [IO.File]::WriteAllText('C:\GTASOON\ovh\diagnostic-ssh.txt', "port22=$port`r`n$($r[0]) : $($r[1])`r`n`r`n$raw")
    } catch { }
    return $r[0]
}
function Initialize-SshKey($vps) {
    if ($script:KeyReady) { return }
    Test-Ssh
    $dir = Join-Path $env:USERPROFILE '.ssh'
    $key = Join-Path $dir 'roadline_ovh'
    [void][IO.Directory]::CreateDirectory($dir)
    if (-not (Test-Path -LiteralPath $key)) { & ssh-keygen -q -t ed25519 -N '""' -C 'roadline-pc' -f $key | Out-Null }
    $pub = (Get-Content -LiteralPath "$key.pub" -Raw).Trim()
    while (-not (Test-KeyLogin $key $vps)) {
        $state = Show-SshDiagnostic $key $vps
        if ($state -eq 'ok') { break }
        Write-Host ''
        Write-Host '  Que faire ?' -ForegroundColor Cyan
        Write-Host '   1. Réinstaller le VPS chez OVH avec la clé de ce PC (instructions), puis attendre qu''il soit prêt' -ForegroundColor White
        Write-Host '   2. J''ai DÉJÀ réinstallé : attendre encore (vérifie toutes les 30 s, 15 min max)' -ForegroundColor White
        Write-Host '   3. Poser la clé avec le mot de passe du VPS (mail OVH « identifiants »), une seule fois' -ForegroundColor White
        Write-Host '   4. Corriger l''IP ou l''utilisateur du VPS' -ForegroundColor White
        Write-Host '   0. Quitter (le détail est dans C:\GTASOON\ovh\diagnostic-ssh.txt)' -ForegroundColor White
        switch ((Read-Host '  Choix').Trim()) {
            '1' { Show-ReinstallHelp $pub; Read-Host '  Appuie sur Entrée quand tu as cliqué sur Confirmer chez OVH'; $wait = $true }
            '2' { $wait = $true }
            '3' { Install-KeyWithPassword $key $vps; $wait = $false }
            '4' {
                Remove-Item -LiteralPath $VpsFile -Force -ErrorAction SilentlyContinue
                $n = Get-Vps; $vps.user = $n.user; $vps.ip = $n.ip; $wait = $false
            }
            default { throw 'Arrêté. Envoie une capture du DIAGNOSTIC ci-dessus (aucun mot de passe dedans).' }
        }
        if ($wait) {
            $deadline = (Get-Date).AddMinutes(15)
            while ((Get-Date) -lt $deadline) {
                cmd /c "ssh-keygen -R $($vps.ip) >nul 2>&1" # le VPS réinstallé change d'empreinte : on oublie l'ancienne
                if (Test-KeyLogin $key $vps) { break }
                $r = Get-SshReason $key $vps
                Write-Host ('  {0:HH:mm} · {1}' -f (Get-Date), $r[1]) -ForegroundColor DarkGray
                if ($r[0] -eq 'refus') { break } # en ligne mais clé refusée : inutile d'attendre, retour au diagnostic
                Start-Sleep -Seconds 30
            }
        }
    }
    Write-Host '  Connecté au VPS avec la clé : plus jamais de mot de passe.' -ForegroundColor Green
    $script:SshKey = $key
    $script:KeyReady = $true
}
function SshArgs { if ($script:SshKey) { @('-i', $script:SshKey) } else { @() } }

# Commande courte sur le VPS dont on lit la réponse (sans fenêtre, sans erreur PowerShell sur stderr)
function Get-VpsOutput($vps, $command) {
    Initialize-SshKey $vps
    $a = SshArgs
    $old = $ErrorActionPreference; $ErrorActionPreference = 'Continue'
    $out = & ssh @a -o BatchMode=yes -o ConnectTimeout=15 "$($vps.user)@$($vps.ip)" $command 2>$null
    $ErrorActionPreference = $old
    return (($out | Out-String).Trim())
}

# Envoi robuste : vérifie la place sur le VPS, reprend là où il s'est arrêté si la connexion coupe (5 essais),
# et contrôle la taille reçue. $dest : dossier (finit par /) ou chemin complet du fichier (un seul fichier).
function Send-Vps($vps, [string[]]$files, $dest) {
    Initialize-SshKey $vps
    $a = SshArgs
    $target = "$($vps.user)@$($vps.ip)"
    $total = ($files | ForEach-Object { (Get-Item -LiteralPath $_).Length } | Measure-Object -Sum).Sum
    $dir = if ($dest.EndsWith('/')) { $dest } else { ($dest -replace '[^/]+$', '') }
    $free = Get-VpsOutput $vps "df -B1 --output=avail $dir | tail -1"
    if ($free -match '^\d+$' -and [int64]$free -lt ($total * 2.2)) {
        throw (('Pas assez de place sur le VPS : il faut environ {0} Go libres (archive {1} Go + décompression), il en reste {2} Go. ' -f
            [math]::Ceiling($total * 2.2 / 1GB), [math]::Round($total / 1GB, 1), [math]::Round([int64]$free / 1GB, 1)) +
            'Allège le serveur du PC (vieux mods, cache) ou prends un VPS avec plus de disque.')
    }
    foreach ($f in $files) {
        $size = (Get-Item -LiteralPath $f).Length
        $remote = if ($dest.EndsWith('/')) { $dest + (Split-Path $f -Leaf) } else { $dest }
        Write-Host ('  {0} ({1} Mo)' -f (Split-Path $f -Leaf), [math]::Round($size / 1MB, 1)) -ForegroundColor DarkGray
        [void](Get-VpsOutput $vps "rm -f '$remote'")
        $batch = Join-Path $env:TEMP 'roadline-envoi.txt'
        $got = ''
        for ($try = 1; $try -le 5; $try++) {
            $put = if ([int64]("0$got") -gt 0) { 'put -a' } else { 'put' } # -a : reprend un envoi coupé
            [IO.File]::WriteAllText($batch, "$put `"$($f.Replace('\', '/'))`" `"$remote`"`n")
            $old = $ErrorActionPreference; $ErrorActionPreference = 'Continue'
            & sftp @a -o StrictHostKeyChecking=accept-new -o ServerAliveInterval=15 -b $batch $target 2>&1 |
                ForEach-Object { if ("$_" -notmatch '^sftp>') { Write-Host "    $_" -ForegroundColor DarkGray } }
            $ErrorActionPreference = $old
            $got = Get-VpsOutput $vps "stat -c %s '$remote' 2>/dev/null"
            if ($got -eq "$size") { break }
            if ($try -lt 5) {
                Write-Host ('  Envoi coupé ({0} / {1} Mo reçus), reprise dans 10 s… (essai {2}/5)' -f
                    [math]::Round([int64]("0$got") / 1MB), [math]::Round($size / 1MB), ($try + 1)) -ForegroundColor Yellow
                Start-Sleep -Seconds 10
            }
        }
        Remove-Item -LiteralPath $batch -Force -ErrorAction SilentlyContinue
        if ($got -ne "$size") {
            throw ('Envoi interrompu 5 fois de suite (' + (Split-Path $f -Leaf) + '). Ta connexion internet a coupé, ' +
                'ou le VPS est plein. Relance l''outil : rien n''est perdu.')
        }
    }
}

function Invoke-Vps($vps, $command) {
    Initialize-SshKey $vps
    $a = SshArgs
    & ssh @a -t -o StrictHostKeyChecking=accept-new "$($vps.user)@$($vps.ip)" $command
}

#--- Archive avec des chemins « / » (lisible sous Linux, crochets de [gtasoon] compris)
function New-UnixZip($folder, $zip) {
    Add-Type -AssemblyName System.IO.Compression, System.IO.Compression.FileSystem
    if (Test-Path -LiteralPath $zip) { Remove-Item -LiteralPath $zip -Force }
    $root = (Resolve-Path -LiteralPath $folder).Path.TrimEnd('\')
    $archive = [IO.Compression.ZipFile]::Open($zip, 'Create')
    try {
        foreach ($f in Get-ChildItem -LiteralPath $root -Recurse -File -Force) {
            $rel = $f.FullName.Substring($root.Length + 1).Replace('\', '/')
            [void][IO.Compression.ZipFileExtensions]::CreateEntryFromFile($archive, $f.FullName, $rel, 'Optimal')
        }
    } finally { $archive.Dispose() }
}

#--- Copie d'un script shell en fins de ligne Unix (un clone Windows peut les avoir passées en CRLF)
function Copy-Unix($src, $dest) {
    $t = [IO.File]::ReadAllText($src) -replace "`r`n", "`n"
    [IO.File]::WriteAllText($dest, $t, (New-Object Text.UTF8Encoding $false))
}

#--- Copie de la base du PC (mêmes réglages que SAUVEGARDER-BDD). Retourne $true si le fichier est écrit.
function Export-LocalDb($Data, $out) {
    $secrets = Get-Content -LiteralPath (Join-Path $Data 'cfg\secrets.cfg') -Raw -Encoding UTF8
    $cs = [regex]::Match($secrets, 'mysql_connection_string\s+"mysql:/{2}([^:]+):(.*)@([^:/@]+)(?::(\d+))?/([^?"]+)')
    $svc = Get-CimInstance Win32_Service | Where-Object { $_.Name -match 'maria|mysql' -and $_.PathName -match 'mysqld|mariadbd' } | Select-Object -First 1
    $bin = if ($svc) { Split-Path ([regex]::Match($svc.PathName, '^"?([^"]+?(mysqld|mariadbd)\.exe)').Groups[1].Value) }
    $dump = if ($bin) { @('mariadb-dump.exe', 'mysqldump.exe') | ForEach-Object { Join-Path $bin $_ } | Where-Object { Test-Path $_ } | Select-Object -First 1 }
    if (-not ($cs.Success -and $dump)) { return $false }
    $old = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    $env:MYSQL_PWD = [uri]::UnescapeDataString($cs.Groups[2].Value)
    $p = if ($cs.Groups[4].Value) { $cs.Groups[4].Value } else { '3306' }
    & $dump -h $cs.Groups[3].Value -P $p -u $cs.Groups[1].Value --single-transaction --routines --default-character-set=utf8mb4 --result-file="$out" $cs.Groups[5].Value 2>&1 | Out-Null
    $code = $LASTEXITCODE
    Remove-Item Env:MYSQL_PWD -ErrorAction SilentlyContinue
    $ErrorActionPreference = $old
    return ($code -eq 0 -and (Test-Path -LiteralPath $out) -and (Get-Item $out).Length -gt 500)
}
