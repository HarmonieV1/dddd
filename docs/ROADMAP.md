# Roadmap · où on en est

*Mis à jour le 05/10/2026 · **V11** · bêta ouverte sur le VPS OVH (profil privé, 16 places).*

## Fait
- **Serveur** : Qbox/ox, 66 ressources RoadLine (`gs_*`), **21 signatures**. Tests automatiques au vert : 2 500+ contrôles Lua + 20 du bot.
- **VPS OVH** (Ubuntu 24.04) :
  - le serveur démarre tout seul ;
  - **veille** toutes les 2 min : alerte Discord et relance si le serveur tombe ;
  - **redémarrage quotidien** à 6 h, annoncé en jeu ;
  - sauvegardes de la base toutes les 6 h, copiées chaque jour sur le PC ;
  - pare-feu configuré, connexion par clé (aucun mot de passe).
- **Outils PC**, en un double-clic :
  - `PREPARER-OVH` : première mise en ligne ;
  - `METTRE-A-JOUR-OVH` : mise à jour, en vérifiant que la version du PC correspond à celle du zip ;
  - `GERER-OVH` : 19 options, dont état, diagnostic, erreurs, Discord, txAdmin, sauvegardes et redémarrage.
- **Modération** : panneau staff mobile (joueurs, tickets, annonce, txAdmin), bot Discord, menu F11, txAdmin en option.
- **Profil public** :
  - `sv_pureLevel 1`, déjà actif aussi en privé pour le backtest ;
  - `sv_authMinTrust` laissé désactivé : il obligerait à avoir Steam ;
  - `sv_forceIndirectListing` laissé désactivé : inutile sans proxy.
- **V11** : lieux de mémoire, ville en timelapse sur le site, site en « bêta ouverte » avec l'adresse de connexion.

## Priorités

| Priorité | Quoi | Statut |
|---|---|---|
| **P0 · cette semaine** | Backtest avec `ROADLINE_Backtest_complet.pdf` (77 tests, dont 24 bloquants). Chaque jour : `GERER-OVH` → 3 (erreurs), puis me remonter les captures avec le numéro du test | En cours |
| **P0** | Relier Discord sur le VPS : CONFIGURER-DISCORD, puis `GERER-OVH` → 12, puis 17 | À faire (5 min) |
| **P0** | Programmer la copie quotidienne des sauvegardes sur le PC : `GERER-OVH` → 18 | À faire (1 min) |
| **P1 · après le backtest** | Corriger les retours du backtest (tri : bloquant → gênant → confort) | À venir |
| **P2 · avant l'ouverture** | Nom de domaine (`connect play.roadline…`), code cfx.re (passage en public) pour la carte en direct du site, whitelist ou non | À décider |
| **P3 · lancement** | Ouverture publique (`GERER-OVH` → 7), boutique `gs_store` après validation PLA, communication, streamers | Plus tard |

> **Carte en direct du site** : le site est en https et ne peut pas lire une adresse « http://IP ». Il faut l'adresse https
> `…users.cfx.re` donnée par FiveM quand le serveur est public (à mettre dans `CONFIG.cityUrl`). D'ici là, le site montre un aperçu,
> timelapse compris.

## Idées de signatures (à valider)
**Déjà proposées :**
- **Les jurés de Los Santos** : citoyens tirés au sort, ils votent le verdict.
- **La Gazette du dimanche** : journal hebdomadaire généré tout seul.
- **Élections municipales** : le maire active de vrais leviers.
- **Héritage** : testament, tombe et épitaphe.

**Nouvelles :**
1. **« Précédemment à Los Santos »** : l'écran de chargement montre les 3 ou 4 faits marquants des dernières 24 h, comme le résumé d'une série. On reprend le fil dès la connexion.
2. **Les objets ont un passé** : comme le carnet des voitures, les bijoux, montres et armes gardent leur histoire (« volé 2 fois, revendu au marché noir »). Les receleurs paient moins cher un objet « trop connu », et la police s'en sert comme preuve.
3. **Fantômes de la route** : sur le road trip et les courses, la voiture fantôme du meilleur temps de la semaine roule à côté de toi, en transparence.
4. **La galerie Weazel** : les meilleures photos de presse, avec l'accord du photographe, sont publiées sur le site avec la légende et le nom du journaliste.
5. **Files d'attente vivantes** : quand un commerce marche bien (recette, standing), des PNJ font la queue devant. Quand il est délaissé, il est vide. Le succès se voit dans la rue.
6. **Appels d'offres de la mairie** : chaque semaine, un chantier public (réparer un quartier, sécuriser un événement, convoyer des fonds) est mis aux enchères. Les entreprises de joueurs se battent pour le décrocher.

## Rappels
- Jamais de vraie marque, ni de mot de passe dans les fichiers ou les messages.
- Avant chaque mise à jour du VPS : METTRE-A-JOUR sur le PC, test rapide, puis METTRE-A-JOUR-OVH (il vérifie la version tout seul).
