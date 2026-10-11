#!/usr/bin/env python3
"""Crimes signalés à la police (gs_wanted) : aucun type inconnu, aucune alerte perdue en silence.

gs_wanted ignore SANS MESSAGE un type de crime qui n'est pas dans Config.Crimes (`if not crime then return nil`).
Une faute de frappe dans une ressource = un crime qui n'arrive jamais au central. Ce test vérifie que chaque type
utilisé existe : appels ReportCrime / Wanted.report écrits en dur, champs `crime = '…'` des configs, et listes
de types des ressources qui réagissent aux crimes (empreintes, vitres brisées, commerçants).
"""
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
RES = ROOT / 'server' / 'resources' / '[gtasoon]'
CFG = RES / 'gs_wanted' / 'shared' / 'config.lua'

# Listes de types de crimes dans d'autres ressources : { type = true, … }
CONSUMERS = [
    ('gs_evidence/shared/config.lua', r'Config\.PrintCrimes\s*=\s*\{(.*?)\}'),
    ('gs_scars/shared/config.lua', r'Config\.Glass\s*=\s*\{\s*crimes\s*=\s*\{(.*?)\}'),
    ('gs_economy/shared/config.lua', r'Config\.Regulars\s*=\s*\{.*?crimes\s*=\s*\{(.*?)\}'),
]


def known_crimes() -> set:
    text = CFG.read_text(encoding='utf-8')
    start = text.index('Config.Crimes = {')
    block = text[start:text.index('\n}', start)]
    return set(re.findall(r'^\s*([a-z_]+)\s*=\s*\{', block, re.M))


def main() -> int:
    known = known_crimes()
    problems, used = [], 0
    for f in RES.rglob('*.lua'):
        text = f.read_text(encoding='utf-8', errors='ignore')
        rel = f.relative_to(ROOT)
        for m in re.finditer(r"ReportCrime\([^,()]+,\s*['\"]([a-z_]+)['\"]", text):
            used += 1
            if m.group(1) not in known:
                problems.append(f"{rel}:{text[:m.start()].count(chr(10)) + 1} : ReportCrime('{m.group(1)}') inconnu")
        for m in re.finditer(r"Wanted\.report\([^,()]+,\s*['\"]([a-z_]+)['\"]", text):
            used += 1
            if m.group(1) not in known:
                problems.append(f"{rel}:{text[:m.start()].count(chr(10)) + 1} : Wanted.report('{m.group(1)}') inconnu")
        if '/shared/' in f.as_posix():
            for m in re.finditer(r"\bcrime\s*=\s*'([a-z_]+)'", text):
                used += 1
                if m.group(1) not in known:
                    problems.append(f"{rel}:{text[:m.start()].count(chr(10)) + 1} : crime = '{m.group(1)}' inconnu")
    for rel, rx in CONSUMERS:
        p = RES / rel
        if not p.exists():
            continue
        m = re.search(rx, p.read_text(encoding='utf-8'), re.S)
        if not m:
            problems.append(f'{rel} : liste de crimes introuvable (le test doit suivre la config)')
            continue
        for k in re.findall(r'([a-z_]+)\s*=\s*true', m.group(1)):
            used += 1
            if k not in known:
                problems.append(f"{rel} : type '{k}' inconnu de gs_wanted")
    if problems:
        print('Crimes INCONNUS de gs_wanted (ces alertes n\'arriveraient jamais à la police) :')
        for p in problems:
            print('  - ' + p)
        print(f'Types connus : {", ".join(sorted(known))}')
        return 1
    print(f'Crimes OK ({len(known)} types, {used} utilisations vérifiées)')
    return 0


if __name__ == '__main__':
    sys.exit(main())
