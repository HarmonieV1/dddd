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
