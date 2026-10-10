@echo off
REM GTA SOON : inviter 1 ou 2 amis sur ton serveur local. Double-clic : ouvre le pare-feu, installe Tailscale si besoin,
REM et affiche l'adresse a donner a tes amis.
net session >nul 2>&1
if errorlevel 1 (
  echo Droits administrateur necessaires : clique "Oui" dans la fenetre Windows.
  powershell -NoProfile -Command "Start-Process -FilePath '%~f0' -Verb RunAs"
  exit /b
)
powershell -NoProfile -ExecutionPolicy Bypass -Command "$t = Get-Content -LiteralPath '%~f0' -Raw; iex ($t.Substring($t.LastIndexOf('#DEBUT' + 'PS#') + 9))"
pause
exit /b
#DEBUTPS#
function Say($m, $c = 'Gray') { Write-Host $m -ForegroundColor $c }
$port = 30120

Say '[1/3] Pare-feu Windows (port 30120)' 'Cyan'
foreach ($proto in 'TCP', 'UDP') {
    $name = "GTA SOON FiveM $proto"
    if (-not (Get-NetFirewallRule -DisplayName $name -ErrorAction SilentlyContinue)) {
        New-NetFirewallRule -DisplayName $name -Direction Inbound -Protocol $proto -LocalPort $port -Action Allow -Profile Any | Out-Null
        Say "  regle ajoutee : $proto $port" 'Green'
    } else { Say "  regle deja presente : $proto $port" 'Green' }
}

Say '[2/3] Tailscale (reseau prive entre toi et tes amis)' 'Cyan'
$ts = @('C:\Program Files\Tailscale\tailscale.exe', 'C:\Program Files (x86)\Tailscale\tailscale.exe') | Where-Object { Test-Path -LiteralPath $_ } | Select-Object -First 1
if (-not $ts) {
    Say '  Tailscale absent : installation (winget)...' 'Yellow'
    try { winget install --id Tailscale.Tailscale -e --silent --accept-package-agreements --accept-source-agreements | Out-Null } catch { }
    $ts = @('C:\Program Files\Tailscale\tailscale.exe', 'C:\Program Files (x86)\Tailscale\tailscale.exe') | Where-Object { Test-Path -LiteralPath $_ } | Select-Object -First 1
}
if (-not $ts) {
    Say '  Installation automatique impossible. Telecharge Tailscale sur https://tailscale.com/download (Windows), installe-le, connecte-toi, puis relance ce fichier.' 'Red'
    Start-Process 'https://tailscale.com/download'
} else {
    $ip = (& $ts ip -4 2>$null | Select-Object -First 1)
    if (-not $ip) {
        Say '  Tailscale installe mais pas connecte : une fenetre de connexion va s''ouvrir. Connecte-toi (compte Google ou Microsoft), puis relance ce fichier.' 'Yellow'
        Start-Process -FilePath $ts -ArgumentList 'up' -ErrorAction SilentlyContinue
    } else {
        Say "  Tailscale OK : ton adresse privee est $ip" 'Green'
    }
}

Say '[3/3] Adresses a donner' 'Cyan'
$lan = Get-NetIPAddress -AddressFamily IPv4 -ErrorAction SilentlyContinue | Where-Object { $_.IPAddress -match '^(192\.168|10\.|172\.(1[6-9]|2\d|3[01]))\.' -and $_.InterfaceAlias -notmatch 'Tailscale|vEthernet|VirtualBox|VMware' } | Select-Object -First 1
if ($lan) { Say "  Ami DANS TA MAISON (meme box / Wi-Fi) : connect $($lan.IPAddress):$port" 'Green' }
if ($ts -and $ip) { Say "  Ami A DISTANCE (via Tailscale)         : connect $ip`:$port" 'Green' }

Say "`nComment faire, cote ami :" 'Cyan'
Say '  A distance : ton ami installe Tailscale (https://tailscale.com/download) et cree son compte.'
Say '    Toi : va sur https://login.tailscale.com/admin/machines , a droite de ton PC clique les 3 points > Share > entre l''e-mail de ton ami.'
Say '    Lui : accepte l''invitation recue par e-mail, garde Tailscale connecte.'
Say '  Ensuite, dans FiveM, il appuie sur F8 et tape la ligne "connect ..." affichee plus haut.'
Say '  Ton serveur doit etre lance (DEMARRER.bat) et ton PC allume. 48 places max (cfg\dev.cfg).'
