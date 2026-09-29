-- gs_onboarding (client) : règlement (obligatoire à la 1re connexion ou après une mise à jour, puis /regles),
-- accueil des nouveaux (GPS vers Max, le guide du « premier jour »).
local function showRules(mandatory)
    local answer = lib.alertDialog({
        header = 'Règlement de Roadtrip', content = Config.Rules, centered = true, size = 'lg',
        cancel = mandatory, labels = mandatory and { confirm = 'J\'accepte', cancel = 'Je refuse' } or { confirm = 'Fermer' },
    })
    if mandatory then lib.callback.await('gs_onboarding:accept', false, answer == 'confirm') end
end

RegisterNetEvent('gs_onboarding:client:rules', function(mandatory)
    Wait(1500) -- laisser l'écran de chargement se fermer
    showRules(mandatory == true)
end)

RegisterCommand('regles', function() showRules(false) end, false)

RegisterNetEvent('gs_onboarding:client:welcome', function()
    Wait(8000)
    local c = vec3(-536.9, -218.4, 37.65) -- Max « le Guide » (gs_quests, personnage guide)
    SetNewWaypoint(c.x, c.y)
    lib.notify({ title = 'Bienvenue à Los Santos !', description = 'Rejoins Max devant la mairie (GPS posé) pour ton premier jour. F2 : progression · F1 : téléphone · /regles : règlement.',
        type = 'inform', icon = 'hand', duration = 15000 })
end)
