# Patch note — 17/10/2026 (V12.65)

> Suite de la V12.64 (`docs/PATCH_NOTE_V12.64.md`). Version prête à coller sur Discord : `docs/PATCH_NOTE_V12.65_DISCORD.txt`.
> Installation : METTRE-A-JOUR → VIDER-CACHE-FIVEM → METTRE-A-JOUR-OVH. Rien n'a encore été vu en jeu : backtest, section **4r**.
> Propositions livrées (choix du fondateur) : 278, 280, 282, 290 (+ alcoolo), 292, 294, 295, 302, 303, 304, 305, 307, 317, 322.

## 1. Pour les joueurs
| Nouveauté | Comment ça marche |
|---|---|
| **Témoins au procès** | Un crime signalé laisse un témoignage (ce que les passants ont vu : tenue, véhicule, plaque partielle ; jamais le nom), gardé 14 jours. Au tribunal, le juge, l'avocat ou la police peut faire venir le témoin : un passant se présente à la barre, toute la salle lit son récit, qui devient une pièce du dossier. |
| **Tags qui vivent** | La pluie délave les tags de gang (ils pâlissent puis disparaissent) ; dans un quartier calme, la mairie finit par repeindre les vieux tags. Le gang est prévenu. Les hommages R.I.P. ne bougent pas. |

## 2. Pour le staff
| Nouveauté | Où | Ce que ça change |
|---|---|---|
| **Mises en scène d'ambiance** (sans sanction) | F11 → joueur → Mises en scène | **Hélico de la police** (30 s au-dessus, projecteur la nuit), **foule de curieux** (filment, commentent), **appel masqué** (son téléphone sonne, une voix dit ton texte), **chien errant**, **alcoolo collant** (il titube derrière lui et raconte sa vie). Tout le monde voit la scène ; tout est nettoyé à la fin. |
| **Relâché dans le désert** | Mises en scène | Version douce de l'enlèvement : même camionnette, jeté en plein désert en sous-vêtements, SANS son argent liquide, pas d'expulsion (motif au journal). Sa tenue revient à la reconnexion ou à la garde-robe. |
| **Interrogatoire** | Mises en scène → Arrestation PNJ (case à cocher) | Avant la cellule : salle d'interrogatoire de Mission Row, un inspecteur pose 3 questions, le joueur répond (ou se tait) ; ses réponses s'affichent chez toi et vont au journal. |
| **Transfert en fourgon attaquable** | Mises en scène | Fourgon de police de Mission Row vers Bolingbroke, détenu à l'arrière ; annonce Weazel au choix. Fourgon arrêté (moteur détruit, conducteur à terre, vérifié par le serveur) = **évadé** (staff prévenu) ; sinon isolement à l'arrivée. |
| **Favoris F11** | F11 → Gérer mes favoris | Jusqu'à 6 actions épinglées en haut du menu (⭐), gardées sur ton PC. |
| **Chat staff** | `/sc message` en jeu, appli → Tableau de bord | Le même fil en jeu et dans l'appli. |
| **Incidents de la soirée** | Appli → Carte (bouton « Incidents ») | Tickets, joueurs à terre, alertes anti-triche des 12 dernières heures, en losanges colorés. |
| **Événements programmés** | Appli → Tableau de bord | Un événement (rassemblement, concert, chasse au trésor…) à un lieu de la liste, ou une météo (neige, tempête…), à l'heure voulue (heure du serveur), même sans staff en jeu. |
| **Double validation des bans définitifs** | Bannir (F11, F10, appli, hors ligne) | Un ban définitif posé par un admin ou un super-admin = 24 h tout de suite ; il devient définitif quand un AUTRE admin le valide (F11 → Bans définitifs à valider, ou appli). Refusé ou jamais validé : il reste à 24 h. Le fondateur n'a pas besoin de validation. |

### Qui a droit à quoi (demande du fondateur)
| Rang | Mises en scène, événements et effets fun (F11) |
|---|---|
| Helper, modérateur | Rien de tout ça : outils de modération seulement (noms, vol libre, invisible, invincible, TP au marqueur). |
| Admin | Arrestation PNJ (+ interrogatoire), appel masqué, foule de curieux ; rassemblements, fait divers PNJ, rumeurs ; effets légers sur soi (vision de nuit / thermique, feux d'artifice, confettis). |
| Super-admin, fondateur | Tout : enlèvement, désert, transfert, hélico, chien errant, alcoolo ; chasse au trésor, bonus serveur (double XP), météo spéciale (neige, tempête, Halloween) ; tous les effets fun et transformations (peds, animaux). |
Vérifié côté serveur (même en contournant le menu) ; `/gsevent`, `/meteoevent` et `/halloween` passent au rang super-admin.

## 3. Pour le fondateur
- Nouveaux fichiers : `gs_admin/server/staffhub.lua`, `gs_admin/web/src/staff/Hub.jsx`, `gs_wanted/server/testimony.lua`.
- Réglages : `gs_admin` Config.Scenes (désert, interrogatoire, transfert, ambiance) et Config.StaffHub ; `gs_wanted` Config.Testimony ;
  `gs_justice` Config.Witness (place du témoin à caler) ; `gs_gangs` Config.TagLife.
- Points à caler en jeu : place du témoin au tribunal (Config.Witness.stand), départ du fourgon (Config.Scenes.transfer.from),
  lieux du désert (Config.Scenes.desert.drops).
- Tests : 46 contrôles en plus ; toute la suite est verte. Propositions D14 mises à jour.
- **Relecture avant livraison (corrigé)** :
  - un ban définitif ne peut pas être validé par la même personne passée par l'appli (pseudo comparé) ;
  - un joueur débanni entre-temps n'est pas rebanni à la validation ;
  - les bans définitifs posés depuis Discord passent aussi par la validation ;
  - un événement programmé raté de plus de 10 min (serveur éteint) n'est pas lancé en retard ;
  - le serveur n'accepte pour une scène que les PNJ et véhicules créés par le joueur concerné, jamais un autre joueur ;
  - le transfert n'est « évadé » que si le vrai fourgon a été vu et est arrêté ;
  - l'interrogatoire n'accepte qu'une seule série de réponses ;
  - le transfert est publié dans #sanctions ;
  - un joueur à terre ne compte qu'une fois par minute sur la carte des incidents.
