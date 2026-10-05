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
function Initialize-SshKey($vps) {
    if ($script:KeyReady) { return }
    Test-Ssh
    $dir = Join-Path $env:USERPROFILE '.ssh'
    $key = Join-Path $dir 'roadline_ovh'
    [void][IO.Directory]::CreateDirectory($dir)
    if (-not (Test-Path -LiteralPath $key)) { & ssh-keygen -q -t ed25519 -N '""' -C 'roadline-pc' -f $key | Out-Null }
    if (-not (Test-KeyLogin $key $vps)) {
        $pub = (Get-Content -LiteralPath "$key.pub" -Raw).Trim()
        try { Set-Clipboard -Value $pub } catch { }
        Write-Host ''
        Write-Host '  ================= CONNEXION AU VPS SANS MOT DE PASSE =================' -ForegroundColor Cyan
        Write-Host '  La clé de ce PC vient d''être COPIÉE (presse-papiers). Dans l''espace client OVH :' -ForegroundColor White
        Write-Host '   1. Bare Metal Cloud  >  Serveurs privés virtuels (VPS)  >  ton VPS' -ForegroundColor White
        Write-Host '   2. Onglet Accueil, encadré « Votre VPS », ligne OS / Distribution : bouton « ... »  >  Réinstaller mon VPS' -ForegroundColor White
        Write-Host '   3. Choisis Ubuntu 24.04, et dans le champ « Clé SSH » : clic droit > Coller (Ctrl+V)' -ForegroundColor White
        Write-Host '   4. Confirmer. La réinstallation prend 5 à 10 min (le VPS est vide : rien n''est perdu).' -ForegroundColor White
        Write-Host '  Ne ferme pas cette fenêtre : elle attend toute seule que le VPS soit prêt, puis continue.' -ForegroundColor Yellow
        Write-Host ''
        Write-Host '  (la clé, si besoin de la recopier :)' -ForegroundColor DarkGray
        Write-Host "  $pub" -ForegroundColor DarkGray
        Read-Host '  Appuie sur Entrée quand tu as cliqué sur Confirmer chez OVH'
        $deadline = (Get-Date).AddMinutes(20)
        do {
            cmd /c "ssh-keygen -R $($vps.ip) >nul 2>&1" # le VPS réinstallé change d'empreinte : on oublie l'ancienne
            if (Test-KeyLogin $key $vps) { break }
            Write-Host ('  … le VPS se réinstalle ({0:HH:mm}), nouvel essai dans 30 s' -f (Get-Date)) -ForegroundColor DarkGray
            Start-Sleep -Seconds 30
        } while ((Get-Date) -lt $deadline)
        if (-not (Test-KeyLogin $key $vps)) {
            throw ('Le VPS ne répond toujours pas avec la clé. Vérifie que la clé a bien été collée dans « Clé SSH » et ' +
                'que l''utilisateur est bien « ' + $vps.user + ' » (mail OVH de réinstallation), puis relance cet outil.')
        }
        Write-Host '  Connecté au VPS avec la clé : plus jamais de mot de passe.' -ForegroundColor Green
    }
    $script:SshKey = $key
    $script:KeyReady = $true
}
function SshArgs { if ($script:SshKey) { @('-i', $script:SshKey) } else { @() } }

function Send-Vps($vps, [string[]]$files, $dest) {
    Initialize-SshKey $vps
    $a = SshArgs
    & scp @a -o StrictHostKeyChecking=accept-new @files "$($vps.user)@$($vps.ip):$dest"
    if ($LASTEXITCODE -ne 0) { throw 'Envoi refusé (adresse, utilisateur ou mot de passe du VPS ?).' }
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
