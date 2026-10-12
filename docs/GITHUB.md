# GitHub : pousser et synchroniser entre les deux postes (V12.34)

Deux postes travaillent sur le même dépôt (`HarmonieV1/dddd`, branches `feature/phase1-bridge` et
`claude/gta-rp-architecture-stack-pbvdxz`, toujours identiques) : le **PC Windows** (clone local, pas d'identité GitHub
enregistrée au départ) et la **session distante** (clone avec accès GitHub). Trois outils, zéro commande à retenir.

## 1. `POUSSER-GITHUB.bat` (PC Windows, à la racine du clone)

Un clic. Dans l'ordre :
1. trouve Git (ou dit comment l'installer : `winget install --id Git.Git -e --source winget`) ;
2. lit GitHub et affiche : commits à envoyer d'ici, commits de l'autre session pas encore là ;
3. fichiers modifiés non enregistrés → propose de les mettre dans un commit (message demandé) ;
4. si l'autre session a avancé et pas toi → **récupère** (avance rapide, sans risque) et s'arrête ;
   si les deux côtés ont avancé → **s'arrête** : « demande la fusion à Claude ». Jamais de `--force` ;
5. lance `tests/run.sh` (si bash, lua5.4 et python sont installés sur ce PC ; sinon le dit et demande confirmation) ;
6. pousse sur les deux branches. **Première fois** : une fenêtre GitHub s'ouvre (Git Credential Manager, livré avec Git),
   tu t'identifies une fois, c'est mémorisé par Windows. Si ça échoue : `gh auth login --web` puis `gh auth setup-git`.

Il se lance depuis le **clone** (dossier qui contient `.git`), pas depuis le zip d'installation.

## 2. Paquet de commits pour la session distante (`ROADLINE-commits.bundle`)

Quand le PC ne peut pas pousser, Claude livre un **paquet git** (`livraison/ROADLINE-commits.bundle`) : les commits du PC
**avec leur historique**, pas une copie des fichiers. Plus de commit « Synchronisation » géant, plus de conflits de fins
de ligne, plus de doublons. À envoyer à la session distante avec cette consigne :

```bash
bash scripts/linux/recevoir-bundle.sh ROADLINE-commits.bundle
```

Le script vérifie le paquet, le fusionne (avance rapide si possible, vraie fusion sinon), relance les tests et pousse les
deux branches. Claude peut le faire lui-même là-bas : lui donner le fichier et la ligne ci-dessus.

## 3. Règles qui évitent les bugs de synchronisation

- **Avant de travailler** sur un poste : `POUSSER-GITHUB.bat` (ou `git fetch origin`) pour voir si l'autre a avancé.
- **Une version par livraison** : `gs_version` dans `server/server.cfg.example` et `VERSION` dans `tools/pdf.py`
  (les autres outils l'importent), une entrée en tête de l'historique de `docs/ETAT_PROJET.md`.
- Les **zips d'installation** servent au serveur (METTRE-A-JOUR, METTRE-A-JOUR-OVH), **pas** à synchroniser le code entre
  postes : pour ça, GitHub ou le paquet de commits. Un zip dézippé puis commité crée un commit géant sans historique et
  des conflits partout (c'est ce qui est arrivé le 11/10).
- Les deux branches doivent rester identiques : l'outil et le script poussent toujours les deux.
- Secrets (`cfg/secrets.cfg`, jetons, webhooks) : jamais dans le dépôt.
