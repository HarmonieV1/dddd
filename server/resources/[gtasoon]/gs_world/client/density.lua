-- gs_world (client) : densité PNJ / trafic appliquée à chaque frame (seule façon que GTA la respecte).
local D = Config.Density

CreateThread(function()
    while true do
        SetPedDensityMultiplierThisFrame(D.peds)
        SetScenarioPedDensityMultiplierThisFrame(D.scenarios, D.scenarios)
        SetVehicleDensityMultiplierThisFrame(D.vehicles)
        SetRandomVehicleDensityMultiplierThisFrame(D.vehicles)
        SetParkedVehicleDensityMultiplierThisFrame(D.parked)
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
