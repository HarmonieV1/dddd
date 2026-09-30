# Outil "amis" : telecharge playit.gg, ajoute ton ami a la whitelist, lance le tunnel.
$ErrorActionPreference = 'Stop'
$root  = Split-Path $PSScriptRoot -Parent
$srv   = Join-Path $root 'server'
$tools = Join-Path $root 'tools'
try {
  $props = Join-Path $srv 'server.properties'
  if (-not (Test-Path $props)) { throw 'Lance JOUER.bat d''abord.' }
  function Get-Prop($k) { ((Get-Content $props | Where-Object { $_ -match "^$k=" }) -replace "^$k=", '') | Select-Object -First 1 }
  $rconPort = [int](Get-Prop 'rcon.port'); $rconPass = Get-Prop 'rcon.password'
  . (Join-Path $PSScriptRoot 'rcon.ps1')
  if ((Invoke-Rcon 'list') -match 'injoignable') { throw 'Le serveur n''est pas demarre : lance JOUER.bat d''abord et laisse sa fenetre ouverte.' }

  while ($true) {
    $ami = (Read-Host 'Pseudo Minecraft de ton ami (vide = terminer)').Trim()
    if (-not $ami) { break }
    Write-Host (Invoke-Rcon "whitelist add $ami") -ForegroundColor Cyan
  }

  New-Item -ItemType Directory -Force $tools | Out-Null
  $exe = Join-Path $tools 'playit.exe'
  if (-not (Test-Path $exe)) {
    Write-Host '>> Telechargement de playit.gg...' -ForegroundColor Yellow
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    $rel = Invoke-RestMethod 'https://api.github.com/repos/playit-cloud/playit-agent/releases/latest' -Headers @{ 'User-Agent' = 'roadtrip-mc-setup' }
    $asset = $rel.assets | Where-Object { $_.name -match 'windows.*x86_64.*\.exe$' } | Sort-Object { $_.name -match 'signed' } -Descending | Select-Object -First 1
    if (-not $asset) { throw 'Programme playit introuvable. Telecharge-le sur https://playit.gg/download et mets-le dans le dossier tools sous le nom playit.exe.' }
    Invoke-WebRequest $asset.browser_download_url -OutFile $exe
  }
  Start-Process $exe
  Write-Host ''
  Write-Host '=============================================' -ForegroundColor Green
  Write-Host ' Une fenetre playit s''est ouverte.' -ForegroundColor Green
  Write-Host ' 1. Elle affiche un lien : ouvre-le (ou il s''ouvre seul), cree un compte gratuit, valide.'
  Write-Host ' 2. Sur le site : cree un tunnel "Minecraft Java", port local 25565.'
  Write-Host ' 3. Copie l''adresse affichee et envoie-la a ton ami (version Minecraft 26.2).'
  Write-Host ' Garde la fenetre playit ET celle du serveur ouvertes.'
  Write-Host '=============================================' -ForegroundColor Green
} catch {
  Write-Host "ERREUR : $($_.Exception.Message)" -ForegroundColor Red
}
