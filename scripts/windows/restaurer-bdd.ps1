<#
  ROADLINE - RESTAURER LA BASE (retour en arrière après un gros bug, un crash ou une triche).
  Double-clic sur RESTAURER-BDD.bat :
    1. Retour en arrière COMPLET : toute la base revient à l'heure de la sauvegarde choisie (serveur arrêté).
    2. Retour en arrière d'UN SEUL joueur : son personnage (argent, inventaire, métier…) et ses véhicules reviennent
       à l'heure de la sauvegarde ; le reste du serveur ne bouge pas (idéal après une triche).
  Avant toute restauration, l'état actuel est sauvegardé (on peut donc annuler en restaurant cette sauvegarde-là).
  Aucun mot de passe n'est affiché.
#>
$ErrorActionPreference = 'Stop'
function Say($m, $c = 'Gray') { Write-Host $m -ForegroundColor $c }
function Fail($m) { Say "ERREUR : $m" 'Red'; Read-Host 'Entrée pour quitter'; exit 1 }

$Data = 'C:\GTASOON\server-data'
$secrets = Join-Path $Data 'cfg\secrets.cfg'
if (-not (Test-Path -LiteralPath $secrets)) { Fail "Introuvable : $secrets (lance d'abord INSTALLER.bat)." }
$content = Get-Content -LiteralPath $secrets -Raw -Encoding UTF8
$cs = [regex]::Match($content, 'mysql_connection_string\s+"mysql:/{2}([^:]+):(.*)@([^:/@]+)(?::(\d+))?/([^?"]+)')
if (-not $cs.Success) { Fail 'mysql_connection_string illisible dans secrets.cfg.' }
$user, $pass, $dbHost, $port, $db = $cs.Groups[1].Value, $cs.Groups[2].Value, $cs.Groups[3].Value, $cs.Groups[4].Value, $cs.Groups[5].Value
if (-not $port) { $port = '3306' }

$svc = Get-CimInstance Win32_Service | Where-Object { $_.Name -match 'maria|mysql' -and $_.PathName -match 'mysqld|mariadbd' } | Select-Object -First 1
if (-not $svc) { Fail 'Service MariaDB introuvable.' }
$bin = Split-Path ([regex]::Match($svc.PathName, '^"?([^"]+?(mysqld|mariadbd)\.exe)').Groups[1].Value)
$Client = @('mariadb.exe', 'mysql.exe') | ForEach-Object { Join-Path $bin $_ } | Where-Object { Test-Path $_ } | Select-Object -First 1
if (-not $Client) { Fail "Client MariaDB introuvable dans $bin." }

function Sql([string]$database, [string]$query) {
    $env:MYSQL_PWD = $pass
    $ErrorActionPreference = 'Continue'
    $cli = @('-h', $dbHost, '-P', $port, '-u', $user, '--default-character-set=utf8mb4', '-N', '-B')
    if ($database) { $cli += $database }
    $out = & $Client @cli -e $query 2>&1
    $code = $LASTEXITCODE
    $ErrorActionPreference = 'Stop'
    Remove-Item Env:MYSQL_PWD -ErrorAction SilentlyContinue
    $msg = ($out | ForEach-Object { "$_" } | Where-Object { $_ -notmatch 'ssl-verify-server-cert' }) -join ' '
    if ($code -ne 0) { throw $msg }
    return $out
}
function Import([string]$database, [string]$file) {
    $path = $file -replace '\\', '/'
    Sql $database "SET FOREIGN_KEY_CHECKS=0; source $path; SET FOREIGN_KEY_CHECKS=1;" | Out-Null
}

Say ''
Say '  ROADLINE · RESTAURER LA BASE DE DONNÉES' 'Magenta'
Say '  ----------------------------------------' 'DarkMagenta'
$dir = 'C:\GTASOON\sauvegardes\bdd'
$list = @(Get-ChildItem -LiteralPath $dir -Filter '*.sql' -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending | Select-Object -First 20)
if ($list.Count -eq 0) { Fail "Aucune sauvegarde dans $dir. Lance d'abord SAUVEGARDER-BDD.bat." }

Say ''
Say '  Que veux-tu faire ?' 'Cyan'
Say '   1. Retour en arrière COMPLET (tout le serveur)'
Say '   2. Retour en arrière d''UN joueur (après une triche, un bug sur son perso)'
$mode = Read-Host '  Choix (1 ou 2)'
if ($mode -notin @('1', '2')) { Fail 'Choix invalide.' }

$cid = $null
if ($mode -eq '2') {
    Say '  citizenid du joueur (visible dans le menu staff F11 → Joueurs, ou F10) :' 'Cyan'
    $cid = (Read-Host '  citizenid').Trim().ToUpper()
    if ($cid -notmatch '^[A-Z0-9]{3,16}$') { Fail 'citizenid invalide (lettres et chiffres uniquement).' }
}

Say ''
Say '  Sauvegardes disponibles (la plus récente en premier) :' 'Cyan'
for ($i = 0; $i -lt $list.Count; $i++) {
    $f = $list[$i]
    Say ("   {0,2}. {1:dd/MM/yyyy HH:mm}   {2,6} Mo   {3}" -f ($i + 1), $f.LastWriteTime, [math]::Round($f.Length / 1MB, 1), $f.Name)
}
$n = Read-Host '  Numéro de la sauvegarde à restaurer'
$idx = 0
if (-not [int]::TryParse($n, [ref]$idx) -or $idx -lt 1 -or $idx -gt $list.Count) { Fail 'Numéro invalide.' }
$chosen = $list[$idx - 1]

$running = Get-Process -ErrorAction SilentlyContinue | Where-Object { $_.ProcessName -match '^FXServer' }
if ($mode -eq '1' -and $running) {
    Say ''
    Say '  Le serveur tourne. Il doit être arrêté pour un retour en arrière complet.' 'Yellow'
    if ((Read-Host '  Arrêter le serveur maintenant ? (O/N)') -notmatch '^[oOyY]') { Fail 'Annulé : arrête le serveur puis relance cet outil.' }
    $running | Stop-Process -Force
    Start-Sleep -Seconds 3
}
if ($mode -eq '2' -and $running) {
    Say '  Le serveur tourne : assure-toi que ce joueur est DÉCONNECTÉ (sinon le jeu réécrira ses données).' 'Yellow'
}

Say ''
$what = if ($mode -eq '1') { "TOUTE la base '$db'" } else { "le joueur $cid (perso + véhicules)" }
Say ("  Tu vas remettre {0} à l'état du {1:dd/MM/yyyy à HH:mm}." -f $what, $chosen.LastWriteTime) 'Yellow'
if ((Read-Host '  Confirmer ? Tape OUI') -ne 'OUI') { Fail 'Annulé.' }

# 1. Sauvegarde de sécurité de l'état actuel (pour pouvoir annuler)
$backup = Join-Path $PSScriptRoot 'sauvegarder-bdd.ps1'
if (-not (Test-Path -LiteralPath $backup)) { $backup = 'C:\GTASOON\outils\sauvegarder-bdd.ps1' }
if (Test-Path -LiteralPath $backup) {
    Say '  [1/2] Sauvegarde de sécurité de l''état actuel…' 'Cyan'
    & powershell -NoProfile -ExecutionPolicy Bypass -File $backup -Auto -Label 'avant-restauration'
    if ($LASTEXITCODE -ne 0) { Fail 'La sauvegarde de sécurité a échoué : restauration annulée (rien n''a été modifié).' }
} else {
    Say '  [1/2] Outil de sauvegarde introuvable : pas de sauvegarde de sécurité.' 'Yellow'
    if ((Read-Host '  Continuer quand même ? (O/N)') -notmatch '^[oOyY]') { Fail 'Annulé.' }
}

# 2. Restauration
try {
    if ($mode -eq '1') {
        Say '  [2/2] Restauration complète (quelques minutes selon la taille)…' 'Cyan'
        Import $db $chosen.FullName
    } else {
        $rb = "${db}_retour"
        Say '  [2/2] Lecture de la sauvegarde dans une base temporaire…' 'Cyan'
        Sql '' "DROP DATABASE IF EXISTS ``$rb``; CREATE DATABASE ``$rb`` CHARACTER SET utf8mb4;" | Out-Null
        Import $rb $chosen.FullName
        $found = Sql '' "SELECT COUNT(*) FROM ``$rb``.players WHERE citizenid = '$cid';"
        if ("$found".Trim() -eq '0') {
            Sql '' "DROP DATABASE IF EXISTS ``$rb``;" | Out-Null
            Fail "Le joueur $cid n'existait pas encore dans cette sauvegarde. Rien n'a été modifié."
        }
        Say '        Remise du personnage et des véhicules…' 'Cyan'
        Sql '' @"
SET FOREIGN_KEY_CHECKS=0;
START TRANSACTION;
REPLACE INTO ``$db``.players SELECT * FROM ``$rb``.players WHERE citizenid = '$cid';
DELETE FROM ``$db``.player_vehicles WHERE citizenid = '$cid';
INSERT INTO ``$db``.player_vehicles SELECT * FROM ``$rb``.player_vehicles WHERE citizenid = '$cid';
COMMIT;
SET FOREIGN_KEY_CHECKS=1;
"@ | Out-Null
        Sql '' "DROP DATABASE IF EXISTS ``$rb``;" | Out-Null
    }
} catch {
    Fail ("Restauration échouée : $_`nTon état d'avant est dans la sauvegarde « avant-restauration » ($dir).")
}

Say ''
Say '  Restauration terminée.' 'Green'
if ($mode -eq '1') { Say '  Relance le serveur (LANCER-SERVEUR / txAdmin).' 'Green' }
else { Say "  Le joueur $cid peut se reconnecter." 'Green' }
Say "  Pour annuler : relance cet outil et choisis la sauvegarde « avant-restauration »." 'Cyan'
Read-Host 'Entrée pour fermer'
