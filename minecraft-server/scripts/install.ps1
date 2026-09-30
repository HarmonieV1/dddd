# Installe Java + derniere version de Paper (serveur Minecraft optimise). Relancable = mise a jour du jar.
$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
$srv  = Join-Path $root 'server'
New-Item -ItemType Directory -Force $srv | Out-Null
$hdr = @{ 'User-Agent' = 'roadtrip-mc-setup/1.0' }
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

Write-Host '== 1/4 Recherche de la derniere version de Minecraft (Paper)...'
$proj = Invoke-RestMethod 'https://fill.papermc.io/v3/projects/paper' -Headers $hdr
$all = @()
foreach ($p in $proj.versions.PSObject.Properties) { $all += $p.Value }
$all = $all | Where-Object { $_ -match '^\d+(\.\d+)+$' } | Sort-Object { [version]$_ } -Descending
$mc = $null; $build = $null
foreach ($v in $all) {
  $builds = Invoke-RestMethod "https://fill.papermc.io/v3/projects/paper/versions/$v/builds" -Headers $hdr
  $ok = @($builds) | Where-Object { $_.channel -eq 'STABLE' } | Select-Object -First 1
  if ($ok) { $mc = $v; $build = $ok; break }
}
if (-not $mc) { throw 'Aucune version stable de Paper trouvee.' }
Write-Host "   Minecraft $mc (Paper build $($build.id))"

# Java : 25 pour les versions 26.x et plus, 21 avant
$parts = $mc.Split('.') | ForEach-Object { [int]$_ }
$needJava = if ($parts[0] -ge 26 -or ($parts[0] -eq 1 -and $parts[1] -ge 26)) { 25 } else { 21 }
function Get-JavaMajor($exe) {
  try { $o = (cmd /c "`"$exe`" -version 2>&1") | Out-String; if ($o -match 'version "(\d+)') { return [int]$Matches[1] } } catch {}
  return 0
}
Write-Host "== 2/4 Java $needJava (ou plus) requis..."
$javaFile = Join-Path $srv 'java-path.txt'
$java = 'java'
if ((Get-JavaMajor 'java') -lt $needJava) {
  $found = Get-ChildItem "$env:ProgramFiles\Eclipse Adoptium\jdk-*\bin\java.exe" -ErrorAction SilentlyContinue |
    Where-Object { (Get-JavaMajor $_.FullName) -ge $needJava } | Select-Object -First 1
  if (-not $found) {
    Write-Host "   Installation de Temurin JDK $needJava via winget..."
    winget install -e --id "EclipseAdoptium.Temurin.$needJava.JDK" --accept-package-agreements --accept-source-agreements
    $found = Get-ChildItem "$env:ProgramFiles\Eclipse Adoptium\jdk-*\bin\java.exe" -ErrorAction SilentlyContinue |
      Where-Object { (Get-JavaMajor $_.FullName) -ge $needJava } | Select-Object -First 1
  }
  if (-not $found) { throw "Java $needJava introuvable. Installe-le a la main : https://adoptium.net puis relance." }
  $java = $found.FullName
}
Set-Content $javaFile $java
Write-Host "   OK : $java"

Write-Host '== 3/4 Telechargement du serveur...'
$dl = $build.downloads.'server:default'
$jar = Join-Path $srv 'paper.jar'
$tmp = "$jar.tmp"
Invoke-WebRequest $dl.url -OutFile $tmp -Headers $hdr
$hash = (Get-FileHash $tmp -Algorithm SHA256).Hash.ToLower()
if ($hash -ne $dl.checksums.sha256.ToLower()) { Remove-Item $tmp; throw 'Somme de controle invalide, telechargement corrompu.' }
Move-Item $tmp $jar -Force
Set-Content (Join-Path $srv 'version.txt') "$mc build $($build.id)"

Write-Host '== 4/4 Configuration...'
$eula = Join-Path $srv 'eula.txt'
if (-not (Test-Path $eula) -or -not (Select-String -Path $eula -Pattern 'eula=true' -Quiet)) {
  Write-Host '   Tu dois accepter le CLUF de Mojang : https://aka.ms/MinecraftEULA'
  if ((Read-Host '   Tu acceptes ? (o/n)') -notmatch '^[oOyY]') { throw 'CLUF refuse : installation annulee.' }
  Set-Content $eula 'eula=true'
}
$props = Join-Path $srv 'server.properties'
if (-not (Test-Path $props)) {
  $rng = New-Object byte[] 18
  [Security.Cryptography.RandomNumberGenerator]::Create().GetBytes($rng)
  $pw = [Convert]::ToBase64String($rng) -replace '[^A-Za-z0-9]', 'x'
  (Get-Content (Join-Path $root 'config\server.properties.template')) -replace '@@RCON@@', $pw | Set-Content $props
}
Write-Host ''
Write-Host "TERMINE. Minecraft $mc est installe."
Write-Host 'Etape suivante : LANCER.bat, puis ADMIN.bat pour t''ajouter en op et ajouter tes potes a la whitelist.'
