-- gs_onboarding (client) : aide des touches (I ou /touches). Une seule liste, sans doublon : si tu changes une touche
-- par défaut quelque part, mets-la aussi à jour ici. Chaque joueur peut réassigner : Échap → Paramètres → Raccourcis → FiveM.
local KEYS = [[
| Touche | Action |
|---|---|
| **F1** | Téléphone (Carnet, Weazel, Commandes, Inconnu…) |
| **F2** | Inventaire · **TAB** barre rapide · **1 à 5** objets rapides · **double-clic ou Alt + clic** : utiliser |
| **K** | Inventaire proche (coffre, boîte à gants) |
| **F3** | Progression, quêtes, niveau |
| **F4** | Intervention (police / EMS en service) |
| **F5** | Emotes · **X** annuler · **J** pointer · **G** effets · **Pavé num. 1 à 5** emotes rapides (F5 → Raccourcis) |
| **M** | Tomber au sol (ragdoll) · rappuie pour te relever |
| **F6** | Métiers (service, tenue, facture, patron) · **/service** prise de service par téléphone (touche à choisir) |
| **F7** | Duo |
| **F9** | Gang |
| **W** | Menu radial (W sur clavier français, Z en QWERTY) : Moi (tenue en objet, chapeau, lunettes, masque…), Radio, Véhicule |
| **Alt gauche** (appui simple) | Viser / interagir : choisis à la souris, rappuie sur Alt pour fermer |
| **N** | Parler · **²** portée de la voix · **/son** si le jeu baisse quand on parle |
| **Verr. Maj** (maintenu) | Parler à la radio (fréquence réglée) |
| **H** | Mains en l'air · en voiture : démarrer sans clé |
| **L** | Verrouiller / déverrouiller son véhicule |
| **B** | Ceinture |
| **U** | Garde-robe : retirer / enfiler chaque vêtement (objets du sac) · **/tenue** plier sa tenue |
| **Ctrl gauche** | S'accroupir |
| **/vue** | Vue d'ensemble : caméra autour de ton perso (aussi W → Moi) |
| **I** | Cette aide |

**Téléphone (F1)** : **Weazel** le journal · **Carnet** carnets de route et road trip du mois · **Inconnu** le marché noir
**Commandes utiles** : **/report** appeler le staff · **/quartiers** l'ambiance des quartiers · **/me** **/do** actions RP
]]

local STAFF = [[

**Staff** : **F10** panel · **F11** menu rapide · en mode staff : **Ctrl+Y** TP au marqueur · **Ctrl+U** vol libre · **Ctrl+O** noms et ID
]]

RegisterCommand('touches', function()
    if IsNuiFocused() then return end -- V11.5 : pas pendant une saisie (I dans un message ouvrait l'aide)
    local staff = LocalPlayer.state.gsStaff == true
    lib.alertDialog({ header = 'Touches de RoadLine', content = KEYS .. (staff and STAFF or '') ..
        '\n*Réassigner : Échap → Paramètres → Raccourcis clavier → FiveM.*', centered = true, size = 'lg', labels = { confirm = 'Fermer' } })
end, false)
RegisterKeyMapping('touches', 'Aide : toutes les touches', 'keyboard', 'I')

-- V12.52 · /son : le son du jeu qui baisse quand quelqu'un parle vient de WINDOWS (atténuation « Communications » ou
-- « améliorations audio »), pas du serveur : aucun serveur FiveM ne peut changer ce réglage chez le joueur. On l'explique
-- en jeu (commande, guide « Que faire ? » → Aide, rappel aux 3 premières connexions, écran de chargement).
local SOUND_HELP = '**Le son du jeu baisse quand quelqu\'un parle ?** C\'est Windows : il baisse tout le reste dès qu\'il détecte une conversation. 30 secondes à régler, une seule fois :\n\n'
    .. '1. Touche **Windows**, tape **son**, ouvre **Paramètres de son** puis **Plus de paramètres de son**.\n'
    .. '2. Onglet **Communications** : coche **Ne rien faire**, puis **OK**.\n'
    .. '3. Si ça continue : onglet **Lecture**, ton casque, **Propriétés**, onglet **Améliorations** (ou **Avancé**) : décoche les améliorations audio.\n\n'
    .. '**On ne t\'entend pas, ou tu n\'entends personne ?** Échap, **Paramètres**, **Chat vocal** : activé, le bon micro et le bon casque, volumes au maximum.\n\n'
    .. '**Portées** (touche ²) : Chuchoter 2 m · Normal 6 m · Crier 14 m. **Radio** : maintiens Verr. Maj.'

RegisterCommand('son', function()
    if IsNuiFocused() then return end
    lib.alertDialog({ header = 'Son et micro', content = SOUND_HELP, centered = true, size = 'lg' })
end, false)

-- Rappel discret aux 3 premières connexions (compteur gardé sur le PC du joueur)
AddEventHandler('QBCore:Client:OnPlayerLoaded', function() -- [API] qbx_core
    local seen = GetResourceKvpInt('gs_son_tip')
    if seen >= 3 then return end
    SetResourceKvpInt('gs_son_tip', seen + 1)
    SetTimeout(45000, function()
        lib.notify({ title = 'Vocal', description = 'Le son du jeu baisse quand quelqu\'un parle, ou on ne t\'entend pas ? Tape /son (réglage Windows, 30 s).',
            type = 'inform', icon = 'volume-high', duration = 12000 })
    end)
end)
