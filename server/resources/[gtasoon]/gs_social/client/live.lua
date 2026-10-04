-- gs_social (client) · V10.1 « Direct Weazel » : l'hélicoptère de la chaîne suit le suspect au-dessus de la poursuite.
-- Hélicoptère et pilote LOCAUX (non réseau) : chaque joueur proche a le sien, aucun trafic, aucune entité côté serveur.
-- Disparaît à la fin du direct, si le suspect est trop loin ou au bout de la durée maximale.
local L = Config.Live
local heli, pilot = nil, nil
local token = 0

local function stop()
    token = token + 1
    if pilot and DoesEntityExist(pilot) then DeleteEntity(pilot) end
    if heli and DoesEntityExist(heli) then DeleteEntity(heli) end
    heli, pilot = nil, nil
end

local function targetPed(srv)
    local p = GetPlayerFromServerId(srv)
    if p == -1 then return nil end
    local ped = GetPlayerPed(p)
    return ped ~= 0 and DoesEntityExist(ped) and ped or nil
end

local function start(srv)
    stop()
    local my = token
    local ped = targetPed(srv)
    if not ped then return end
    local hHeli, hPilot = joaat(L.heli), joaat(L.pilot)
    lib.requestModel(hHeli) lib.requestModel(hPilot)
    if my ~= token then return end
    local c = GetEntityCoords(ped)
    heli = CreateVehicle(hHeli, c.x + 120.0, c.y + 120.0, c.z + L.altitude + 40.0, 0.0, false, false)
    pilot = CreatePedInsideVehicle(heli, 26, hPilot, -1, false, false)
    SetModelAsNoLongerNeeded(hHeli) SetModelAsNoLongerNeeded(hPilot)
    SetEntityInvincible(heli, true) SetEntityInvincible(pilot, true)
    SetVehicleEngineOn(heli, true, true, false) SetHeliBladesFullSpeed(heli)
    SetBlockingOfNonTemporaryEvents(pilot, true)
    TaskHeliChase(pilot, ped, 0.0, 0.0, L.altitude)
    local endAt = GetGameTimer() + (L.maxMinutes + 1) * 60000
    while my == token and heli and DoesEntityExist(heli) do
        Wait(2000)
        local t = targetPed(srv)
        if not t or GetGameTimer() > endAt or #(GetEntityCoords(t) - GetEntityCoords(heli)) > L.range * 2 then break end
        if t ~= ped then ped = t TaskHeliChase(pilot, ped, 0.0, 0.0, L.altitude) end
    end
    if my == token then stop() end
end

RegisterNetEvent('gs_social:client:live', function(srv)
    if not srv then return stop() end
    if heli and DoesEntityExist(heli) then return end
    CreateThread(function() start(srv) end)
end)

AddEventHandler('onResourceStop', function(res) if res == GetCurrentResourceName() then stop() end end)
