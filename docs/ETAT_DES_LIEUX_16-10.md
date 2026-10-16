# État des lieux avant l'ouverture (16/10/2026, V12.63)

> Établi à partir du code et des retours de backtest. Rien ici n'a été vérifié en jeu par la session de secours : la fiche de
> backtest (sections 4d à 4i, 5) reste la référence.

## 1. À confirmer en jeu (corrigé dans le code, jamais vu tourner)
| Quoi | Comment vérifier |
|---|---|
| Lives (F11 et appli) : screenshot-basic patché (rappel en https) | F8 `/livestest` chez toi puis chez le joueur regardé ; appli → Lives |
| Poubelles : l'option inventaire d'ox_inventory retirée par gs_vie | Alt sur une benne : une seule option, « Fouiller la poubelle » |
| Animations des gestes « visage » et « boire » (noms non vérifiés) | Alt sur un lavabo / une fontaine ; sans animation, le geste marche quand même |
| Idées du soir et retours du 16/10 (affiches, mur des légendes, trêve, figure du coin, avis vitrine, fausse alerte, courses, quartiers rectangulaires, rangs de l'appli) | Fiche de backtest, section 4i |
| Doublons de mods mis en pause (14) | Après METTRE-A-JOUR-OVH : console sans les lignes en double |

## 2. Risques connus
- **52 positions « à caler »** dans les configs (guichet des jetons, carré du cimetière, mur des légendes, tribunal, état civil,
  combats clandestins, assurance, Fleeca, location, quêtes…). Toutes déplaçables en jeu : F11 → Monde et lieux → Déplacer un point.
- ~~Serveur figé ~11 s une fois après chaque démarrage~~ **corrigé (soir du 16/10)** : les packs en conflit ne sont relancés que
  si leur ordre de démarrage n'est pas déjà le bon (console : « ordre de démarrage déjà bon, aucune relance »).
- **Textures trop lourdes** signalées par la console (48 Mo : police.ytd du pack LSPD, sultanrsv8.ytd ; 32 Mo : nombreuses livrées).
  IMPORTER-MODS allège déjà seul les .ytd de plus de 48 Mo (mods non protégés). DIAGNOSTIC-MODS liste maintenant tout ce qui
  dépasse 32 Mo ; les modèles (.yft) et les packs chiffrés ne se réduisent pas sans risque : à remplacer si l'un ne s'affiche pas.
- **Shadow Complex** : l'archive `patoche_shadow_complex_pack_1` réimportée le remet en service (l'ancien nom reste retiré, la raison
  du retrait — Plasmakart — n'existe plus). Animalerie `_1` : copie d'un pack déjà réglé → DIAGNOSTIC-MODS la met en pause.
- **Clients FiveM Canary** : version de test de FiveM, plus instable. Conseiller la version normale aux joueurs.
- **Test de charge jamais fait** (fiche section 5) : 10 joueurs ou plus, 45 min, `/perfserveur` et resmon.
- **Boutique désactivée** (`Config.Enabled = false`) tant que prix et conformité PLA ne sont pas validés.
- **Sauvegarde / restauration de la base** : à tester une fois de bout en bout avant l'ouverture.

## 3. Optimisations possibles (sans toucher à ce qui tourne)
1. ~~Démarrage : plus de gel de 11 s~~ fait (16/10 soir).
2. Textures > 32 Mo : repérées par DIAGNOSTIC-MODS (les .ytd > 48 Mo sont déjà allégés à l'import).
3. 81 boucles client « par image » : toutes sont conditionnelles (à proximité, pendant une action). À contrôler pendant le
   test de charge avec resmon (objectif : aucune ressource gs_ au-dessus de 0,5 ms en continu).
4. Téléchargement des joueurs : 103 mods démarrés ; retirer les voitures jamais utilisées allège la première connexion.
   À décider après une semaine de jeu (on saura lesquelles sont achetées / sorties) : rien n'est retiré sans ton accord.
5. Appli staff : la page se recompile avec le panneau F10 (Vite) ; rien à optimiser côté serveur (réponses immédiates).

## 4. Manques avant / juste après l'ouverture
- Bande-annonce YouTube officielle (le site lit déjà une vidéo YouTube dès qu'on lui donne l'identifiant).
- Code cfx.re du serveur (liste FiveM, compteur de joueurs sur le site, bouton « Rejoindre » direct).
- Code personnel fondateur pour l'appli staff (GERER-OVH → 20 → A, rang 5).
- Positions à caler (voir 2), guichet des jetons et cimetière en premier.
- Fusion des derniers changements dans `feature/phase1-bridge` (sur accord).

## 5. Cartes : ce qui est autorisé
- **Los Santos, Blaine County, Cayo Perico, North Yankton** : contenu de GTA V, aucun risque de licence. North Yankton occupe
  les mêmes coordonnées que Cayo Perico : on ne peut pas charger les deux en même temps (vols vers North Yankton reportés).
- **Maps achetées (Patoche, packs .fxap)** : licences Cfx liées au compte du serveur, autorisées.
- **Interdit** : contenu d'autres jeux (portages de Vice City, Liberty City, San Andreas), et de façon générale tout ce qui
  reprend la propriété d'un tiers (marques réelles, logos) : risque de fermeture du serveur par Cfx / Rockstar.
