@echo off
REM GTA SOON : supprime de ce PC les mods de MARQUES REELLES deja installes (voitures sous licence, mode, police reelle),
REM pour eviter un retrait du serveur par Cfx.re / Rockstar. Garde tout le reste (maps, vetements sans marque, coiffures).
REM Double-clic : arrete le serveur, supprime les mods concernes + leurs archives, nettoie le catalogue, vide le cache.
powershell -NoProfile -ExecutionPolicy Bypass -Command "$t = Get-Content -LiteralPath '%~f0' -Raw; iex ($t.Substring($t.LastIndexOf('#DEBUT' + 'PS#') + 9))"
pause
exit /b
#DEBUTPS#
function Say($m, $c = 'Gray') { Write-Host $m -ForegroundColor $c }
$Root = if ($env:GTASOON_ROOT) { $env:GTASOON_ROOT } else { 'C:\GTASOON' }
$Data = Join-Path $Root 'server-data'
$Addons = Join-Path $Data 'resources\[addons]'
$Cfg = Join-Path $Data 'cfg\addons.cfg'
# Meme liste que scripts\windows\importer-mods.ps1 ($BrandBlock / $BrandStrong) : garder les deux identiques.
$BrandBlock = 'lamborghini|ferrari|porsche|mercedes|maybach|amg|audi|etron|bmw|dodge|chrysler|jeep|ford|mustang|chevrolet|chevy|corvette|cadillac|volkswagen|golf|toyota|lexus|nissan|honda|mazda|subaru|mitsubishi|bugatti|mclaren|tesla|bentley|rolls|aston|jaguar|land.?rover|range.?rover|maserati|alfa|fiat|peugeot|renault|citroen|koenigsegg|pagani|rimac|gucci|versace|nike|adidas|jordan|supreme|balenciaga|louis.?vuitton|dior|chanel|prada|rolex|north.?face|dallas|nypd|lapd|lspd_real|rhgs|roadtrip_vetements_homme'
$BrandStrong = 'lamborghini|ferrari|porsche|mercedes|maybach|bugatti|mclaren|koenigsegg|gucci|versace|balenciaga|louis.?vuitton|rolex|dallas'
function Is-Brand($name) { $name.ToLower() -match $BrandBlock }

if (-not (Test-Path -LiteralPath $Data)) { Say "Serveur introuvable ($Data) : rien a nettoyer." 'Yellow'; return }

Say '[1/5] Recherche des mods de marques' 'Cyan'
$dirs = @()
if (Test-Path -LiteralPath $Addons) {
    foreach ($d in @(Get-ChildItem -LiteralPath $Addons -Directory -Filter 'gsa_*')) {
        $hit = Is-Brand $d.Name.Substring(4)
        if (-not $hit) { $hit = @(Get-ChildItem -LiteralPath $d.FullName -Recurse -File -Force -ErrorAction SilentlyContinue | Where-Object { $_.Name.ToLower() -match $BrandStrong } | Select-Object -First 1).Count -gt 0 }
        if ($hit) { $dirs += $d }
    }
}
$archives = @()
$src = Join-Path $Root 'mods-a-trier'
if (Test-Path -LiteralPath $src) { $archives = @(Get-ChildItem -LiteralPath $src -File -Recurse | Where-Object { Is-Brand $_.BaseName }) }
$sorted = @()
$out = Join-Path $Root 'mods-tri'
if (Test-Path -LiteralPath $out) { $sorted = @(Get-ChildItem -LiteralPath $out -Directory | ForEach-Object { Get-ChildItem -LiteralPath $_.FullName -Directory } | Where-Object { Is-Brand $_.Name }) }

if (($dirs.Count + $archives.Count + $sorted.Count) -eq 0) { Say '  Aucun mod de marque trouve : tout est deja propre.' 'Green'; if ($env:GTASOON_MARQUES_AUTO) { return } }
else {
    foreach ($d in $dirs) { Say "  mod installe : $($d.Name)" 'Yellow' }
    foreach ($a in $archives) { Say "  archive     : $($a.Name)" 'Yellow' }
    foreach ($s in $sorted) { Say "  mods-tri    : $($s.Parent.Name)\$($s.Name)" 'Yellow' }
    if (-not $env:GTASOON_TEST -and -not $env:GTASOON_MARQUES_AUTO) {
        $ok = Read-Host "`nSupprimer tout ca ? (O = oui)"
        if ($ok -notmatch '^[oOyY]') { Say 'Annule : rien n''a ete supprime.' 'Yellow'; return }
    }

    Say '[2/5] Arret du serveur' 'Cyan'
    $srv = @(Get-Process -ErrorAction SilentlyContinue | Where-Object { $_.ProcessName -match '^FXServer' })
    if ($srv.Count -gt 0) { $srv | Stop-Process -Force -ErrorAction SilentlyContinue; Start-Sleep -Seconds 3; Say '  serveur arrete' 'Green' } else { Say '  serveur deja arrete' 'Green' }

    Say '[3/5] Suppression' 'Cyan'
    foreach ($x in @($dirs) + @($sorted)) { Remove-Item -LiteralPath $x.FullName -Recurse -Force -ErrorAction SilentlyContinue; if (Test-Path -LiteralPath $x.FullName) { Say "  impossible (fichier ouvert ?) : $($x.FullName)" 'Red' } }
    foreach ($a in $archives) { Remove-Item -LiteralPath $a.FullName -Force -ErrorAction SilentlyContinue }
    Get-ChildItem -LiteralPath $Root -Directory -Filter '_extraction*' -ErrorAction SilentlyContinue | Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
    if (Test-Path -LiteralPath $Cfg) {
        $names = @($dirs | ForEach-Object { $_.Name })
        $lines = @(Get-Content -LiteralPath $Cfg | Where-Object { $l = $_; -not ($names | Where-Object { $l -match ('(^|\s)' + [regex]::Escape($_) + '(\s|$)') }) })
        [IO.File]::WriteAllLines($Cfg, [string[]]$lines, (New-Object Text.UTF8Encoding $false))
    }
    Say "  $($dirs.Count) mod(s), $($archives.Count) archive(s), $($sorted.Count) dossier(s) tries supprimes" 'Green'
}

Say '[4/5] Catalogue de la concession' 'Cyan'
$core = Get-ChildItem -LiteralPath (Join-Path $Data 'resources') -Directory -Recurse -Filter 'qbx_core' -ErrorAction SilentlyContinue | Select-Object -First 1
$veh = if ($core) { Join-Path $core.FullName 'shared\vehicles.lua' }
if ($veh -and (Test-Path -LiteralPath $veh)) {
    $text = [IO.File]::ReadAllText($veh)
    $new = [regex]::Replace($text, '(?s)\s*-- GTA SOON ADDONS DEBUT.*?-- GTA SOON ADDONS FIN\r?\n', "`n")
    if ($new -ne $text) { [IO.File]::WriteAllText($veh, $new, (New-Object Text.UTF8Encoding $false)); Say '  vehicules importes retires (reconstruit au prochain IMPORTER-MODS / METTRE-A-JOUR)' 'Green' }
    else { Say '  rien a retirer' 'Green' }
}
# Force le prochain import a reconstruire le catalogue avec les mods restants
Remove-Item -LiteralPath (Join-Path $Root 'mods-tri\.derniere-signature') -Force -ErrorAction SilentlyContinue

Say '[5/5] Cache FiveM et serveur' 'Cyan'
Get-Process -ErrorAction SilentlyContinue | Where-Object { $_.ProcessName -match '^FiveM' } | Stop-Process -Force -ErrorAction SilentlyContinue
$fd = Join-Path $env:LOCALAPPDATA 'FiveM\FiveM.app\data'
foreach ($d in 'server-cache', 'server-cache-priv') { Remove-Item -LiteralPath (Join-Path $fd $d) -Recurse -Force -ErrorAction SilentlyContinue }
if (Test-Path -LiteralPath (Join-Path $fd 'cache')) { Get-ChildItem -LiteralPath (Join-Path $fd 'cache') -Force | Where-Object { $_.Name -ne 'game' } | Remove-Item -Recurse -Force -ErrorAction SilentlyContinue }
Remove-Item -LiteralPath (Join-Path $Data 'cache') -Recurse -Force -ErrorAction SilentlyContinue
Say '  caches vides (fichiers de GTA gardes)' 'Green'

Say "`nTermine. Si tes archives de marques sont aussi sur Google Drive (dossier GTA), elles seront simplement refusees a l'import." 'Green'
Say 'Relance METTRE-A-JOUR.bat (ou DEMARRER.bat) : le serveur repart avec les mods sans marque uniquement.' 'Green'
