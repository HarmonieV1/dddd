<#
  GTA SOON - fonctions partagées par installer-serveur.ps1 et mettre-a-jour.ps1 (chargé avec « . »).
  - Merge-GtaSoonItems : ajoute nos items dans ox_inventory (et remplace ceux marqués « -- remplace »)
  - Set-QboxOverrides  : pose nos fichiers de config (server\overrides) et applique nos réglages Qbox
#>

# Réglages appliqués aux ressources Qbox (fichier relatif à la ressource, motif, remplacement).
$QboxPatches = @(
    @{ res = 'qbx_medical'; file = 'config\client.lua'; find = 'laststandReviveInterval\s*=\s*\d+'; repl = 'laststandReviveInterval = 90'; why = 'à terre : 90 s' },
    @{ res = 'qbx_medical'; file = 'config\client.lua'; find = 'deathTime\s*=\s*\d+'; repl = 'deathTime = 70'; why = 'réapparition possible après 70 s' },
    @{ res = 'qbx_ambulancejob'; file = 'config\shared.lua'; find = 'checkInCost\s*=\s*\d+'; repl = 'checkInCost = 500'; why = 'hôpital : 500 $' },
    @{ res = 'qbx_ambulancejob'; file = 'config\shared.lua'; find = 'minForCheckIn\s*=\s*\d+'; repl = 'minForCheckIn = 1'; why = 'accueil IA si aucun EMS' },
    @{ res = 'qbx_ambulancejob'; file = 'config\server.lua'; find = 'wipeInvOnRespawn\s*=\s*true'; repl = 'wipeInvOnRespawn = false'; why = 'inventaire gardé à la réapparition' },
    @{ res = 'illenium-appearance'; file = 'shared\config.lua'; find = '(Config\.NewCharacterSections\s*=\s*\{\s*Ped\s*=\s*)true'; repl = '${1}false'; why = 'création : perso classique seulement (pas de ped GTA)' },
    @{ res = 'illenium-appearance'; file = 'shared\config.lua'; find = 'Config\.UseTarget\s*=\s*false'; repl = 'Config.UseTarget = true'; why = 'vêtements / coiffeur / tatoueur / chirurgien : vendeur PNJ au comptoir (ox_target)' },
    @{ res = 'illenium-appearance'; file = 'shared\config.lua'; find = 'Config\.EnablePedsForShops\s*=\s*true'; repl = 'Config.EnablePedsForShops = false'; why = 'magasins de vêtements : pas de ped GTA (boutique / staff seulement)' },
    @{ res = 'illenium-appearance'; file = 'shared\config.lua'; find = 'Config\.EnablePedsForClothingRooms\s*=\s*true'; repl = 'Config.EnablePedsForClothingRooms = false'; why = 'vestiaires : pas de ped GTA' },
    @{ res = 'illenium-appearance'; file = 'shared\config.lua'; find = 'Config\.EnablePedsForPlayerOutfitRooms\s*=\s*true'; repl = 'Config.EnablePedsForPlayerOutfitRooms = false'; why = 'garde-robes : pas de ped GTA' },
    @{ res = 'qbx_core'; file = 'config\client.lua'; find = 'startingApartment\s*=\s*true'; repl = 'startingApartment = false'; why = 'nouveau perso : apparition en ville (mairie), pas d''appartement gratuit' },
    # Clés : moins de voitures PNJ verrouillées (garées 50 %, en circulation 35 %), clés trouvées plus souvent en fouillant
    @{ res = 'qbx_vehiclekeys'; file = 'config\shared.lua'; find = 'spawnLockedIfParked = 0\.75'; repl = 'spawnLockedIfParked = 0.5'; why = 'voitures PNJ garées : 50 % verrouillées' },
    @{ res = 'qbx_vehiclekeys'; file = 'config\shared.lua'; find = 'spawnLockedIfDriven = 0\.75'; repl = 'spawnLockedIfDriven = 0.35'; why = 'voitures PNJ en circulation : 35 % verrouillées' },
    @{ res = 'qbx_vehiclekeys'; file = 'config\shared.lua'; find = 'findKeysChance = 0\.5,'; repl = 'findKeysChance = 0.65,'; why = 'fouiller une voiture (H) : 65 % de trouver les clés' },
    # Inventaire : double-clic sur un objet = l'utiliser (ox_inventory ne le fait qu'avec Alt + clic)
    @{ res = 'ox_inventory'; file = 'web\build\index.html'; why = 'inventaire : double-clic pour utiliser un objet'
       find = '(?<!<!--gs-dblclick-->)</body>'
       repl = '<script>document.addEventListener("dblclick",function(e){if(e.target&&e.target.dispatchEvent){e.target.dispatchEvent(new MouseEvent("click",{bubbles:true,cancelable:true,altKey:true,view:window}))}},true)</script><!--gs-dblclick--></body>' },
    # Concession PDM : catégorie « Imports ROADTRIP » en tête, avec toutes les voitures importées (IMPORTER-MODS)
    @{ res = 'qbx_vehicleshop'; file = 'config\shared.lua'; find = "(categories = \{\s*\n(\s*))sportsclassics = 'Sports Classics',"; repl = "`${1}roadtrip = ' ★ Imports ROADTRIP',`n`${2}sportsclassics = 'Sports Classics',"; why = 'concession : catégorie Imports ROADTRIP' }
    @{ res = 'illenium-appearance'; file = 'locales\fr.lua'; find = 'description = "tu resteras moche"'; repl = 'description = "Ton apparence sera enregistrée"'; why = 'création perso : texte d''enregistrement propre' }
    # Carte d'identité montrée : se ferme seule après 6 s (sinon restait à l'écran), Échap ou Retour arrière la ferment aussi
    @{ res = 'qbx_idcard'; file = 'config\shared.lua'; find = 'status\s*=\s*false,[^\n]*\n\s*time\s*=\s*\d+'; repl = "status = true,`n            time = 6000"; why = 'carte d''identité : fermeture auto après 6 s' }
    @{ res = 'qbx_idcard'; file = 'web\js\config.js'; find = 'status:\s*false,[^\n]*\n\s*time:\s*\d+'; repl = "status: true,`n            time: 6000"; why = 'carte d''identité (page) : fermeture auto' }
    @{ res = 'qbx_idcard'; file = 'web\js\main.js'; find = 'if \(e\.key !== config\.idCardSettings\.closeKey\) return;'; repl = 'if (e.key !== config.idCardSettings.closeKey && e.key !== ''Escape'') return;'; why = 'carte d''identité : Échap la ferme' }
    @{ res = 'qbx_idcard'; file = 'config\shared.lua'; find = "header = 'Identity'"; repl = "header = 'Carte d\'identité'"; why = 'carte d''identité en français' }
    @{ res = 'qbx_idcard'; file = 'config\shared.lua'; find = "header = 'Driver License'"; repl = "header = 'Permis de conduire'"; why = 'permis en français' }
    @{ res = 'qbx_idcard'; file = 'config\shared.lua'; find = "header = 'Weapon License'"; repl = "header = 'Permis de port d\'arme'"; why = 'permis d''arme en français' }
    @{ res = 'ox_lib'; file = 'resource\interface\client\context.lua'; find = 'lib\.setNuiFocus\(false\)'; repl = 'lib.setNuiFocus(true)'; why = 'menus cliquables : on peut marcher menu ouvert' },
    # Menus ox_lib : palette « dark » grise de Mantine remplacée par du noir-violet néon (DA GTA SOON)
    @{ res = 'ox_lib'; dir = 'web\build\assets'; filter = '*.js'; why = 'menus ox_lib en noir néon'
       find = '(?i)\["#C1C2C5","#A6A7AB","#909296","#5c5f66","#373A40","#2C2E33","#25262b","#1A1B1E","#141517","#101113"\]'
       repl = '["#EDE4FF","#CBBBEA","#A493C7","#6F5E93","#3B2A5C","#2A1C45","#1E1433","#150D26","#0F091C","#0A0613"]' }
)

function Find-Resource($Res, $name) {
    return Get-ChildItem -LiteralPath $Res -Directory -Recurse -Filter $name -ErrorAction SilentlyContinue | Select-Object -First 1
}

function Write-Utf8($path, $text) { [IO.File]::WriteAllText($path, $text, (New-Object Text.UTF8Encoding $false)) }

#--- Retire la définition ['name'] = { ... }, d'items.lua (accolades équilibrées). Retourne le texte modifié.
function Remove-ItemBlock([string]$content, [string]$name) {
    $m = [regex]::Match($content, "(?m)^[ \t]*\[\s*['""]" + [regex]::Escape($name) + "['""]\s*\]\s*=\s*\{")
    if (-not $m.Success) { return $content }
    $i = $m.Index + $m.Length
    $depth = 1
    while ($i -lt $content.Length -and $depth -gt 0) {
        $ch = $content[$i]
        if ($ch -eq '{') { $depth++ } elseif ($ch -eq '}') { $depth-- }
        $i++
    }
    while ($i -lt $content.Length -and ($content[$i] -eq ',' -or $content[$i] -eq ' ' -or $content[$i] -eq "`t")) { $i++ }
    return $content.Remove($m.Index, $i - $m.Index)
}

#--- Retourne @{ added; replaced } (ou $null si items.lua introuvable).
function Merge-GtaSoonItems($Res, $Repo) {
    $items = Get-ChildItem -LiteralPath $Res -Recurse -Filter items.lua -ErrorAction SilentlyContinue |
        Where-Object { $_.FullName -match 'ox_inventory\\data\\items\.lua$' } | Select-Object -First 1
    if (-not $items) { return $null }
    $content = Get-Content -LiteralPath $items.FullName -Raw -Encoding UTF8
    $add = @()
    $replaced = 0
    foreach ($line in Get-Content -LiteralPath (Join-Path $Repo 'server\ox_items_gtasoon.lua') -Encoding UTF8) {
        if ($line -notmatch "^\['([a-z0-9_]+)'\]") { continue }
        $name = $Matches[1]
        $clean = $line -replace '\s*--\s*remplace\s*$', ''
        $exists = $content -match ("\[\s*['""]" + [regex]::Escape($name) + "['""]\s*\]\s*=")
        if ($exists -and $line -match '--\s*remplace\s*$' -and -not $content.Contains($clean)) {
            $content = Remove-ItemBlock $content $name
            $replaced++
            $exists = $false
        }
        if (-not $exists) { $add += '    ' + $clean }
    }
    if ($add.Count -gt 0) {
        $i = $content.LastIndexOf('}')
        $content = $content.Substring(0, $i).TrimEnd() + "`n`n    -- GTA SOON`n" + ($add -join "`n") + "`n" + $content.Substring($i)
        Write-Utf8 $items.FullName $content
    }
    return @{ added = $add.Count - $replaced; replaced = $replaced }
}

#--- Fichiers de server\overrides\<ressource>\... posés sur la ressource, puis réglages $QboxPatches.
function Set-QboxOverrides($Res, $Repo, [scriptblock]$Say) {
    $root = Join-Path $Repo 'server\overrides'
    if (Test-Path -LiteralPath $root) {
        foreach ($dir in Get-ChildItem -LiteralPath $root -Directory) {
            $target = Find-Resource $Res $dir.Name
            if (-not $target) { & $Say "  $($dir.Name) absent : réglage ignoré" 'Yellow'; continue }
            foreach ($f in Get-ChildItem -LiteralPath $dir.FullName -Recurse -File) {
                $rel = $f.FullName.Substring($dir.FullName.Length + 1)
                $dest = Join-Path $target.FullName $rel
                [void][IO.Directory]::CreateDirectory((Split-Path $dest))
                Copy-Item -LiteralPath $f.FullName -Destination $dest -Force
                & $Say "  $($dir.Name)\$rel remplacé" 'Green'
            }
        }
    }
    foreach ($p in $QboxPatches) {
        $target = Find-Resource $Res $p.res
        if ($p.dir) { # correctif sur des fichiers compilés (nom variable) : tous les fichiers du dossier
            $folder = if ($target) { Join-Path $target.FullName $p.dir } else { $null }
            if (-not $folder -or -not (Test-Path -LiteralPath $folder)) { & $Say "  $($p.res) : dossier $($p.dir) introuvable ($($p.why) non appliqué)" 'Yellow'; continue }
            $done = $false
            foreach ($f in Get-ChildItem -LiteralPath $folder -Filter $p.filter -File) {
                $text = [IO.File]::ReadAllText($f.FullName)
                if ($text -match $p.find) { Write-Utf8 $f.FullName ([regex]::Replace($text, $p.find, $p.repl)); $done = $true }
                elseif ($text.Contains($p.repl)) { $done = $true }
            }
            & $Say "  $($p.res) : $($p.why)$(if (-not $done) { ' (motif introuvable, version différente ?)' })" $(if ($done) { 'Green' } else { 'Yellow' })
            continue
        }
        $file = if ($target) { Join-Path $target.FullName $p.file } else { $null }
        if (-not $file -or -not (Test-Path -LiteralPath $file)) { & $Say "  $($p.res)\$($p.file) introuvable : $($p.why) non appliqué" 'Yellow'; continue }
        $text = Get-Content -LiteralPath $file -Raw -Encoding UTF8
        if ($text -match $p.find) {
            Write-Utf8 $file ([regex]::Replace($text, $p.find, $p.repl))
            & $Say "  $($p.res) : $($p.why)" 'Green'
        } elseif (-not $p.repl.Contains('${') -and $text -notmatch [regex]::Escape($p.repl)) {
            & $Say "  $($p.res) : réglage « $($p.why) » introuvable (version différente ?)" 'Yellow'
        }
    }
    Merge-FrenchLocales $Res $Repo $Say
}

#--- Ajoute nos traductions (server\locales-fr\<ressource>.json) aux locales\fr.json des ressources Qbox.
#    N'écrase jamais une traduction existante : seules les clés absentes sont ajoutées (Qbox reste à jour).
function Merge-JsonMissing($target, $source) {
    $added = 0
    foreach ($prop in $source.PSObject.Properties) {
        $cur = $target.PSObject.Properties[$prop.Name]
        if ($prop.Value -is [pscustomobject]) {
            if (-not $cur) { $target | Add-Member -NotePropertyName $prop.Name -NotePropertyValue ([pscustomobject]@{}); $cur = $target.PSObject.Properties[$prop.Name] }
            if ($cur.Value -is [pscustomobject]) { $added += Merge-JsonMissing $cur.Value $prop.Value }
        } elseif (-not $cur) {
            $target | Add-Member -NotePropertyName $prop.Name -NotePropertyValue $prop.Value
            $added++
        }
    }
    return $added
}

function Merge-FrenchLocales($Res, $Repo, [scriptblock]$Say) {
    $dir = Join-Path $Repo 'server\locales-fr'
    if (-not (Test-Path -LiteralPath $dir)) { return }
    foreach ($f in Get-ChildItem -LiteralPath $dir -Filter '*.json') {
        $target = Find-Resource $Res $f.BaseName
        if (-not $target) { continue }
        $frFile = Join-Path $target.FullName 'locales\fr.json'
        try {
            $fr = if (Test-Path -LiteralPath $frFile) { Get-Content -LiteralPath $frFile -Raw -Encoding UTF8 | ConvertFrom-Json } else { [pscustomobject]@{} }
            $ours = Get-Content -LiteralPath $f.FullName -Raw -Encoding UTF8 | ConvertFrom-Json
            $n = Merge-JsonMissing $fr $ours
            if ($n -gt 0) {
                Write-Utf8 $frFile ($fr | ConvertTo-Json -Depth 20)
                & $Say "  $($f.BaseName) : $n traduction(s) française(s) ajoutée(s)" 'Green'
            }
        } catch { & $Say "  $($f.BaseName) : traduction non fusionnée ($($_.Exception.Message))" 'Yellow' }
    }
}

#--- Trouve FXServer.exe : chemin de l'ancien DEMARRER.bat s'il existe encore, emplacements habituels, recherche dans
#    C:\FXServer, C:\GTASOON, Téléchargements, Bureau ; sinon demande le dossier. Retourne le chemin complet ou $null.
function Find-FxServer($Data) {
    $bat = Join-Path $Data 'DEMARRER.bat'
    $cands = @()
    if (Test-Path -LiteralPath $bat) {
        $old = [regex]::Match([IO.File]::ReadAllText($bat, [Text.Encoding]::Default), '"([^"]*FXServer\.exe)"').Groups[1].Value
        if ($old) { $cands += $old }
    }
    $cands += 'C:\FXServer\server\FXServer.exe', 'C:\FXServer\FXServer.exe', 'C:\GTASOON\FXServer\FXServer.exe', 'C:\GTASOON\server\FXServer.exe'
    foreach ($c in $cands) { if ($c -and (Test-Path -LiteralPath $c)) { return (Resolve-Path -LiteralPath $c).Path } }
    $roots = @('C:\FXServer', 'C:\GTASOON', (Join-Path $env:USERPROFILE 'Downloads'), (Join-Path $env:USERPROFILE 'Desktop'), (Join-Path $env:USERPROFILE 'Documents'))
    foreach ($r in $roots) {
        if (-not (Test-Path -LiteralPath $r)) { continue }
        $f = Get-ChildItem -LiteralPath $r -Recurse -Depth 4 -Filter 'FXServer.exe' -File -ErrorAction SilentlyContinue |
            Where-Object { Test-Path -LiteralPath (Join-Path $_.DirectoryName 'citizen') } | Select-Object -First 1
        if ($f) { return $f.FullName }
    }
    Add-Type -AssemblyName System.Windows.Forms
    $d = New-Object System.Windows.Forms.FolderBrowserDialog
    $d.Description = 'FXServer.exe introuvable : choisis le dossier où tu as extrait server.7z (celui qui contient FXServer.exe)'
    if ($d.ShowDialog() -eq 'OK') {
        $exe = Join-Path $d.SelectedPath 'FXServer.exe'
        if (Test-Path -LiteralPath $exe) { return $exe }
    }
    return $null
}

#--- FXServer dans OneDrive (Bureau / Documents synchronisés) = crashs du serveur (fichiers verrouillés ou « en ligne
#    uniquement » pendant qu'il tourne). On le copie une fois dans C:\FXServer\server et on utilise cette copie.
function Move-FxServerOutOfOneDrive($FxExe, [scriptblock]$Say) {
    if (-not $FxExe -or $FxExe -notmatch '\\OneDrive') { return $FxExe }
    $src = Split-Path $FxExe
    $dst = 'C:\FXServer\server'
    & $Say "  FXServer est dans OneDrive ($src) : cause connue de crashs. Copie vers $dst…" 'Yellow'
    Get-Process -Name FXServer -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
    [void][IO.Directory]::CreateDirectory($dst)
    & robocopy.exe $src $dst /E /R:2 /W:2 /XD crashes cache /NFL /NDL /NJH /NJS /NP | Out-Null
    $new = Join-Path $dst 'FXServer.exe'
    if ($LASTEXITCODE -lt 8 -and (Test-Path -LiteralPath $new) -and (Test-Path -LiteralPath (Join-Path $dst 'citizen'))) {
        & $Say "  FXServer copié dans $dst (l'ancien dossier OneDrive n'est plus utilisé, tu pourras le supprimer)" 'Green'
        return $new
    }
    & $Say "  Copie impossible (code $LASTEXITCODE) : on garde $FxExe. Déplace le dossier à la main hors de OneDrive (ex. C:\FXServer\server)." 'Yellow'
    return $FxExe
}

#--- Écrit DEMARRER.bat (encodage de la console Windows : les chemins avec accents restent valides) avec un contrôle
#    clair si FXServer.exe disparaît un jour (déplacé, antivirus…).
function Write-Launcher($Data, $FxExe) {
    $lines = @(
        '@echo off', 'title Serveur GTA SOON', 'cd /d "%~dp0"',
        "if not exist `"$FxExe`" (",
        '  echo.',
        "  echo ERREUR : FXServer.exe introuvable : $($FxExe -replace '([()&<>^|])', '^$1')",
        '  echo Il a ete deplace ou supprime. Lance REPARER-LANCEUR.bat dans le dossier GTA SOON extrait.',
        '  echo.', '  pause', '  exit /b 1', ')',
        "`"$FxExe`" +set onesync on +exec server.cfg",
        'pause')
    $oem = [Text.Encoding]::GetEncoding([Globalization.CultureInfo]::CurrentCulture.TextInfo.OEMCodePage)
    [IO.File]::WriteAllText((Join-Path $Data 'DEMARRER.bat'), (($lines -join "`r`n") + "`r`n"), $oem)
}
