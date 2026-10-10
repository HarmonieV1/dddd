#!/usr/bin/env python3
"""Garde-fou V11 : la traduction des objets (Set-FrenchLabels, outils-communs.ps1) ne doit JAMAIS casser items.lua / weapons.lua.
Reprend la vraie expression régulière du script PowerShell, l'applique 2 fois (comme 2 METTRE-A-JOUR de suite) sur un faux
fichier avec tous les objets traduits + des lignes déjà abîmées par l'ancienne version, puis vérifie la syntaxe Lua (luac)."""
import json, re, subprocess, sys, tempfile, os

ps = open('scripts/windows/outils-communs.ps1', encoding='utf-8-sig').read()
m = re.search(r"\$re = \[regex\]::new\('(.*?)' \+ \[regex\]::Escape\(\$p\.Name\) \+ '(.*?)'\)\r?\n", ps)
if not m:
    sys.exit("ERREUR : expression de Set-FrenchLabels introuvable dans outils-communs.ps1")
head, tail = (s.replace("''", "'") for s in m.groups())  # guillemets PowerShell '' → '

def patch(text, mapping):
    for name, value in mapping.items():
        mm = re.search(head + re.escape(name) + tail, text)
        if not mm:
            continue
        label = value.replace('\\', '').replace("'", "\\'")
        if mm.group(2) == "'" + label + "'" and mm.group(3).strip() == '':
            continue
        text = text[:mm.start()] + mm.group(1) + "'" + label + "'" + text[mm.end():]
    return text

errors = []
for lua, dic in (('items.lua', 'items.json'), ('weapons.lua', 'weapons.json')):
    mapping = json.load(open(os.path.join('server/locales-fr', dic), encoding='utf-8'))
    keys = list(mapping)
    lines = ['return {']
    for i, k in enumerate(keys):
        if i % 7 == 3 and "'" in mapping[k]:  # ligne déjà cassée par l'ancienne version (« d\'eau'eau' »)
            broken = mapping[k].replace("'", "\\'") + "'" + mapping[k].split("'")[-1] + "'"
            lines.append(f"\t['{k}'] = {{\n\t\tlabel = '{broken}',\n\t\tweight = 100,\n\t}},")
        else:
            lines.append(f"\t['{k}'] = {{\n\t\tlabel = 'Original {i}',\n\t\tweight = 100,\n\t}},")
    lines.append('}')
    text = '\n'.join(lines)
    once = patch(text, mapping)
    twice = patch(once, mapping)
    if once != twice:
        errors.append(f'{lua} : le 2e passage modifie encore le fichier')
    with tempfile.NamedTemporaryFile('w', suffix='.lua', delete=False, encoding='utf-8') as f:
        f.write(twice)
    r = subprocess.run(['luac5.4' if subprocess.run(['which', 'luac5.4'], capture_output=True).returncode == 0 else 'luac', '-p', f.name],
                       capture_output=True, text=True)
    os.unlink(f.name)
    if r.returncode != 0:
        errors.append(f'{lua} : Lua invalide après traduction : {r.stderr.strip()}')
    missing = [k for k in keys if ("'" + mapping[k].replace("'", "\\'") + "'") not in twice]
    if missing:
        errors.append(f'{lua} : {len(missing)} libellé(s) non appliqué(s) : {missing[:5]}')

if errors:
    print('Traductions KO :'); [print('  - ' + e) for e in errors]; sys.exit(1)
print('Traductions des objets OK (2 passages, réparation des anciennes coupures, syntaxe Lua)')
