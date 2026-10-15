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
$RscExt = '^\.(ydd|ytd|yft|ydr|ybn)$'

function Get-Head([string]$path) {
    $fs = [IO.File]::OpenRead($path)
    try { $b = New-Object byte[] 4; $n = $fs.Read($b, 0, 4); if ($n -lt 4) { return '' } return [Text.Encoding]::ASCII.GetString($b) } finally { $fs.Close() }
}
function Add-To($table, $key, $value) { if (-not $table.ContainsKey($key)) { $table[$key] = New-Object System.Collections.ArrayList } if (-not $table[$key].Contains($value)) { [void]$table[$key].Add($value) } }

Say "`nDIAGNOSTIC-MODS · $($active.Count) mod(s) démarré(s) dans cfg\addons.cfg" 'Cyan'
foreach ($mod in $active) {
    $dir = Join-Path $Addons $mod
    if (-not (Test-Path -LiteralPath $dir)) { continue }
    $all = @(Get-ChildItem -LiteralPath $dir -Recurse -File -Force -ErrorAction SilentlyContinue)
    $size = ($all | Measure-Object Length -Sum).Sum
    if ($size -gt 150MB) { $heavy += ('{0} ({1} Mo)' -f $mod, [math]::Round($size / 1MB)) }
    if (@($all | Where-Object { $_.Name -ieq '.fxap' -or $_.Extension -ieq '.fxap' }).Count -gt 0) { continue } # pack protégé : chiffré
    foreach ($f in $all) {
        $ext = $f.Extension.ToLower()
        if ($ext -match $RscExt) {
            # Un modèle / une texture du jeu commence toujours par « RSC7 » ; vide ou autre chose = coupé ou abîmé
            if ($f.Length -lt 16) { if (-not $broken.ContainsKey($mod)) { $broken[$mod] = "$($f.Name) (fichier vide)" } }
            elseif ((Get-Head $f.FullName) -ne 'RSC7') { if (-not $broken.ContainsKey($mod)) { $broken[$mod] = "$($f.Name) (en-tête illisible : archive coupée ou mauvais format)" } }
            if ($f.Name -notmatch '_occl') { # occlusion : fusionnée toute seule par gs_admin
                $h = (Get-FileHash -LiteralPath $f.FullName -Algorithm SHA1).Hash
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
Section 'VOITURES EN DOUBLE (même nom de spawn : une seule des deux existe)' @($modelDup | ForEach-Object { "$_ dans : $($models[$_] -join ', ')" }) 'garde un seul des mods (# devant l''autre dans cfg\addons.cfg)'
Section 'FICHIERS EN DOUBLE (même nom, contenu différent : l''un écrase l''autre)' @($fileDup | Select-Object -First 60 | ForEach-Object { "$_ : $((@($files[$_] | ForEach-Object { $_.mod } | Sort-Object -Unique)) -join ', ')" }) 'souvent deux versions du même mod : garde la plus récente'
Section 'LIGNES DE addons.cfg SANS DOSSIER (mod supprimé à la main)' $orphans 'enlevées par la correction sûre'
Section 'MODS INSTALLÉS MAIS JAMAIS DÉMARRÉS' $never 'normal s''ils ont été retirés (F11) ; sinon relance IMPORTER-MODS'
Section 'MODS TRÈS LOURDS (> 150 Mo : chargement long, mémoire)' $heavy ''
if ($fileDup.Count -gt 60) { $out += "(… et $($fileDup.Count - 60) autres fichiers en double)"; $out += '' }

# Corrections sûres -----------------------------------------------------------------------------------------------------
$todo = $orphans.Count + $broken.Count
$apply = $Fix -or ($todo -gt 0 -and -not $NoFix -and -not $env:GTASOON_TEST -and (Read-Host "`n$todo correction(s) sûre(s) possible(s) (lignes mortes enlevées, mods abîmés mis en pause). Appliquer ? (O/N)") -match '^[oOyY]')
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
        }
        [void]$new.Add($l)
    }
    [IO.File]::WriteAllLines($Cfg, [string[]]$new, (New-Object Text.UTF8Encoding $false))
    $out += "CORRECTIONS APPLIQUÉES : $($orphans.Count) ligne(s) morte(s) enlevée(s), $($broken.Count) mod(s) abîmé(s) mis en pause."
    $out += 'Copie de l''ancien fichier : cfg\addons.cfg.avant-diagnostic. Puis : VIDER-CACHE-FIVEM, METTRE-A-JOUR-OVH, redémarrer.'
} elseif ($todo -gt 0) { $out += 'Aucune correction appliquée (relance et réponds O pour appliquer les corrections sûres).' }
else { $out += 'Aucune correction nécessaire.' }
$out += ''
$out += 'Envoie-moi ce fichier (copier-coller) si un conflit reste : je te dis lequel garder, ou je corrige le mod.'
[IO.File]::WriteAllLines($Report, [string[]]$out, (New-Object Text.UTF8Encoding $false))
$color = if ($broken.Count + $dlcDup.Count + $modelDup.Count -gt 0) { 'Yellow' } else { 'Green' }
Say ("Abîmés : {0} · vêtements en conflit : {1} · voitures en double : {2} · fichiers en double : {3} · lignes mortes : {4}" -f $broken.Count, $dlcDup.Count, $modelDup.Count, $fileDup.Count, $orphans.Count) $color
Say "Rapport : $Report" 'Green'
if (-not $env:GTASOON_TEST) { Start-Process notepad.exe $Report; Read-Host 'Entrée pour quitter' }
