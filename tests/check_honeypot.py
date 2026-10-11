#!/usr/bin/env python3
"""Pots de miel (gs_security/server/honeypot.lua) : garantit le ZÉRO FAUX POSITIF.

Un nom de piège qui serait aussi utilisé par un vrai script bannirait des joueurs honnêtes. Ce test vérifie que
chaque nom d'event et de callback piégé n'apparaît nulle part ailleurs dans le dépôt (ressources, tests, outils).
À lancer par tests/run.sh. Sortie non nulle = un piège est dangereux, il faut le renommer ou le retirer.
"""
import re
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
TRAP = ROOT / 'server' / 'resources' / '[gtasoon]' / 'gs_security' / 'server' / 'honeypot.lua'


def names(block: str) -> list:
    """Noms entre apostrophes, hors commentaires (le français en contient : « qu'on n'utilise pas »)."""
    code = '\n'.join(line.split('--')[0] for line in block.splitlines())
    return re.findall(r"'([^']+)'", code)


def main() -> int:
    if not TRAP.exists():
        print(f'Pots de miel : {TRAP.relative_to(ROOT)} introuvable.')
        return 1
    src = TRAP.read_text(encoding='utf-8')

    traps = []
    for table in ('EVENTS', 'CALLBACKS'):
        m = re.search(r'local %s = \{(.*?)\n\}' % table, src, re.S)
        if not m:
            print(f'Pots de miel : table {table} introuvable dans honeypot.lua.')
            return 1
        traps += names(m.group(1))
    if not traps:
        print('Pots de miel : aucun piège déclaré.')
        return 1

    # Les fichiers de code du dépôt, sauf le piège lui-même, ses copies et ce test. On lit la liste de Git quand il
    # est là : les dossiers ignorés (livraison/, colis de synchronisation dézippés…) contiennent des COPIES de
    # honeypot.lua qui ne sont pas de vrais scripts et feraient échouer le contrôle à tort.
    candidates = []
    try:
        out = subprocess.run(['git', 'ls-files', '--cached', '--others', '--exclude-standard'],
                             cwd=ROOT, capture_output=True, text=True, check=True).stdout
        candidates = [ROOT / p for p in out.splitlines()]
    except (OSError, subprocess.CalledProcessError):
        for pattern in ('**/*.lua', '**/*.js', '**/*.html'):
            candidates += [f for f in ROOT.glob(pattern) if 'node_modules' not in f.parts and '.git' not in f.parts]
    files = []
    for f in candidates:
        if f.suffix not in ('.lua', '.js', '.html') or not f.is_file():
            continue
        if f.name == 'check_honeypot.py' or f.as_posix().endswith('gs_security/server/honeypot.lua'):
            continue
        files.append(f)

    bad = []
    for f in files:
        try:
            text = f.read_text(encoding='utf-8', errors='ignore')
        except OSError:
            continue
        for t in traps:
            if t in text:
                bad.append((t, f.relative_to(ROOT)))

    if bad:
        print('Pots de miel DANGEREUX (le nom est utilisé par un vrai script : des joueurs honnêtes seraient bannis) :')
        for t, f in bad:
            print(f'  - « {t} » apparaît dans {f}')
        return 1

    print(f'Pots de miel OK ({len(traps)} pièges, aucun nom utilisé ailleurs)')
    return 0


if __name__ == '__main__':
    sys.exit(main())
