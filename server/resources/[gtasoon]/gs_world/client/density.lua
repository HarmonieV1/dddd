-- gs_world (client) : densité PNJ / trafic appliquée à chaque frame (seule façon que GTA la respecte).
local D = Config.Density

-- Facteur selon le nombre de joueurs connectés (GlobalState.gsPlayers, tenu à jour par le serveur).
local function crowdFactor()
    local c, n = D.crowd, GlobalState.gsPlayers or 0
    if not c or n <= c.from then return 1.0 end
    if n >= c.to then return c.min end
    return 1.0 - (1.0 - c.min) * (n - c.from) / (c.to - c.from)
end

CreateThread(function() -- par frame : GTA oublie la densité à chaque image
    local k, nextCheck = 1.0, 0
    while true do
        if GetGameTimer() > nextCheck then k = crowdFactor(); nextCheck = GetGameTimer() + 10000 end
        SetPedDensityMultiplierThisFrame(D.peds * k)
        SetScenarioPedDensityMultiplierThisFrame(D.scenarios * k, D.scenarios * k)
        SetVehicleDensityMultiplierThisFrame(D.vehicles * k)
        SetRandomVehicleDensityMultiplierThisFrame(D.vehicles * k)
        SetParkedVehicleDensityMultiplierThisFrame(D.parked * k)
        Wait(0)
    end
end)

-- Filtre « Vice » (réglage du téléphone, mémorisé par joueur) : couleurs saturées + léger vignettage, ambiance sunset / néons.
local function applyFilter(on)
    if on then
        SetTimecycleModifier('rply_saturation') SetTimecycleModifierStrength(0.35) -- [API] filtres de l'éditeur Rockstar
        SetExtraTimecycleModifier('rply_vignette') SetExtraTimecycleModifierStrength(0.25)
    else
        ClearTimecycleModifier() ClearExtraTimecycleModifier()
    end
end
exports('SetViceFilter', function(on)
    SetResourceKvpInt('gs_world_vice', on and 1 or 0)
    applyFilter(on)
end)
exports('GetViceFilter', function() return GetResourceKvpInt('gs_world_vice') == 1 end)
CreateThread(function() if GetResourceKvpInt('gs_world_vice') == 1 then applyFilter(true) end end)
