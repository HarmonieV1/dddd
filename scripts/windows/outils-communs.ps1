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
    @{ res = 'qbx_ambulancejob'; file = 'config\server.lua'; find = 'wipeInvOnRespawn\s*=\s*true'; repl = 'wipeInvOnRespawn = false'; why = 'inventaire gardé à la réapparition' }
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
        $file = if ($target) { Join-Path $target.FullName $p.file } else { $null }
        if (-not $file -or -not (Test-Path -LiteralPath $file)) { & $Say "  $($p.res)\$($p.file) introuvable : $($p.why) non appliqué" 'Yellow'; continue }
        $text = Get-Content -LiteralPath $file -Raw -Encoding UTF8
        if ($text -match $p.find) {
            Write-Utf8 $file ([regex]::Replace($text, $p.find, $p.repl))
            & $Say "  $($p.res) : $($p.why)" 'Green'
        } elseif ($text -notmatch [regex]::Escape($p.repl)) {
            & $Say "  $($p.res) : réglage « $($p.why) » introuvable (version différente ?)" 'Yellow'
        }
    }
}
