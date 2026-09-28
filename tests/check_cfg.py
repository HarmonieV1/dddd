#!/usr/bin/env python3
"""Linter de config serveur : ordre des ensure, dépendances, ressources interdites, fuites de secrets."""
import pathlib, re, subprocess, sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
SERVER = ROOT / "server"
OURS = SERVER / "resources" / "[gtasoon]"
FORBIDDEN = {"qbx_management": "remplacé par gs_jobs", "qbx_weathersync": "remplacé par gs_weather",
             "Renewed-Weathersync": "remplacé par gs_weather", "qbx_hud": "remplacé par gs_hud", "npwd": "remplacé par gs_phone",
             "qb-weathersync": "remplacé par gs_weather", "vSync": "remplacé par gs_weather"}
SECRET_KEYS = re.compile(r"(licensekey|webhook|mysql_connection|apikey|password|token|secret)", re.I)
errors = []

def read_cfg(path, seen):
    """Lit un cfg et suit les `exec` (hors secrets.cfg, remplacé par son .example)."""
    lines = []
    for n, raw in enumerate(path.read_text(encoding="utf-8").splitlines(), 1):
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

if errors:
    print("Config KO :")
    for e in errors:
        print("  - " + e)
    sys.exit(1)
print(f"Config OK ({len(ensures)} ressources, {len(tracked)} fichiers scannés)")
