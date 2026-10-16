# Patch note — session du 16/10/2026 (V12.63, depuis le matin)

> Seulement ce qui a été fait pendant cette session (du correctif des Lives jusqu'à la journée North Yankton et au site).
> Ce qui précède (nuit du 15 au 16/10 : appli staff externe, outils OVH, mur des légendes, trêves, figure du coin, diaporama du
> site…) est dans `docs/PATCH_SESSION_15-10.md`. Version prête à coller sur Discord : `docs/PATCH_NOTE_V12.63_DISCORD.txt`.
> Installation : METTRE-A-JOUR → DIAGNOSTIC-MODS (O) → VIDER-CACHE-FIVEM → METTRE-A-JOUR-OVH.
> Rien n'a encore été vu en jeu : fiche de backtest, section **4j**.

## 1. Pour les joueurs
| Nouveauté | Comment ça marche |
|---|---|
| **Journée North Yankton** | Un jour sur deux, le vol régulier de l'aéroport (LSIA) part pour la ville enneigée du prologue de GTA V au lieu de Cayo Perico. Le comptoir et le site indiquent le vol du jour ; retour quand tu veux au comptoir d'arrivée. |
| **Photomaton** (fête foraine) | À côté du guichet des jetons : une photo souvenir pour 3 jetons. Serrez-vous dans la cabine, chacun repart avec sa copie (à regarder ou accrocher au mur). |
| **Hommage peint** (gangs) | Avec une bombe de peinture, choisir « Un hommage » : « R.I.P. » et le nom d'un membre disparu, aux couleurs du gang. 24 h, ou pour toujours contre 1 000 $ de la caisse du gang. Un rival peut l'effacer (le gang est prévenu). |
| **Voisins vigilants** | `/voisins` dans ton quartier (hors gang) : prévenu des délits qui y sont signalés (sans position) ; plus vous êtes nombreux, plus le calme revient vite. |
| **Alcootest du shérif** | La nuit, quand aucun policier n'est en service, le shérif tient parfois un barrage sur les routes hors de la ville. Positif à partir de 2 verres : amende et points de permis. Fuir = refus d'obtempérer. |
| **Gestes selon l'objet** | Alt sur un lavabo (mains, visage), une douche, une fontaine (boire) ; dans la mer, E pour se rincer. Le sang et la saleté partent ; les secours peuvent nettoyer tes plaies. |
| **Poubelles** | Une seule option : la fouille animée (l'ouverture de l'inventaire de la benne a disparu). |
| **Courses sur mesure** | L'organisateur peut imposer un véhicule ; inscription à 15 m de lui ; sur la ligne, E relance le départ et X annule. |
| **Gangs** | Plus de gangs créés d'office (un gang naît d'un projet RP validé par le staff) ; territoires découpés en pâtés de maisons. |
| **Cyclone** | Vitesse maximale ramenée à 210 km/h. |
| **Coincé sous la carte** | Tu es ramené tout seul au dernier endroit sûr après 6 secondes. |
| **Site** | « ✈️ Vol du jour » dans « En ce moment en ville » (annonce dans le bandeau les jours North Yankton) ; journal « Nouveautés » mis à jour. |

## 2. Pour le staff
| Nouveauté | Où | Ce que ça change |
|---|---|---|
| **Lives : capture réparée** | F11 → Lives, appli → Lives | screenshot-basic patché pour les versions récentes de FiveM ; si la capture échoue, la raison s'affiche après 6 s au lieu d'une attente sans fin ; F8 `/livestest` teste la capture sur ton PC. |
| **Appli staff : rangs** | GERER-OVH → 20 → A | Code personnel avec rang (5 = fondateur : agit sur tout le monde ; sinon seulement sur les rangs inférieurs). Le mot de passe collectif reste au rang modérateur. Bannir = admin minimum. |
| **Carte des tickets** | appli → Carte | Anneau jaune sur l'auteur de chaque ticket ouvert. |
| **Coincé sous la carte** | F11 → Joueurs, F10, appli | Bouton « Coincé : ramener au dernier endroit sûr » (helper et plus), en plus du retour automatique. |
| **Destination du vol de l'île** | F11 → Monde et lieux | Alternance (un jour sur deux), Cayo ou North Yankton tous les jours ; les joueurs sur place sont rapatriés à l'aéroport ; soirée plage de Cayo seulement un jour Cayo. |
| **Courses : véhicule imposé** | F11 → Monde et lieux → Courses | Sur un brouillon ou une course existante. |
| **Forme des quartiers** | `/quartierforme <quartier> <angle> [taille] [allongement 0.4-2.5]` | Rectangles de pâtés de maisons. Créer un gang : F11 → Monde et lieux → Gangs. |
| **Journal staff** | F10 → Journal | Hommages peints, coincés ramenés, choix de destination du vol. |

## 3. Pour le fondateur (serveur, mods, docs)
| Quoi | Ce que ça change |
|---|---|
| **Démarrage plus rapide** | Plus de gel de ~11 s après chaque démarrage : les maps en conflit ne sont relancées que si leur ordre de démarrage n'est pas déjà le bon. |
| **DIAGNOSTIC-MODS** | **Même map en deux versions** (archive « _1 » retéléchargée) : la version _1 en pause, l'original déjà réglé reste ; section **textures / modèles ≥ 32 Mo** (IMPORTER-MODS allège déjà seul les .ytd > 48 Mo). |
| **Nouvelles maps du jour** | Shadow Complex revient (archive _1 ; la raison de son retrait — Plasmakart — n'existe plus) ; animalerie _1 = copie d'un pack déjà réglé → mise en pause par DIAGNOSTIC-MODS. |
| **Docs** | État des lieux avant l'ouverture (`docs/ETAT_DES_LIEUX_16-10.md`), propositions n° 167 à 196, guides, fiche de backtest (4j), documentation à jour. |

## 4. Encore à faire / à vérifier
- **Positions à caler en jeu** (F11 → Monde et lieux → Déplacer un point) : photomaton (gs_casino), comptoir du vol retour à North Yankton (gs_world).
- **À confirmer en jeu** : Lives (F11 et appli), animations des gestes « visage » et « boire », décor et neige de North Yankton, barrage du shérif, hommage peint.
- **Code cfx.re** du serveur (txAdmin → tableau de bord, ou liste FiveM en mode public : GERER-OVH → 7) pour le bouton « Rejoindre » du site.
- **Code personnel fondateur** pour l'appli : GERER-OVH → 20 → A, rang 5.
