<#
  GTA SOON - Diagnostic et réparation FiveM (« could not detect a valid GTA V Legacy installation »)
  Double-cliquer sur diagnostic-fivem.bat.
  1. Cherche TOUTES les installations de GTA V (registre, Steam, Epic, Rockstar, scan des disques)
  2. Dit pour chacune : Legacy ou Enhanced, complète ou incomplète
  3. Lit la config de FiveM (CitizenFX.ini) et le chemin qu'il utilise
  4. Propose de pointer FiveM sur la bonne installation Legacy (sauvegarde de l'ancien fichier)
  5. Écrit un rapport sur le Bureau : rapport-fivem.txt → l'envoyer à [DEV]
  NON TESTÉ sur une vraie machine Windows : il ne supprime rien, il ne modifie que CitizenFX.ini (sauvegardé).
#>
$ErrorActionPreference = 'Continue'
$report = New-Object System.Collections.Generic.List[string]
function Say($msg, $color = 'Gray') { Write-Host $msg -ForegroundColor $color; $report.Add($msg) }

Say "=== Diagnostic FiveM GTA SOON - $(Get-Date -Format 'dd/MM/yyyy HH:mm') ===" 'Cyan'
Say ("Windows : " + [Environment]::OSVersion.VersionString)

# --- 1. Recherche des installations -------------------------------------------------------
$candidates = New-Object System.Collections.Generic.HashSet[string]
function Add-Candidate($path) {
    if ($path -and (Test-Path -LiteralPath $path)) { [void]$candidates.Add((Resolve-Path -LiteralPath $path).Path.TrimEnd('\')) }
}

Say "`n[1] Registre Rockstar" 'Cyan'
foreach ($root in 'HKLM:\SOFTWARE\WOW6432Node\Rockstar Games', 'HKLM:\SOFTWARE\Rockstar Games') {
    if (Test-Path $root) {
        Get-ChildItem $root -ErrorAction SilentlyContinue | ForEach-Object {
            $props = Get-ItemProperty $_.PSPath -ErrorAction SilentlyContinue
            foreach ($p in $props.PSObject.Properties) {
                if ($p.Name -like 'InstallFolder*') {
                    Say ("  " + $_.PSChildName + " / " + $p.Name + " = " + $p.Value)
                    Add-Candidate $p.Value
                }
            }
        }
    }
}

Say "`n[2] Steam" 'Cyan'
$steam = (Get-ItemProperty 'HKCU:\Software\Valve\Steam' -ErrorAction SilentlyContinue).SteamPath
if ($steam) {
    $libs = @($steam.Replace('/', '\'))
    $vdf = Join-Path $steam 'steamapps\libraryfolders.vdf'
    if (Test-Path -LiteralPath $vdf) {
        Select-String -LiteralPath $vdf -Pattern '"path"\s+"([^"]+)"' | ForEach-Object { $libs += $_.Matches[0].Groups[1].Value.Replace('\\', '\') }
    }
    foreach ($lib in ($libs | Select-Object -Unique)) {
        $common = Join-Path $lib 'steamapps\common'
        Say "  bibliothèque : $lib"
        Get-ChildItem -LiteralPath $common -Directory -ErrorAction SilentlyContinue |
            Where-Object { $_.Name -like 'Grand Theft Auto*' } | ForEach-Object { Add-Candidate $_.FullName }
    }
} else { Say "  Steam non trouvé" }

Say "`n[3] Epic Games" 'Cyan'
$manifests = 'C:\ProgramData\Epic\EpicGamesLauncher\Data\Manifests'
if (Test-Path $manifests) {
    Get-ChildItem $manifests -Filter *.item -ErrorAction SilentlyContinue | ForEach-Object {
        try {
            $m = Get-Content -LiteralPath $_.FullName -Raw | ConvertFrom-Json
            if ($m.DisplayName -like '*Grand Theft Auto*') { Say ("  " + $m.DisplayName + " → " + $m.InstallLocation); Add-Candidate $m.InstallLocation }
        } catch {}
    }
} else { Say "  Epic non trouvé" }

Say "`n[4] Scan des disques (dossiers courants, quelques secondes)" 'Cyan'
Get-PSDrive -PSProvider FileSystem | Where-Object { $_.Free -ne $null } | ForEach-Object {
    foreach ($sub in 'Program Files', 'Program Files (x86)', 'Games', 'Jeux', 'SteamLibrary', 'Epic Games', 'Rockstar Games', '') {
        $base = Join-Path $_.Root $sub
        if (-not (Test-Path -LiteralPath $base)) { continue }
        Get-ChildItem -LiteralPath $base -Recurse -Depth 4 -File -Include 'GTA5.exe', 'GTA5_Enhanced.exe' -ErrorAction SilentlyContinue |
            ForEach-Object { Add-Candidate $_.DirectoryName }
    }
}

# --- 2. Classement ----------------------------------------------------------------------------
Say "`n[5] Installations trouvées" 'Cyan'
$legacy = @()
$i = 0
foreach ($dir in $candidates) {
    $isLegacy = Test-Path -LiteralPath (Join-Path $dir 'GTA5.exe')
    $isEnhanced = Test-Path -LiteralPath (Join-Path $dir 'GTA5_Enhanced.exe')
    if (-not $isLegacy -and -not $isEnhanced) { continue }
    $missing = @('x64a.rpf', 'common.rpf', 'update\update.rpf', 'PlayGTAV.exe') | Where-Object { -not (Test-Path -LiteralPath (Join-Path $dir $_)) }
    $sizeGb = [math]::Round(((Get-ChildItem -LiteralPath $dir -Recurse -File -ErrorAction SilentlyContinue | Measure-Object Length -Sum).Sum / 1GB), 1)
    $kind = if ($isLegacy) { 'LEGACY' } else { 'ENHANCED (incompatible FiveM)' }
    $state = if ($missing.Count -eq 0) { 'complète' } else { 'INCOMPLÈTE, manque : ' + ($missing -join ', ') }
    $i++
    Say ("  [$i] $kind | $state | $sizeGb Go | $dir") ($(if ($isLegacy -and $missing.Count -eq 0) { 'Green' } else { 'Yellow' }))
    if ($isLegacy -and $missing.Count -eq 0) { $legacy += $dir }
}
if ($i -eq 0) { Say "  AUCUNE installation de GTA V trouvée." 'Red' }

# --- 3. FiveM ----------------------------------------------------------------------------------
Say "`n[6] FiveM" 'Cyan'
$app = Join-Path $env:LOCALAPPDATA 'FiveM\FiveM.app'
$ini = Join-Path $app 'CitizenFX.ini'
Say ("  dossier FiveM.app : " + $(if (Test-Path -LiteralPath $app) { 'présent' } else { 'ABSENT (FiveM jamais lancé ?)' }))
if (Test-Path -LiteralPath $ini) { Get-Content -LiteralPath $ini | ForEach-Object { Say "  ini> $_" } } else { Say "  CitizenFX.ini : absent" }
$running = Get-Process -Name 'FiveM*' -ErrorAction SilentlyContinue
if ($running) { Say "  ATTENTION : FiveM tourne encore (ferme-le avant de réparer)" 'Yellow' }
$rgl = (Get-ItemProperty 'HKLM:\SOFTWARE\WOW6432Node\Rockstar Games\Launcher' -ErrorAction SilentlyContinue).InstallFolder
Say ("  Rockstar Games Launcher : " + $(if ($rgl) { $rgl } else { 'NON INSTALLÉ (nécessaire pour Social Club)' }))

# --- 4. Réparation ------------------------------------------------------------------------------
Say "`n[7] Réparation" 'Cyan'
if ($legacy.Count -eq 0) {
    Say "  Aucune installation Legacy COMPLÈTE : installe « Grand Theft Auto V Legacy » (Steam/Epic/Rockstar)," 'Red'
    Say "  lance-le une fois jusqu'au menu, puis relance ce diagnostic." 'Red'
} else {
    $target = $legacy[0]
    if ($legacy.Count -gt 1) {
        for ($k = 0; $k -lt $legacy.Count; $k++) { Write-Host "  ($($k + 1)) $($legacy[$k])" }
        $choice = Read-Host "  Plusieurs Legacy : numéro à utiliser"
        if ($choice -match '^\d+$' -and [int]$choice -ge 1 -and [int]$choice -le $legacy.Count) { $target = $legacy[[int]$choice - 1] }
    }
    $answer = Read-Host "  Pointer FiveM sur '$target' ? (o/n)"
    if ($answer -match '^[oOyY]') {
        if ($running) { $running | Stop-Process -Force; Start-Sleep -Seconds 2 }
        New-Item -ItemType Directory -Force $app | Out-Null
        $lines = @()
        if (Test-Path -LiteralPath $ini) {
            Copy-Item -LiteralPath $ini -Destination "$ini.bak-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
            $lines = Get-Content -LiteralPath $ini | Where-Object { $_ -notmatch '^\s*IVPath\s*=' }
        }
        if (-not ($lines -match '^\s*\[Game\]')) { $lines = @('[Game]') + $lines }
        $out = New-Object System.Collections.Generic.List[string]
        foreach ($l in $lines) { $out.Add($l); if ($l -match '^\s*\[Game\]') { $out.Add("IVPath=$target") } }
        [System.IO.File]::WriteAllLines($ini, $out, (New-Object System.Text.UTF8Encoding $false))
        Say "  CitizenFX.ini réécrit (ancien sauvegardé en .bak). Relance FiveM." 'Green'
    } else { Say "  Aucune modification." }
}

$file = Join-Path ([Environment]::GetFolderPath('Desktop')) 'rapport-fivem.txt'
$report | Set-Content -LiteralPath $file -Encoding UTF8
Write-Host "`nRapport enregistré : $file  → envoie-le à [DEV] si FiveM ne marche toujours pas." -ForegroundColor Cyan
