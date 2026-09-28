<#
  GTA SOON - Changer la clé de licence du serveur (sans ouvrir de fichier).
  1. Copie ta clé sur portal.cfx.re (Server Keys)  2. Double-clic sur CHANGER-LICENCE.bat
  Lit la clé dans le presse-papiers, vérifie le format, l'écrit dans cfg\secrets.cfg, redémarre le serveur.
#>
$ErrorActionPreference = 'Stop'
function Say($m, $c = 'Gray') { Write-Host $m -ForegroundColor $c }
$Data = 'C:\GTASOON\server-data'
$secrets = Join-Path $Data 'cfg\secrets.cfg'
if (-not (Test-Path -LiteralPath $secrets)) { Say "Introuvable : $secrets (lance d'abord INSTALLER.bat)." 'Red'; Read-Host 'Entrée'; exit 1 }

# Nettoie (espaces, guillemets) et dédoublonne une clé collée deux fois (cfxk_AAAcfxk_AAA -> cfxk_AAA)
function Clean($k) {
    $k = "$k" -replace '[\s"''<>]', ''
    $m = [regex]::Match($k, 'cfxk_.*?(?=cfxk_|$)')
    if ($m.Success) { return $m.Value } else { return $k }
}
$key = ''
try { $clip = Clean (Get-Clipboard -Raw) } catch { $clip = '' }
if ($clip -match '^cfxk_[A-Za-z0-9_\-]{10,}$') {
    Say "Clé trouvée dans le presse-papiers : $($clip.Substring(0, 9))…$($clip.Substring($clip.Length - 4)) ($($clip.Length) caractères)" 'Green'
    $key = $clip
} else {
    # Pas de clé copiée : si la clé déjà enregistrée a été collée deux fois, on la répare directement
    $old = [regex]::Match((Get-Content -LiteralPath $secrets -Raw -Encoding UTF8), 'sv_licenseKey\s+"([^"]*)"').Groups[1].Value
    if (([regex]::Matches($old, 'cfxk_')).Count -gt 1) {
        $key = Clean $old
        Say "Clé enregistrée collée en double : réparée ($($key.Substring(0, 9))…$($key.Substring($key.Length - 4)))." 'Green'
    }
}
if (-not $key) {
    Say 'Pas de clé dans le presse-papiers.' 'Yellow'
    Say 'Va sur https://portal.cfx.re > Server Keys, COPIE ta clé, puis reviens ici.' 'Cyan'
    while ($key -notmatch '^cfxk_[A-Za-z0-9_\-]{10,}$') {
        Read-Host 'Appuie sur Entrée quand la clé est copiée'
        try { $key = Clean (Get-Clipboard -Raw) } catch { $key = '' }
        if ($key -notmatch '^cfxk_') { Say 'Toujours pas de clé cfxk_… dans le presse-papiers.' 'Red' }
    }
    Say "Clé : $($key.Substring(0, 9))…$($key.Substring($key.Length - 4)) ($($key.Length) caractères)" 'Green'
}

$content = Get-Content -LiteralPath $secrets -Raw -Encoding UTF8
$content = [regex]::Replace($content, 'sv_licenseKey\s+"[^"]*"', ('sv_licenseKey "' + $key + '"'))
[IO.File]::WriteAllText($secrets, $content, (New-Object Text.UTF8Encoding $false))
Say 'Clé enregistrée dans cfg\secrets.cfg.' 'Green'

Get-Process -Name FXServer -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
Start-Sleep -Seconds 2
Start-Process -FilePath (Join-Path $Data 'DEMARRER.bat') -WorkingDirectory $Data
Say "`nServeur relancé. Dans la fenêtre « Serveur GTA SOON », cherche : « Server license key authentication succeeded »." 'Cyan'
Say 'Si l''erreur de clé revient avec une clé toute neuve : attends 5-10 min et relance ce même outil.' 'Cyan'
Read-Host 'Entrée pour fermer'
