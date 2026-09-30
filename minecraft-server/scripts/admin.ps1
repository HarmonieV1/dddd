# Menu admin : envoie des commandes au serveur en marche via RCON (127.0.0.1) + sauvegardes / mise a jour.
$root  = Split-Path $PSScriptRoot -Parent
$srv   = Join-Path $root 'server'
$props = Join-Path $srv 'server.properties'
if (-not (Test-Path $props)) { Write-Host 'Lance INSTALLER.bat d''abord.'; Read-Host 'Entree'; exit 1 }
function Get-Prop($k) { ((Get-Content $props | Where-Object { $_ -match "^$k=" }) -replace "^$k=", '') | Select-Object -First 1 }
$rconPort = [int](Get-Prop 'rcon.port')
$rconPass = Get-Prop 'rcon.password'

function Read-Exact($s, $n) {
  $buf = New-Object byte[] $n; $off = 0
  while ($off -lt $n) { $r = $s.Read($buf, $off, $n - $off); if ($r -le 0) { throw 'connexion fermee' }; $off += $r }
  , $buf
}
function Send-Packet($s, $id, $type, $body) {
  $b = [Text.Encoding]::UTF8.GetBytes($body)
  $ms = New-Object IO.MemoryStream; $w = New-Object IO.BinaryWriter($ms)
  $w.Write([int](10 + $b.Length)); $w.Write([int]$id); $w.Write([int]$type)
  $w.Write([byte[]]$b); $w.Write([byte]0); $w.Write([byte]0); $w.Flush()
  $bytes = $ms.ToArray(); $s.Write($bytes, 0, $bytes.Length)
}
function Read-Packet($s) {
  $len = [BitConverter]::ToInt32((Read-Exact $s 4), 0)
  $d = Read-Exact $s $len
  [pscustomobject]@{ Id = [BitConverter]::ToInt32($d, 0); Type = [BitConverter]::ToInt32($d, 4); Body = [Text.Encoding]::UTF8.GetString($d, 8, $len - 10) }
}
function Invoke-Rcon($cmd) {
  try {
    $c = New-Object Net.Sockets.TcpClient('127.0.0.1', $rconPort)
    $c.ReceiveTimeout = 5000
    $s = $c.GetStream()
    Send-Packet $s 1 3 $rconPass
    do { $p = Read-Packet $s } while ($p.Type -ne 2)
    if ($p.Id -eq -1) { $c.Close(); return 'RCON : mot de passe refuse.' }
    Send-Packet $s 2 2 $cmd
    $r = Read-Packet $s
    $c.Close()
    if ($r.Body) { return $r.Body } else { return '(ok)' }
  } catch { return 'Serveur injoignable : est-il demarre (LANCER.bat) ?' }
}
function Ask($q) { Read-Host $q }
function Run($cmd) { Write-Host (Invoke-Rcon $cmd) -ForegroundColor Cyan }

function Backup {
  $dir = Join-Path $root 'backups'; New-Item -ItemType Directory -Force $dir | Out-Null
  $running = (Invoke-Rcon 'save-off') -notmatch 'injoignable'
  if ($running) { Invoke-Rcon 'save-all flush' | Out-Null }
  $zip = Join-Path $dir ("monde-{0}.zip" -f (Get-Date -Format 'yyyy-MM-dd_HH-mm'))
  $items = Get-ChildItem $srv -Directory | Where-Object { $_.Name -like 'world*' } | ForEach-Object { $_.FullName }
  if ($items) { Compress-Archive -Path $items -DestinationPath $zip -Force; Write-Host "Sauvegarde : $zip" -ForegroundColor Green }
  else { Write-Host 'Aucun monde a sauvegarder pour le moment.' }
  if ($running) { Invoke-Rcon 'save-on' | Out-Null }
}

while ($true) {
  Clear-Host
  $ver = if (Test-Path (Join-Path $srv 'version.txt')) { Get-Content (Join-Path $srv 'version.txt') } else { '?' }
  Write-Host "=== ADMIN MINECRAFT ($ver) ===" -ForegroundColor Yellow
  Write-Host ' 1  Qui est connecte          8  Kick un joueur'
  Write-Host ' 2  Ajouter a la whitelist    9  Bannir / debannir'
  Write-Host ' 3  Retirer de la whitelist  10  Message a tous'
  Write-Host ' 4  Donner op (admin)        11  Jour + beau temps'
  Write-Host ' 5  Retirer op                12  Mode de jeu d''un joueur'
  Write-Host ' 6  Sauvegarder le monde     13  Commande libre'
  Write-Host ' 7  Arreter le serveur       14  Mettre a jour Minecraft (sauvegarde auto)'
  Write-Host ' 0  Quitter'
  switch (Ask "`nChoix") {
    '1'  { Run 'list' }
    '2'  { Run ("whitelist add " + (Ask 'Pseudo')) }
    '3'  { Run ("whitelist remove " + (Ask 'Pseudo')) }
    '4'  { Run ("op " + (Ask 'Pseudo')) }
    '5'  { Run ("deop " + (Ask 'Pseudo')) }
    '6'  { Backup }
    '7'  { if ((Ask 'Arreter le serveur ? (o/n)') -match '^[oOyY]') { Run 'say Arret du serveur...'; Run 'stop' } }
    '8'  { Run ("kick " + (Ask 'Pseudo')) }
    '9'  { if ((Ask 'b = bannir, d = debannir') -eq 'd') { Run ("pardon " + (Ask 'Pseudo')) } else { Run ("ban " + (Ask 'Pseudo')) } }
    '10' { Run ("say " + (Ask 'Message')) }
    '11' { Run 'time set day'; Run 'weather clear' }
    '12' { $j = Ask 'Pseudo'; Run ("gamemode " + (Ask 'survival / creative / adventure / spectator') + " $j") }
    '13' { Run (Ask 'Commande (sans /)') }
    '14' {
      if ((Invoke-Rcon 'list') -notmatch 'injoignable') { Write-Host 'Arrete d''abord le serveur (option 7).' -ForegroundColor Red }
      else { Backup; & (Join-Path $PSScriptRoot 'install.ps1') }
    }
    '0'  { exit }
  }
  Read-Host "`nEntree pour revenir au menu"
}
