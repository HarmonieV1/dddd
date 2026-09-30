@echo off
REM GTA SOON : crash "audNorthAudioEngine / INIT_CORE" au lancement de GTA = aucune sortie son sur le PC.
REM Double-clic : reactive les sorties son desactivees, sinon installe une sortie son virtuelle gratuite (VB-CABLE).
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
function Get-ActiveOutputs {
    $root = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\MMDevices\Audio\Render'
    @(Get-ChildItem -LiteralPath $root -ErrorAction SilentlyContinue | Where-Object { (Get-ItemProperty -LiteralPath $_.PSPath -Name DeviceState -ErrorAction SilentlyContinue).DeviceState -eq 1 })
}

Say '[1/3] Sorties son actives' 'Cyan'
$active = Get-ActiveOutputs
if ($active.Count -gt 0) { Say "  $($active.Count) sortie(s) son active(s) : GTA a de quoi demarrer." 'Green' }
else {
    Say '  Aucune sortie son active.' 'Yellow'
    Say '[2/3] Reactivation des peripheriques son desactives' 'Cyan'
    $off = @(Get-PnpDevice -Class AudioEndpoint, MEDIA -ErrorAction SilentlyContinue | Where-Object { $_.Status -ne 'OK' -and $_.Problem -eq 'CM_PROB_DISABLED' })
    foreach ($d in $off) { try { Enable-PnpDevice -InstanceId $d.InstanceId -Confirm:$false -ErrorAction Stop; Say "  reactive : $($d.FriendlyName)" 'Green' } catch { } }
    Start-Sleep -Seconds 3
    $active = Get-ActiveOutputs
    if ($active.Count -gt 0) { Say "  OK : $($active.Count) sortie(s) son active(s)." 'Green' }
    else {
        Say '[3/3] Installation d''une sortie son virtuelle (VB-CABLE, gratuit)' 'Cyan'
        $dir = Join-Path $env:TEMP 'vbcable'
        [void][IO.Directory]::CreateDirectory($dir)
        $zip = Join-Path $dir 'vbcable.zip'
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        $ok = $false
        foreach ($v in 45, 44, 43, 42) {
            try { Invoke-WebRequest -UseBasicParsing -Uri "https://download.vb-audio.com/Download_CABLE/VBCABLE_Driver_Pack$v.zip" -OutFile $zip -ErrorAction Stop; $ok = $true; break } catch { }
        }
        if (-not $ok) {
            Say '  Telechargement impossible. Va sur https://vb-audio.com/Cable/ , telecharge VB-CABLE, extrais, clic droit sur VBCABLE_Setup_x64.exe > Executer en tant qu''administrateur > Install Driver.' 'Red'
            Start-Process 'https://vb-audio.com/Cable/'
        } else {
            Expand-Archive -LiteralPath $zip -DestinationPath $dir -Force
            $setup = Join-Path $dir 'VBCABLE_Setup_x64.exe'
            Say '  Installation (si une fenetre VB-CABLE s''ouvre : clique Install Driver, puis OK).' 'Yellow'
            Start-Process -FilePath $setup -ArgumentList '-i', '-h' -Wait
            Start-Sleep -Seconds 5
            $active = Get-ActiveOutputs
            if ($active.Count -gt 0) { Say '  OK : sortie son virtuelle installee (CABLE Input).' 'Green' }
            else { Start-Process -FilePath $setup -Wait; $active = Get-ActiveOutputs; if ($active.Count -gt 0) { Say '  OK : sortie son virtuelle installee.' 'Green' } else { Say '  Pas encore active : redemarre le PC, puis relance ce fichier.' 'Yellow' } }
        }
    }
}
Say "`nTermine. Relance FiveM (si c'etait deja lance, ferme-le d'abord)." 'Green'
