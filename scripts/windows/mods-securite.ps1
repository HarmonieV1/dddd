<#
  GTA SOON - MODS SÉCURITÉ : crash en jeu (« Streamer crashed ») à cause d'un mod ? En un clic :
   1. désactive les mods LOURDS (textures > 48 Mo, les mêmes que les lignes « Oversized » de la console) + les vêtements
      convertis non testés : le serveur redevient stable, les mods légers restent ;
   2. désactive TOUS les mods importés (test : si ça plante encore, ce ne sont pas les mods) ;
   3. réactive tout.
  Ne supprime rien : seulement des # dans C:\GTASOON\server-data\cfg\addons.cfg. Vide ensuite le cache FiveM.
#>
$ErrorActionPreference = 'Stop'
function Say($m, $c = 'Gray') { Write-Host $m -ForegroundColor $c }
$Root = if ($env:GTASOON_ROOT) { $env:GTASOON_ROOT } else { 'C:\GTASOON' }
$Cfg = Join-Path $Root 'server-data\cfg\addons.cfg'
$Addons = Join-Path $Root 'server-data\resources\[addons]'
if (-not (Test-Path -LiteralPath $Cfg)) { Say "Pas de $Cfg : aucun mod importé, rien à faire." 'Yellow'; if (-not $env:GTASOON_TEST) { Read-Host 'Entrée pour quitter' }; exit 0 }

function Get-RscPhys([string]$path) {
    $fs = [IO.File]::OpenRead($path)
    try { $b = New-Object byte[] 16; if ($fs.Read($b, 0, 16) -lt 16) { return 0 } } finally { $fs.Dispose() }
    if ([BitConverter]::ToUInt32($b, 0) -ne 0x37435352) { return 0 }
    $f = [BitConverter]::ToUInt32($b, 12)
    $n = ((($f -shr 27) -band 1)) + ((($f -shr 26) -band 1) -shl 1) + ((($f -shr 25) -band 1) -shl 2) + ((($f -shr 24) -band 1) -shl 3) +
         ((($f -shr 17) -band 0x7F) -shl 4) + ((($f -shr 11) -band 0x3F) -shl 5) + ((($f -shr 7) -band 0xF) -shl 6) +
         ((($f -shr 5) -band 3) -shl 7) + ((($f -shr 4) -band 1) -shl 8)
    return [long](0x200 -shl ($f -band 0xF)) * $n
}
function Get-Heaviest($name) {
    $dir = Join-Path $Addons $name
    if (-not (Test-Path -LiteralPath $dir)) { return 0 }
    $max = 0
    foreach ($f in Get-ChildItem -LiteralPath $dir -Recurse -File -Filter '*.ytd') { $p = Get-RscPhys $f.FullName; if ($p -gt $max) { $max = $p } }
    return $max
}

$choice = $env:GTASOON_CHOICE
if (-not $choice) {
    Say 'MODS SÉCURITÉ' 'Cyan'
    Say '  1 = désactiver les mods LOURDS + vêtements non testés (recommandé : serveur stable, les autres mods restent)'
    Say '  2 = désactiver TOUS les mods importés (pour tester sans aucun mod)'
    Say '  3 = tout réactiver'
    $choice = Read-Host 'Ton choix (1, 2 ou 3)'
}
$lines = @(Get-Content -LiteralPath $Cfg)
$out = @(); $off = @(); $on = @()
foreach ($l in $lines) {
    if ($l -notmatch '^\s*(#\s*)?ensure\s+(gsa_\S+)') { $out += $l; continue }
    $name = $Matches[2]
    $disable = switch ($choice) {
        '1' { ($name -like 'gsa_roadtrip_vetements_*') -or ((Get-Heaviest $name) -gt 48MB) }   # les mods légers (et les coiffures) sont (ré)activés
        '2' { $true }
        '3' { $false }
        default { $l -match '^\s*#' }
    }
    if ($disable) { $out += "# ensure $name"; $off += $name } else { $out += "ensure $name"; $on += $name }
}
# Les notes « désactivé par sécurité » laissées par l'import restent valables ; option 3 : on les retire.
if ($choice -eq '3') { $out = @($out | Where-Object { $_ -notmatch '^## gsa_\S+ : désactivé' }) }
Copy-Item -LiteralPath $Cfg -Destination "$Cfg.avant-securite" -Force
[IO.File]::WriteAllLines($Cfg, $out, (New-Object Text.UTF8Encoding $false))
Say "`nActifs ($($on.Count)) : $($on -join ', ')" 'Green'
Say "Désactivés ($($off.Count)) : $($off -join ', ')" 'Yellow'
Say "(ancienne version gardée : addons.cfg.avant-securite)"

# Cache FiveM vidé dans la foulée (les anciens fichiers en cache peuvent aussi faire planter)
$cacheTool = Join-Path $PSScriptRoot 'vider-cache-fivem.ps1'
if (Test-Path -LiteralPath $cacheTool) { Say "`nVidage du cache FiveM…" 'Cyan'; $env:GTASOON_TEST = '1'; & $cacheTool }
Say "`nC'est prêt : (re)lance le serveur puis connecte-toi." 'Green'
if (-not $env:GTASOON_CHOICE) { Read-Host 'Entrée pour quitter' }
