<#
  RoadLine RP · DIAGNOSTIC-MODS (V12.60) : « l'outil magique » demandé au backtest du 15/10 pour les mods qui buguent
  (vêtements cassés, voitures qui s'écrasent l'une l'autre, maps qui font planter, lignes mortes dans addons.cfg).
  Il LIT tous les mods de resources\[addons] démarrés par cfg\addons.cfg et écrit un rapport clair :
    1. fichiers ABÎMÉS (modèle / texture coupé : crash « Invalid fixup » chez les joueurs) ;
    2. VÊTEMENTS en conflit : deux packs avec le même nom de collection (dlcName) → l'un des deux s'affiche cassé ;
    3. VOITURES en double : même nom de spawn dans deux mods → une seule des deux existe vraiment ;
    4. FICHIERS en double : même fichier (même nom, contenu différent) dans deux mods → l'un écrase l'autre ;
    5. lignes de addons.cfg qui démarrent un dossier qui n'existe plus, mods jamais démarrés, mods très lourds.
  Corrections SÛRES proposées (rien n'est supprimé, tout est réversible en retirant le # dans addons.cfg) :
    - ligne d'un dossier disparu : enlevée ;
    - mod avec un fichier abîmé : mis en pause (# devant sa ligne) avec la raison.
  Les conflits (2, 3, 4) ne sont jamais tranchés tout seuls : le rapport dit lesquels sont en jeu, tu choisis.
  Packs payants protégés (.fxap) : leurs fichiers sont chiffrés, ils ne sont pas lus (ni signalés à tort).
#>
param([switch]$Fix, [switch]$NoFix)
$ErrorActionPreference = 'Stop'
function Say($m, $c = 'Gray') { Write-Host $m -ForegroundColor $c }

$Root   = if ($env:GTASOON_ROOT) { $env:GTASOON_ROOT } else { 'C:\GTASOON' }   # (variable : tests automatiques)
$Data   = Join-Path $Root 'server-data'
$Addons = Join-Path $Data 'resources\[addons]'
$Cfg    = Join-Path $Data 'cfg\addons.cfg'
$OutDir = Join-Path $Root 'mods-tri'
$Report = Join-Path $OutDir 'DIAGNOSTIC-MODS.txt'
if (-not (Test-Path -LiteralPath $Addons) -or -not (Test-Path -LiteralPath $Cfg)) {
    Say "Serveur introuvable ($Addons ou cfg\addons.cfg). Lance d'abord INSTALLER.bat puis IMPORTER-MODS.bat." 'Yellow'
    if (-not $env:GTASOON_TEST) { Read-Host 'Entrée pour quitter' }
    exit 0
}
[void][IO.Directory]::CreateDirectory($OutDir)

$lines = @(Get-Content -LiteralPath $Cfg -Encoding UTF8)
$active = @(); $paused = @()
foreach ($l in $lines) {
    if ($l -match '^\s*ensure\s+(\S+)') { $active += $Matches[1] }
    elseif ($l -match '^\s*#\s*ensure\s+(\S+)') { $paused += $Matches[1] }
}
$folders = @(Get-ChildItem -LiteralPath $Addons -Directory | ForEach-Object { $_.Name })

$broken = @{}     # [mod] = « fichier (raison) »
$orphans = @($active | Where-Object { $folders -notcontains $_ })
$never = @($folders | Where-Object { $_ -match '^gsa_' -and $active -notcontains $_ -and $paused -notcontains $_ -and $_ -notmatch '^gsa_zz_' })
$dlc = @{}        # [dlcName] = mods
$models = @{}     # [modèle] = mods
$files = @{}      # [nom de fichier] = @( @{ mod; hash } )
$heavy = @()
$sizes = @{}      # [mod] = taille (V12.62 : choisir la copie la plus complète d'une voiture en double)
$RscExt = '^\.(ydd|ytd|yft|ydr|ybn)$'
$heavyTex = @() # V12.63 : fichiers ≥ 32 Mo en mémoire (textures / modèles trop lourds)
$sigs = @{}       # V12.63 : [mod] = empreintes de ses fichiers (nom|taille|SHA1) : repérer les copies complètes d'un autre mod
$SkipSig = '^(fxmanifest\.lua|__resource\.lua)$|\.(txt|md|png|jpe?g|webp|gif|pdf|url|html?|bat|exe)$'

function Get-Head([string]$path) {
    $fs = [IO.File]::OpenRead($path)
    try { $b = New-Object byte[] 4; $n = $fs.Read($b, 0, 4); if ($n -lt 4) { return '' } return [Text.Encoding]::ASCII.GetString($b) } finally { $fs.Close() }
}
# V12.63 · Mémoire occupée une fois chargé (Mo) d'un fichier RSC7 : même formule que gs_admin/server/maps.js (« page flags »)
function Get-PagesSize([uint32]$f) {
    $s = (($f -shr 27) -band 1) + ((($f -shr 26) -band 1) * 2) + ((($f -shr 25) -band 1) * 4) + ((($f -shr 24) -band 1) * 8) +
        ((($f -shr 17) -band 0x7f) * 16) + ((($f -shr 11) -band 0x3f) * 32) + ((($f -shr 7) -band 0xf) * 64) +
        ((($f -shr 5) -band 3) * 128) + ((($f -shr 4) -band 1) * 256)
    return [double](0x200 * [math]::Pow(2, ($f -band 0xf))) * $s
}
function Get-MemoryMB([string]$path) {
    $fs = [IO.File]::OpenRead($path)
    try {
        $b = New-Object byte[] 16
        if ($fs.Read($b, 0, 16) -lt 16 -or [Text.Encoding]::ASCII.GetString($b, 0, 4) -ne 'RSC7') { return 0 }
        return [math]::Max((Get-PagesSize ([BitConverter]::ToUInt32($b, 8))), (Get-PagesSize ([BitConverter]::ToUInt32($b, 12)))) / 1MB
    } finally { $fs.Close() }
}
function Add-To($table, $key, $value) { if (-not $table.ContainsKey($key)) { $table[$key] = New-Object System.Collections.ArrayList } if (-not $table[$key].Contains($value)) { [void]$table[$key].Add($value) } }

Say "`nDIAGNOSTIC-MODS · $($active.Count) mod(s) démarré(s) dans cfg\addons.cfg" 'Cyan'
foreach ($mod in $active) {
    $dir = Join-Path $Addons $mod
    if (-not (Test-Path -LiteralPath $dir)) { continue }
    $all = @(Get-ChildItem -LiteralPath $dir -Recurse -File -Force -ErrorAction SilentlyContinue)
    $size = ($all | Measure-Object Length -Sum).Sum
    $sizes[$mod] = [int64]("0$size")
    if ($size -gt 150MB) { $heavy += ('{0} ({1} Mo)' -f $mod, [math]::Round($size / 1MB)) }
    # V12.63 : empreinte de chaque fichier (packs protégés compris : deux copies d'un même pack ont les mêmes octets)
    $fh = @{}
    $sig = New-Object 'System.Collections.Generic.HashSet[string]'
    foreach ($f in $all) {
        if ($f.Name -match $SkipSig) { continue }
        $h = (Get-FileHash -LiteralPath $f.FullName -Algorithm SHA1).Hash
        $fh[$f.FullName] = $h
        [void]$sig.Add($f.Name.ToLower() + '|' + $f.Length + '|' + $h)
    }
    if ($mod -notmatch '^gsa_zz_') { $sigs[$mod] = $sig }
    if (@($all | Where-Object { $_.Name -ieq '.fxap' -or $_.Extension -ieq '.fxap' }).Count -gt 0) { continue } # pack protégé : chiffré
    foreach ($f in $all) {
        $ext = $f.Extension.ToLower()
        if ($ext -match $RscExt) {
            # Un modèle / une texture du jeu commence toujours par « RSC7 » ; vide ou autre chose = coupé ou abîmé
            if ($f.Length -lt 16) { if (-not $broken.ContainsKey($mod)) { $broken[$mod] = "$($f.Name) (fichier vide)" } }
            elseif ((Get-Head $f.FullName) -ne 'RSC7') { if (-not $broken.ContainsKey($mod)) { $broken[$mod] = "$($f.Name) (en-tête illisible : archive coupée ou mauvais format)" } }
            else { $mb = Get-MemoryMB $f.FullName; if ($mb -ge 32) { $heavyTex += [pscustomobject]@{ mod = $mod; file = $f.Name; mb = [math]::Round($mb, 1) } } }
            if ($f.Name -notmatch '_occl') { # occlusion : fusionnée toute seule par gs_admin
                $h = if ($fh.ContainsKey($f.FullName)) { $fh[$f.FullName] } else { (Get-FileHash -LiteralPath $f.FullName -Algorithm SHA1).Hash }
                if (-not $files.ContainsKey($f.Name.ToLower())) { $files[$f.Name.ToLower()] = New-Object System.Collections.ArrayList }
                [void]$files[$f.Name.ToLower()].Add(@{ mod = $mod; hash = $h })
            }
        } elseif ($ext -eq '.meta') {
            $t = [IO.File]::ReadAllText($f.FullName)
            foreach ($m in [regex]::Matches($t, '<dlcName>\s*([^<\s]+)\s*</dlcName>')) { Add-To $dlc $m.Groups[1].Value.ToLower() $mod }
            if ($f.Name -ieq 'vehicles.meta') {
                foreach ($m in [regex]::Matches($t, '<modelName>\s*([^<\s]+)\s*</modelName>')) { Add-To $models $m.Groups[1].Value.ToLower() $mod }
            }
        } elseif ($ext -eq '.ymt' -and $f.BaseName -match '^mp_[fm]_freemode_01_(.+)$') {
            Add-To $dlc $Matches[1].ToLower() $mod   # collection de vêtements (le .ymt porte le dlcName)
        }
    }
}
$dlcDup = @($dlc.Keys | Where-Object { $dlc[$_].Count -gt 1 } | Sort-Object)
$modelDup = @($models.Keys | Where-Object { $models[$_].Count -gt 1 } | Sort-Object)
# V12.62 · Voitures en double : on garde UNE copie (pas abîmée, la plus complète, sinon le nom le plus court) et les autres
# passent en pause, seulement si CHACUNE de leurs voitures reste dans un mod gardé (jamais une voiture perdue).
# V12.63 · COPIES EN DOUBLE (console du VPS : batic, hachura ×3, sentinel, Patoche gang… chargés deux fois) : un mod dont TOUS
# les fichiers (même nom, même taille, mêmes octets) sont déjà dans un autre mod n'apporte rien, et les joueurs le téléchargent
# deux fois. Il passe en pause ; le mod gardé est le plus complet (à égalité : le nom le plus court, sans « _1 »).
$copyPause = @{}  # [mod mis en pause] = mod qui contient déjà tout
$sigMods = @($sigs.Keys | Where-Object { $sigs[$_].Count -gt 0 -and -not $broken.ContainsKey($_) } |
    Sort-Object @{ Expression = { $sigs[$_].Count }; Descending = $true }, @{ Expression = { $_.Length } }, @{ Expression = { $_ } })
foreach ($x in $sigMods) {
    foreach ($y in $sigMods) {
        if ($y -eq $x) { break }                      # seulement un mod plus complet (ou égal, au nom plus court)
        if ($copyPause.ContainsKey($y)) { continue }  # jamais « gardé » dans un mod lui-même mis en pause
        if ($sigs[$x].IsSubsetOf($sigs[$y])) { $copyPause[$x] = $y; break }
    }
}
# V12.63 · MÊME MAP EN DEUX VERSIONS (16/10 : patoche_petshop_pack + patoche_petshop_pack_1, archive retéléchargée, octets
# différents donc pas une « copie ») : démarrées toutes les deux, le bâtiment existe deux fois au même endroit (murs qui
# clignotent) ou l'une écrase l'autre au hasard. On garde l'ORIGINAL (déjà réglé en jeu : blips, portes, positions) et la
# version « _1 » passe en pause, si au moins la moitié de ses fichiers de map (.ymap / .ytyp / .ybn) portent les mêmes noms.
# Jamais si l'original est retiré (RETIRED_MAPS de maps.js, mods-retires.txt : ex. Shadow Complex, dont « _1 » est le retour).
$retiredNames = New-Object 'System.Collections.Generic.HashSet[string]'
$mapsJs = Join-Path $Data 'resources\[gtasoon]\gs_admin\server\maps.js'
if (Test-Path -LiteralPath $mapsJs) {
    $block = [regex]::Match((Get-Content -LiteralPath $mapsJs -Raw -Encoding UTF8), '(?s)const RETIRED_MAPS = \[(.*?)\];').Groups[1].Value
    foreach ($m in [regex]::Matches($block, "'([a-z0-9_]+)'")) { [void]$retiredNames.Add($m.Groups[1].Value) }
}
$retFile = Join-Path $Root 'mods-retires.txt'
if (Test-Path -LiteralPath $retFile) {
    foreach ($l in [IO.File]::ReadAllLines($retFile)) { $t = $l.Trim().ToLower(); if ($t -and -not $t.StartsWith('#')) { [void]$retiredNames.Add($(if ($t.StartsWith('gsa_')) { $t } else { 'gsa_' + $t })) } }
}
function Get-MapNames($mod) {
    $n = New-Object 'System.Collections.Generic.HashSet[string]'
    foreach ($s in $sigs[$mod]) { $f = $s.Split('|')[0]; if ($f -match '\.(ymap|ytyp|ybn)$' -and $f -notmatch '_occl') { [void]$n.Add($f) } }
    return ,$n
}
$versionPause = @{}  # [version mise en pause] = original gardé
foreach ($x in @($sigs.Keys | Sort-Object)) {
    if ($x -notmatch '^(gsa_.+)_\d+$') { continue }
    $orig = $Matches[1]
    if (-not $sigs.ContainsKey($orig) -or $retiredNames.Contains($orig)) { continue }
    if ($broken.ContainsKey($orig) -or $copyPause.ContainsKey($orig) -or $broken.ContainsKey($x) -or $copyPause.ContainsKey($x)) { continue }
    $a = Get-MapNames $orig; $b = Get-MapNames $x
    if ($a.Count -eq 0 -or $b.Count -eq 0) { continue }
    $common = 0; foreach ($f in $b) { if ($a.Contains($f)) { $common++ } }
    if ($common * 2 -ge [math]::Min($a.Count, $b.Count)) { $versionPause[$x] = $orig }
}
$dupPause = @{}   # [mod mis en pause] = mod gardé
foreach ($m in $modelDup) {
    $cands = @($models[$m] | Where-Object { -not $broken.ContainsKey($_) -and -not $copyPause.ContainsKey($_) })
    if ($cands.Count -lt 2) { continue }
    $keep = @($cands | Sort-Object @{ Expression = { $sizes[$_] }; Descending = $true }, @{ Expression = { $_.Length } }, @{ Expression = { $_ } })[0]
    foreach ($x in $cands) { if ($x -ne $keep -and -not $dupPause.ContainsKey($x)) { $dupPause[$x] = $keep } }
}
do {
    $changed = $false
    foreach ($x in @($dupPause.Keys)) {
        foreach ($m in @($models.Keys | Where-Object { $models[$_].Contains($x) })) {
            $still = @($models[$m] | Where-Object { $_ -ne $x -and -not $dupPause.ContainsKey($_) -and -not $copyPause.ContainsKey($_) -and -not $broken.ContainsKey($_) })
            if ($still.Count -eq 0) { $dupPause.Remove($x); $changed = $true; break }
        }
    }
} while ($changed)
$fileDup = @($files.Keys | Where-Object {
    $list = $files[$_]
    @($list | ForEach-Object { $_.mod } | Sort-Object -Unique).Count -gt 1 -and @($list | ForEach-Object { $_.hash } | Sort-Object -Unique).Count -gt 1
} | Sort-Object)

# Rapport ---------------------------------------------------------------------------------------------------------------
$out = @("DIAGNOSTIC-MODS · $(Get-Date -Format 'dd/MM/yyyy HH:mm') · $($active.Count) mods démarrés, $($paused.Count) en pause", '')
function Section($title, $items, $hint) {
    $script:out += "=== $title ($($items.Count))"
    if ($items.Count -eq 0) { $script:out += '  rien à signaler' } else { foreach ($i in $items) { $script:out += "  - $i" }; if ($hint) { $script:out += "  → $hint" } }
    $script:out += ''
}
Section 'FICHIERS ABÎMÉS (crash « Invalid fixup » / « Streamer crashed »)' @($broken.Keys | Sort-Object | ForEach-Object { "$_ : $($broken[$_])" }) 'retélécharge le mod (archive complète) puis IMPORTER-MODS ; en attendant il est mis en pause par la correction sûre'
Section 'VÊTEMENTS EN CONFLIT (même collection dlcName : l''un des packs s''affiche cassé)' @($dlcDup | ForEach-Object { "« $_ » dans : $($dlc[$_] -join ', ')" }) 'garde UN des packs (mets un # devant les autres dans cfg\addons.cfg) ou envoie-les-moi : je renomme la collection'
Section 'COPIES EN DOUBLE (tous les fichiers déjà dans un autre mod : téléchargé deux fois pour rien)' @($copyPause.Keys | Sort-Object | ForEach-Object { "$_ (tout est déjà dans $($copyPause[$_]))" }) 'correction sûre : la copie passe en pause (# dans cfg\addons.cfg, rien n''est supprimé)'
Section 'MÊME MAP EN DEUX VERSIONS (même bâtiment deux fois : murs qui clignotent)' @($versionPause.Keys | Sort-Object | ForEach-Object { "$_ (version de $($versionPause[$_]), gardée)" }) 'correction sûre : la version « _1 » passe en pause, l''original déjà réglé en jeu reste (retire le # pour échanger)'
Section 'VOITURES EN DOUBLE (même nom de spawn : une seule des deux existe)' @($modelDup | ForEach-Object { "$_ dans : $($models[$_] -join ', ')" }) ('correction sûre : une seule copie gardée (la plus complète), les autres mises en pause : ' + $(if ($dupPause.Count) { (@($dupPause.Keys | Sort-Object | ForEach-Object { "$_ (gardé : $($dupPause[$_]))" }) -join ', ') } else { 'aucune (copies abîmées ou voitures uniques dedans)' }))
Section 'FICHIERS EN DOUBLE (même nom, contenu différent : l''un écrase l''autre)' @($fileDup | Select-Object -First 60 | ForEach-Object { "$_ : $((@($files[$_] | ForEach-Object { $_.mod } | Sort-Object -Unique)) -join ', ')" }) 'souvent deux versions du même mod : garde la plus récente'
Section 'LIGNES DE addons.cfg SANS DOSSIER (mod supprimé à la main)' $orphans 'enlevées par la correction sûre'
Section 'MODS INSTALLÉS MAIS JAMAIS DÉMARRÉS' $never 'normal s''ils ont été retirés (F11) ; sinon relance IMPORTER-MODS'
Section 'MODS TRÈS LOURDS (> 150 Mo : chargement long, mémoire)' $heavy ''
Section 'TEXTURES / MODÈLES TROP LOURDS (≥ 32 Mo en mémoire ; au-delà de 48 Mo, FiveM peut ne pas les afficher)' @($heavyTex | Sort-Object mb -Descending | Select-Object -First 40 | ForEach-Object { "$($_.file) dans $($_.mod) ($($_.mb) Mo)" }) 'IMPORTER-MODS allège déjà seul les textures (.ytd) de plus de 48 Mo des mods non protégés ; restent ici des modèles (.yft / .ydr) ou des textures de 32 à 48 Mo : ils s''affichent mais chargent lentement. Si l''un ne s''affiche pas en jeu, envoie-moi la ligne (rien n''est modifié ici)'
if ($fileDup.Count -gt 60) { $out += "(… et $($fileDup.Count - 60) autres fichiers en double)"; $out += '' }

# Corrections sûres -----------------------------------------------------------------------------------------------------
$todo = $orphans.Count + $broken.Count + $dupPause.Count + $copyPause.Count + $versionPause.Count
$apply = $Fix -or ($todo -gt 0 -and -not $NoFix -and -not $env:GTASOON_TEST -and (Read-Host "`n$todo correction(s) sûre(s) possible(s) (lignes mortes enlevées, mods abîmés, copies, maps en deux versions et voitures en double mis en pause). Appliquer ? (O/N)") -match '^[oOyY]')
if ($apply -and $todo -gt 0) {
    Copy-Item -LiteralPath $Cfg -Destination ($Cfg + '.avant-diagnostic') -Force   # copie de sécurité
    $new = New-Object System.Collections.ArrayList
    foreach ($l in $lines) {
        if ($l -match '^\s*ensure\s+(\S+)') {
            $n = $Matches[1]
            if ($orphans -contains $n) { continue }
            if ($broken.ContainsKey($n)) {
                [void]$new.Add("## $n : désactivé par sécurité (fichier abîmé $($broken[$n] -replace ' \(.*$', ''), DIAGNOSTIC-MODS) : retélécharge-le puis IMPORTER-MODS")
                [void]$new.Add("# ensure $n")
                continue
            }
            if ($copyPause.ContainsKey($n)) { # V12.63
                [void]$new.Add("## $n : en pause (copie en double, tout est déjà dans $($copyPause[$n]), DIAGNOSTIC-MODS) : retire le # pour la reprendre")
                [void]$new.Add("# ensure $n")
                continue
            }
            if ($versionPause.ContainsKey($n)) { # V12.63
                [void]$new.Add("## $n : en pause (même map en deux versions, gardé : $($versionPause[$n]), DIAGNOSTIC-MODS) : retire le # pour la reprendre")
                [void]$new.Add("# ensure $n")
                continue
            }
            if ($dupPause.ContainsKey($n)) { # V12.62
                [void]$new.Add("## $n : en pause (voiture en double, gardée dans $($dupPause[$n]), DIAGNOSTIC-MODS) : retire le # pour la reprendre")
                [void]$new.Add("# ensure $n")
                continue
            }
        }
        [void]$new.Add($l)
    }
    [IO.File]::WriteAllLines($Cfg, [string[]]$new, (New-Object Text.UTF8Encoding $false))
    $out += "CORRECTIONS APPLIQUÉES : $($orphans.Count) ligne(s) morte(s) enlevée(s), $($broken.Count) mod(s) abîmé(s) et $($copyPause.Count) copie(s), $($versionPause.Count) map(s) en deux versions et $($dupPause.Count) voiture(s) en double mis en pause."
    $out += 'Copie de l''ancien fichier : cfg\addons.cfg.avant-diagnostic. Puis : VIDER-CACHE-FIVEM, METTRE-A-JOUR-OVH, redémarrer.'
} elseif ($todo -gt 0) { $out += 'Aucune correction appliquée (relance et réponds O pour appliquer les corrections sûres).' }
else { $out += 'Aucune correction nécessaire.' }
$out += ''
$out += 'Envoie-moi ce fichier (copier-coller) si un conflit reste : je te dis lequel garder, ou je corrige le mod.'
[IO.File]::WriteAllLines($Report, [string[]]$out, (New-Object Text.UTF8Encoding $false))
$color = if ($broken.Count + $dlcDup.Count + $modelDup.Count -gt 0) { 'Yellow' } else { 'Green' }
Say ("Abîmés : {0} · copies en double : {5} · vêtements en conflit : {1} · voitures en double : {2} · fichiers en double : {3} · lignes mortes : {4}" -f $broken.Count, $dlcDup.Count, $modelDup.Count, $fileDup.Count, $orphans.Count, $copyPause.Count) $color
Say "Rapport : $Report" 'Green'
if (-not $env:GTASOON_TEST) { Start-Process notepad.exe $Report; Read-Host 'Entrée pour quitter' }
