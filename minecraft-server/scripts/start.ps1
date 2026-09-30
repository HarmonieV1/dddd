# Demarre le serveur avec les flags JVM recommandes (Aikar). RAM = min(4 Go, moitie de la RAM du PC).
$root = Split-Path $PSScriptRoot -Parent
$srv  = Join-Path $root 'server'
if (-not (Test-Path (Join-Path $srv 'paper.jar'))) { Write-Host 'Lance INSTALLER.bat d''abord.'; exit 1 }
$java = 'java'
$jf = Join-Path $srv 'java-path.txt'
if (Test-Path $jf) { $java = (Get-Content $jf -Raw).Trim() }
$totalGb = [math]::Floor((Get-CimInstance Win32_ComputerSystem).TotalPhysicalMemory / 1GB)
$ram = [math]::Max(2, [math]::Min(4, [math]::Floor($totalGb / 2)))
Set-Location $srv
Write-Host "Demarrage avec ${ram} Go de RAM. Tape 'stop' dans cette fenetre pour arreter proprement."
$flags = @(
  "-Xms${ram}G", "-Xmx${ram}G",
  '-XX:+UseG1GC', '-XX:+ParallelRefProcEnabled', '-XX:MaxGCPauseMillis=200', '-XX:+UnlockExperimentalVMOptions',
  '-XX:+DisableExplicitGC', '-XX:+AlwaysPreTouch', '-XX:G1NewSizePercent=30', '-XX:G1MaxNewSizePercent=40',
  '-XX:G1HeapRegionSize=8M', '-XX:G1ReservePercent=20', '-XX:G1HeapWastePercent=5', '-XX:G1MixedGCCountTarget=4',
  '-XX:InitiatingHeapOccupancyPercent=15', '-XX:G1MixedGCLiveThresholdPercent=90', '-XX:G1RSetUpdatingPauseTimePercent=5',
  '-XX:SurvivorRatio=32', '-XX:+PerfDisableSharedMem', '-XX:MaxTenuringThreshold=1',
  '-Dusing.aikars.flags=https://mcflags.emc.gg', '-Daikars.new.flags=true',
  '-jar', 'paper.jar', '--nogui'
)
& $java @flags
