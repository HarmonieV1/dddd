<#
  ROADLINE - POUSSER SUR GITHUB (dépôt HarmonieV1/dddd, branches feature/phase1-bridge et claude/gta-rp-architecture-stack-pbvdxz).
  En un clic : état du dépôt, récupération de ce que l'autre session a poussé (si c'est sans risque), tests, envoi des commits.
  Identification GitHub : une fenêtre du navigateur à la première fois (Git Credential Manager, livré avec Git), puis mémorisée.
  Jamais de --force : si les deux côtés ont avancé, l'outil s'arrête et dit de demander la fusion à Claude.
  À lancer depuis le CLONE du dépôt (dossier avec .git), pas depuis le zip d'installation.
#>
$ErrorActionPreference = 'Continue'
function Say($m, $c = 'Gray') { Write-Host $m -ForegroundColor $c }
function Fail($m) { Say "ERREUR : $m" 'Red'; Read-Host 'Entrée pour quitter'; exit 1 }
function Ask($q) { return (Read-Host $q).Trim().ToLower() }

$Repo = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)   # scripts\windows -> racine du dépôt
$Main = 'feature/phase1-bridge'
$Twin = 'claude/gta-rp-architecture-stack-pbvdxz'
$Web  = 'https://github.com/HarmonieV1/dddd'

Say ''
Say '  ROADLINE · POUSSER SUR GITHUB' 'Magenta'
Say '  -----------------------------' 'DarkMagenta'

# 1. Git (installé ?) --------------------------------------------------------------------------------------------
$git = $null
$cmd = Get-Command git -ErrorAction SilentlyContinue
if ($cmd) { $git = $cmd.Source }
foreach ($p in @("$env:ProgramFiles\Git\cmd\git.exe", "${env:ProgramFiles(x86)}\Git\cmd\git.exe", "$env:LOCALAPPDATA\Programs\Git\cmd\git.exe")) {
    if (-not $git -and (Test-Path -LiteralPath $p)) { $git = $p }
}
if (-not $git) {
    Say '  Git n''est pas installé sur ce PC. Installe-le une fois (fenêtre PowerShell) :' 'Yellow'
    Say '    winget install --id Git.Git -e --source winget' 'Cyan'
    Say '  puis relance ce .bat.' 'Yellow'
    Read-Host 'Entrée pour quitter'; exit 1
}
$env:Path = (Split-Path -Parent $git) + ';' + $env:Path
$env:GIT_TERMINAL_PROMPT = '1'
$env:GCM_INTERACTIVE = 'always'
if (-not (Test-Path -LiteralPath (Join-Path $Repo '.git'))) {
    Fail "ce dossier n'est pas un clone git : $Repo`n  Il faut le dépôt cloné (git clone $Web), pas le zip d'installation."
}
Set-Location -LiteralPath $Repo
$script:gitCode = 0
function Git {
    param([Parameter(ValueFromRemainingArguments = $true)] $a)
    $out = & $git @a 2>&1
    $script:gitCode = $LASTEXITCODE
    return @($out | ForEach-Object { "$_" })
}
# Identité pour les commits faits d'ici (si aucune n'est réglée)
if (-not ((Git config user.name) -join '')) { Git config user.name 'RoadLine' | Out-Null; Git config user.email 'roadline@users.noreply.github.com' | Out-Null }

# 2. Branche et état ---------------------------------------------------------------------------------------------
$branch = (Git rev-parse --abbrev-ref HEAD) -join ''
if ($branch -ne $Main) {
    Say "  Branche actuelle : $branch (attendu : $Main)." 'Yellow'
    if ((Ask "  Basculer sur $Main ? (o/N)") -eq 'o') {
        Git checkout $Main | Out-Null
        if ($script:gitCode -ne 0) { Fail 'impossible de basculer (modifications en cours ?).' }
    } else { Fail "reste sur $Main pour pousser." }
}
Say "  Dépôt : $Repo" 'DarkGray'
Say '  Lecture de GitHub…' 'DarkGray'
$f = Git fetch origin --prune
if ($script:gitCode -ne 0) { Say ($f -join "`n") 'Yellow'; Fail 'GitHub injoignable (réseau coupé, ou identification demandée : voir le message ci-dessus).' }
$ahead  = [int]((Git rev-list --count "origin/$Main..HEAD") -join '')
$behind = [int]((Git rev-list --count "HEAD..origin/$Main") -join '')
Say ('  Ici    : ' + ((Git log -1 --format='%h %s' HEAD) -join '')) 'Gray'
Say ('  GitHub : ' + ((Git log -1 --format='%h %s' "origin/$Main") -join '')) 'Gray'
Say "  Commits à envoyer : $ahead · commits de l'autre session pas encore ici : $behind" 'Cyan'

# 3. Modifications non enregistrées ------------------------------------------------------------------------------
$dirty = @((Git status --porcelain) | Where-Object { $_ -ne '' })
if ($dirty.Count -gt 0) {
    Say ''
    Say "  $($dirty.Count) fichier(s) modifié(s) pas encore enregistré(s) dans un commit :" 'Yellow'
    $dirty | Select-Object -First 15 | ForEach-Object { Say "    $_" 'DarkGray' }
    if ((Ask '  Les enregistrer dans un commit avant d''envoyer ? (o/N)') -eq 'o') {
        $msg = (Read-Host '  Message du commit (ex : V12.34 : …)').Trim()
        if (-not $msg) { $msg = 'Mise à jour depuis le PC (POUSSER-GITHUB)' }
        Git add -A | Out-Null
        $c = Git commit -q -m $msg
        if ($script:gitCode -ne 0) { Say ($c -join "`n") 'Yellow'; Fail 'commit impossible.' }
        $ahead = [int]((Git rev-list --count "origin/$Main..HEAD") -join '')
        Say '  Commit enregistré.' 'Green'
    } else { Say '  (ces fichiers ne seront pas envoyés)' 'DarkGray' }
}

# 4. Récupération ou divergence ----------------------------------------------------------------------------------
if ($behind -gt 0 -and $ahead -eq 0) {
    Say ''
    Say "  L'autre session a poussé $behind commit(s) et rien de nouveau ici : on peut les récupérer sans risque." 'Cyan'
    if ((Ask '  Les récupérer maintenant ? (O/n)') -ne 'n') {
        $p = Git pull --ff-only origin $Main
        if ($script:gitCode -ne 0) { Say ($p -join "`n") 'Yellow'; Fail 'récupération impossible.' }
        Say '  Dépôt à jour. Rien à envoyer.' 'Green'
    }
    Read-Host 'Entrée pour quitter'; exit 0
}
if ($behind -gt 0 -and $ahead -gt 0) {
    Say ''
    Say "  Les deux côtés ont avancé ($ahead commit(s) ici, $behind sur GitHub) : une FUSION est nécessaire." 'Yellow'
    Say '  Rien n''est forcé. Demande à Claude : « fusionne origin/feature/phase1-bridge dans ma branche », puis relance ce .bat.' 'Yellow'
    Read-Host 'Entrée pour quitter'; exit 1
}
if ($ahead -eq 0) { Say ''; Say '  Rien à envoyer : GitHub est déjà à jour.' 'Green'; Read-Host 'Entrée pour quitter'; exit 0 }

# 5. Tests avant envoi (mêmes tests que le hook pre-push) --------------------------------------------------------
$bash = $null
foreach ($p in @("$env:ProgramFiles\Git\bin\bash.exe", "${env:ProgramFiles(x86)}\Git\bin\bash.exe", (Join-Path (Split-Path -Parent (Split-Path -Parent $git)) 'bin\bash.exe'))) {
    if (-not $bash -and (Test-Path -LiteralPath $p)) { $bash = $p }
}
$tools = Join-Path $env:USERPROFILE '.roadline-tools'
if (Test-Path -LiteralPath $tools) {
    $env:Path = "$tools;$env:LOCALAPPDATA\Programs\Lua\bin;$env:ProgramFiles\nodejs;$env:Path"
    $env:LUA_INIT = '@' + ((Join-Path $tools 'windows-date-fix.lua') -replace '\\', '/')
}
$env:PYTHONUTF8 = '1'
$hasPy = (Get-Command python3 -ErrorAction SilentlyContinue) -or (Get-Command python -ErrorAction SilentlyContinue)
$canTest = $bash -and (Get-Command lua5.4 -ErrorAction SilentlyContinue) -and $hasPy
if ($canTest) {
    Say ''
    Say '  Tests avant envoi (2 à 3 min)…' 'Cyan'
    $u = $Repo -replace '\\', '/'
    $log = & $bash -c "cd '$u' && bash tests/run.sh" 2>&1 | ForEach-Object { "$_" }
    $code = $LASTEXITCODE
    $log | Select-Object -Last 10 | ForEach-Object { Say "    $_" 'DarkGray' }
    if ($code -ne 0) { Fail 'tests en échec : rien n''est envoyé. Corrige (ou demande à Claude) puis relance.' }
    Say '  Tests verts.' 'Green'
} else {
    Say ''
    Say '  Les outils de test (bash, lua5.4, python) ne sont pas installés sur ce PC : les tests ne peuvent pas tourner ici.' 'Yellow'
    if ((Ask '  Envoyer quand même (les tests ont déjà tourné sur le PC de développement) ? (o/N)') -ne 'o') { Read-Host 'Entrée pour quitter'; exit 1 }
}

# 6. Envoi -------------------------------------------------------------------------------------------------------
Say ''
Say "  Envoi de $ahead commit(s) sur GitHub : $Main puis $Twin…" 'Cyan'
Say '  (première fois : une fenêtre GitHub s''ouvre pour t''identifier ; ensuite c''est mémorisé par Windows)' 'DarkGray'
$r1 = Git push origin "${Main}:${Main}"
if ($script:gitCode -ne 0) {
    Say ($r1 -join "`n") 'Yellow'
    if (($r1 -join ' ') -match 'Authentication|could not read Username|403|denied|Permission|Invalid username') {
        Say ''
        Say '  Identification GitHub absente ou refusée.' 'Yellow'
        if (Get-Command gh -ErrorAction SilentlyContinue) {
            Say '  Dans PowerShell :  gh auth login --web   puis   gh auth setup-git   et relance ce .bat.' 'Cyan'
        } else {
            Say '  Installe GitHub CLI :  winget install --id GitHub.cli  puis  gh auth login --web  et  gh auth setup-git' 'Cyan'
        }
    }
    Fail 'envoi refusé (rien n''est perdu : tout reste enregistré ici).'
}
$r2 = Git push origin "${Main}:${Twin}"
if ($script:gitCode -ne 0) {
    Say ($r2 -join "`n") 'Yellow'
    Say "  $Main est sur GitHub, mais pas $Twin (elle a divergé) : demande à Claude de la réaligner." 'Yellow'
} else {
    Say '  Les deux branches sont à jour sur GitHub.' 'Green'
}
Say "  $Web/commits/$Main" 'DarkGray'
Read-Host 'Entrée pour quitter'
