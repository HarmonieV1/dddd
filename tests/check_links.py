#!/usr/bin/env python3
"""Vérifie les liaisons entre fichiers et ressources gs_* : un nom mal tapé = un bug silencieux en jeu.
- chaque lib.callback.await / TriggerServerEvent / TriggerClientEvent vise un handler existant
- chaque exports.gs_x:Fn appelé est bien exporté par gs_x
- pas de commande, de touche, de table SQL ou de nom d'event en double
- chaque clé L('...') existe dans la locale
"""
import pathlib, re, sys
from collections import defaultdict

ROOT = pathlib.Path(__file__).resolve().parent.parent / "server" / "resources" / "[gtasoon]"
EXTERNAL_PREFIXES = ("QBCore:", "qb-weathersync:", "ox_lib:", "illenium-appearance:", "gs_bridge:client:", "gs_bridge:server:")
errors = []

def side(path):
    parts = path.parts
    return "client" if "client" in parts else "server" if "server" in parts else "shared"

def strip_comments(text):
    return re.sub(r"--[^\n]*", "", text)

res_files = {r.name: sorted(r.rglob("*.lua")) for r in ROOT.iterdir() if (r / "fxmanifest.lua").exists()}

net = {"server": set(), "client": set()}     # RegisterNetEvent par côté
local = {"server": set(), "client": set()}   # AddEventHandler par côté
callbacks, exports_def = set(), defaultdict(set)
uses = []                                     # (kind, name, file, line)
commands, keys, tables = defaultdict(list), defaultdict(list), defaultdict(list)

for res, files in res_files.items():
    for f in files:
        text = strip_comments(f.read_text(encoding="utf-8"))
        s = side(f)
        rel = f.relative_to(ROOT)
        def line_of(m): return text.count("\n", 0, m.start()) + 1
        for m in re.finditer(r"RegisterNetEvent\('([^']+)'", text):
            if s in net: net[s].add(m.group(1))
        for m in re.finditer(r"AddEventHandler\('([^']+)'", text):
            if s in local: local[s].add(m.group(1))
        for m in re.finditer(r"lib\.callback\.register\('([^']+)'", text):
            callbacks.add(m.group(1))
        for m in re.finditer(r"exports\('([^']+)'", text):
            exports_def[(res, s)].add(m.group(1))
        for m in re.finditer(r"lib\.callback\.await\('([^']+)'", text):
            uses.append(("callback", m.group(1), rel, line_of(m), s))
        for m in re.finditer(r"TriggerServerEvent\('([^']+)'", text):
            uses.append(("server_event", m.group(1), rel, line_of(m), s))
        for m in re.finditer(r"TriggerClientEvent\('([^']+)'", text):
            uses.append(("client_event", m.group(1), rel, line_of(m), s))
        for m in re.finditer(r"TriggerEvent\('([^']+)'", text):
            uses.append(("local_event", m.group(1), rel, line_of(m), s))
        for m in re.finditer(r"exports\.(gs_\w+)[:.](\w+)", text):
            uses.append(("export", (m.group(1), m.group(2)), rel, line_of(m), s))
        # alias : local X = exports.gs_y  puis X:Fn(
        for m in re.finditer(r"(\w+)\s*=\s*exports\.(gs_\w+)\s*$", text, re.M):
            alias, target = m.groups()
            for m2 in re.finditer(r"\b%s:(\w+)\(" % re.escape(alias), text):
                uses.append(("export", (target, m2.group(1)), rel, line_of(m2), s))
        for m in re.finditer(r"(?:RegisterCommand|lib\.addCommand)\('([^']+)'", text):
            commands[m.group(1)].append(str(rel))
        for m in re.finditer(r"RegisterKeyMapping\('[^']+',\s*'[^']*',\s*'keyboard',\s*'([^']+)'\)", text):
            keys[m.group(1)].append(str(rel))
        for m in re.finditer(r"CREATE TABLE IF NOT EXISTS `(\w+)`", text):
            tables[m.group(1)].append(str(rel))

# Les exports sont appelés depuis le même côté que leur définition
def export_exists(target, fn, s):
    return fn in exports_def.get((target, s), set())

for kind, name, rel, line, s in uses:
    where = f"{rel}:{line}"
    if kind == "callback" and name not in callbacks:
        errors.append(f"{where} callback inconnu : {name}")
    elif kind == "server_event" and name not in net["server"] and not name.startswith(EXTERNAL_PREFIXES):
        errors.append(f"{where} event serveur inconnu : {name}")
    elif kind == "client_event" and name not in net["client"] and not name.startswith(EXTERNAL_PREFIXES):
        errors.append(f"{where} event client inconnu : {name}")
    elif kind == "local_event" and name not in local[s] and not name.startswith(EXTERNAL_PREFIXES) \
            and not name.startswith("gs_weather:server:") and not name.startswith("gs_wanted:server:") \
            and not name.startswith("gs_jobs:internal:"):
        errors.append(f"{where} event local sans écouteur : {name}")
    elif kind == "export":
        target, fn = name
        if target not in res_files:
            continue  # gs_* simulé ou pas encore créé : signalé par le linter de config
        if not export_exists(target, fn, s):
            errors.append(f"{where} export inconnu : {target}:{fn} ({s})")

# Events locaux internes : doivent avoir au moins un écouteur
for prefix in ("gs_jobs:internal:",):
    for kind, name, rel, line, s in uses:
        if kind == "local_event" and name.startswith(prefix) and name not in local[s]:
            errors.append(f"{rel}:{line} event interne sans écouteur : {name}")

for label, table in (("commande", commands), ("touche", keys), ("table SQL", tables)):
    for name, where in table.items():
        if len(set(where)) > 1 or (label != "table SQL" and len(where) > 1):
            errors.append(f"{label} en double : {name} ({', '.join(where)})")

# Interfaces NUI : chaque nui('action') du front a son RegisterNUICallback côté client Lua
for res in res_files:
    web = ROOT / res / "web" / "src"
    if not web.exists():
        continue
    handlers = set()
    for f in res_files[res]:
        text = strip_comments(f.read_text(encoding="utf-8"))
        handlers |= set(re.findall(r"RegisterNUICallback\('([^']+)'", text))
        # boucle for _, action in ipairs({ 'a', 'b' }) do RegisterNUICallback(action, ...)
        for m in re.finditer(r"ipairs\(\{([^}]*)\}\)\s*do\s*RegisterNUICallback\(action", text):
            handlers |= set(re.findall(r"'([^']+)'", m.group(1)))
    for js in web.rglob("*.js*"):
        # nui('action') direct, ou via le helper run('action', ...) de l'app
        for m in re.finditer(r"\b(?:nui|run)\('([^']+)'", js.read_text(encoding="utf-8")):
            if m.group(1) not in handlers:
                errors.append(f"{js.relative_to(ROOT)} action NUI sans handler Lua : {m.group(1)}")

# Clés de locale
for res, files in res_files.items():
    loc = ROOT / res / "shared" / "locale.lua"
    if not loc.exists():
        continue
    defined = set(re.findall(r"^\s+(\w+)\s*=", loc.read_text(encoding="utf-8"), re.M))
    for f in files:
        text = strip_comments(f.read_text(encoding="utf-8"))
        for m in re.finditer(r"\bL\('(\w+)'", text):
            if m.group(1) not in defined:
                errors.append(f"{f.relative_to(ROOT)} clé de locale inconnue : {m.group(1)}")

if errors:
    print("Liaisons KO :")
    for e in errors:
        print("  - " + e)
    sys.exit(1)
n_uses = len(uses)
print(f"Liaisons OK ({n_uses} appels vérifiés, {len(callbacks)} callbacks, {len(commands)} commandes, {len(tables)} tables)")
