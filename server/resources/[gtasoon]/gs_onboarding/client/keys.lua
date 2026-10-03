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
| **F5** | Emotes · **X** annuler · **J** pointer · **G** effets |
| **F6** | Métiers (service, tenue, facture, patron) |
| **F7** | Duo |
| **F9** | Gang |
| **Z** | Menu radial : Moi (tenue en objet, chapeau, lunettes, masque…), Radio, Véhicule |
| **Alt gauche** (maintenu) | Viser / interagir (ox_target) |
| **N** | Parler · **²** portée de la voix |
| **Verr. Maj** (maintenu) | Parler à la radio (fréquence réglée) |
| **H** | Mains en l'air · en voiture : démarrer sans clé |
| **L** | Verrouiller / déverrouiller son véhicule |
| **B** | Ceinture |
| **Ctrl gauche** | S'accroupir |
| **I** | Cette aide |

**Téléphone (F1)** : **Weazel** le journal · **Carnet** carnets de route et road trip du mois · **Inconnu** le marché noir
**Commandes utiles** : **/report** appeler le staff · **/quartiers** l'ambiance des quartiers · **/me** **/do** actions RP
]]

local STAFF = [[

**Staff** : **F10** panel · **F11** menu rapide · en mode staff : **Ctrl+Y** TP au marqueur · **Ctrl+U** vol libre · **Ctrl+O** noms et ID
]]

RegisterCommand('touches', function()
    local staff = LocalPlayer.state.gsStaff == true
    lib.alertDialog({ header = 'Touches de Roadtrip', content = KEYS .. (staff and STAFF or '') ..
        '\n*Réassigner : Échap → Paramètres → Raccourcis clavier → FiveM.*', centered = true, size = 'lg', labels = { confirm = 'Fermer' } })
end, false)
RegisterKeyMapping('touches', 'Aide : toutes les touches', 'keyboard', 'I')
