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

function Send-Vps($vps, [string[]]$files, $dest) {
    Test-Ssh
    & scp -o StrictHostKeyChecking=accept-new @files "$($vps.user)@$($vps.ip):$dest"
    if ($LASTEXITCODE -ne 0) { throw 'Envoi refusé (adresse, utilisateur ou mot de passe du VPS ?).' }
}

function Invoke-Vps($vps, $command) {
    Test-Ssh
    & ssh -t -o StrictHostKeyChecking=accept-new "$($vps.user)@$($vps.ip)" $command
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
