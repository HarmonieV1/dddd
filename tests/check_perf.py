#!/usr/bin/env python3
"""Budget de performance des ressources gs_* (vérification statique, avant les mesures en jeu avec resmon).
Règles :
 1. toute boucle `while true do` contient un Wait(...) (sinon le jeu gèle) ;
 2. une boucle `while true do` qui tourne à chaque image (Wait(0) sans autre attente plus longue) doit être justifiée
    par un commentaire « par frame » / « chaque frame » juste au-dessus (densité PNJ, dessin…) ;
 3. côté serveur, pas de boucle infinie plus rapide que 250 ms ;
 4. budget par ressource : threads client permanents et boucles par image plafonnés (voir BUDGET).
Affiche un tableau récapitulatif (ressources, threads, boucles par image) : à comparer avec `resmon` en jeu.
"""
import pathlib, re, sys

ROOT = pathlib.Path(__file__).resolve().parent.parent / "server" / "resources" / "[gtasoon]"
BUDGET = {"client_threads": 12, "frame_loops": 2}   # par ressource
errors, rows = [], []

def block_after(lines, i, span=150):
    """Texte de la boucle commençant ligne i (approximation : jusqu'au `end` de même indentation)."""
    indent = len(lines[i]) - len(lines[i].lstrip())
    out = []
    for j in range(i + 1, min(len(lines), i + span)):
        line = lines[j]
        if line.strip() == "end" and len(line) - len(line.lstrip()) == indent:
            break
        out.append(line)
    return "\n".join(out)

for res in sorted(p for p in ROOT.iterdir() if (p / "fxmanifest.lua").exists()):
    threads = frame = 0
    for f in sorted(res.rglob("*.lua")):
        if "node_modules" in f.parts:
            continue
        side = "client" if "client" in f.parts else "server" if "server" in f.parts else "shared"
        lines = f.read_text(encoding="utf-8").splitlines()
        rel = f.relative_to(ROOT)
        if side == "client":
            threads += sum(1 for l in lines if "CreateThread(" in l)
        for i, line in enumerate(lines):
            if not re.match(r"\s*while true do\s*(--.*)?$", line):
                continue
            body = block_after(lines, i)
            waits = re.findall(r"Wait\(([^)]*)\)", body)
            if not waits:
                errors.append(f"{rel}:{i + 1} boucle infinie sans Wait")
                continue
            only_frame = all(w.strip() == "0" for w in waits)
            if side == "client" and only_frame:
                frame += 1
                context = "\n".join(lines[max(0, i - 6):i]).lower()
                if "par frame" not in context and "chaque frame" not in context:
                    errors.append(f"{rel}:{i + 1} boucle à chaque image non justifiée (commentaire « par frame » attendu)")
            if side == "server":
                fast = [w.strip() for w in waits if w.strip().isdigit() and int(w.strip()) < 250]
                if fast and len(fast) == len(waits):
                    errors.append(f"{rel}:{i + 1} boucle serveur trop rapide (Wait({fast[0]}))")
    rows.append((res.name, threads, frame))
    if threads > BUDGET["client_threads"]:
        errors.append(f"{res.name} : {threads} threads client (budget {BUDGET['client_threads']})")
    if frame > BUDGET["frame_loops"]:
        errors.append(f"{res.name} : {frame} boucles permanentes par image (budget {BUDGET['frame_loops']})")

if "-v" in sys.argv:
    print(f"{'ressource':<16} threads  boucles/image")
    for name, t, fr in rows:
        print(f"{name:<16} {t:>7}  {fr:>13}")
if errors:
    print("Budget de performance KO :")
    for e in errors:
        print("  - " + e)
    sys.exit(1)
print(f"Performance OK ({len(rows)} ressources, {sum(r[1] for r in rows)} threads client, {sum(r[2] for r in rows)} boucles permanentes par image)")
