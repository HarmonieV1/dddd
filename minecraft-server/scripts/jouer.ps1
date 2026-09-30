# Outil "magique" : installe si besoin, demarre le serveur, t'ajoute whitelist + op, et te dit quoi faire.
$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
$srv  = Join-Path $root 'server'
try {
  if (-not (Test-Path (Join-Path $srv 'paper.jar'))) {
    Write-Host '>> Premiere fois : installation (quelques minutes)...' -ForegroundColor Yellow
    & (Join-Path $PSScriptRoot 'install.ps1')
  }
  $pseudoFile = Join-Path $srv 'pseudo.txt'
  if (-not (Test-Path $pseudoFile)) {
    $p = Read-Host 'Ton pseudo Minecraft (exactement comme en jeu)'
    Set-Content $pseudoFile $p.Trim()
  }
  $pseudo = (Get-Content $pseudoFile -Raw).Trim()

  $props = Join-Path $srv 'server.properties'
  function Get-Prop($k) { ((Get-Content $props | Where-Object { $_ -match "^$k=" }) -replace "^$k=", '') | Select-Object -First 1 }
  $rconPort = [int](Get-Prop 'rcon.port'); $rconPass = Get-Prop 'rcon.password'
  . (Join-Path $PSScriptRoot 'rcon.ps1')

  if ((Invoke-Rcon 'list') -match 'injoignable') {
    $worlds = Get-ChildItem $srv -Directory -ErrorAction SilentlyContinue | Where-Object { $_.Name -like 'world*' } | ForEach-Object { $_.FullName }
    if ($worlds) {
      $bdir = Join-Path $root 'backups'; New-Item -ItemType Directory -Force $bdir | Out-Null
      Compress-Archive -Path $worlds -DestinationPath (Join-Path $bdir ("auto-{0}.zip" -f (Get-Date -Format 'yyyy-MM-dd_HH-mm'))) -Force
      Get-ChildItem $bdir -Filter 'auto-*.zip' | Sort-Object LastWriteTime -Descending | Select-Object -Skip 10 | Remove-Item -Force
      Write-Host '>> Sauvegarde automatique du monde faite.' -ForegroundColor Yellow
    }
    Write-Host '>> Demarrage du serveur dans une nouvelle fenetre (ne la ferme pas)...' -ForegroundColor Yellow
    Start-Process powershell -ArgumentList '-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', "`"$(Join-Path $PSScriptRoot 'start.ps1')`""
    $ok = $false
    for ($i = 0; $i -lt 90; $i++) {
      Start-Sleep -Seconds 4
      if ((Invoke-Rcon 'list') -notmatch 'injoignable') { $ok = $true; break }
      Write-Host '   ... chargement du monde'
    }
    if (-not $ok) { throw 'Le serveur ne repond pas. Regarde la fenetre du serveur pour voir l''erreur.' }
  }
  Invoke-Rcon "whitelist add $pseudo" | Out-Null
  Invoke-Rcon "op $pseudo" | Out-Null

  Write-Host ''
  Write-Host '=============================================' -ForegroundColor Green
  Write-Host ' SERVEUR PRET !' -ForegroundColor Green
  Write-Host " 1. Ouvre Minecraft Java (version : $(Get-Content (Join-Path $srv 'version.txt')))"
  Write-Host ' 2. Multijoueur > Ajouter un serveur'
  Write-Host ' 3. Adresse : localhost'
  Write-Host " (pseudo whitelist + admin : $pseudo)"
  Write-Host ' Ne ferme pas la fenetre du serveur pendant que tu joues.'
  Write-Host '=============================================' -ForegroundColor Green
} catch {
  Write-Host "ERREUR : $($_.Exception.Message)" -ForegroundColor Red
}
