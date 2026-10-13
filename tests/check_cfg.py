#!/usr/bin/env python3
"""Linter de config serveur : ordre des ensure, dépendances, ressources interdites, fuites de secrets."""
import pathlib, re, subprocess, sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
SERVER = ROOT / "server"
OURS = SERVER / "resources" / "[gtasoon]"
FORBIDDEN = {"qbx_management": "remplacé par gs_jobs", "qbx_weathersync": "remplacé par gs_weather",
             "Renewed-Weathersync": "remplacé par gs_weather", "qbx_hud": "remplacé par gs_hud", "npwd": "remplacé par gs_phone",
             "qb-weathersync": "remplacé par gs_weather", "vSync": "remplacé par gs_weather"}
REMOVED = {"onesync": "ConVar interne, passer +set onesync on sur la ligne de commande",
           "sv_endpointPrivacy": "supprimée par FXServer"}
REQUIRED = {"qbx_idcard": "qbx_core en a besoin à la création du perso (sinon écran noir + chargement infini)",
            "qbx_vehicles": "requis par garages / concession"}
SECRET_KEYS = re.compile(r"(licensekey|webhook|mysql_connection|apikey|password|token|secret)", re.I)
errors = []

def read_cfg(path, seen):
    """Lit un cfg et suit les `exec` (hors secrets.cfg, remplacé par son .example)."""
    lines = []
    for n, raw in enumerate(path.read_text(encoding="utf-8").splitlines(), 1):
        if ";" in raw:
            errors.append(f"{path.name}:{n} point-virgule interdit (séparateur de commandes FiveM, même en commentaire)")
        for removed in REMOVED:
            if re.match(rf"\s*(set[sr]?\s+)?{removed}\b", raw):
                errors.append(f"{path.name}:{n} {removed} : {REMOVED[removed]}")
        line = raw.split("#", 1)[0].strip()
        if not line:
            continue
        m = re.match(r"exec\s+(\S+)", line)
        if m:
            target = SERVER / m.group(1)
            if not target.exists():
                target = target.with_name(target.name + ".example")
            if not target.exists():
                errors.append(f"{path.name}:{n} exec introuvable : {m.group(1)}")
            elif target not in seen:
                seen.add(target)
                lines += read_cfg(target, seen)
            continue
        lines.append((path, n, line))
    return lines

lines = read_cfg(SERVER / "server.cfg.example", set())

# 1. Ensures : doublons, interdits, ressources maison présentes
ensures = []
for path, n, line in lines:
    m = re.match(r"(?:ensure|start)\s+(\S+)", line)
    if not m:
        continue
    res = m.group(1)
    if res in ensures:
        errors.append(f"{path.name}:{n} ensure en double : {res}")
    if res in FORBIDDEN:
        errors.append(f"{path.name}:{n} ressource interdite {res} ({FORBIDDEN[res]})")
    if res.startswith("gs_") and not (OURS / res / "fxmanifest.lua").exists():
        errors.append(f"{path.name}:{n} {res} ensure mais absente de resources/[gtasoon]")
    ensures.append(res)

for res, why in REQUIRED.items():
    if res not in ensures:
        errors.append(f"ensure {res} manquant : {why}")

for folder in sorted(OURS.iterdir()):
    if (folder / "fxmanifest.lua").exists() and folder.name not in ensures:
        errors.append(f"ressource maison jamais démarrée : {folder.name}")

# 2. Dépendances déclarées (fxmanifest) démarrées AVANT la ressource
for folder in sorted(OURS.iterdir()):
    manifest = folder / "fxmanifest.lua"
    if not manifest.exists() or folder.name not in ensures:
        continue
    text = manifest.read_text(encoding="utf-8")
    if "lua54 'yes'" not in text:
        errors.append(f"{folder.name} : lua54 'yes' manquant")
    m = re.search(r"dependenc(?:y|ies)\s*\{([^}]*)\}", text)
    for dep in re.findall(r"'([^']+)'", m.group(1) if m else ""):
        if dep not in ensures:
            errors.append(f"{folder.name} dépend de {dep}, jamais démarré")
        elif ensures.index(dep) > ensures.index(folder.name):
            errors.append(f"{folder.name} démarre avant sa dépendance {dep}")

# 3. Secrets : jamais répliqués aux clients, jamais de vraie valeur dans le repo
for path, n, line in lines:
    m = re.match(r"(setr|sets|set)?\s*(\S+)\s+(.*)", line)
    if not m:
        continue
    cmd, key, value = m.groups()
    if SECRET_KEYS.search(key) and cmd in ("setr", "sets"):
        errors.append(f"{path.name}:{n} secret {key} en {cmd} : il serait envoyé aux clients, utiliser set")

tracked = subprocess.run(["git", "ls-files"], cwd=ROOT, capture_output=True, text=True).stdout.split()
leak = re.compile(r"discord(?:app)?\.com/api/webhooks/\d+|mysql://[^:\s]+:(?!CHANGE_ME@)[^@\s]+@|sv_licenseKey\s+\"?(?!CHANGE_ME)[A-Za-z0-9]{10,}")
for f in tracked:
    if f == "tests/check_cfg.py":  # contient les motifs eux-mêmes
        continue
    p = ROOT / f
    if p.suffix in (".png", ".jpg", ".ttf", ".woff2") or not p.is_file():
        continue
    try:
        for n, line in enumerate(p.read_text(encoding="utf-8").splitlines(), 1):
            if leak.search(line):
                errors.append(f"{f}:{n} secret probable commité")
    except UnicodeDecodeError:
        pass

# 4. V12.36 · ACE exigées par Qbox pour le service admin : qbx_core/server/functions.lua (IsOptin, ToggleOptin) fait
#    IsPlayerAceAllowed(src, 'admin') et la commande /optin (ox_lib, restricted = 'group.admin') exige command.optin.
#    Résolution comme FXServer : objet le plus précis d'abord (command.optin puis command), puis les parents du principal
#    (add_principal enfant parent). Vérifié pour admin et au-dessus ; mod et helper ne doivent PAS l'avoir (moindre privilège).
QBX_ACES = {"admin": "qbx_core IsOptin / ToggleOptin : IsPlayerAceAllowed(src, 'admin')",
            "command.optin": "commande /optin (ox_lib restricted = 'group.admin', couverte par « command allow »)"}
STAFF_WITH_ADMIN = ("group.admin", "group.superadmin", "group.god")
STAFF_WITHOUT_ADMIN = ("group.helper", "group.mod")
parents, aces = {}, {}
for path, n, line in lines:
    m = re.match(r"add_principal\s+(\S+)\s+(\S+)", line)
    if m:
        parents.setdefault(m.group(1), []).append(m.group(2))
        continue
    m = re.match(r"add_ace\s+(\S+)\s+(\S+)\s+(allow|deny)", line)
    if m:
        aces[(m.group(1), m.group(2))] = m.group(3)

def ace_result(principal, obj, seen=None):
    """allow / deny / None : l'ACE la plus précise du principal, sinon celle héritée de ses parents."""
    if seen is None:
        seen = set()
    if principal in seen:
        return None
    seen.add(principal)
    parts = obj.split(".")
    for i in range(len(parts), 0, -1):
        r = aces.get((principal, ".".join(parts[:i])))
        if r:
            return r
    for parent in parents.get(principal, []):
        r = ace_result(parent, obj, seen)
        if r:
            return r
    return None

for group in STAFF_WITH_ADMIN:
    for obj, why in QBX_ACES.items():
        if ace_result(group, obj) != "allow":
            errors.append(f"permissions.cfg : {group} n'a pas l'ACE « {obj} » ({why}) : /optin ne fera rien pour ce groupe")
for group in STAFF_WITHOUT_ADMIN:
    if ace_result(group, "admin") == "allow":
        errors.append(f"permissions.cfg : {group} a l'ACE « admin » (commandes Qbox /tp, /dv, /givemoney…) : réservée à admin et plus")

# 5. V12.36 · Les ACE Qbox vivent dans permissions.cfg : le serveur réel (VPS) doit le recevoir à chaque mise à jour,
#    et la commande « roadline » du VPS doit être poussée avant « roadline maj » (c'est elle qui installe le fichier).
warnings = []
_ovh = (ROOT / "scripts/windows/mettre-a-jour-ovh.ps1").read_text(encoding="utf-8")
_sh = (ROOT / "scripts/linux/roadline.sh").read_text(encoding="utf-8")
if "$_.Name -ne 'secrets.cfg'" not in _ovh or "'permissions.cfg'" in _ovh.split("Where-Object")[1].split("|")[0]:
    errors.append("mettre-a-jour-ovh.ps1 : permissions.cfg doit être envoyé au VPS (seul secrets.cfg reste exclu)")
if "/usr/local/bin/roadline" not in _ovh:
    errors.append("mettre-a-jour-ovh.ps1 : la commande roadline du VPS doit être mise à jour avant « roadline maj »")
if 'permissions.cfg) permissions_maj "$f"' not in _sh or "permissions_maj()" not in _sh:
    errors.append("roadline.sh : « roadline maj » doit installer permissions.cfg via permissions_maj (staff ajouté à la main conservé)")

for w in warnings:
    print("  Attention : " + w)
if errors:
    print("Config KO :")
    for e in errors:
        print("  - " + e)
    sys.exit(1)
print(f"Config OK ({len(ensures)} ressources, {len(tracked)} fichiers scannés, ACE Qbox vérifiées pour {len(STAFF_WITH_ADMIN)} groupes)")
