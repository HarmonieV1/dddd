# Alertes et notifications — qui est prévenu de quoi

Référence vérifiée le 11/10/2026 (V12.7). Sert au staff pour comprendre ce que voit un policier ou un EMS, et à
vérifier la cohérence RP. Garde-fou automatique : `tests/check_crimes.py` (aucun type de crime inconnu, donc aucune
alerte perdue sans message).

## 1. Le central police (`gs_wanted`) — le seul canal pour les crimes

Tout crime passe par `exports.gs_wanted:ReportCrime(src, type, coords, opts)`. Le central décide :

- **Signalé ou pas** : base du crime + témoins (PNJ et joueurs à 40 m), × heure, × météo, × black-out, × arme
  silencieuse, × notoriété, × tension du quartier (`gs_city`). Un policier en service à portée = signalement certain.
- **Avec quelle précision** : zone floutée (20 à 250 m), délai (5 à 40 s), plaque partiellement lisible, description
  brute (jamais le nom, sauf visage connu non masqué).
- **Caméras** de surveillance proches : quasi certain, zone précise, plaque lisible, preuve vidéo gardée.
- **Alarme silencieuse** (braquages) : certain et précis.
- **Destinataires** : policiers en service (**LSPD et shérif**, via `countsAs = 'police'`), et les membres d'un gang
  qui a piraté le scanner. Moins de 1 policier joueur en service → **police IA** (étoiles du jeu, patrouilles).

### Alertes systématiques (même sans témoin)

| Événement | Alerte | Exceptions |
|---|---|---|
| Coups de feu | « Coups de feu détectés », rue + GPS, sans description | policier / shérif en service ; stands de tir Ammu-Nation ; **chasseur avec permis dans la zone de chasse** ; arme silencieuse (pas d'alerte automatique, seulement les témoins) ; 1 alerte / 10 s / joueur, 1 / 20 s / zone |
| Arme blanche (couteau, batte…) | « Agression à l'arme blanche signalée » | policier / shérif en service ; 1 / 15 s |

### Tous les types de crimes (25)

| Type | Intitulé reçu par le policier | Déclenché par |
|---|---|---|
| `gunshot` | Coups de feu | tir (gs_evidence → gs_wanted) |
| `stabbing` | Agression à l'arme blanche | coup d'arme blanche (serveur) |
| `explosion` | Explosion | explosion causée par un joueur (serveur) |
| `carjack` | Vol de véhicule avec violence | sortir un conducteur de sa voiture |
| `vehicle_theft` | Vol de véhicule (serrure forcée / fils) | `qbx_vehiclekeys` (branché sur le central en V12.7) |
| `store_robbery` | Braquage de supérette | supérettes 24/7 (`gs_heists`) |
| `shop_robbery` | Braquage de commerce | caisse d'un commerce au pistolet (`gs_stickup`), caisse d'une doublure (`gs_business`) |
| `teller_robbery` | Braquage de guichet | guichet de banque (`gs_stickup`) |
| `jewelry` | Braquage de bijouterie | Vangelico (`gs_heists`) |
| `bank` | Braquage de banque | Fleeca, gros coup en duo (`gs_heists`) |
| `mugging` | Racket à main armée | racket d'un passant (`gs_stickup`) |
| `racket` | Racket et dégradation de commerce | racket d'un commerce par un gang (`gs_gangs`) |
| `vandalism` | Dégradation d'une caméra de surveillance | caméra peinte (`gs_cctv`) |
| `sabotage` | Sabotage du réseau électrique | transformateur (black-out, `gs_city`) |
| `drug_sale` | Vente de stupéfiants | ventes, plantations (`gs_drugs`, `gs_gangs`) |
| `black_market` | Trafic d'armes | marché noir |
| `contract` | Contrat criminel | contrats du marché noir |
| `duo_contract` | Vol de marchandise | contrat en duo (`gs_duo`) |
| `smuggling` | Transport de marchandise illégale | `gs_smuggling`, `gs_gigs` |
| `street_race` | Course de rue illégale | `gs_races` |
| `poaching` | Braconnage | dépecer sans permis de chasse (`gs_harvest`) |
| `refusal` | Refus d'obtempérer | contrôle routier (`gs_roadside`) |
| `money_laundering` | Blanchiment d'argent | contrôle fiscal (`gs_jobs`) |
| `assault`, `robbery` | Agression, Braquage | génériques (réservés) |

Volontairement **sans alerte** : combats clandestins (le ring se trouve par les rumeurs), labos et plantations tant
qu'on n'y vend pas, faux papiers (démasqués au contrôle au commissariat).

### Ce que le crime déclenche ensuite (même s'il n'est pas signalé)

Traces pour l'enquête (`gs_evidence` : douilles, empreintes, sang), mémoire de la ville (tenue, véhicule), tension du
quartier (`gs_city`), rumeurs (`gs_rumors`), direct Weazel possible (`gs_social`), résumé du soir sur Discord,
vitres brisées et cicatrices (`gs_scars`), commerçants qui refusent un braqueur reconnu (`gs_economy`).

## 2. Secours (EMS)

| Situation | Ce qui se passe |
|---|---|
| À terre, **EMS joueur en service** | « [G] Demander de l'aide » (`qbx_ambulancejob`) → alerte + GPS aux EMS en service |
| À terre, **aucun EMS** | « [G] Appeler les secours » (`gs_services`) → secouriste IA payant, réanimation |
| Témoin d'un accident | appli **Urgences** du téléphone → EMS en service, avec position |

## 3. Appels des citoyens

L'appli **Urgences** du téléphone (`gs_phone`) : police, EMS, dépanneuse, avec position. Impossible menotté ou à
terre (le téléphone est bloqué), c'est voulu. `/911p` (Qbox) est réservé au staff depuis la V12.7 : il permettait
d'appeler sans téléphone, même menotté.

## 4. Annonces générales (toute la ville)

Flash Weazel et réseau social (`gs_social`), Radio Los Santos (`gs_lsradio`), météo et événements (`gs_weather`),
avis de recherche des fugitifs (`gs_wanted`), annonces staff (`gs_admin`, aussi depuis Discord : `/annonce en_jeu`),
redémarrages (txAdmin + Discord).

## 5. Ce qui n'est PAS dans le dépôt et dépend de l'installation

Les retouches de `qbx_vehiclekeys` (vols → central) et de `qbx_police` (`/911p` staff) sont appliquées par
`METTRE-A-JOUR.bat` (`outils-communs.ps1`, liste `$QboxPatches`). Vérifie dans sa fenêtre :
« qbx_vehiclekeys : vols de véhicule : alerte par le central RoadLine » et « qbx_police : /911p réservé au staff »
en vert. En jaune = la version de Qbox a changé, me le signaler. Puis `METTRE-A-JOUR-OVH.bat` pour le VPS.
