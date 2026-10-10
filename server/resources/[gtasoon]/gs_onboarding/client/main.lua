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
        header = 'Règlement de RoadLine', content = Config.Rules, centered = true, size = 'lg',
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

RegisterNetEvent('gs_onboarding:client:welcome', function(arrival)
    waitInGame()
    while rulesPending do Wait(500) end
    local function welcome()
        local c = vec3(-536.9, -218.4, 37.65) -- Max « le Guide » (gs_quests, personnage guide)
        SetNewWaypoint(c.x, c.y)
        lib.notify({ title = 'Bienvenue à Los Santos !', description = 'Rejoins Max devant la mairie (GPS posé) pour ton premier jour. F3 : progression · F1 : téléphone · I : toutes les touches · /regles : règlement.',
            type = 'inform', icon = 'hand', duration = 15000 })
    end
    -- V11.5 : la première fois seulement, on arrive en bus (le serveur note que c'est fait)
    if arrival == true and not cache.vehicle then
        TriggerServerEvent('gs_onboarding:server:arrived')
        return GSArrival(welcome)
    end
    welcome()
end)

-- /retoucheperso : rouvre le créateur complet (visage, cheveux, maquillage, vêtements) une seule fois par personnage.
RegisterCommand('retoucheperso', function()
    local ok, msg = lib.callback.await('gs_onboarding:retouche:check', false)
    if not ok then return lib.notify({ description = msg, type = 'error' }) end
    if lib.alertDialog({ header = 'Retoucher mon personnage', centered = true, cancel = true,
        content = 'Tu peux refaire ton personnage **une seule fois** : visage, cheveux, sourcils, maquillage, vêtements.\n\n'
            .. 'Ta retouche n\'est utilisée qu\'en **enregistrant** : si tu quittes sans enregistrer, tu la gardes.' }) ~= 'confirm' then return end
    if GetResourceState('illenium-appearance') ~= 'started' then return lib.notify({ description = 'Créateur indisponible.', type = 'error' }) end
    local all = { masks = true, upperBody = true, lowerBody = true, bags = true, shoes = true, scarfAndChains = true, bodyArmor = true,
        shirts = true, decals = true, jackets = true }
    exports['illenium-appearance']:startPlayerCustomization(function(appearance)
        if not appearance then return lib.notify({ description = 'Retouche annulée : tu la gardes pour plus tard.', type = 'inform' }) end
        TriggerServerEvent('illenium-appearance:server:saveAppearance', appearance)
        lib.callback.await('gs_onboarding:retouche:done', false)
        lib.notify({ description = 'Personnage enregistré. Belle nouvelle tête !', type = 'success' })
    end, { ped = false, headBlend = true, faceFeatures = true, headOverlays = true, components = true, componentConfig = all,
        props = true, propConfig = { hats = true, glasses = true, ear = true, watches = true, bracelets = true },
        tattoos = false, enableExit = true, hasTracker = false, automaticFade = false })
end, false)

