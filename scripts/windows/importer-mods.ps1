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
$Cats   = @{ vehicule = 'vehicules'; vetement = 'vetements'; map = 'maps'; script = 'scripts-a-verifier'; convertir = 'a-convertir'; rejete = 'rejetes' }

[void][IO.Directory]::CreateDirectory($Src)
$archives = @(Get-ChildItem -LiteralPath $Src -File | Where-Object { $_.Extension -match '^\.(zip|rar|7z)$' })
# Rien dans mods-a-trier ? On regarde « Google Drive pour ordinateur » (lecteur G:, H:…) : dossier GTA de Mon Drive.
if ($archives.Count -eq 0) {
    foreach ($d in Get-PSDrive -PSProvider FileSystem -ErrorAction SilentlyContinue) {
        foreach ($sub in 'Mon Drive\GTA', 'My Drive\GTA') {
            $g = Join-Path $d.Root $sub
            if (Test-Path -LiteralPath $g) {
                $found = @(Get-ChildItem -LiteralPath $g -File | Where-Object { $_.Extension -match '^\.(zip|rar|7z)$' })
                if ($found.Count -gt 0) { Say "Dossier Google Drive trouvé : $g ($($found.Count) archives)" 'Green'; $archives = $found; break }
            }
        }
        if ($archives.Count -gt 0) { break }
    }
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

# 2. Analyse ----------------------------------------------------------------------------------------------------------
function MB($bytes) { [math]::Round($bytes / 1MB, 1) }
function Analyze($pkg) {
    $all = @(Get-ChildItem -LiteralPath $pkg.FullName -Recurse -File)
    $r = [ordered]@{ name = (Clean-Name $pkg.Name); source = $pkg.Name; type = 'rejete'; sizeMB = MB (($all | Measure-Object Length -Sum).Sum)
        issues = New-Object System.Collections.ArrayList; notes = New-Object System.Collections.ArrayList; root = $pkg.FullName; models = @(); install = $false }
    $ext = { param($e) @($all | Where-Object { $_.Extension -ieq $e }) }
    $manifest = $all | Where-Object { $_.Name -ieq 'fxmanifest.lua' -or $_.Name -ieq '__resource.lua' } | Select-Object -First 1
    $lua = & $ext '.lua'
    $big = @($all | Where-Object { $_.Extension -match '^\.(ytd|yft|ydd|ydr)$' -and $_.Length -gt 16MB })
    foreach ($b in $big) { [void]$r.issues.Add("fichier trop lourd $($b.Name) ($(MB $b.Length) Mo > 16 Mo) : textures qui disparaissent / crash, à optimiser") }
    if ($r.sizeMB -gt 150) { [void]$r.issues.Add("mod très lourd ($($r.sizeMB) Mo) : temps de chargement et mémoire des joueurs") }
    if (@($all | Where-Object { $_.Extension -ieq '.fxap' }).Count -gt 0) { [void]$r.issues.Add('script chiffré (escrow Tebex) : ne marche que pour le compte qui l''a acheté') }
    if (@($all | Where-Object { $_.Extension -match '^\.(oiv|asi|dll)$' -or $_.Name -match 'reshade|visualsettings|timecycle' }).Count -gt 0) {
        [void]$r.notes.Add('contient un mod graphique / solo (oiv, asi, reshade) : inutile côté serveur')
    }
    foreach ($m in @($all | Where-Object { $_.Name -ieq 'vehicles.meta' })) {
        $r.models += @([regex]::Matches((Get-Content -LiteralPath $m.FullName -Raw), '<modelName>\s*([^<\s]+)\s*</modelName>') | ForEach-Object { $_.Groups[1].Value.ToLower() })
    }
    if ($manifest) {
        $r.root = $manifest.DirectoryName
        if ($lua.Count -gt 1) {
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
            else { $r.type = 'convertir'; [void]$r.issues.Add('vêtement au format solo (remplace un vêtement du jeu) : à convertir en ajout FiveM (outil durty cloth tool) — je peux le faire si tu me l''envoies') }
        } elseif ($rpf.Count -gt 0) { $r.type = 'convertir'; [void]$r.issues.Add('mod solo (dlc.rpf) : ouvrir avec OpenIV ou CodeWalker et extraire le contenu, puis relancer') }
        else { [void]$r.issues.Add('rien d''utilisable pour FiveM trouvé') }
    }
    if ($r.issues | Where-Object { $_ -match 'escrow|ESX|obfusqué' }) { $r.install = $false; if ($r.type -eq 'script') { $r.type = 'rejete' } }
    if ($big.Count -gt 0 -and $r.type -in 'vehicule', 'vetement', 'map') { [void]$r.notes.Add('installé quand même, mais à optimiser avant l''ouverture publique') }
    return [pscustomobject]$r
}

function Write-Manifest($dir, $r) {
    $meta = @(Get-ChildItem -LiteralPath $dir -Recurse -File -Filter '*.meta')
    $ytyp = @(Get-ChildItem -LiteralPath $dir -Recurse -File -Filter '*.ytyp')
    $lines = @("-- Généré par IMPORTER-MODS (GTA SOON) : $($r.source)", "fx_version 'cerulean'", "game 'gta5'", "lua54 'yes'", '')
    if ($r.type -eq 'map') { $lines += "this_is_a_map 'yes'" }
    if ($meta.Count -gt 0) { $lines += "files { 'data/**/*.meta' }" }
    $kinds = @{ 'handling.meta' = 'HANDLING_FILE'; 'vehicles.meta' = 'VEHICLE_METADATA_FILE'; 'carcols.meta' = 'CARCOLS_FILE'
        'carvariations.meta' = 'VEHICLE_VARIATION_FILE'; 'vehiclelayouts.meta' = 'VEHICLE_LAYOUTS_FILE'; 'dlctext.meta' = 'DLCTEXT_FILE' }
    foreach ($k in $kinds.Keys) { if ($meta | Where-Object { $_.Name -ieq $k }) { $lines += "data_file '$($kinds[$k])' 'data/**/$k'" } }
    foreach ($y in $ytyp) { $lines += "data_file 'DLC_ITYP_REQUEST' 'stream/$($y.Name)'" }
    [IO.File]::WriteAllLines((Join-Path $dir 'fxmanifest.lua'), $lines, (New-Object Text.UTF8Encoding $false))
}

#--- Crée une ressource FiveM propre : stream\ (modèles, textures, collisions) + data\ (fichiers .meta), sans doublons.
function Build-Resource($r, $dest) {
    if (Test-Path -LiteralPath $dest) { Remove-Item -LiteralPath $dest -Recurse -Force }
    $existing = Get-ChildItem -LiteralPath $r.root -Recurse -File | Where-Object { $_.Name -ieq 'fxmanifest.lua' -or $_.Name -ieq '__resource.lua' } | Select-Object -First 1
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
        '## Mets un # devant une ligne pour désactiver un mod.')
    $previous = Join-Path $Data 'cfg\addons.cfg'
    $keep = @()
    if (Test-Path -LiteralPath $previous) { $keep = @(Get-Content -LiteralPath $previous | Where-Object { $_ -match '^#?\s*ensure gsa_' }) }
    $names = @($installed) + @($keep | ForEach-Object { ($_ -replace '^#?\s*ensure\s+', '').Trim() }) | Sort-Object -Unique
    foreach ($n in $names) {
        $wasOff = $keep | Where-Object { $_ -match '^#' -and $_ -match [regex]::Escape($n) }
        $cfg += $(if ($wasOff) { "# ensure $n" } else { "ensure $n" })
    }
    [IO.File]::WriteAllLines($previous, $cfg, (New-Object Text.UTF8Encoding $false))
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
Say "`nTerminé : $($results.Count) mods analysés, $($installed.Count) installés." 'Green'
Say "Rapport : $Report" 'Green'
if (-not $canInstall) { Say "Serveur non installé ($Data) : rien d'installé, tout est rangé dans $Out." 'Yellow' }
if (-not $env:GTASOON_TEST) { Start-Process notepad.exe $Report; Read-Host 'Entrée pour quitter' }
