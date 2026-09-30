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
$archives = @(Get-ChildItem -LiteralPath $Src -File | Where-Object { $_.Extension -match '^\.(zip|rar|7z)$' })
# En plus de mods-a-trier : « Google Drive pour ordinateur » (lecteur G:, H:…), dossier GTA de Mon Drive, s'il existe.
# (Un fichier présent aux deux endroits n'est pris qu'une fois.)
if (-not $env:GTASOON_ROOT) {
    foreach ($d in Get-PSDrive -PSProvider FileSystem -ErrorAction SilentlyContinue) {
        foreach ($sub in 'Mon Drive\GTA', 'My Drive\GTA') {
            $g = Join-Path $d.Root $sub
            if (Test-Path -LiteralPath $g) {
                $names = @($archives | ForEach-Object { $_.Name })
                $found = @(Get-ChildItem -LiteralPath $g -File | Where-Object { $_.Extension -match '^\.(zip|rar|7z)$' -and $names -notcontains $_.Name })
                if ($found.Count -gt 0) { Say "Dossier Google Drive trouvé : $g (+$($found.Count) archives)" 'Green'; $archives += $found }
            }
        }
    }
}
if ($archives.Count -eq 0 -and $env:GTASOON_CHAIN) {
    Say "  Mods : aucun fichier dans $Src (voitures, maps, vêtements du Drive : mets-les là, tels quels)." 'Yellow'; return
}
# Lancé par METTRE-A-JOUR : si ni les archives ni cet importeur n'ont changé depuis le dernier import, rien à refaire
# (évite de tout redécompresser à chaque mise à jour).
$Stamp = Join-Path $Out '.derniere-signature'
$signature = (@($archives | Sort-Object Name | ForEach-Object { "$($_.Name)|$($_.Length)|$($_.LastWriteTimeUtc.Ticks)" }) +
    (Get-FileHash -LiteralPath $PSCommandPath -Algorithm SHA1).Hash) -join "`n"
if ($env:GTASOON_CHAIN -and (Test-Path -LiteralPath $Stamp) -and (Get-Content -LiteralPath $Stamp -Raw).Trim() -eq $signature.Trim()) {
    Say '  Mods : rien de nouveau depuis le dernier import.' 'Green'; return
}
if ($archives.Count -eq 0) {
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
if (Test-Path -LiteralPath $Work) { Remove-Item -LiteralPath $Work -Recurse -Force }
[void][IO.Directory]::CreateDirectory($Work)
function Clean-Name([string]$n) {
    $n = [IO.Path]::GetFileNameWithoutExtension($n)
    $n = $n -replace '^[0-9a-f]{6}-', '' -replace '_\d{9,}_\d+$', ''          # préfixes / suffixes des sites de mods
    $n = ($n -replace '[^A-Za-z0-9]+', '_').Trim('_').ToLower()
    if ($n.Length -gt 40) { $n = $n.Substring(0, 40).Trim('_') }
    if (-not $n) { $n = 'mod' }
    return $n
}
#--- Décompresse une archive. Si elle contient elle-même des archives (zip du Drive = plusieurs mods), chacune
#    devient un mod séparé. Retourne la liste des dossiers « mod ».
function Expand-One($file, $dest) {
    & $7z x $file "-o$dest" -y -bso0 -bsp0 | Out-Null
    for ($depth = 0; $depth -lt 3; $depth++) { # archives dans l'archive d'un même mod (ex : pack de vêtements)
        $inner = @(Get-ChildItem -LiteralPath $dest -Recurse -File | Where-Object { $_.Extension -match '^\.(zip|rar|7z)$' })
        if ($inner.Count -eq 0) { break }
        foreach ($i in $inner) {
            & $7z x $i.FullName ("-o" + (Join-Path $i.DirectoryName ([IO.Path]::GetFileNameWithoutExtension($i.Name)))) -y -bso0 -bsp0 | Out-Null
            Remove-Item -LiteralPath $i.FullName -Force
        }
    }
}
function Expand-Package($file, $dest) {
    & $7z x $file "-o$dest" -y -bso0 -bsp0 | Out-Null
    $inner = @(Get-ChildItem -LiteralPath $dest -Recurse -File | Where-Object { $_.Extension -match '^\.(zip|rar|7z)$' })
    $loose = @(Get-ChildItem -LiteralPath $dest -Recurse -File | Where-Object { $_.Extension -notmatch '^\.(zip|rar|7z|txt|url|html?|jpe?g|png|webp)$' })
    if ($inner.Count -ge 2 -and $loose.Count -eq 0) {
        $list = @()
        foreach ($i in $inner) {
            $sub = Join-Path $Work (Clean-Name $i.Name)
            Expand-One $i.FullName $sub
            Remove-Item -LiteralPath $i.FullName -Force
            $list += Get-Item -LiteralPath $sub
        }
        Remove-Item -LiteralPath $dest -Recurse -Force
        return $list
    }
    Remove-Item -LiteralPath $dest -Recurse -Force
    Expand-One $file $dest
    return @(Get-Item -LiteralPath $dest)
}
Say "`n[1/3] Décompression de $($archives.Count) archive(s)" 'Cyan'
$packages = @()
foreach ($a in $archives) {
    Say "  $($a.Name)"
    try { $packages += Expand-Package $a.FullName (Join-Path $Work (Clean-Name $a.Name)) } catch { Say "    échec : $($_.Exception.Message)" 'Yellow' }
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
$Converted = @{ mp_male_the_goat = 'ROADTRIP-vetements_homme.zip'; brilliantovaja_cep_pervyjj_dollar = 'ROADTRIP-vetements_homme.zip'
    vine_cross_diamond_chain_mp_male = 'ROADTRIP-vetements_homme.zip'; basic = 'ROADTRIP-coiffures_femme_1.zip'; box_braids = 'ROADTRIP-coiffures_femme_1.zip'
    dreads = 'ROADTRIP-coiffures_femme_1.zip'; edgar = 'ROADTRIP-coiffures_femme_2.zip'; leopard_print = 'ROADTRIP-coiffures_femme_2.zip'
    locs = 'ROADTRIP-coiffures_femme_2.zip' }
$PackPick = @{ dallas_police = @('dpd23char', 'dpd20fpiu', 'dpd21hoe', 'dpdunchar') }
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
function Analyze($pkg) {
    $pre = New-Object System.Collections.ArrayList
    $pick = $PackPick[(Clean-Name $pkg.Name)]
    if ($pick) { $n = Pick-Models $pkg.FullName $pick; [void]$pre.Add("pack allégé : $n modèles retirés, gardés : $($pick -join ', ')") }
    $slim = @(Slim-Tuning $pkg.FullName)
    if ($slim.Count -gt 0) { [void]$pre.Add("$($slim.Count) pièces de tuning trop lourdes retirées (kit $($slim[0])…) : la voiture reste complète") }
    $all = @(Get-ChildItem -LiteralPath $pkg.FullName -Recurse -File -Force)
    $r = [ordered]@{ name = (Clean-Name $pkg.Name); source = $pkg.Name; type = 'rejete'; sizeMB = MB (($all | Measure-Object Length -Sum).Sum)
        issues = New-Object System.Collections.ArrayList; notes = $pre; root = $pkg.FullName; models = @(); install = $false; risk = $null }
    $ext = { param($e) @($all | Where-Object { $_.Extension -ieq $e }) }
    $manifest = $all | Where-Object { $_.Name -ieq 'fxmanifest.lua' -or $_.Name -ieq '__resource.lua' } | Select-Object -First 1
    $lua = @($all | Where-Object { $_.Extension -ieq '.lua' -and $_.Name -notmatch '^(fxmanifest|__resource)\.lua$' })
    $big = @($all | Where-Object { $_.Extension -match '^\.(ytd|yft|ydd|ydr)$' -and $_.Length -gt 16MB })
    foreach ($b in $big) { [void]$r.issues.Add("fichier trop lourd $($b.Name) ($(MB $b.Length) Mo > 16 Mo) : textures qui disparaissent / crash, à optimiser") }
    if ($r.sizeMB -gt 150) { [void]$r.issues.Add("mod très lourd ($($r.sizeMB) Mo) : temps de chargement et mémoire des joueurs") }
    if (@($all | Where-Object { $_.Name -ieq '.fxap' -or $_.Extension -ieq '.fxap' }).Count -gt 0) { [void]$r.issues.Add('script chiffré (escrow Tebex) : ne marche que pour le compte qui l''a acheté') }
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
        if ($lua.Count -gt 0) {
            $r.type = 'script'
            $code = ($lua | ForEach-Object { Get-Content -LiteralPath $_.FullName -Raw -ErrorAction SilentlyContinue }) -join "`n"
            if ($code -match 'es_extended|ESX\.') { [void]$r.issues.Add('script ESX : incompatible avec notre base Qbox (à réécrire)') }
            if ($code -match "qb-core|QBCore") { [void]$r.notes.Add('script QBCore : souvent compatible Qbox, à tester') }
            if (($code -split "`n" | Where-Object { $_.Length -gt 5000 }).Count -gt 0) { [void]$r.issues.Add('code obfusqué (lignes illisibles) : risque sécurité, refusé') }
            [void]$r.notes.Add('script : je le relis avant installation (sécurité, performance, doublons avec nos gs_*)')
        } elseif (@($all | Where-Object { $_.Extension -match '^\.(yft)$' }).Count -gt 0 -or $r.models.Count -gt 0) { $r.type = 'vehicule'; $r.install = $true }
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
            elseif (@($all | Where-Object { $_.FullName -match '(?i)franklin|trevor|mich(ae|ea)l|player_(zero|one|two)' }).Count -gt 0 -or
                    @($all | Where-Object { $_.Name -match '^uppr_' }).Count -gt 0) {
                $r.type = 'rejete'; [void]$r.issues.Add('vêtement pour Franklin / Michael / Trevor (perso solo) : pas convertible pour les persos FiveM')
            } elseif ($ydd.Count -eq 0) {
                $r.type = 'rejete'; [void]$r.issues.Add('textures seules (recoloration d''un vêtement du jeu) : pas convertible en ajout')
            } else { $r.type = 'convertir'; [void]$r.issues.Add('vêtement au format solo (remplace un vêtement du jeu) : à convertir en ajout FiveM — je peux le faire si tu me l''envoies') }
        } elseif ($rpf.Count -gt 0) { $r.type = 'convertir'; [void]$r.issues.Add('mod solo (dlc.rpf) : ouvrir avec OpenIV ou CodeWalker et extraire le contenu, puis relancer') }
        else { [void]$r.issues.Add('rien d''utilisable pour FiveM trouvé') }
    }
    if ($r.issues | Where-Object { $_ -match 'escrow|ESX|obfusqué' }) { $r.install = $false; $r.type = 'rejete' }
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
# DÉSACTIVÉ par défaut (crash « Streamer crashed » signalé en jeu après optimisation) : les mods sont installés avec
# leurs textures d'origine. Pour réactiver (tests) : variable d'environnement GTASOON_TEXOPT=1.
if ($env:GTASOON_TEXOPT -eq '1') { try {
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
    if (-not $TexReady) { return }
    foreach ($f in @(Get-ChildItem -LiteralPath $dir -Recurse -File -Filter '*.ytd' | Where-Object { $_.Length -gt 1MB })) {
        try {
            $res = [GtaSoon.Tex]::Ytd($f.FullName, 40MB, 512)
            if ($res -and [long]($res -split '\|')[1] -gt 46MB) {   # encore trop lourd : 2e passage, textures jusqu'à 256 px
                $res2 = [GtaSoon.Tex]::Ytd($f.FullName, 40MB, 256)
                if ($res2) { $res = ($res -split '\|')[0] + '|' + ($res2 -split '\|')[1] }
            }
            if ($res) { $a, $b = $res -split '\|'; [void]$r.notes.Add("textures $($f.Name) allégées : $(MB $a) → $(MB $b) Mo en mémoire") }
        } catch { [void]$r.notes.Add("textures $($f.Name) : optimisation impossible, gardé tel quel") }
    }
}

Say "[2/3] Analyse et tri" 'Cyan'
$results = @()
foreach ($p in $packages) { try { $results += Analyze $p } catch { Say "  $($p.Name) : analyse impossible ($($_.Exception.Message))" 'Yellow' } }

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
        # Les véhicules lourds restent ACTIFS (ils tournent) : simple signalement dans le rapport.
        $heavy = @(Get-Oversized $sorted)
        if ($heavy.Count -gt 0) { [void]$r.notes.Add("lourd pour FiveM : $($heavy -join ', ') (à alléger plus tard)") }
        if ($r.name -like 'roadtrip_*') { $r.risk = 'vêtements convertis, à tester un par un' }
        if ($r.risk) { [void]$r.issues.Add("désactivé par sécurité ($($r.risk)) : pour tester, retire le # de sa ligne dans cfg\addons.cfg") }
    }
    if ($r.install -and $canInstall) {
        $name = 'gsa_' + $r.name
        $dest = Join-Path $Addons $name
        if (Test-Path -LiteralPath $dest) { Remove-Item -LiteralPath $dest -Recurse -Force }
        Copy-Item -LiteralPath $sorted -Destination $dest -Recurse -Force
        $installed += $name
    }
}
if ($canInstall) {
    $cfg = @('## Mods importés par IMPORTER-MODS.bat (véhicules, vêtements, maps). Ce fichier n''est jamais écrasé par METTRE-A-JOUR.',
        '## Mets un # devant une ligne pour désactiver un mod.',
        '## « désactivé par sécurité » = pas encore testé en jeu : retire le # pour l''essayer, ton choix est gardé.')
    $previous = Join-Path $Data 'cfg\addons.cfg'
    $keep = @()
    if (Test-Path -LiteralPath $previous) { $keep = @(Get-Content -LiteralPath $previous | Where-Object { $_ -match '^#?\s*ensure gsa_' }) }
    $names = @($installed) + @($keep | ForEach-Object { (($_ -replace '^#?\s*ensure\s+', '').Trim() -split '\s+')[0] }) | Sort-Object -Unique
    $notes = @()
    if (Test-Path -LiteralPath $previous) { $notes = @(Get-Content -LiteralPath $previous | Where-Object { $_ -match '^## gsa_\S+ : désactivé' } | ForEach-Object { ($_ -split '\s+')[1] }) }
    $risks = @{}
    foreach ($r in $results) { if ($r.install -and $r.risk) { $risks['gsa_' + $r.name] = $r.risk } }
    foreach ($n in $names) {
        $line = $keep | Where-Object { $_ -match ('^#?\s*ensure\s+' + [regex]::Escape($n) + '(\s|$)') } | Select-Object -First 1
        $wasOff = $line -and $line -match '^#'
        # Mod déjà désactivé par sécurité et dont le joueur a retiré le # : son choix est respecté
        $forcedOn = $line -and -not $wasOff -and ($notes -contains $n)
        if ($risks.ContainsKey($n)) {
            $cfg += "## $n : désactivé par sécurité ($($risks[$n])), retire le # de la ligne suivante pour l'activer"
            $cfg += $(if ($forcedOn) { "ensure $n" } else { "# ensure $n" })
        } else { $cfg += $(if ($wasOff) { "# ensure $n" } else { "ensure $n" }) }
    }
    [IO.File]::WriteAllLines($previous, $cfg, (New-Object Text.UTF8Encoding $false))
}

# Catalogue Qbox : les véhicules installés sont ajoutés à qbx_core\shared\vehicles.lua (concession, garages, prix),
# dans un bloc balisé réécrit à chaque import (le reste du fichier n'est pas touché).
$Prices = @{ fenomeno = 3200000; evcs500c = 185000; snpurosangue23 = 460000; panamera25 = 265000; '6gt24dd' = 215000; gxetron = 165000
    '392slimshakersc' = 95000; ghoulcharger22 = 115000; glasshuracansc = 320000; stospydersc = 345000; gle21 = 150000; gls600 = 255000; golf8beast = 48000 }
# Noms propres pour la concession (sinon : nom du fichier téléchargé). @(nom, marque, catégorie ou $null)
$Labels = @{ fenomeno = @('Lamborghini Fenomeno', 'Lamborghini', 'super'); evcs500c = @('Mercedes S500 Cabriolet', 'Mercedes', $null)
    snpurosangue23 = @('Ferrari Purosangue', 'Ferrari', $null); panamera25 = @('Porsche Panamera Turbo E-Hybrid', 'Porsche', $null)
    '6gt24dd' = @('Audi RS6 Avant GT', 'Audi', $null); gxetron = @('Audi e-tron GT', 'Audi', $null); '392slimshakersc' = @('Dodge Charger 392 Shaker', 'Dodge', 'muscle')
    ghoulcharger22 = @('Dodge Charger Ghoul', 'Dodge', 'muscle'); glasshuracansc = @('Lamborghini Huracán (toit verre)', 'Lamborghini', $null)
    stospydersc = @('Lamborghini Huracán STO Spyder', 'Lamborghini', $null); gle21 = @('Mercedes-AMG GLE 63 S', 'Mercedes', 'suvs')
    gls600 = @('Mercedes-Maybach GLS 600', 'Mercedes', 'suvs'); golf8beast = @('Volkswagen Golf 8', 'Volkswagen', $null) }
$ClassMap = @{ VC_SUPER = @('super', 1500000); VC_SPORT = @('sports', 250000); VC_SPORT_CLASSIC = @('sportsclassics', 200000); VC_SUV = @('suvs', 120000)
    VC_SEDAN = @('sedans', 60000); VC_COMPACT = @('compacts', 30000); VC_MUSCLE = @('muscle', 85000); VC_COUPE = @('coupes', 90000)
    VC_OFF_ROAD = @('offroad', 70000); VC_MOTORCYCLE = @('motorcycles', 40000); VC_VAN = @('vans', 45000); VC_EMERGENCY = @('emergency', 0) }
$Brands = 'lamborghini', 'mercedes', 'ferrari', 'porsche', 'audi', 'dodge', 'volkswagen', 'bmw', 'nissan', 'toyota', 'ford', 'chevrolet', 'bugatti', 'mclaren'
$vehEntries = @()
# Catalogue construit depuis TOUS les mods installés et actifs (pas seulement ceux de cet import : sinon un import de
# vêtements seuls viderait la concession).
$sources = @()
if ($canInstall) {
    $active = @(Get-Content -LiteralPath (Join-Path $Data 'cfg\addons.cfg') | Where-Object { $_ -match '^\s*ensure\s+gsa_' } | ForEach-Object { (($_ -replace '^\s*ensure\s+', '').Trim() -split '\s+')[0] })
    foreach ($dir in @(Get-ChildItem -LiteralPath $Addons -Directory -Filter 'gsa_*' | Where-Object { $active -contains $_.Name })) {
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
        $lines += ("- {0} [{1} Mo]{2}{3}" -f $r.name, $r.sizeMB, $(if ($r.install -and $canInstall) { ' → INSTALLÉ (gsa_' + $r.name + ')' } else { '' }),
            $(if ($r.models.Count) { ' · spawn : ' + ($r.models -join ', ') } else { '' }))
        foreach ($i in $r.issues) { $lines += "    ! $i" }
        foreach ($n in $r.notes) { $lines += "    · $n" }
    }
    $lines += ''
}
$lines += 'Envoie-moi ce fichier (copier-coller) : je branche les véhicules (concession, garages), les maps (coords, blips) et je relis les scripts.'
[IO.File]::WriteAllLines($Report, $lines, (New-Object Text.UTF8Encoding $false))
if ($canInstall) { [IO.File]::WriteAllText($Stamp, $signature, (New-Object Text.UTF8Encoding $false)) }
Say "`nTerminé : $($results.Count) mods analysés, $($installed.Count) installés." 'Green'
Say "Rapport : $Report" 'Green'
if (-not $canInstall) { Say "Serveur non installé ($Data) : rien d'installé, tout est rangé dans $Out." 'Yellow' }
if (-not $env:GTASOON_TEST -and -not $env:GTASOON_CHAIN) { Start-Process notepad.exe $Report; Read-Host 'Entrée pour quitter' }
