-- gs_onboarding (client) : règlement (obligatoire à la 1re connexion ou après une mise à jour, puis /regles),
-- accueil des nouveaux (GPS vers Max, le guide du « premier jour »).
-- On attend que le joueur soit vraiment en jeu (écran visible, aucune interface ouverte : choix du spawn, création
-- d'apparence…) pour ne pas superposer deux fenêtres.
local function waitInGame()
    local calm = 0
    while calm < 3 do
        if IsScreenFadedOut() or IsPauseMenuActive() or IsNuiFocused() or not LocalPlayer.state.isLoggedIn then calm = 0 else calm = calm + 1 end
        Wait(1000)
    end
end

local function showRules(mandatory)
    local answer = lib.alertDialog({
        header = 'Règlement de Roadtrip', content = Config.Rules, centered = true, size = 'lg',
        cancel = mandatory, labels = mandatory and { confirm = 'J\'accepte', cancel = 'Je refuse' } or { confirm = 'Fermer' },
    })
    if mandatory then lib.callback.await('gs_onboarding:accept', false, answer == 'confirm') end
end

local rulesPending = false

RegisterNetEvent('gs_onboarding:client:rules', function(mandatory)
    rulesPending = true
    waitInGame()
    showRules(mandatory == true)
    rulesPending = false
end)

RegisterCommand('regles', function() showRules(false) end, false)

RegisterNetEvent('gs_onboarding:client:welcome', function()
    waitInGame()
    while rulesPending do Wait(500) end
    local c = vec3(-536.9, -218.4, 37.65) -- Max « le Guide » (gs_quests, personnage guide)
    SetNewWaypoint(c.x, c.y)
    lib.notify({ title = 'Bienvenue à Los Santos !', description = 'Rejoins Max devant la mairie (GPS posé) pour ton premier jour. F2 : progression · F1 : téléphone · /regles : règlement.',
        type = 'inform', icon = 'hand', duration = 15000 })
end)
