-- gs_world (client) : Cayo Perico. L'île du jeu (DLC) est activée seulement quand on s'en approche, puis désactivée :
-- pas de coût en ville, eau / minimap / chemins IA de Los Santos intacts. [API] natives GTA « heist island ».
local I = Config.Island
local loaded = false

local function setIsland(on)
    loaded = on
    SetIslandHopperEnabled('HeistIsland', on)
    SetToggleMinimapHeistIsland(on)
    SetAiGlobalPathNodesType(on and 1 or 0)
    LoadGlobalWaterFile(on and 1 or 0)
    SetDeepOceanScaler(on and 0.0 or 1.0)
    SetScenarioGroupEnabled('Heist_Island_Peds', on)
    SetAudioFlag('PlayerOnDLCHeist4Island', on)
    SetAmbientZoneListStatePersistent('AZL_DLC_Hei4_Island_Zones', on, on)
    SetAmbientZoneListStatePersistent('AZL_DLC_Hei4_Island_Disabled_Zones', not on, not on)
end

CreateThread(function()
    while true do
        local near = #(GetEntityCoords(cache.ped) - I.center) < I.loadRadius
        if near ~= loaded then setIsland(near) end
        Wait(near and 2000 or 3000)
    end
end)

-- Vols réguliers LS ↔ île
AddEventHandler('gs_world:client:fly', function(side)
    local f = I.flight
    local alert = lib.alertDialog({ header = f[side].label, content = ('Billet : %d $ (banque). On y va ?'):format(f.price), centered = true, cancel = true })
    if alert ~= 'confirm' then return end
    DoScreenFadeOut(600)
    while not IsScreenFadedOut() do Wait(0) end
    local ok, msg = lib.callback.await('gs_world:fly', false, side)
    if ok then
        -- laisser l'île se charger (ou se décharger) avant de rendre l'image
        local t = GetGameTimer() + 4000
        while GetGameTimer() < t do Wait(100) end
    end
    DoScreenFadeIn(800)
    if msg then lib.notify({ description = msg, type = ok and 'success' or 'error' }) end
end)

CreateThread(function()
    for side, s in pairs(I.flight) do
        if type(s) == 'table' then
            exports.gs_markers:Add('gs_world:fly:' .. side, { coords = s.counter, style = 'entry', label = s.label,
                event = 'gs_world:client:fly', args = { side }, prompt = s.label, distance = 20.0 })
        end
    end
    local b = AddBlipForCoord(I.flight.mainland.counter.x, I.flight.mainland.counter.y, I.flight.mainland.counter.z)
    SetBlipSprite(b, 307) SetBlipColour(b, 5) SetBlipScale(b, 0.7) SetBlipAsShortRange(b, true)
    BeginTextCommandSetBlipName('STRING') AddTextComponentSubstringPlayerName('Vols pour Cayo Perico') EndTextCommandSetBlipName(b)
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    if loaded then setIsland(false) end
    exports.gs_markers:RemovePrefix('gs_world:')
end)
