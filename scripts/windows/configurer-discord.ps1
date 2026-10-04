<#
  ROADLINE - CONFIGURER DISCORD (statut en direct, annonces, bot avec présence et /statut, rôles de métier).
  Tout est demandé une fois ; les adresses et le jeton vont dans secrets.cfg. Le bot tourne dans le serveur (rien à installer).
  Rien n'est affiché en clair (le jeton est saisi masqué). Entrée vide = on garde la valeur actuelle.
#>
$ErrorActionPreference = 'Stop'
function Say($m, $c = 'Gray') { Write-Host $m -ForegroundColor $c }
function Fail($m) { Say "ERREUR : $m" 'Red'; Read-Host 'Entrée pour quitter'; exit 1 }

$Data = 'C:\GTASOON\server-data'
$secrets = Join-Path $Data 'cfg\secrets.cfg'
if (-not (Test-Path -LiteralPath $secrets)) { Fail "Introuvable : $secrets (lance d'abord INSTALLER.bat)." }
$text = Get-Content -LiteralPath $secrets -Raw -Encoding UTF8

function Get-Conv($name) { $m = [regex]::Match($script:text, "(?m)^\s*set\s+$name\s+""([^""]*)"""); if ($m.Success) { $m.Groups[1].Value } else { '' } }
function Set-Conv($name, $value, $comment) {
    $line = "set $name ""$value"""
    if ($comment) { $line = $line.PadRight(48) + "# $comment" }
    if ([regex]::IsMatch($script:text, "(?m)^\s*set\s+$name\s")) {
        $script:text = [regex]::Replace($script:text, "(?m)^\s*set\s+$name\s.*$", [Text.RegularExpressions.MatchEvaluator] { param($m) $line })
    }
    else { $script:text = $script:text.TrimEnd() + "`r`n" + $line + "`r`n" }
}
function Ask-Hook($label, $name) {
    $has = (Get-Conv $name) -ne ''
    Say ''
    Say "  $label" 'Cyan'
    Say ('  (Salon Discord → Modifier → Intégrations → Webhooks → Nouveau → Copier l''URL)' + $(if ($has) { ' · déjà réglé, Entrée pour garder' } else { '' })) 'DarkGray'
    $v = (Read-Host '  URL du webhook').Trim()
    if ($v -eq '') { return }
    if ($v -notmatch '^https://(discord|discordapp)\.com/api/webhooks/\d+/[\w-]+$') { Say '  Adresse invalide, ignorée.' 'Yellow'; return }
    Set-Conv $name $v
    Say '  OK (adresse enregistrée, non affichée).' 'Green'
}

Say ''
Say '  ROADLINE · CONFIGURER DISCORD' 'Magenta'
Say '  -----------------------------' 'DarkMagenta'
Ask-Hook '1/4 · Salon #statut (un message mis à jour chaque minute : joueurs, services, météo)' 'gs_webhook_status'
Ask-Hook '2/4 · Salon #annonces (serveur ouvert, redémarrages)' 'gs_webhook_annonces'

Say ''
Say '  3/4 · Adresse pour rejoindre (ex : cfx.re/join/abc123, visible dans txAdmin). Entrée = garder.' 'Cyan'
$connect = (Read-Host '  Adresse').Trim()
if ($connect -match '^[\w./:-]{4,80}$') { Set-Conv 'gs_connect' $connect 'affichée dans le statut Discord' } else { $connect = Get-Conv 'gs_connect' }

Say ''
Say '  4/4 · Bot RoadLine (présence « 12/48 citoyens », /statut, rôles de métier). Entrée = passer.' 'Cyan'
Say '  (discord.com/developers → New Application → Bot → Reset Token → copier ; inviter le bot avec « Gérer les rôles »)' 'DarkGray'
$sec = Read-Host '  Jeton du bot (masqué)' -AsSecureString
$token = [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($sec))
if ($token) {
    if ($token -notmatch '^[\w.-]{50,100}$') { Say '  Jeton invalide, ignoré.' 'Yellow'; $token = '' }
    else {
        Set-Conv 'gs_discord_bot_token' $token 'NE JAMAIS PARTAGER'
        $guild = (Read-Host '  Identifiant du serveur Discord (clic droit sur le serveur → Copier l''identifiant), Entrée = passer').Trim()
        if ($guild -match '^\d{15,22}$') { Set-Conv 'gs_discord_guild' $guild }
        Say '  Rôles de métier : mets les identifiants des rôles dans [gtasoon]\gs_discord\shared\config.lua (Config.Roles).' 'DarkGray'
    }
}
[IO.File]::WriteAllText($secrets, $text, (New-Object Text.UTF8Encoding $false))
Say ''
Say '  secrets.cfg mis à jour (effet au prochain démarrage du serveur).' 'Green'

if ($token) {
    # Le bot tourne DANS le serveur FiveM (gs_discord) : rien à installer, il démarre avec le serveur, en local comme chez l'hébergeur.
    # Lien d'invitation : l'identifiant du bot est la 1re partie du jeton (pas secrète).
    $first = $token.Split('.')[0]
    $token = $null
    try {
        $pad = $first + ('=' * ((4 - $first.Length % 4) % 4))
        $botId = [Text.Encoding]::ASCII.GetString([Convert]::FromBase64String($pad))
        if ($botId -match '^\d{15,22}$') {
            $invite = "https://discord.com/oauth2/authorize?client_id=$botId&scope=bot%20applications.commands&permissions=268435456"
            Say ''
            Say '  Ajoute le bot à ton Discord (une fois) : la page s''ouvre, choisis ton serveur → Autoriser.' 'Cyan'
            Say "  $invite" 'DarkGray'
            Start-Process $invite
        }
    } catch { }
    Say '  Le bot démarre tout seul avec le serveur (présence « 12/48 citoyens », /statut, /rejoindre, /rdv, /site).' 'Green'
}
Read-Host 'Entrée pour fermer'
