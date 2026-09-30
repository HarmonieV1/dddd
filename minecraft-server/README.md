# Serveur Minecraft (2-3 joueurs) — Paper, dernière version

Serveur Java **Paper** (fork optimisé de Minecraft, compatible client vanilla), sans mod : base propre, rapide, whitelist activée.
Windows uniquement pour l'instant (scripts `.bat` + PowerShell).

## En local (gratuit)
0. **Version express : double-clic sur `JOUER.bat`** (fait tout ci-dessous, te demande juste ton pseudo, affiche l'adresse `localhost`).

1. Double-clic **`INSTALLER.bat`** : trouve la dernière version de Minecraft via l'API PaperMC, installe Java (Temurin via `winget`) si besoin, télécharge et vérifie le jar, accepte le CLUF (il te le demande).
2. Double-clic **`LANCER.bat`** : démarre le serveur (RAM auto : 4 Go max, jamais plus de la moitié du PC). Écris `stop` dans la fenêtre pour l'arrêter proprement.
3. Double-clic **`ADMIN.bat`** (serveur démarré) : menu numéroté — whitelist, op, kick/ban, sauvegarde du monde, message, jour/beau temps, gamemode, commande libre, arrêt, mise à jour (avec sauvegarde auto).
   → Commence par **4** (te donner op), puis **2** pour chaque pote.
4. Dans Minecraft (même version que le serveur, voir `server/version.txt`) : *Multijoueur → Ajouter un serveur → `localhost`*.

Une fois op, tu as aussi les commandes en jeu (`/gamemode`, `/tp`, `/time`, `/whitelist`, `/ban`…).

## Jouer avec les potes (sans payer)
- **playit.gg** (tunnel gratuit) : pas de redirection de port, tes potes se connectent à l'adresse fournie. Le plus simple.
- Ou redirection du port **25565 TCP** sur ta box vers ton PC (IP publique, pare-feu Windows à ouvrir).
- Le PC doit rester allumé pendant que les autres jouent.

## Hébergeur (2ᵉ temps)
| Option | Prix | À savoir |
|---|---|---|
| Oracle Cloud « Always Free » | 0 € | VM ARM costaudes, dispo. souvent limitée, carte bancaire demandée. Nécessite Linux (scripts à adapter). |
| Aternos | 0 € | File d'attente, s'éteint quand vide, versions/plugins parfois en retard. |
| Hébergeur payant (quelques €/mois, 4 Go) | ~3-6 € | Panel web, Paper en 1 clic, sauvegardes : le plus tranquille. |

Pour 2-3 joueurs, **4 Go de RAM** suffisent. La config (`server/server.properties`) est celle à reprendre chez l'hébergeur.

## Réglages
`server/server.properties` (créé à l'installation) : `max-players=5`, `view-distance=10`, `simulation-distance=8`, whitelist + `online-mode` activés, RCON activé (mot de passe aléatoire, sert uniquement au menu admin ; ne redirige **jamais** le port 25575).
Sauvegardes : dossier `backups/`. `server/` et `backups/` ne sont pas versionnés.

> Les scripts n'ont pas pu être exécutés dans l'environnement où ils ont été écrits (pas de Windows) : au premier lancement, signale-moi toute erreur affichée.
