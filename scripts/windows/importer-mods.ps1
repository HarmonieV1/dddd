<#
  GTA SOON - IMPORTER DES MODS (véhicules, vêtements, maps / MLO, scripts) téléchargés sur internet ou sur ton Drive.
  1. Télécharge ton dossier Drive (clic droit sur le dossier → Télécharger) : un ou plusieurs .zip arrivent.
  2. Mets-les TELS QUELS dans C:\GTASOON\mods-a-trier (le script crée le dossier au premier lancement).
  3. Double-clic sur IMPORTER-MODS.bat.
  Le script : décompresse tout (zip, rar, 7z, même imbriqués), reconnaît chaque mod, vérifie s'il est « propre » pour
  FiveM (textures trop lourdes, scripts chiffrés, ESX, mod solo), range dans C:\GTASOON\mods-tri\, installe
  automatiquement les bons dans resources\[addons] (+ cfg\addons.cfg) et écrit RAPPORT-MODS.txt à m'envoyer.
  Rien n'est supprimé de mods-a-trier. Relançable autant de fois que tu veux (les mods déjà installés sont remplacés).
#>
$ErrorActionPreference = 'Stop'
function Say($m, $c = 'Gray') { Write-Host $m -ForegroundColor $c }
function Fail($m) { Say "ERREUR : $m" 'Red'; Read-Host 'Entrée pour quitter'; exit 1 }

$Root   = if ($env:GTASOON_ROOT) { $env:GTASOON_ROOT } else { 'C:\GTASOON' }   # (variable : tests automatiques)
$Src    = Join-Path $Root 'mods-a-trier'
$Out    = Join-Path $Root 'mods-tri'
$Work   = Join-Path $Out '_extraction'
$Data   = Join-Path $Root 'server-data'
$Addons = Join-Path $Data 'resources\[addons]'
$Report = Join-Path $Out 'RAPPORT-MODS.txt'
$Cats   = @{ vehicule = 'vehicules'; vetement = 'vetements'; map = 'maps'; script = 'scripts-a-verifier'; convertir = 'a-convertir'; converti = 'deja-convertis'; rejete = 'rejetes' }

[void][IO.Directory]::CreateDirectory($Src)
# V12.59 · Archives en plusieurs morceaux : seul le 1er morceau est pris (7-Zip lit les suivants tout seul) :
#     « x.7z.001 » / « x.zip.001 », « x.part1.rar ». Avant, les « .001 » étaient ignorés sans message et les « .part2.rar »
#     ouverts seuls (archive incomplète).
function Test-ArchiveName([string]$n) {
    if ($n -match '(?i)\.part0*([2-9]|\d{2,})\.rar$') { return $false }
    return $n -match '(?i)(\.(zip|rar|7z)|\.(7z|zip)\.0*1)$'
}
$archives = @(Get-ChildItem -LiteralPath $Src -File | Where-Object { Test-ArchiveName $_.Name })
# V12.59 · Dossiers déjà décompressés posés dans mods-a-trier : avant ignorés sans message (« le mod ne passe pas »),
#     maintenant importés comme une archive (sauf nos dossiers de travail).
$folders = @(Get-ChildItem -LiteralPath $Src -Directory | Where-Object { $_.Name -notmatch '^(_|\.)' })
# En plus de mods-a-trier : « Google Drive pour ordinateur » (lecteur G:, H:…), dossier GTA de Mon Drive, s'il existe.
# (Un fichier présent aux deux endroits n'est pris qu'une fois.)
if (-not $env:GTASOON_ROOT) {
    foreach ($d in Get-PSDrive -PSProvider FileSystem -ErrorAction SilentlyContinue) {
        foreach ($sub in 'Mon Drive\GTA', 'My Drive\GTA') {
            $g = Join-Path $d.Root $sub
            if (Test-Path -LiteralPath $g) {
                $names = @($archives | ForEach-Object { $_.Name })
                $found = @(Get-ChildItem -LiteralPath $g -File | Where-Object { (Test-ArchiveName $_.Name) -and $names -notcontains $_.Name })
                if ($found.Count -gt 0) { Say "Dossier Google Drive trouvé : $g (+$($found.Count) archives)" 'Green'; $archives += $found }
            }
        }
    }
}
if ($archives.Count -eq 0 -and $folders.Count -eq 0 -and $env:GTASOON_CHAIN) {
    Say "  Mods : aucun fichier dans $Src (voitures, maps, vêtements du Drive : mets-les là, tels quels)." 'Yellow'; return
}
# Lancé par METTRE-A-JOUR : si ni les archives ni cet importeur n'ont changé depuis le dernier import, rien à refaire
# (évite de tout redécompresser à chaque mise à jour).
$Stamp = Join-Path $Out '.derniere-signature'
$signature = (@($archives | Sort-Object Name | ForEach-Object { "$($_.Name)|$($_.Length)|$($_.LastWriteTimeUtc.Ticks)" }) +
    @($folders | Sort-Object Name | ForEach-Object { $fs = @(Get-ChildItem -LiteralPath $_.FullName -Recurse -File -Force -ErrorAction SilentlyContinue)
        "$($_.Name)/|$($fs.Count)|$(($fs | Measure-Object Length -Sum).Sum)|$(($fs | ForEach-Object { $_.LastWriteTimeUtc.Ticks } | Measure-Object -Maximum).Maximum)" }) +
    (Get-FileHash -LiteralPath $PSCommandPath -Algorithm SHA1).Hash) -join "`n"
if ($env:GTASOON_CHAIN -and (Test-Path -LiteralPath $Stamp) -and (Get-Content -LiteralPath $Stamp -Raw).Trim() -eq $signature.Trim()) {
    Say '  Mods : rien de nouveau depuis le dernier import.' 'Green'; return
}
if ($archives.Count -eq 0 -and $folders.Count -eq 0) {
    Say "Mets tes fichiers (.zip / .rar / .7z) dans $Src puis relance IMPORTER-MODS.bat." 'Yellow'
    Start-Process explorer.exe $Src
    Read-Host 'Entrée pour quitter'; exit 0
}

# 7-Zip : indispensable pour les .rar (installé automatiquement si absent)
$7z = @($env:GTASOON_7Z, 'C:\Program Files\7-Zip\7z.exe', 'C:\Program Files (x86)\7-Zip\7z.exe') | Where-Object { $_ -and (Test-Path -LiteralPath $_) } | Select-Object -First 1
if (-not $7z) {
    Say '7-Zip absent : installation (winget)…' 'Cyan'
    try { winget install --id 7zip.7zip -e --silent --accept-package-agreements --accept-source-agreements | Out-Null } catch { }
    $7z = @('C:\Program Files\7-Zip\7z.exe', 'C:\Program Files (x86)\7-Zip\7z.exe') | Where-Object { Test-Path -LiteralPath $_ } | Select-Object -First 1
    if (-not $7z) { Fail 'Installe 7-Zip (https://www.7-zip.org, gratuit) puis relance.' }
}

# 1. Décompression (récursive : un zip du Drive contient lui-même des .rar) ------------------------------------------
# Dossier temporaire de l'import précédent : supprimé. Si un fichier est verrouillé (antivirus, Explorateur, import
# encore en cours), on réessaie, puis on travaille dans un nouveau dossier plutôt que de s'arrêter.
if (Test-Path -LiteralPath $Work) {
    for ($try = 0; $try -lt 3 -and (Test-Path -LiteralPath $Work); $try++) {
        Remove-Item -LiteralPath $Work -Recurse -Force -ErrorAction SilentlyContinue
        if (Test-Path -LiteralPath $Work) { Start-Sleep -Seconds 2 }
    }
    if (Test-Path -LiteralPath $Work) {
        Say "  (ancien dossier temporaire verrouillé par un autre programme : il sera nettoyé au prochain import)" 'Yellow'
        $Work = Join-Path $Out ('_extraction_' + (Get-Date -Format 'HHmmss'))
    }
}
# Restes d'imports interrompus
Get-ChildItem -LiteralPath $Out -Directory -Filter '_extraction_*' -ErrorAction SilentlyContinue | ForEach-Object { Remove-Item -LiteralPath $_.FullName -Recurse -Force -ErrorAction SilentlyContinue }
[void][IO.Directory]::CreateDirectory($Work)
function Clean-Name([string]$n) {
    $n = [IO.Path]::GetFileNameWithoutExtension($n) -replace '(?i)\.(7z|zip|part0*1)$', ''   # « x.7z.001 », « x.part1.rar » → x
    $n = $n -replace '^[0-9a-f]{6}-', '' -replace '_\d{9,}_\d+$', ''          # préfixes / suffixes des sites de mods
    $n = ($n -replace '[^A-Za-z0-9]+', '_').Trim('_').ToLower()
    if ($n.Length -gt 40) { $n = $n.Substring(0, 40).Trim('_') }
    if (-not $n) { $n = 'mod' }
    return $n
}
#--- V12.27 : 7-Zip en erreur (code 2 et plus : « Unexpected end of archive », données tronquées) = archive incomplète.
#    Un fichier tronqué installé fait planter chaque joueur qui le charge (« Invalid fixup, address is neither virtual
#    nor physical (in patoche_beach_guard.ydr) »). L'archive en cours est notée, ses mods refusés plus bas.
$script:ArchiveBroken = $false
function Invoke-7z([string[]]$a) {
    & $7z @a | Out-Null
    if ($LASTEXITCODE -ge 2) { $script:ArchiveBroken = $true }
}
#--- Décompresse une archive. Si elle contient elle-même des archives (zip du Drive = plusieurs mods), chacune
#    devient un mod séparé. Retourne la liste des dossiers « mod ».
function Expand-One($files, $dest) {
    foreach ($f in @($files)) { Invoke-7z @('x', $f, "-o$dest", '-y', '-bso0', '-bsp0') }
    Expand-Inner $dest
}
function Expand-Inner($dest) {
    for ($depth = 0; $depth -lt 3; $depth++) { # archives dans l'archive d'un même mod (ex : pack de vêtements)
        $inner = @(Get-ChildItem -LiteralPath $dest -Recurse -File | Where-Object { Test-ArchiveName $_.Name })
        if ($inner.Count -eq 0) { break }
        foreach ($i in $inner) {
            Invoke-7z @('x', $i.FullName, ("-o" + (Join-Path $i.DirectoryName (Clean-Name $i.Name))), '-y', '-bso0', '-bsp0')
            Remove-Item -LiteralPath $i.FullName -Force -ErrorAction SilentlyContinue
        }
    }
}
# Fichiers du jeu (ce qui fait un mod) : sert à repérer un mod resté à côté des dossiers-ressources
$GameExt = '^\.(yft|ytd|ydd|ydr|ymap|ytyp|ybn|ymt|meta|rpf|ycd|awc|rel|dat\d*|nametable|gxt2)$'
# $files : une archive, ou les morceaux d'un téléchargement Google Drive coupé en plusieurs zips (V12.59) ; $folder : un
# dossier déjà décompressé posé dans mods-a-trier (V12.59).
function Expand-Package($files, $dest, $folder) {
    $files = @($files | Where-Object { $_ })
    if ($folder) { Copy-Item -LiteralPath $folder -Destination $dest -Recurse -Force }
    else { foreach ($f in $files) { Invoke-7z @('x', $f, "-o$dest", '-y', '-bso0', '-bsp0') } }
    $inner = @(Get-ChildItem -LiteralPath $dest -Recurse -File | Where-Object { Test-ArchiveName $_.Name })
    # V12.59 : un mode d'emploi (pdf, doc, vidéo…) à côté des archives ne fusionne plus tous les mods en un seul
    $loose = @(Get-ChildItem -LiteralPath $dest -Recurse -File | Where-Object { -not (Test-ArchiveName $_.Name) -and
        $_.Extension -notmatch '^\.(zip|rar|7z|\d{3}|txt|md|nfo|pdf|docx?|rtf|url|html?|jpe?g|png|gif|webp|bmp|mp4|webm|mkv|avi|ini|log)$' })
    if ($inner.Count -ge 2 -and $loose.Count -eq 0) {
        $list = @()
        foreach ($i in $inner) {
            $sub = Join-Path $Work (Clean-Name $i.Name)
            if (Test-Path -LiteralPath $sub) { $sub = $sub + '_' + (Clean-Name (Split-Path $dest -Leaf)) }
            Expand-One $i.FullName $sub
            Remove-Item -LiteralPath $i.FullName -Force -ErrorAction SilentlyContinue
            $list += Get-Item -LiteralPath $sub
        }
        Remove-Item -LiteralPath $dest -Recurse -Force -ErrorAction SilentlyContinue
        return $list
    }
    Expand-Inner $dest
    # V12.18 : pack payant livré en plusieurs dossiers-ressources (map + dépendance…) dans un seul zip : un mod par
    # dossier (sinon seul le premier fxmanifest était installé, les autres oubliés)
    $sep = [IO.Path]::DirectorySeparatorChar
    $mans = @(Get-ChildItem -LiteralPath $dest -Recurse -File -Force | Where-Object { $_.Name -ieq 'fxmanifest.lua' -or $_.Name -ieq '__resource.lua' } | ForEach-Object { $_.DirectoryName } | Sort-Object -Unique)
    $tops = @($mans | Where-Object { $d = $_; -not @($mans | Where-Object { $_ -ne $d -and $d.StartsWith($_ + $sep) }).Count })
    # V12.59 : mod sans fxmanifest (voiture, vêtement « stream » seul) rangé à côté de dossiers-ressources : avant, il était
    # effacé sans un mot (2 ressources ou plus) ou ignoré (1 ressource : seul son dossier était lu). Il devient un mod à part.
    $outside = @(Get-ChildItem -LiteralPath $dest -Recurse -File -Force | Where-Object { $_.Extension -match $GameExt -and
        $(foreach ($t in $tops) { if ($_.FullName.StartsWith($t + $sep)) { $true; break } }) -ne $true })
    if ($tops.Count -ge 2 -or ($tops.Count -eq 1 -and $outside.Count -gt 0 -and $tops[0] -ne $dest)) {
        $list = @()
        foreach ($t in $tops) {
            $sub = Join-Path $Work (Clean-Name (Split-Path $t -Leaf))
            if (Test-Path -LiteralPath $sub) { $sub = $sub + '_' + (Clean-Name (Split-Path $dest -Leaf)) }
            Move-Item -LiteralPath $t -Destination $sub -Force
            $list += Get-Item -LiteralPath $sub
        }
        if ($outside.Count -gt 0) { $list += Get-Item -LiteralPath $dest }   # le reste : un mod de plus (voitures, vêtements…)
        else { Remove-Item -LiteralPath $dest -Recurse -Force -ErrorAction SilentlyContinue }
        return $list
    }
    return @(Get-Item -LiteralPath $dest)
}
# V12.59 · Google Drive coupe un gros dossier en plusieurs zips (« GTA-20261014T101500Z-001.zip », « -002 »…) et un même
#     mod peut être à cheval sur deux zips : chaque moitié était analysée seule (modèles sans .meta, .meta sans modèles),
#     la 2e moitié souvent prise pour un doublon. Les morceaux d'un même téléchargement sont décompressés ensemble.
$groups = [ordered]@{}
foreach ($a in $archives) {
    $key = if ($a.Name -match '(?i)^(.+-\d{8}T\d{6}Z)-(\d+-)?\d{3}\.zip$') { $Matches[1] } else { $a.Name }
    if (-not $groups.Contains($key)) { $groups[$key] = @() }
    $groups[$key] += $a
}
Say "`n[1/3] Décompression de $($archives.Count) archive(s)$(if ($folders.Count) { " et $($folders.Count) dossier(s)" })" 'Cyan'
$packages = @()
$BrokenPkg = @{} # [dossier du mod] = archive incomplète d'où il vient
$script:ImportFailed = $false # V12.59 : échec à refaire au prochain METTRE-A-JOUR (la signature n'est pas enregistrée)
$jobs = @(foreach ($k in $groups.Keys) { [pscustomobject]@{ label = (@($groups[$k] | ForEach-Object { $_.Name }) -join ' + '); name = $k; files = @($groups[$k] | ForEach-Object { $_.FullName }); folder = $null } }) +
    @(foreach ($f in $folders) { [pscustomobject]@{ label = "$($f.Name)\ (dossier)"; name = $f.Name; files = @(); folder = $f.FullName } })
foreach ($j in $jobs) {
    Say "  $($j.label)"
    if ($j.files.Count -gt 1) { Say "    téléchargement Google Drive en $($j.files.Count) morceaux : décompressés ensemble" 'DarkGray' }
    $script:ArchiveBroken = $false
    try {
        $dest = Join-Path $Work (Clean-Name $j.name)
        if (Test-Path -LiteralPath $dest) { $dest = $dest + '_' + $packages.Count }
        $got = @(Expand-Package $j.files $dest $j.folder)
        $packages += $got
        if ($script:ArchiveBroken) {
            foreach ($g in $got) { $BrokenPkg[$g.FullName] = $j.label }
            Say "    ARCHIVE INCOMPLÈTE (téléchargement coupé) : pas installée. Retélécharge-la puis relance." 'Red'
        }
    } catch { $script:ImportFailed = $true; Say "    échec : $($_.Exception.Message)" 'Yellow' }
}

# 1b. Archives dlc.rpf (mods « solo » faits avec OpenIV) : extraction directe si non chiffrées (format OPEN), sans
#     OpenIV. Les fichiers « ressource » (yft, ytd, ymap…) sont copiés tels quels (en-tête RSC7 compris), les autres
#     décompressés. Les .rpf imbriqués (x64\vehicles.rpf…) sont ouverts aussi.
function Expand-Rpf([byte[]]$buf, [long]$base, [string]$dest) {
    $magic = [BitConverter]::ToUInt32($buf, $base)
    if ($magic -ne 0x52504637) { return $false }                       # 'RPF7'
    $count = [BitConverter]::ToUInt32($buf, $base + 4)
    $namesLen = [BitConverter]::ToUInt32($buf, $base + 8)
    $enc = [BitConverter]::ToUInt32($buf, $base + 12)
    if ($enc -ne 0x4E45504F -and $enc -ne 0) { return $false }          # chiffré (AES / NG) : non géré
    $entries = $base + 16
    $names = $entries + 16 * $count
    function Name($off) { $e = $names + $off; $n = $e; while ($buf[$n] -ne 0) { $n++ }; [Text.Encoding]::ASCII.GetString($buf, $e, $n - $e) }
    function Walk($index, $path) {
        $o = $entries + 16 * $index
        $x = [BitConverter]::ToUInt32($buf, $o); $y = [BitConverter]::ToUInt32($buf, $o + 4)
        if ($y -eq 0x7FFFFF00) {
            $first = [BitConverter]::ToUInt32($buf, $o + 8); $n = [BitConverter]::ToUInt32($buf, $o + 12)
            $dir = if ($index -eq 0) { $path } else { Join-Path $path (Name ($x -band 0xFFFF)) }
            [void][IO.Directory]::CreateDirectory($dir)
            for ($k = 0; $k -lt $n; $k++) { Walk ($first + $k) $dir }
            return
        }
        $raw = [BitConverter]::ToUInt64($buf, $o)
        $name = Name ([uint32]($raw -band 0xFFFF))
        $size = [long](($raw -shr 16) -band 0xFFFFFF)
        $offset = $base + [long](($raw -shr 40) -band 0x7FFFFF) * 512
        $file = Join-Path $path $name
        if (($y -band 0x80000000) -ne 0) {                               # ressource (RSC7)
            if ($size -eq 0xFFFFFF) { $size = [long]$buf[$offset + 7] -bor ([long]$buf[$offset + 14] -shl 8) -bor ([long]$buf[$offset + 5] -shl 16) -bor ([long]$buf[$offset + 2] -shl 24) }
            $out = New-Object byte[] $size; [Array]::Copy($buf, $offset, $out, 0, $size)
            [IO.File]::WriteAllBytes($file, $out)
        } else {
            $usize = [BitConverter]::ToUInt32($buf, $o + 8)
            if ($size -eq 0) {
                if ($name -like '*.rpf') { [void](Expand-Rpf $buf $offset ($file -replace '\.rpf$', '_rpf')); return }
                $out = New-Object byte[] $usize; [Array]::Copy($buf, $offset, $out, 0, $usize)
            } else {
                $ms = New-Object IO.MemoryStream($buf, [int]$offset, [int]$size)
                $ds = New-Object IO.Compression.DeflateStream($ms, [IO.Compression.CompressionMode]::Decompress)
                $out = New-Object byte[] $usize; $read = 0
                while ($read -lt $usize) { $r = $ds.Read($out, $read, $usize - $read); if ($r -le 0) { break }; $read += $r }
                $ds.Dispose()
            }
            if ($name -like '*.rpf') { [void](Expand-Rpf $out 0 ($file -replace '\.rpf$', '_rpf')) } else { [IO.File]::WriteAllBytes($file, $out) }
        }
    }
    Walk 0 $dest
    return $true
}
function Expand-RpfFiles($pkgDir) {
    foreach ($rpf in @(Get-ChildItem -LiteralPath $pkgDir -Recurse -File -Filter '*.rpf')) {
        if ($rpf.Length -gt 1.5GB) { continue }
        try {
            $ok = Expand-Rpf ([IO.File]::ReadAllBytes($rpf.FullName)) 0 (Join-Path $rpf.DirectoryName ($rpf.BaseName + '_rpf'))
            if ($ok) { Remove-Item -LiteralPath $rpf.FullName -Force }
        } catch { Say "    $($rpf.Name) : extraction impossible ($($_.Exception.Message))" 'Yellow' }
    }
}
Say "[1b] Ouverture des dlc.rpf (mods solo)" 'Cyan'
foreach ($p in $packages) { Expand-RpfFiles $p.FullName }

# Un mod livré avec un dossier « FiveM » (souvent à côté d'une version solo) : on installe la version FiveM,
# une ressource par fxmanifest trouvé dedans (ex : haut + bas d'un maillot).
$final = @()
foreach ($p in $packages) {
    $fivem = @(Get-ChildItem -LiteralPath $p.FullName -Recurse -Directory -Force | Where-Object { $_.Name -match '^five\s*m$' })
    $mans = @($fivem | ForEach-Object { Get-ChildItem -LiteralPath $_.FullName -Recurse -File -Force -Filter 'fxmanifest.lua' })
    if ($mans.Count -gt 0) {
        $i = 0
        foreach ($m in $mans) {
            $i++
            $final += [pscustomobject]@{ Name = $(if ($mans.Count -gt 1) { "$($p.Name)_$i" } else { $p.Name }); FullName = $m.DirectoryName }
        }
    } else {
        # Plusieurs ressources FiveM côte à côte dans une même archive (ex : vêtements homme + femme) : une par manifest.
        $all = @(Get-ChildItem -LiteralPath $p.FullName -Recurse -File -Force -Filter 'fxmanifest.lua')
        if ($all.Count -gt 1) {
            foreach ($m in $all) { $final += [pscustomobject]@{ Name = $m.Directory.Name; FullName = $m.DirectoryName } }
        } else { $final += [pscustomobject]@{ Name = $p.Name; FullName = $p.FullName } }
    }
}
$packages = $final

# 2. Analyse ----------------------------------------------------------------------------------------------------------
function Find-Resource($Res, $name) { Get-ChildItem -LiteralPath $Res -Directory -Recurse -Filter $name -ErrorAction SilentlyContinue | Select-Object -First 1 }
function MB($bytes) { [math]::Round($bytes / 1MB, 1) }
# Packs trop lourds : on ne garde que quelques modèles choisis (le reste des fichiers et des entrées .meta est retiré).
# Vêtements solo déjà convertis par nos soins (zips ROADTRIP-*.zip) : signalés comme tels au lieu de « à convertir ».
$Converted = @{ basic = 'ROADTRIP-coiffures_femme_1.zip'; box_braids = 'ROADTRIP-coiffures_femme_1.zip'; dreads = 'ROADTRIP-coiffures_femme_1.zip'
    edgar = 'ROADTRIP-coiffures_femme_2.zip'; leopard_print = 'ROADTRIP-coiffures_femme_2.zip'; locs = 'ROADTRIP-coiffures_femme_2.zip'
    # V12.45 · convertis le 14/10 (session web)
    dreadlocks = 'ROADTRIP-coiffures_homme_2.zip'; buzzcut_fade = 'ROADTRIP-coiffures_homme_2.zip'
    hyun_hair = 'ROADTRIP-coiffures_femme_3.zip'; braid_with_long_hairstyle_for_mp_female = 'ROADTRIP-coiffures_femme_3.zip'
    long_braids_hairstyle_by_jazlyn13 = 'ROADTRIP-coiffures_femme_3.zip'; long_hair = 'ROADTRIP-coiffures_femme_3.zip'
    '088_erika_hair' = 'ROADTRIP-coiffures_femme_3.zip'; free_alycia_hair_by_jinxstore = 'ROADTRIP-coiffures_femme_3.zip'
    grace_dress = 'ROADTRIP-tenues_femme_1.zip'; knee_jeans = 'ROADTRIP-tenues_femme_2.zip'
    dollie_moko_summer_dress_for_mp_female = 'ROADTRIP-tenues_femme_2.zip'; dress_with_cut_outs_for_mp_female_by_jaa = 'ROADTRIP-tenues_femme_1.zip'
    tidefn5modshairpack = 'ROADTRIP-coiffures_homme_3.zip et ROADTRIP-coiffures_homme_4.zip'
    dresspackmpfemale1_0 = 'ROADTRIP-tenues_femme_3.zip, _4.zip et _5.zip'
    # V12.48 : rapport du 14/10 08:22
    lace_up_sweats = 'ROADTRIP-tenues_femme_1.zip'; hair = 'ROADTRIP-coiffures_homme_2.zip'; natt_hair5_fivem = 'ROADTRIP-coiffures_femme_3.zip' }
# V12.48 · Refusés pour une raison que l'analyse ne peut pas voir seule (ped de l'histoire, archive coupée…).
$Refused = @{ afro_for_lamar_tykus = 'coiffure du personnage de l''histoire Lamar (ped ig_lamardavis), pas des persos FiveM : pas convertible' }
$PackPick = @{} # ex. : @{ nom_du_pack = @('modele1', 'modele2') }
function Save-Xml($x, $path) {
    $s = New-Object Xml.XmlWriterSettings; $s.Encoding = New-Object Text.UTF8Encoding $false; $s.Indent = $true
    $w = [Xml.XmlWriter]::Create($path, $s); $x.Save($w); $w.Close()
}
function Pick-Models($root, [string[]]$keep) {
    $metas = @(Get-ChildItem -LiteralPath $root -Recurse -File -Force | Where-Object { $_.Name -match '^(vehicles|carvariations)\.meta$' })
    $gone = @()
    foreach ($m in $metas) {
        [xml]$x = Get-Content -LiteralPath $m.FullName -Raw
        foreach ($item in @($x.SelectNodes('//InitDatas/Item | //variationData/Item'))) {
            $name = "$($item.modelName)".Trim().ToLower()
            if ($name -and $keep -notcontains $name) { $gone += $name; [void]$item.ParentNode.RemoveChild($item) }
        }
        Save-Xml $x $m.FullName
    }
    $gone = @($gone | Sort-Object -Unique)
    foreach ($f in @(Get-ChildItem -LiteralPath $root -Recurse -File -Force | Where-Object { $_.Extension -match '^\.(yft|ytd)$' })) {
        $base = ($f.BaseName.ToLower() -replace '(\+hi|_hi)$', '')
        if ($gone -contains $base) { Remove-Item -LiteralPath $f.FullName -Force }
    }
    return $gone.Count
}
# Pièces de tuning (kits carrosserie) de plus de 16 Mo : retirées avec les pièces liées, et enlevées du carcols.meta.
# La voiture reste complète, seul ce kit disparaît du garage de tuning.
function Slim-Tuning($root) {
    $big = @(Get-ChildItem -LiteralPath $root -Recurse -File -Force -Filter '*.yft' | Where-Object { $_.Length -gt 16MB } | ForEach-Object { $_.BaseName.ToLower() })
    if ($big.Count -eq 0) { return @() }
    $drop = @()
    foreach ($c in @(Get-ChildItem -LiteralPath $root -Recurse -File -Force -Filter 'carcols.meta')) {
        try { [xml]$x = Get-Content -LiteralPath $c.FullName -Raw } catch { continue }
        $changed = $false
        foreach ($item in @($x.SelectNodes('//visibleMods/Item'))) {
            $name = "$($item.modelName)".Trim().ToLower()
            $linked = @($item.SelectNodes('linkedModels/Item') | ForEach-Object { $_.InnerText.Trim().ToLower() })
            if ($big -contains $name -or @($linked | Where-Object { $big -contains $_ }).Count -gt 0) {
                $drop += @($name) + $linked; [void]$item.ParentNode.RemoveChild($item); $changed = $true
            }
        }
        foreach ($item in @($x.SelectNodes('//linkMods/Item'))) {
            if ($drop -contains "$($item.modelName)".Trim().ToLower()) { [void]$item.ParentNode.RemoveChild($item); $changed = $true }
        }
        if ($changed) { Save-Xml $x $c.FullName }
    }
    $removed = @()
    foreach ($f in @(Get-ChildItem -LiteralPath $root -Recurse -File -Force -Filter '*.yft' | Where-Object { $drop -contains $_.BaseName.ToLower() })) {
        $removed += $f.BaseName; Remove-Item -LiteralPath $f.FullName -Force
    }
    return $removed
}
# Marques réelles (voitures sous licence, mode, police réelle) : refusées, risque de retrait du serveur par Cfx.re /
# Rockstar. On garde le contenu « lore GTA » (marques inventées du jeu) ou sans marque.
$BrandBlock = 'lamborghini|ferrari|porsche|mercedes|maybach|amg|audi|etron|bmw|dodge|chrysler|jeep|ford|mustang|chevrolet|chevy|corvette|cadillac|volkswagen|(?<!mini)golf|toyota|lexus|nissan|honda|mazda|subaru|mitsubishi|bugatti|mclaren|tesla|bentley|rolls|aston|jaguar|land.?rover|range.?rover|maserati|alfa|fiat|peugeot|renault|citroen|koenigsegg|pagani|rimac|gucci|versace|nike|adidas|jordan|supreme|balenciaga|louis.?vuitton|dior|chanel|prada|rolex|north.?face|dallas|nypd|lapd|lspd_real|rhgs|roadtrip_vetements_homme|boomods_brand_bag|ysl'
# Fichiers à l'intérieur d'un pack : marques sans ambiguïté seulement (un « golf_course.ytd » de map n'est pas une Golf)
$BrandStrong = 'lamborghini|ferrari|porsche|mercedes|maybach|bugatti|mclaren|koenigsegg|gucci|versace|balenciaga|louis.?vuitton|rolex|dallas'
function Test-Brand($name, [switch]$File) { return ($name.ToLower() -match $(if ($File) { $BrandStrong } else { $BrandBlock })) }

function Analyze($pkg) {
    $pre = New-Object System.Collections.ArrayList
    $pick = $PackPick[(Clean-Name $pkg.Name)]
    if ($pick) { $n = Pick-Models $pkg.FullName $pick; [void]$pre.Add("pack allégé : $n modèles retirés, gardés : $($pick -join ', ')") }
    $slim = @(Slim-Tuning $pkg.FullName)
    if ($slim.Count -gt 0) { [void]$pre.Add("$($slim.Count) pièces de tuning trop lourdes retirées (kit $($slim[0])…) : la voiture reste complète") }
    $all = @(Get-ChildItem -LiteralPath $pkg.FullName -Recurse -File -Force)
    $brandHit = (Test-Brand $pkg.Name) -or @($all | Where-Object { Test-Brand $_.Name -File } | Select-Object -First 1).Count -gt 0
    $r = [ordered]@{ name = (Clean-Name $pkg.Name); source = $pkg.Name; type = 'rejete'; sizeMB = MB (($all | Measure-Object Length -Sum).Sum)
        issues = New-Object System.Collections.ArrayList; notes = $pre; root = $pkg.FullName; models = @(); install = $false; risk = $null; escrow = $false; broken = $null; deps = @(); resName = $null; companion = $null
        bytes = [long](($all | Measure-Object Length -Sum).Sum); nfiles = $all.Count }
    $ext = { param($e) @($all | Where-Object { $_.Extension -ieq $e }) }
    $manifest = $all | Where-Object { $_.Name -ieq 'fxmanifest.lua' -or $_.Name -ieq '__resource.lua' } | Select-Object -First 1
    $lua = @($all | Where-Object { $_.Extension -ieq '.lua' -and $_.Name -notmatch '^(fxmanifest|__resource)\.lua$' })
    $big = @($all | Where-Object { $_.Extension -match '^\.(ytd|yft|ydd|ydr)$' -and $_.Length -gt 16MB })
    foreach ($b in $big) { [void]$r.issues.Add("fichier trop lourd $($b.Name) ($(MB $b.Length) Mo > 16 Mo) : textures qui disparaissent / crash, à optimiser") }
    if ($r.sizeMB -gt 150) { [void]$r.issues.Add("mod très lourd ($($r.sizeMB) Mo) : temps de chargement et mémoire des joueurs") }
    # V12.5 : escrow Cfx (.fxap). Une MAP achetée sur la boutique officielle du créateur (Gabz, UncleJust…) est presque
    # toujours protégée ainsi : elle est installée, avec un avertissement. Un SCRIPT chiffré seul n'est pas installé (illisible).
    $fxap = @($all | Where-Object { $_.Name -ieq '.fxap' -or $_.Extension -ieq '.fxap' }).Count -gt 0
    # V12.18 : un pack payant protégé qui contient des fichiers du jeu (map, véhicule, vêtement) est installé même s'il
    # embarque un petit script chiffré (portes, ascenseurs, IPL) : avant, ces packs (Shadow Complex, circuit…) étaient refusés.
    $escrowMap = $fxap -and @($all | Where-Object { $_.Extension -match '^\.(ymap|ytyp|ybn|yft|ydd|ydr)$' }).Count -gt 0
    $r.escrow = $fxap
    if ($escrowMap) { [void]$r.notes.Add('pack protégé (escrow Cfx) : ne fonctionne QUE s''il a été acheté avec le compte Cfx.re lié à la clé du serveur. Fichiers gardés tels quels (jamais modifiés)') }
    elseif ($fxap) { [void]$r.notes.Add('script payant chiffré (escrow) : illisible, donc pas installé automatiquement. Marche seulement avec le compte Cfx.re de la clé du serveur et le bon framework (Qbox / QBCore)') }
    if (@($all | Where-Object { $_.Extension -match '^\.(oiv|asi|dll)$' -or $_.Name -match 'reshade|visualsettings|timecycle' }).Count -gt 0) {
        [void]$r.notes.Add('contient un mod graphique / solo (oiv, asi, reshade) : inutile côté serveur')
    }
    $yftNames = @($all | Where-Object { $_.Extension -ieq '.yft' } | ForEach-Object { $_.BaseName.ToLower() })
    foreach ($m in @($all | Where-Object { $_.Name -ieq 'vehicles.meta' })) {
        foreach ($name in @([regex]::Matches((Get-Content -LiteralPath $m.FullName -Raw), '<modelName>\s*([^<\s]+)\s*</modelName>') | ForEach-Object { $_.Groups[1].Value.ToLower() })) {
            if ($yftNames.Count -eq 0 -or $yftNames -contains $name) { $r.models += $name }
            else { [void]$r.notes.Add("$name déclaré dans vehicles.meta mais absent du pack : ignoré") }
        }
    }
    if ($manifest) {
        $r.root = $manifest.DirectoryName
        # V12.31 : dépendances déclarées (dependency 'x' / dependencies { 'a', 'b' }) ; « /onesync », « /server:… » = réglages
        $mtext = Get-Content -LiteralPath $manifest.FullName -Raw -ErrorAction SilentlyContinue
        if ($mtext) {
            $blocks = @([regex]::Matches($mtext, '(?s)dependencies\s*\{(.*?)\}') | ForEach-Object { $_.Groups[1].Value }) +
                @([regex]::Matches($mtext, 'dependency\s*\(?\s*[''"][^''"]+[''"]') | ForEach-Object { $_.Value })
            $r.deps = @($blocks | ForEach-Object { [regex]::Matches($_, '[''"]([^''"]+)[''"]') | ForEach-Object { $_.Groups[1].Value.Trim() } } |
                Where-Object { $_ -and -not $_.StartsWith('/') } | Sort-Object -Unique)
        }
        # V12.59 · Voiture livrée avec un petit fichier de noms (vehicle_names.lua : AddTextEntry) : rangée « script » et jamais
        #     installée (Jester MK4, Bati 801, Sentinel GTS, Itali GTO du 15/10). Si son code ne fait que nommer le modèle (aucun
        #     événement réseau, commande, export, accès fichier / web, rien côté serveur), c'est une voiture.
        $vehOnly = $false
        if ($lua.Count -gt 0 -and -not $fxap -and (@($all | Where-Object { $_.Extension -ieq '.yft' }).Count -gt 0 -or $r.models.Count -gt 0) -and
            ($lua | Measure-Object Length -Sum).Sum -lt 30KB -and "$mtext" -notmatch 'server_script') {
            $vcode = ($lua | ForEach-Object { Get-Content -LiteralPath $_.FullName -Raw -ErrorAction SilentlyContinue }) -join "`n"
            $vehOnly = $vcode -notmatch '(?i)Trigger(Server|Client)Event|Register(Net|Server)Event|AddEventHandler|RegisterCommand|exports|PerformHttpRequest|\bload(string)?\s*\(|\b(os|io)\.|ExecuteCommand|Kvp|Identifier|DropPlayer|SetEntity|GiveWeapon|NetworkRequest|[\x00-\x08]'
        }
        if ($vehOnly) {
            $r.type = 'vehicule'; $r.install = $true
            [void]$r.notes.Add("voiture avec un petit script de noms ($(@($lua | ForEach-Object { $_.Name }) -join ', ')) : relu automatiquement (il ne fait que nommer le modèle), installée")
        } elseif ($lua.Count -gt 0 -and -not $escrowMap) {
            $r.type = 'script'
            $code = ($lua | ForEach-Object { Get-Content -LiteralPath $_.FullName -Raw -ErrorAction SilentlyContinue }) -join "`n"
            # Script compatible plusieurs frameworks (Config.Framework = 'esx' / 'qb') : pas un script ESX seul
            $qb = $code -match "qb-core|QBCore|qbx_core|qbx"
            if ($code -match 'es_extended|ESX\.' -and -not $qb) { [void]$r.issues.Add('script ESX : incompatible avec notre base Qbox (à réécrire)') }
            if ($qb) { [void]$r.notes.Add('script QBCore / Qbox : souvent compatible, à tester') }
            # Fichiers chiffrés par Cfx (escrow) : illisibles par nature, ce n'est pas de l'obfuscation
            if (-not $fxap -and ($code -split "`n" | Where-Object { $_.Length -gt 5000 }).Count -gt 0) { [void]$r.issues.Add('code obfusqué (lignes illisibles) : risque sécurité, refusé') }
            [void]$r.notes.Add('script : je le relis avant installation (sécurité, performance, doublons avec nos gs_*)')
        } elseif ($escrowMap -and $r.models.Count -eq 0 -and @($all | Where-Object { $_.Extension -match '^\.(ymap|ytyp|ybn)$' }).Count -gt 0) { $r.type = 'map'; $r.install = $true }
        elseif (@($all | Where-Object { $_.Extension -match '^\.(yft)$' }).Count -gt 0 -or $r.models.Count -gt 0) { $r.type = 'vehicule'; $r.install = $true }
        elseif (@($all | Where-Object { $_.Extension -match '^\.(ymap|ytyp|ybn)$' }).Count -gt 0) { $r.type = 'map'; $r.install = $true }
        else { $r.type = 'vetement'; $r.install = $true }
    } else {
        $yft = & $ext '.yft'; $ymap = @($all | Where-Object { $_.Extension -match '^\.(ymap|ytyp)$' }); $ydd = & $ext '.ydd'; $rpf = & $ext '.rpf'
        if ($yft.Count -gt 0) {
            $r.type = 'vehicule'
            if ($r.models.Count -eq 0) { [void]$r.notes.Add('pas de vehicles.meta : véhicule de remplacement (remplace un modèle du jeu)') }
            $r.install = $true
        } elseif ($ymap.Count -gt 0) { $r.type = 'map'; $r.install = $true }
        elseif ($ydd.Count -gt 0 -or @($all | Where-Object { $_.Name -match '^(jbib|lowr|feet|uppr|accs|hair|teef|decl|task|p_head|p_eyes)_' }).Count -gt 0) {
            $r.type = 'vetement'
            if (@($all | Where-Object { $_.Name -match '\^' }).Count -gt 0 -and @($all | Where-Object { $_.Extension -ieq '.ymt' }).Count -gt 0) { $r.install = $true }
            elseif ($Converted[$r.name]) { $r.type = 'converti'; [void]$r.notes.Add("déjà converti : c'est $($Converted[$r.name]) (à mettre dans mods-a-trier)") }
            # V12.59 : « uppr_ » existe aussi chez les persos FiveM (mp_f_freemode / mp_m_freemode : torse, robes) : refusé
            #     seulement s'il n'y a aucune trace de perso FiveM (avant : robe Strut « madison » refusée à tort)
            elseif (@($all | Where-Object { $_.FullName -match '(?i)franklin|trevor|mich(ae|ea)l|player_(zero|one|two)' }).Count -gt 0 -or
                    (@($all | Where-Object { $_.Name -match '^uppr_' }).Count -gt 0 -and
                     @($all | Where-Object { $_.FullName -match '(?i)freemode|mp[ _-]?(fe)?male|for[ _-]mp' }).Count -eq 0)) {
                $r.type = 'rejete'; [void]$r.issues.Add('vêtement pour Franklin / Michael / Trevor (perso solo) : pas convertible pour les persos FiveM')
            } elseif ($ydd.Count -eq 0) {
                $r.type = 'rejete'; [void]$r.issues.Add('textures seules (recoloration d''un vêtement du jeu) : pas convertible en ajout')
            } else { $r.type = 'convertir'; [void]$r.issues.Add('vêtement au format solo (remplace un vêtement du jeu) : à convertir en ajout FiveM — je peux le faire si tu me l''envoies') }
        } elseif ($rpf.Count -gt 0) { $r.type = 'convertir'; [void]$r.issues.Add('mod solo (dlc.rpf) : ouvrir avec OpenIV ou CodeWalker et extraire le contenu, puis relancer') }
        else { [void]$r.issues.Add('rien d''utilisable pour FiveM trouvé') }
    }
    if ($r.issues | Where-Object { $_ -match 'escrow|ESX|obfusqué' }) { $r.install = $false; $r.type = 'rejete' }
    # V12.48 : déjà converti par nos soins (ROADTRIP-…) ou refusé à la main : prioritaire sur l'analyse automatique
    if ($Converted[$r.name] -and $r.type -ne 'converti') {
        $r.type = 'converti'; $r.install = $false; $r.issues.Clear()
        [void]$r.notes.Add("déjà converti : c'est $($Converted[$r.name]) (à mettre dans mods-a-trier) ; l'ancienne copie gsa_$($r.name) n'est plus démarrée")
    }
    if ($Refused[$r.name]) { $r.type = 'rejete'; $r.install = $false; $r.issues.Clear(); [void]$r.issues.Add($Refused[$r.name]) }
    if ($brandHit) { $r.install = $false; $r.type = 'rejete'; [void]$r.issues.Add('marque réelle (voiture, mode, police) : refusé, risque de retrait du serveur par Cfx.re / Rockstar. Cherche une version « lore GTA »') }
    if ($r.sizeMB -gt 300 -and $r.install) { $r.install = $false; [void]$r.issues.Add('trop lourd pour être installé tel quel (> 300 Mo) : on choisira 2 ou 3 éléments du pack') }
    if ($big.Count -gt 0 -and $r.install) { $r.install = $false; [void]$r.issues.Add('pas installé : à optimiser d''abord (fichier > 16 Mo). Je peux l''alléger si tu me l''envoies') }
    return [pscustomobject]$r
}

function Write-Manifest($dir, $r) {
    $meta = @(Get-ChildItem -LiteralPath $dir -Recurse -File -Filter '*.meta')
    $ytyp = @(Get-ChildItem -LiteralPath $dir -Recurse -File -Filter '*.ytyp')
    $lines = @("-- Généré par IMPORTER-MODS (GTA SOON) : $($r.source)", "fx_version 'cerulean'", "game 'gta5'", "lua54 'yes'", '')
    if ($r.type -eq 'map') { $lines += "this_is_a_map 'yes'" }
    if ($meta.Count -gt 0) { $lines += "files { 'data/**/*.meta' }" }
    $kinds = @{ 'handling.meta' = 'HANDLING_FILE'; 'vehicles.meta' = 'VEHICLE_METADATA_FILE'; 'carcols.meta' = 'CARCOLS_FILE'
        'carvariations.meta' = 'VEHICLE_VARIATION_FILE'; 'vehiclelayouts.meta' = 'VEHICLE_LAYOUTS_FILE' }
    foreach ($k in $kinds.Keys) { if ($meta | Where-Object { $_.Name -ieq $k }) { $lines += "data_file '$($kinds[$k])' 'data/**/$k'" } }
    foreach ($y in $ytyp) { $lines += "data_file 'DLC_ITYP_REQUEST' 'stream/$($y.Name)'" }
    [IO.File]::WriteAllLines((Join-Path $dir 'fxmanifest.lua'), $lines, (New-Object Text.UTF8Encoding $false))
}

#--- Crée une ressource FiveM propre : stream\ (modèles, textures, collisions) + data\ (fichiers .meta), sans doublons.
function Build-Resource($r, $dest) {
    if (Test-Path -LiteralPath $dest) { Remove-Item -LiteralPath $dest -Recurse -Force }
    $existing = Get-ChildItem -LiteralPath $r.root -Recurse -File -Force | Where-Object { $_.Name -ieq 'fxmanifest.lua' -or $_.Name -ieq '__resource.lua' } | Select-Object -First 1
    if ($existing) { Copy-Item -LiteralPath $r.root -Destination $dest -Recurse -Force; return }
    [void][IO.Directory]::CreateDirectory((Join-Path $dest 'stream'))
    [void][IO.Directory]::CreateDirectory((Join-Path $dest 'data'))
    foreach ($f in Get-ChildItem -LiteralPath $r.root -Recurse -File) {
        if ($f.Extension -match '^\.(yft|ytd|ydr|ydd|ybn|ymap|ytyp|ycd|ymt|ynv|ypt|awc|rel)$') { Copy-Item -LiteralPath $f.FullName -Destination (Join-Path $dest 'stream') -Force }
        elseif ($f.Extension -ieq '.meta') {
            $sub = Join-Path $dest ('data\' + (Clean-Name $f.Directory.Name))
            [void][IO.Directory]::CreateDirectory($sub)
            Copy-Item -LiteralPath $f.FullName -Destination $sub -Force
        }
    }
    Write-Manifest $dest $r
}

# Optimiseur de textures (tools\textures) : .ytd trop lourds allégés avant installation (« Oversized assets » dans la console).
$TexKit = Join-Path $PSScriptRoot '..\..\tools\textures'
$TexReady = $false
# Actif par défaut (ne touche que les fichiers au-dessus de la limite FiveM). Pour le couper : GTASOON_TEXOPT=0.
if ($env:GTASOON_TEXOPT -ne '0') { try {
    # Fichiers venus d'Internet (zip) : Windows les bloque (« opération non prise en charge ») → débloqués d'abord
    Get-ChildItem -LiteralPath $TexKit -File -ErrorAction SilentlyContinue | Unblock-File -ErrorAction SilentlyContinue
    foreach ($d in 'SharpDX.dll', 'SharpDX.Mathematics.dll', 'CodeWalker.Core.dll', 'GtaSoonTex.dll') { Add-Type -Path (Join-Path $TexKit $d) }
    $TexReady = $true
} catch { Say "  Optimiseur de textures indisponible ($($_.Exception.Message)) : mods installés sans optimisation" 'Yellow' } }
# Mémoire réelle d'un fichier du jeu (en-tête RSC7 : mêmes chiffres que « uses X MiB of physical memory » de FiveM).
function Get-RscMemory([string]$path) {
    $fs = [IO.File]::OpenRead($path)
    try { $b = New-Object byte[] 16; if ($fs.Read($b, 0, 16) -lt 16) { return $null } } finally { $fs.Dispose() }
    if ([BitConverter]::ToUInt32($b, 0) -ne 0x37435352) { return $null }   # 'RSC7'
    $size = { param([uint32]$f)
        $n = ((($f -shr 27) -band 1)) + ((($f -shr 26) -band 1) -shl 1) + ((($f -shr 25) -band 1) -shl 2) + ((($f -shr 24) -band 1) -shl 3) +
             ((($f -shr 17) -band 0x7F) -shl 4) + ((($f -shr 11) -band 0x3F) -shl 5) + ((($f -shr 7) -band 0xF) -shl 6) +
             ((($f -shr 5) -band 3) -shl 7) + ((($f -shr 4) -band 1) -shl 8)
        [long](0x200 -shl ($f -band 0xF)) * $n }
    [pscustomobject]@{ virt = (& $size ([BitConverter]::ToUInt32($b, 8))); phys = (& $size ([BitConverter]::ToUInt32($b, 12))) }
}
# Seuil au-delà duquel FiveM signale « Oversized assets » (crash du streamer possible, surtout à plusieurs).
$OversizedMB = 48
function Get-Oversized($dir) {
    $list = @()
    foreach ($f in @(Get-ChildItem -LiteralPath $dir -Recurse -File -Force | Where-Object { $_.Extension -match '^\.(ytd|yft|ydd|ydr)$' })) {
        $m = Get-RscMemory $f.FullName
        if ($m -and ($m.phys -gt $OversizedMB * 1MB -or $m.virt -gt 64MB)) { $list += "$($f.Name) ($(MB ([math]::Max($m.phys, $m.virt))) Mo)" }
    }
    return $list
}

function Optimize-Textures($dir, $r) {
    if (-not $TexReady -or $r.escrow) { return }   # pack protégé (escrow) : fichiers chiffrés, on n'y touche jamais
    # Seulement les fichiers au-dessus de la limite FiveM : ceux qui marchent déjà ne sont pas touchés
    foreach ($f in @(Get-ChildItem -LiteralPath $dir -Recurse -File -Filter '*.ytd' | Where-Object { $m = Get-RscMemory $_.FullName; $m -and $m.phys -gt $OversizedMB * 1MB })) {
        try {
            # Budget 34 Mo de données : une fois arrondi par le jeu (pages mémoire), on reste sous la limite de 48 Mo
            $res = [GtaSoon.Tex]::Ytd($f.FullName, 34MB, 512)
            if ($res -and [long]($res -split '\|')[1] -gt 36MB) {   # encore trop lourd : 2e passage, textures jusqu'à 256 px
                $res2 = [GtaSoon.Tex]::Ytd($f.FullName, 34MB, 256)
                if ($res2) { $res = ($res -split '\|')[0] + '|' + ($res2 -split '\|')[1] }
            }
            if ($res) { $a, $b = $res -split '\|'; [void]$r.notes.Add("textures $($f.Name) allégées : $(MB $a) → $(MB $b) Mo en mémoire") }
        } catch { [void]$r.notes.Add("textures $($f.Name) : optimisation impossible, gardé tel quel") }
    }
}

Say "[2/3] Analyse et tri" 'Cyan'
$results = @()
foreach ($p in $packages) {
    try {
        $r = Analyze $p
        if ($BrokenPkg[$p.FullName]) { # V12.27 : jamais installé, et désactivé s'il l'était déjà (voir addons.cfg plus bas)
            $r.install = $false; $r.type = 'rejete'; $r.broken = $BrokenPkg[$p.FullName]
            [void]$r.issues.Add("archive incomplète ($($r.broken)) : un fichier tronqué fait planter les joueurs. Retélécharge-la depuis la boutique (portail Cfx) puis relance IMPORTER-MODS")
        }
        $results += $r
    } catch { $script:ImportFailed = $true; Say "  $($p.Name) : analyse impossible ($($_.Exception.Message))" 'Yellow' }
}
# V12.44 · Doublons (même mod dans deux archives : zip d'origine + zip WeTransfer, « pack » et « pack_1 ») : traité une seule fois
# V12.59 : même taille à l'octet près et même nombre de fichiers (avant : taille arrondie au dixième de Mo, deux mods
# différents « x_2 » / « x_3 » de taille proche, ou les morceaux d'un zip Drive, passaient pour des doublons et le 2e sautait)
$seenMods = @{}
$results = @($results | Where-Object {
    $k = ($_.name -replace '_\d+$', '') + '|' + $_.bytes + '|' + $_.nfiles
    if ($seenMods[$k]) { Say "  doublon ignoré : $($_.name) (même mod que $($seenMods[$k]))" 'DarkGray'; $false } else { $seenMods[$k] = $_.name; $true }
})
# V12.16 : mods retirés par le staff (F11 → Supprimer définitivement les maps) : jamais réinstallés, même depuis une archive groupée
$RetiredFile = Join-Path $Root 'mods-retires.txt'
$Retired = @()
if (Test-Path -LiteralPath $RetiredFile) {
    $Retired = @(Get-Content -LiteralPath $RetiredFile | ForEach-Object { $_.Trim().ToLower() } | Where-Object { $_ -and -not $_.StartsWith('#') })
    # V12.31 : maps remises en service après un retrait (12/10 : on garde la villa bunker, c'est la villa 01 qui part) :
    # sorties de mods-retires.txt pour être réinstallées depuis leur archive, gardée dans mods-a-trier.
    $Restored = @() # V12.36 : migration V12.31 (villa bunker) terminée le 12/10 ; miroir de RESTORED_MAPS dans maps.js
    if (@($Retired | Where-Object { $Restored -contains $_ }).Count -gt 0) {
        $Retired = @($Retired | Where-Object { $Restored -notcontains $_ })
        $kept = @(Get-Content -LiteralPath $RetiredFile | Where-Object { $Restored -notcontains $_.Trim().ToLower() })
        [IO.File]::WriteAllLines($RetiredFile, $kept, (New-Object Text.UTF8Encoding $false))
        Say "  Remis en service (retiré de mods-retires.txt) : $($Restored -join ', ')" 'Green'
    }
}
# V12.34 : maps retirées par décision (RETIRED_MAPS de gs_admin/server/maps.js) refusées DÈS l'import, même si le serveur
# n'a pas encore redémarré pour les noter dans mods-retires.txt (dossiers supprimés à la main puis METTRE-A-JOUR : avant,
# l'import les réinstallait depuis mods-a-trier, avec leur script compagnon, jusqu'au prochain démarrage du serveur).
# V12.36 : et par MOTIF (RETIRED_PATTERNS de maps.js : sous-chaînes en minuscules, plasmagame, redline…). Une archive ou une
# ressource dont le nom contient un motif n'est jamais installée, son script compagnon non plus, et leurs lignes de addons.cfg
# sont enlevées : plasmagame_dlc2 et le pack Redline revenaient à chaque import, seuls les noms exacts étant refusés.
$RetiredPatterns = @()
foreach ($mj in @((Join-Path $PSScriptRoot '..\..\server\resources\[gtasoon]\gs_admin\server\maps.js'), (Join-Path $Data 'resources\[gtasoon]\gs_admin\server\maps.js'))) {
    if (-not (Test-Path -LiteralPath $mj)) { continue }
    $mjText = Get-Content -LiteralPath $mj -Raw
    $block = [regex]::Match($mjText, '(?s)const RETIRED_MAPS = \[(.*?)\];').Groups[1].Value
    $Retired += @([regex]::Matches($block, "'gsa_([a-z0-9_]+)'") | ForEach-Object { $_.Groups[1].Value })
    $block = [regex]::Match($mjText, '(?s)const RETIRED_PATTERNS = \[(.*?)\];').Groups[1].Value
    $RetiredPatterns = @([regex]::Matches($block, "'([a-z0-9_]+)'") | ForEach-Object { $_.Groups[1].Value })
    break
}
$Retired = @($Retired | Sort-Object -Unique)
# Pourquoi un nom (archive, dossier de ressource, ligne de addons.cfg) est retiré : texte de la raison, ou $null s'il ne l'est pas
function Test-Retired([string]$n) {
    if (-not $n) { return $null }
    $n = $n.ToLower()
    if ($Retired -contains ($n -replace '^gsa_', '')) { return 'mods-retires.txt / RETIRED_MAPS' }
    foreach ($p in $RetiredPatterns) { if ($n.Contains($p)) { return "motif « $p », RETIRED_PATTERNS" } }
    return $null
}
foreach ($r in $results) {
    $hit = Test-Retired $r.name
    if (-not $hit -and $r.root) { $hit = Test-Retired (Split-Path $r.root -Leaf) }   # dossier de la ressource dans un pack à plusieurs dossiers
    if ($hit) { $r.install = $false; $r.type = 'rejete'; [void]$r.issues.Add("retiré par le staff ($hit) : jamais réinstallé") }
}

# 2b. V12.31 · Scripts COMPAGNONS des maps payantes. Un pack (laser game, villa bunker, auto-tamponneuses…) livre souvent la
#     map et son script dans deux dossiers : la map était installée, le script rangé dans scripts-a-verifier → « les maps
#     sont là mais les scripts ne démarrent pas ». Un script chiffré (escrow, même vendeur) dont le nom correspond à une map
#     installée est installé avec elle, sous son NOM D'ORIGINE (ses exports et dépendances l'appellent par ce nom), si :
#     pas ESX seul (déjà refusé plus haut) et toutes ses dépendances présentes sur le serveur (ou dans le même import).
#     Un script lisible (non chiffré) reste à relire avant installation, comme avant.
$Provides = @{ 'qb-core' = 'qbx_core'; 'qb-target' = 'ox_target'; 'qtarget' = 'ox_target'; 'mysql-async' = 'oxmysql'; 'ghmattimysql' = 'oxmysql' }
$Generic = 'patoche', 'script', 'scripts', 'pack', 'client', 'server', 'fivem', 'resource', 'escrow', 'master', 'release', 'version', 'final', 'update'
$haveRes = @{}
if (Test-Path -LiteralPath (Join-Path $Data 'resources')) {
    foreach ($m in @(Get-ChildItem -LiteralPath (Join-Path $Data 'resources') -Recurse -File -Include 'fxmanifest.lua', '__resource.lua' -ErrorAction SilentlyContinue)) { $haveRes[$m.Directory.Name.ToLower()] = $true }
}
$mapNames = @($results | Where-Object { $_.install -and $_.type -eq 'map' } | ForEach-Object { $_.name })
if (Test-Path -LiteralPath $Addons) { $mapNames += @(Get-ChildItem -LiteralPath $Addons -Directory -Filter 'gsa_*' | ForEach-Object { $_.Name.Substring(4) }) }
$mapNames = @($mapNames | Where-Object { -not (Test-Retired $_) })   # V12.36 : une map retirée (nom ou motif) n'a plus de script compagnon
$scriptPool = @{}
foreach ($r in $results) {
    if ($r.type -ne 'script' -or -not $r.escrow) { continue }
    $r.resName = ((Split-Path $r.root -Leaf) -replace '[^A-Za-z0-9_\-]', '_')
    $scriptPool[$r.resName.ToLower()] = $r
}
# V12.48 · BIBLIOTHÈQUES : un script compagnon dépend parfois d'un autre pack du même vendeur (villa bunker → patoche_interact).
#     Ce pack contient des modèles, il était donc rangé en « map » et installé en gsa_patoche_interact_pack : le nom attendu
#     (patoche_interact) n'existait pas sur le serveur. Un pack dont le dossier (ou le nom sans « _pack ») est réclamé par un
#     script de l'import est installé sous ce nom exact ; son ancienne copie gsa_… n'est plus démarrée (dossier laissé en place).
$libPool = @{}
$Superseded = @{}
foreach ($r in $results) { if ($r.type -eq 'converti') { $Superseded['gsa_' + $r.name] = $true } }
$wanted = @{}
foreach ($r in $results) { if ($r.type -eq 'script') { foreach ($d in $r.deps) { $wanted[$d.ToLower()] = $r } } }
foreach ($r in $results) {
    if ($r.type -eq 'script' -or $r.type -eq 'rejete' -or -not $r.install) { continue }
    $leaf = (Split-Path $r.root -Leaf).ToLower()
    $short = ($r.name -replace '_pack(_\d+)?$', '').ToLower()
    $hitName = @($leaf, $short) | Where-Object { $wanted.ContainsKey($_) } | Select-Object -First 1
    if (-not $hitName) { continue }
    $user = $wanted[$hitName]
    $r.resName = $hitName; $r.companion = ((Split-Path $user.root -Leaf) -replace '[^A-Za-z0-9_\-]', '_')
    $libPool[$hitName] = $r
    $Superseded['gsa_' + $r.name] = $true
    [void]$r.notes.Add("bibliothèque de $($r.companion) : installée sous le nom attendu $hitName (l'ancienne copie gsa_$($r.name) n'est plus démarrée)")
}
function Test-Dep($d) {
    $d = $d.ToLower()
    return $haveRes[$d] -or ($Provides.ContainsKey($d) -and $haveRes[$Provides[$d]]) -or $scriptPool.ContainsKey($d) -or $libPool.ContainsKey($d)
}
foreach ($r in @($scriptPool.Values)) {
    $tokens = @("$($r.name)_$($r.resName)".ToLower() -split '[_\-]' | Where-Object { $_.Length -ge 5 -and $Generic -notcontains $_ } | Sort-Object -Unique) # nom de l'archive + nom du dossier
    $map = $mapNames | Where-Object { $n = $_; @($tokens | Where-Object { $n -match [regex]::Escape($_) }).Count -gt 0 } | Select-Object -First 1
    if (-not $map) { [void]$r.notes.Add('script payant seul : aucune map installée ne lui correspond, pas installé (dis-moi si tu le veux)'); continue }
    $missing = @($r.deps | Where-Object { -not (Test-Dep $_) })
    if ($missing.Count -gt 0) { [void]$r.issues.Add("script de la map gsa_$map pas installé : il lui manque $($missing -join ', ') sur le serveur"); continue }
    $r.install = $true; $r.companion = "gsa_$map"
    [void]$r.notes.Add("script compagnon de la map gsa_$map : installé sous son nom d'origine $($r.resName). Marche seulement si map ET script ont été achetés avec le compte Cfx.re de la clé du serveur")
    foreach ($d in $r.deps) {
        $dep = $scriptPool[$d.ToLower()]
        if ($dep -and -not $dep.install) { $dep.install = $true; $dep.companion = $r.resName; [void]$dep.notes.Add("installé : dépendance de $($r.resName)") }
    }
}
# Installés : les notes « pas installé / je le relis / aucune map » ne valent plus pour eux
foreach ($r in @($scriptPool.Values | Where-Object { $_.install })) {
    $old = @($r.notes | Where-Object { $_ -match 'pas installé automatiquement|je le relis|aucune map installée' })
    foreach ($o in $old) { $r.notes.Remove($o) }
}

# 3. Rangement + installation des bons ---------------------------------------------------------------------------------
Say "[3/3] Rangement dans $Out et installation dans resources\[addons]" 'Cyan'
foreach ($c in $Cats.Values) { [void][IO.Directory]::CreateDirectory((Join-Path $Out $c)) }
$installed = @()
$canInstall = Test-Path -LiteralPath (Join-Path $Data 'resources')
if ($canInstall) { [void][IO.Directory]::CreateDirectory($Addons) }
foreach ($r in $results) {
    $sorted = Join-Path (Join-Path $Out $Cats[$r.type]) $r.name
    try { Build-Resource $r $sorted } catch { [void]$r.issues.Add("rangement impossible : $($_.Exception.Message)"); $r.install = $false }
    if ($r.install) {
        Optimize-Textures $sorted $r
        # Sécurité : vêtements convertis (jamais testés en jeu) installés mais DÉSACTIVÉS dans addons.cfg
        # Encore trop lourd après allègement : mis en pause (crash « bad_alloc » / « Streamer crashed » sur les PC à 8 Go).
        # Le joueur peut le forcer en retirant le # dans addons.cfg (son choix est gardé).
        $heavy = @(Get-Oversized $sorted)
        if ($heavy.Count -gt 0) { $r.risk = "trop lourd même allégé : $($heavy[0]) — cherche une version 2K / FiveM ready" }
        elseif ($r.name -like 'roadtrip_vetements_*') { $r.risk = 'vêtements convertis, à tester un par un' }   # coiffures : validées
        if ($r.risk) { [void]$r.issues.Add("désactivé par sécurité ($($r.risk)) : pour tester, retire le # de sa ligne dans cfg\addons.cfg") }
    }
    if ($r.install -and $canInstall) {
        $name = if ($r.resName -and $r.companion) { $r.resName } else { 'gsa_' + $r.name } # script compagnon : nom d'origine
        $dest = Join-Path $Addons $name
        try {
            if (Test-Path -LiteralPath $dest) { Remove-Item -LiteralPath $dest -Recurse -Force }
            Copy-Item -LiteralPath $sorted -Destination $dest -Recurse -Force
            # V12.5 : les fichiers gardent la date de l'archive (ex. 2024) ; METTRE-A-JOUR-OVH n'envoie que ce qui a changé
            # depuis le dernier envoi → un mod tout juste importé n'arrivait jamais sur le VPS. On le date d'aujourd'hui.
            $now = Get-Date
            Get-ChildItem -LiteralPath $dest -Recurse -File -Force | ForEach-Object { $_.LastWriteTime = $now }
            $installed += $name
        } catch {
            [void]$r.issues.Add("installation impossible (fichier utilisé par un autre programme : serveur lancé ?) — ferme le serveur puis relance")
            $script:ImportFailed = $true
            if (Test-Path -LiteralPath $dest) { $installed += $name }   # l'ancienne version reste en place
        }
    }
}

# 3b. V12.53 · OBJETS réclamés par les scripts installés (jetons d'auto-tamponneuses, tickets, pièces de jeu…). Un objet absent
#     d'ox_inventory = achat qui échoue sans message (« je ne peux pas acheter de jeton »). On lit les fichiers lisibles du
#     script (config.lua : l'escrow ne chiffre presque jamais la config) et on ajoute à ox_inventory les objets qui manquent.
$Accounts = 'money', 'cash', 'bank', 'black_money', 'dirty_money', 'markedbills', 'crypto'
function Get-ScriptItems($dir) {
    $names = @{}
    foreach ($f in @(Get-ChildItem -LiteralPath $dir -Recurse -File -Filter '*.lua' -ErrorAction SilentlyContinue)) {
        $t = [IO.File]::ReadAllText($f.FullName)
        if ($t -match '[\x00-\x08]') { continue } # chiffré (escrow) : illisible
        $rx = @('(?i)\w*(?:item|token|ticket|coin|jeton)(?:name)?s?\s*=\s*[''"]([a-z0-9_]{3,40})[''"]',
                '(?i)\b(?:AddItem|RemoveItem|HasItem|GetItemCount|GetItemByName|CanCarryItem)\s*\(\s*(?:[^,()''"]+,\s*)?[''"]([a-z0-9_]{3,40})[''"]')
        foreach ($x in $rx) { foreach ($m in [regex]::Matches($t, $x)) { $names[$m.Groups[1].Value.ToLower()] = $true } }
    }
    @($names.Keys | Where-Object { $Accounts -notcontains $_ -and $_ -notmatch '^(weapon_|ammo)' })
}
$oxItems = if ($canInstall) { Get-ChildItem -LiteralPath (Join-Path $Data 'resources') -Recurse -Filter 'items.lua' -ErrorAction SilentlyContinue |
    Where-Object { $_.FullName -match 'ox_inventory[\\/]data[\\/]items\.lua$' } | Select-Object -First 1 }
if ($oxItems) {
    $known = [IO.File]::ReadAllText($oxItems.FullName)
    $newItems = @()
    foreach ($r in @($results | Where-Object { $_.install -and ($_.type -eq 'script' -or $_.type -eq 'map') })) { # map + script dans un même pack aussi
        $dest = Join-Path $Addons $(if ($r.resName -and $r.companion) { $r.resName } else { 'gsa_' + $r.name })
        if (-not (Test-Path -LiteralPath $dest)) { continue }
        $missing = @(Get-ScriptItems $dest | Where-Object { $known -notmatch ("\[\s*['""]" + [regex]::Escape($_) + "['""]\s*\]\s*=") -and $newItems -notcontains $_ })
        if ($missing.Count -eq 0) { continue }
        $newItems += $missing
        [void]$r.notes.Add("objets du script ajoutés à ox_inventory (ils n'existaient pas : achat impossible avant) : $($missing -join ', ')")
    }
    if ($newItems.Count -gt 0) {
        $lines = foreach ($n in $newItems) {
            $label = if ($n -match 'token|coin|jeton') { 'Jeton' } elseif ($n -match 'ticket') { 'Ticket' } else { (Get-Culture).TextInfo.ToTitleCase(($n -replace '_', ' ')) }
            "    ['$n'] = { label = '$label', weight = 1, stack = true, close = true, description = 'Objet d\'un script importé (IMPORTER-MODS).' }," # Lua : apostrophe échappée par \'
        }
        $i = $known.LastIndexOf('}')
        $known = $known.Substring(0, $i).TrimEnd() + "`n`n    -- Objets des scripts importés (IMPORTER-MODS, V12.53)`n" + ($lines -join "`n") + "`n" + $known.Substring($i)
        [IO.File]::WriteAllText($oxItems.FullName, $known, (New-Object Text.UTF8Encoding($false)))
        Say "  ox_inventory : $($newItems.Count) objet(s) de scripts importés ajouté(s) ($($newItems -join ', '))" 'Green'
    }
}
if ($canInstall) {
    $cfg = @('## Mods importés par IMPORTER-MODS.bat (véhicules, vêtements, maps). Ce fichier n''est jamais écrasé par METTRE-A-JOUR.',
        '## Mets un # devant une ligne pour désactiver un mod.',
        '## « désactivé par sécurité » = pas encore testé en jeu : retire le # pour l''essayer, ton choix est gardé.')
    $previous = Join-Path $Data 'cfg\addons.cfg'
    $keep = @()
    if (Test-Path -LiteralPath $previous) { $keep = @(Get-Content -LiteralPath $previous | Where-Object { $_ -match '^#?\s*ensure gsa_' -or
        # V12.31 : scripts compagnons (nom d'origine), gardés tant que leur dossier existe
        ($_ -match '^#?\s*ensure\s+(\S+)' -and (Test-Path -LiteralPath (Join-Path $Addons $Matches[1]))) }) }
    $names = @($installed) + @($keep | ForEach-Object { (($_ -replace '^#?\s*ensure\s+', '').Trim() -split '\s+')[0] }) | Sort-Object -Unique
    $names = @($names | Where-Object { -not $Superseded[$_] })   # V12.48 : copie gsa_ remplacée (version convertie, bibliothèque sous son vrai nom)
    $names = @($names | Where-Object { -not (Test-Retired $_) }) # V12.34 : lignes des maps retirées enlevées ; V12.36 : par motif aussi, scripts compagnons compris
    $notes = @()
    if (Test-Path -LiteralPath $previous) { $notes = @(Get-Content -LiteralPath $previous | Where-Object { $_ -match '^## gsa_\S+ : désactivé' } | ForEach-Object { ($_ -split '\s+')[1] }) }
    $risks = @{}
    foreach ($r in $results) { if ($r.install -and $r.risk) { $risks['gsa_' + $r.name] = $r.risk } }
    $forceOff = @{} # V12.27 : archive incomplète → désactivé d'office, même si le # avait été retiré
    foreach ($r in $results) { if ($r.broken) { $forceOff['gsa_' + $r.name] = "archive incomplète $($r.broken), retélécharge-la puis relance IMPORTER-MODS" } }
    foreach ($n in $names) {
        if ($forceOff.ContainsKey($n)) {
            $cfg += "## $n : désactivé par sécurité ($($forceOff[$n]))"
            $cfg += "# ensure $n"
            continue
        }
        $line = $keep | Where-Object { $_ -match ('^#?\s*ensure\s+' + [regex]::Escape($n) + '(\s|$)') } | Select-Object -First 1
        $wasOff = $line -and $line -match '^#'
        # Mod déjà désactivé par sécurité et dont le joueur a retiré le # : son choix est respecté
        $forcedOn = $line -and -not $wasOff -and ($notes -contains $n)
        if ($risks.ContainsKey($n)) {
            $cfg += "## $n : désactivé par sécurité ($($risks[$n])), retire le # de la ligne suivante pour l'activer"
            $cfg += $(if ($forcedOn) { "ensure $n" } else { "# ensure $n" })
        } elseif ($notes -contains $n) {
            $cfg += "ensure $n"   # était en pause « par sécurité », la raison a disparu (allégé, validé) : réactivé
        } else { $cfg += $(if ($wasOff) { "# ensure $n" } else { "ensure $n" }) }
    }
    [IO.File]::WriteAllLines($previous, $cfg, (New-Object Text.UTF8Encoding $false))
}

# Catalogue Qbox : les véhicules installés sont ajoutés à qbx_core\shared\vehicles.lua (concession, garages, prix),
# dans un bloc balisé réécrit à chaque import (le reste du fichier n'est pas touché).
# Prix et noms affichés à la concession, par nom de spawn (sinon : prix de la catégorie, nom du fichier). Marques
# réelles interdites (voir $BrandBlock) : noms « lore GTA » uniquement (Pegassi, Grotti, Übermacht…).
$Prices = @{}
$Labels = @{} # ex. : @{ monmodele = @('Pegassi Zentorno R', 'Pegassi', 'super') }
$ClassMap = @{ VC_SUPER = @('super', 1500000); VC_SPORT = @('sports', 250000); VC_SPORT_CLASSIC = @('sportsclassics', 200000); VC_SUV = @('suvs', 120000)
    VC_SEDAN = @('sedans', 60000); VC_COMPACT = @('compacts', 30000); VC_MUSCLE = @('muscle', 85000); VC_COUPE = @('coupes', 90000)
    VC_OFF_ROAD = @('offroad', 70000); VC_MOTORCYCLE = @('motorcycles', 40000); VC_VAN = @('vans', 45000); VC_EMERGENCY = @('emergency', 0) }
$Brands = 'pegassi', 'grotti', 'truffade', 'ubermacht', 'benefactor', 'obey', 'pfister', 'bravado', 'vapid', 'declasse', 'albany', 'dewbauchee', 'enus', 'karin', 'dinka', 'annis', 'ocelot', 'progen', 'coil'
$vehEntries = @()
# Catalogue construit depuis TOUS les mods installés et actifs (pas seulement ceux de cet import : sinon un import de
# vêtements seuls viderait la concession).
$sources = @()
if ($canInstall) {
    $active = @(Get-Content -LiteralPath (Join-Path $Data 'cfg\addons.cfg') | Where-Object { $_ -match '^\s*ensure\s+gsa_' } | ForEach-Object { (($_ -replace '^\s*ensure\s+', '').Trim() -split '\s+')[0] })
    foreach ($dir in @(Get-ChildItem -LiteralPath $Addons -Directory -Filter 'gsa_*' | Where-Object { $active -contains $_.Name })) {
        # Véhicule d'un pack payant protégé (auto-tamponneuse, kart…) : fait pour son script, pas pour la concession
        if (Test-Path -LiteralPath (Join-Path $dir.FullName '.fxap')) { continue }
        $sources += [pscustomobject]@{ name = $dir.Name.Substring(4); root = $dir.FullName }
    }
}
$seen = @{}
foreach ($r in $sources) {
    # Modèles réellement livrés (.yft présent) : certains packs déclarent des voitures sans leurs fichiers 3D
    $yfts = @(Get-ChildItem -LiteralPath $r.root -Recurse -File -Force -Filter '*.yft' | ForEach-Object { $_.BaseName.ToLower() })
    foreach ($m in @(Get-ChildItem -LiteralPath $r.root -Recurse -File -Force | Where-Object { $_.Name -ieq 'vehicles.meta' })) {
        try { [xml]$doc = Get-Content -LiteralPath $m.FullName -Raw } catch { continue }
        foreach ($item in @($doc.SelectNodes('//InitDatas/Item'))) {
            $model = "$($item.modelName)".Trim().ToLower(); $vc = "$($item.vehicleClass)".Trim()
            if (-not $model -or $seen[$model]) { continue }; $seen[$model] = $true
            if ($yfts -notcontains $model) { continue }   # déclaré mais pas livré : la concession planterait (failed to load model)
            if ($vc -eq 'VC_EMERGENCY') { continue }   # véhicules de service : garages des métiers, pas la concession
            $cls = $ClassMap[$vc]; if (-not $cls) { $cls = @('sports', 150000) }
            $brand = ($Brands | Where-Object { $r.name -match $_ } | Select-Object -First 1)
            $label = (($r.name -replace '_', ' ') -replace '\b(v\d.*|by .*)$', '').Trim()
            $label = (Get-Culture).TextInfo.ToTitleCase($label)
            $price = if ($Prices.ContainsKey($model)) { $Prices[$model] } else { $cls[1] }
            $brand = if ($brand) { (Get-Culture).TextInfo.ToTitleCase($brand) } else { '' }
            $cat = $cls[0]
            if ($Labels.ContainsKey($model)) { $label = $Labels[$model][0]; $brand = $Labels[$model][1]; if ($Labels[$model][2]) { $cat = $Labels[$model][2] } }
            # Catégorie « roadtrip » : tous les véhicules importés regroupés à part à la concession (PDM)
            $vehEntries += "    ['$model'] = { name = '$($label -replace "'", '')', brand = '$brand', model = '$model', price = $price, category = 'roadtrip', type = 'automobile', hash = ``$model`` },"
        }
    }
}
$qbxVeh = $null
if ($canInstall) { $core = Find-Resource (Join-Path $Data 'resources') 'qbx_core'; if ($core) { $qbxVeh = Join-Path $core.FullName 'shared\vehicles.lua' } }
if ($qbxVeh -and (Test-Path -LiteralPath $qbxVeh)) {
    $text = [IO.File]::ReadAllText($qbxVeh)
    $text = [regex]::Replace($text, '(?s)\s*-- GTA SOON ADDONS DEBUT.*?-- GTA SOON ADDONS FIN\r?\n', "`n")
    if ($vehEntries.Count -gt 0) {
        $last = $text.LastIndexOf('}')
        # La dernière voiture du fichier Qbox n'a pas de virgule (« } » puis « } » final) : on l'ajoute, sinon Lua casse
        $before = $text.Substring(0, $last).TrimEnd()
        if (-not ($before.EndsWith(',') -or $before.EndsWith('{'))) { $text = $before + ",`n" + $text.Substring($last); $last = $text.LastIndexOf('}') }
        $blockText = "`n    -- GTA SOON ADDONS DEBUT (IMPORTER-MODS.bat : réécrit à chaque import)`n" + ($vehEntries -join "`n") + "`n    -- GTA SOON ADDONS FIN`n"
        $text = $text.Substring(0, $last) + $blockText + $text.Substring($last)
    }
    [IO.File]::WriteAllText($qbxVeh, $text, (New-Object Text.UTF8Encoding $false))
    Say "  $($vehEntries.Count) véhicule(s) ajouté(s) au catalogue Qbox (concession, garages)" 'Green'
}

# Rapport ---------------------------------------------------------------------------------------------------------------
$lines = @("RAPPORT IMPORTER-MODS · $(Get-Date -Format 'dd/MM/yyyy HH:mm') · $($results.Count) mods", '')
foreach ($grp in ($results | Group-Object type | Sort-Object Name)) {
    $lines += "=== $($Cats[$grp.Name].ToUpper()) ($($grp.Count))"
    foreach ($r in $grp.Group) {
        $lines += ("- {0} [{1} Mo]{2}{3}" -f $r.name, $r.sizeMB, $(if ($r.install -and $canInstall) { ' → INSTALLÉ (' + $(if ($r.companion) { $r.resName + ', avec ' + $r.companion } else { 'gsa_' + $r.name }) + ')' } else { '' }),
            $(if ($r.models.Count) { ' · spawn : ' + ($r.models -join ', ') } else { '' }))
        foreach ($i in $r.issues) { $lines += "    ! $i" }
        foreach ($n in $r.notes) { $lines += "    · $n" }
    }
    $lines += ''
}
$lines += 'Envoie-moi ce fichier (copier-coller) : je branche les véhicules (concession, garages), les maps (coords, blips) et je relis les scripts.'
[IO.File]::WriteAllLines($Report, $lines, (New-Object Text.UTF8Encoding $false))
# V12.59 : signature enregistrée seulement si tout s'est bien passé. Avant, un mod pas installé (serveur lancé pendant
# IMPORTER-MODS : fichiers verrouillés) n'était plus jamais retenté par METTRE-A-JOUR (« Mods : rien de nouveau »).
if ($canInstall -and -not $script:ImportFailed) { [IO.File]::WriteAllText($Stamp, $signature, (New-Object Text.UTF8Encoding $false)) }
elseif ($script:ImportFailed) {
    Remove-Item -LiteralPath $Stamp -Force -ErrorAction SilentlyContinue
    Say "  Un ou plusieurs mods n'ont pas pu être installés : ils seront retentés au prochain IMPORTER-MODS / METTRE-A-JOUR." 'Yellow'
}
# Copie décompressée temporaire (1 à 3 Go) : supprimée, elle est refaite au prochain import
if (Test-Path -LiteralPath $Work) { Remove-Item -LiteralPath $Work -Recurse -Force -ErrorAction SilentlyContinue }
Say "`nTerminé : $($results.Count) mods analysés, $($installed.Count) installés." 'Green'
Say "Rapport : $Report" 'Green'
if (-not $canInstall) { Say "Serveur non installé ($Data) : rien d'installé, tout est rangé dans $Out." 'Yellow' }
if (-not $env:GTASOON_TEST -and -not $env:GTASOON_CHAIN) { Start-Process notepad.exe $Report; Read-Host 'Entrée pour quitter' }
