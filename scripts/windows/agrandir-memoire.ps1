<#
  GTA SOON - AGRANDIR LA MÉMOIRE VIRTUELLE (fichier d'échange de Windows, sur le disque C:).
  Avec 8 Go de RAM, serveur + base + GTA dépassent la mémoire : Windows utilise alors le disque en renfort. S'il est trop
  petit, FiveM plante (« std::bad_alloc »). Règle : 16 Go minimum, 24 Go maximum (il faut ~25 Go libres sur C:).
  Demande les droits administrateur (obligatoire pour ce réglage), puis propose de redémarrer le PC.
#>
function Say($m, $c = 'Gray') { Write-Host $m -ForegroundColor $c }
$admin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $admin) {
    Say 'Droits administrateur nécessaires : clique « Oui » dans la fenêtre Windows qui s''ouvre.' 'Yellow'
    try { Start-Process powershell.exe -Verb RunAs -ArgumentList @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', "`"$PSCommandPath`"") } catch { Say 'Refusé : relance et clique « Oui ».' 'Red'; Read-Host 'Entrée pour quitter' }
    exit
}
$MinMB = 16384; $MaxMB = 24576
try {
    $free = [math]::Round((Get-PSDrive C).Free / 1GB)
    if ($free -lt 30) { Say "Disque C: : seulement $free Go libres, il en faut ~30. Libère de la place puis relance." 'Red'; Read-Host 'Entrée pour quitter'; exit 1 }
    $ram = [math]::Round((Get-CimInstance Win32_OperatingSystem).TotalVisibleMemorySize / 1MB, 1)
    $cur = Get-CimInstance Win32_PageFileUsage -ErrorAction SilentlyContinue | Select-Object -First 1
    Say "RAM : $ram Go · mémoire virtuelle actuelle : $(if ($cur) { "$($cur.AllocatedBaseSize) Mo" } else { 'aucune' })" 'Cyan'

    $cs = Get-CimInstance Win32_ComputerSystem
    if ($cs.AutomaticManagedPagefile) { Set-CimInstance -InputObject $cs -Property @{ AutomaticManagedPagefile = $false } }
    $pf = Get-CimInstance Win32_PageFileSetting -ErrorAction SilentlyContinue | Where-Object { $_.Name -like 'C:*' } | Select-Object -First 1
    if ($pf) { Set-CimInstance -InputObject $pf -Property @{ InitialSize = [uint32]$MinMB; MaximumSize = [uint32]$MaxMB } }
    else { New-CimInstance -ClassName Win32_PageFileSetting -Property @{ Name = 'C:\pagefile.sys'; InitialSize = [uint32]$MinMB; MaximumSize = [uint32]$MaxMB } | Out-Null }
    Say "OK : mémoire virtuelle réglée à 16 Go minimum / 24 Go maximum sur C:." 'Green'
} catch {
    Say "Réglage impossible : $($_.Exception.Message)" 'Red'
    Say 'À la main : touche Windows → « Afficher les paramètres système avancés » → Performances → Paramètres → Avancé → Mémoire virtuelle → Modifier.' 'Yellow'
    Read-Host 'Entrée pour quitter'; exit 1
}
Say "`nIl faut REDÉMARRER le PC pour que ce soit pris en compte." 'Yellow'
$r = Read-Host 'Redémarrer maintenant ? (O/N)'
if ($r -match '^[oOyY]') { Restart-Computer -Force } else { Say 'Pense à redémarrer avant de relancer le serveur.' 'Yellow'; Read-Host 'Entrée pour quitter' }
