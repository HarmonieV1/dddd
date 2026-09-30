<#
  GTA SOON - VIDER LE CACHE FIVEM : à lancer après un changement de mods (voitures, vêtements, maps) ou en cas de crash
  « Streamer crashed » / textures qui ne s'affichent pas.
  Ferme FiveM, vide le cache du jeu (%LocalAppData%\FiveM\FiveM.app\data : cache, server-cache, server-cache-priv ;
  le dossier cache\game, les fichiers de GTA, est gardé pour éviter un gros re-téléchargement) et, si le serveur est
  arrêté, le cache du serveur (C:\GTASOON\server-data\cache). Rien d'autre n'est touché (persos, base, réglages).
#>
$ErrorActionPreference = 'Continue'
function Say($m, $c = 'Gray') { Write-Host $m -ForegroundColor $c }
function Size($p) { try { [math]::Round(((Get-ChildItem -LiteralPath $p -Recurse -File -Force -ErrorAction SilentlyContinue | Measure-Object Length -Sum).Sum) / 1MB) } catch { 0 } }

Say '[1/3] Fermeture de FiveM' 'Cyan'
$fivem = @(Get-Process -ErrorAction SilentlyContinue | Where-Object { $_.ProcessName -match '^FiveM' })
if ($fivem.Count -gt 0) { $fivem | Stop-Process -Force -ErrorAction SilentlyContinue; Start-Sleep -Seconds 3; Say "  FiveM fermé ($($fivem.Count) processus)" 'Green' }
else { Say '  FiveM n''était pas lancé' 'Green' }

Say '[2/3] Cache du jeu (FiveM)' 'Cyan'
$data = Join-Path $env:LOCALAPPDATA 'FiveM\FiveM.app\data'
$freed = 0
if (-not (Test-Path -LiteralPath $data)) { Say "  Dossier FiveM introuvable ($data) : rien à vider" 'Yellow' }
else {
    foreach ($d in 'server-cache', 'server-cache-priv') {
        $p = Join-Path $data $d
        if (Test-Path -LiteralPath $p) { $freed += Size $p; Remove-Item -LiteralPath $p -Recurse -Force -ErrorAction SilentlyContinue; Say "  $d vidé" 'Green' }
    }
    $cache = Join-Path $data 'cache'
    if (Test-Path -LiteralPath $cache) {
        foreach ($item in @(Get-ChildItem -LiteralPath $cache -Force | Where-Object { $_.Name -ne 'game' })) {
            $freed += $(if ($item.PSIsContainer) { Size $item.FullName } else { [math]::Round($item.Length / 1MB) })
            Remove-Item -LiteralPath $item.FullName -Recurse -Force -ErrorAction SilentlyContinue
        }
        Say '  cache vidé (fichiers de GTA gardés)' 'Green'
    }
}

Say '[3/3] Cache du serveur' 'Cyan'
$srvCache = 'C:\GTASOON\server-data\cache'
if (@(Get-Process -ErrorAction SilentlyContinue | Where-Object { $_.ProcessName -match '^FXServer' }).Count -gt 0) {
    Say '  Serveur en marche : son cache n''est pas touché (ferme-le puis relance cet outil si besoin)' 'Yellow'
} elseif (Test-Path -LiteralPath $srvCache) {
    $freed += Size $srvCache; Remove-Item -LiteralPath $srvCache -Recurse -Force -ErrorAction SilentlyContinue; Say '  cache du serveur vidé' 'Green'
} else { Say '  rien à vider' 'Green' }

Say "`nTerminé : $freed Mo libérés. Le prochain lancement sera un peu plus long (le jeu retélécharge les mods du serveur)." 'Green'
if (-not $env:GTASOON_TEST) { Read-Host 'Entrée pour quitter' }
