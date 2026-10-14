<#
  ROADLINE - ENVOYER LES PLACEMENTS DU PC AU VPS OVH (V12.57)
  Ce que tu poses en jeu sur le PC est enregistré dans la base DU PC seulement. Ce fichier copie sur le VPS :
    portes verrouillées (ox_doorlock), mapping F11 (objets posés + objets cachés), points de métiers, lieux posés
    (boutiques, parkings), concession (emplacements d'exposition + sorties), courses sur mesure, PNJ du staff.
  Rien d'autre n'est touché : joueurs, argent, véhicules, inventaires restent ceux du VPS.
  Sur le VPS : base sauvegardée avant (« roadline sauvegardes » pour la retrouver), puis ces tables remplacées.
  ATTENTION : ce qui a été posé DIRECTEMENT sur le VPS (et pas sur le PC) dans ces tables est remplacé.
#>
$ErrorActionPreference = 'Stop'
function Say($m, $c = 'Gray') { Write-Host $m -ForegroundColor $c }
function Fail($m) { Say "ERREUR : $m" 'Red'; Read-Host 'Entrée pour quitter'; exit 1 }
. (Join-Path $PSScriptRoot 'outils-ovh.ps1')

$Data = 'C:\GTASOON\server-data'
$Out = 'C:\GTASOON\ovh'
$Repo = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
# Même liste que PLACEMENTS dans scripts/linux/roadline-bdd.sh (le VPS refuse toute autre table)
$Tables = @('ox_doorlock', 'gs_builder_objects', 'gs_builder_hides', 'gs_job_points', 'gs_places', 'gs_showroom_slots',
    'gs_showroom_starts', 'gs_race_custom', 'gs_staff_peds')
if (-not (Test-Path -LiteralPath (Join-Path $Data 'cfg\secrets.cfg'))) { Fail "Serveur du PC introuvable ($Data)." }

Say 'Envoi des placements du PC vers le VPS' 'Cyan'
Say '  Portes, mapping F11, points de métiers, lieux, concession, courses, PNJ du staff.'
Say '  Les joueurs, l''argent, les véhicules et les inventaires du VPS ne sont PAS touchés.'
Say '  Ce qui a été posé directement sur le VPS dans ces catégories sera remplacé par la version du PC.' 'Yellow'
if ((Read-Host '  Continuer ? (O/N)') -notmatch '^[oOyY]') { exit 0 }

Say '[1/3] Copie des placements du PC' 'Cyan'
[void][IO.Directory]::CreateDirectory($Out)
$sql = Join-Path $Out 'placements.sql'
$gz = Join-Path $Out 'roadline-placements.sql.gz'
if (-not (Export-LocalDb $Data $sql $Tables)) { Fail 'Copie impossible : MariaDB du PC arrêté, ou aucun placement enregistré (lance le serveur du PC une fois).' }
$in = [IO.File]::OpenRead($sql)
$outS = [IO.File]::Create($gz)
$z = New-Object IO.Compression.GZipStream($outS, [IO.Compression.CompressionMode]::Compress)
try { $in.CopyTo($z) } finally { $z.Dispose(); $outS.Dispose(); $in.Dispose() }
Remove-Item -LiteralPath $sql -Force
Say ('  {0} Ko' -f [math]::Ceiling((Get-Item $gz).Length / 1KB)) 'Green'

$vps = Get-Vps
Initialize-SshKey $vps
Say '[2/3] Envoi (et commande roadline à jour)' 'Cyan'
$tmpOutils = Join-Path $env:TEMP 'roadline-outils'
[void][IO.Directory]::CreateDirectory($tmpOutils)
$outils = foreach ($f in 'roadline.sh', 'roadline-bdd.sh') { $d = Join-Path $tmpOutils $f; Copy-Unix (Join-Path $Repo "scripts\linux\$f") $d; $d }
Send-Vps $vps ($outils + $gz) '/tmp/'
Invoke-Vps $vps 'sudo install -m 755 /tmp/roadline.sh /tmp/roadline-bdd.sh /home/fivem/outils/ && sudo install -m 755 /home/fivem/outils/roadline.sh /usr/local/bin/roadline && rm -f /tmp/roadline.sh /tmp/roadline-bdd.sh'
if ($LASTEXITCODE -ne 0) { Fail 'Impossible de mettre à jour la commande roadline sur le VPS (voir au-dessus).' }
[IO.Directory]::Delete($tmpOutils, $true)

Say '[3/3] Installation sur le VPS (base sauvegardée avant)' 'Cyan'
$restart = (Read-Host '  Redémarrer le serveur du VPS pour les voir tout de suite ? (~30 s de coupure) (O/N)') -match '^[oOyY]'
Invoke-Vps $vps ('sudo roadline placements /tmp/roadline-placements.sql.gz' + $(if ($restart) { ' redemarrer' } else { '' }))
if ($LASTEXITCODE -ne 0) { Fail 'L''import a échoué sur le VPS (voir au-dessus). La base du VPS n''a pas changé, ou une sauvegarde « avant-placements » existe.' }
Remove-Item -LiteralPath $gz -Force -ErrorAction SilentlyContinue
Say "`nPlacements envoyés." 'Green'
Read-Host 'Entrée pour fermer'
