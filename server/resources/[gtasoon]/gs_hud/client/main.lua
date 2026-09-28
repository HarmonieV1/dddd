-- gs_hud (client). Lecture adaptative (500 ms à pied, 120 ms en véhicule) et envoi à la NUI
-- UNIQUEMENT des valeurs qui ont changé : l'interface ne se redessine presque jamais.
local Bridge = exports.gs_bridge
local state = {}
local visible = GetResourceKvpInt('gs_hud_hidden') ~= 1
local loaded = false

local WEATHER_LABELS = {
    EXTRASUNNY = 'Grand soleil', CLEAR = 'Dégagé', CLOUDS = 'Nuageux', OVERCAST = 'Couvert', RAIN = 'Pluie',
    THUNDER = 'Orage', CLEARING = 'Éclaircies', FOGGY = 'Brouillard', SMOG = 'Brume', SNOW = 'Neige', XMAS = 'Neige',
}

local function push(patch)
    local changed = {}
    local any = false
    for k, v in pairs(patch) do
        if state[k] ~= v then state[k] = v changed[k] = v any = true end
    end
    if any then SendNUIMessage({ action = 'update', data = changed }) end
end

local function setVisible(v)
    visible = v
    SendNUIMessage({ action = 'visible', visible = v and loaded })
end

RegisterCommand('hud', function()
    setVisible(not visible)
    SetResourceKvpInt('gs_hud_hidden', visible and 0 or 1)
    lib.notify({ description = visible and 'HUD affiché' or 'HUD masqué (mode cinéma)' })
end, false)

-- Événements (pas de sondage) ---------------------------------------------------------------------
AddEventHandler('gs_bridge:client:statusUpdated', function(s)
    push({ hunger = s.hunger, thirst = s.thirst, cash = s.cash, bank = s.bank })
end)

AddEventHandler('gs_bridge:client:jobUpdated', function(job)
    push({ job = job and job.label or 'Sans emploi', duty = job and job.onduty or false })
end)

AddEventHandler('gs_wanted:client:heatChanged', function(heat) push({ stars = math.ceil((heat or 0) / 20) }) end)

AddEventHandler('gs_bridge:client:playerLoaded', function()
    loaded = true
    setVisible(visible)
end)
AddEventHandler('gs_bridge:client:playerUnloaded', function()
    loaded = false
    setVisible(visible)
end)

-- Boucle adaptative ------------------------------------------------------------------------------------
CreateThread(function()
    loaded = Bridge:IsLoggedIn()
    local job = Bridge:GetJob()
    local s = Bridge:GetStatus()
    push({ job = job and job.label or 'Sans emploi', duty = job and job.onduty or false,
           hunger = s.hunger, thirst = s.thirst, cash = s.cash, bank = s.bank, stars = 0 })
    setVisible(visible)
    local speedFactor = Config.SpeedUnit == 'mph' and 2.236936 or 3.6

    while true do
        local ped = PlayerPedId()
        local veh = GetVehiclePedIsIn(ped, false)
        local inVeh = veh ~= 0
        if Config.RadarInVehicleOnly then DisplayRadar(inVeh and visible) end

        if loaded and visible then
            local c = GetEntityCoords(ped)
            local street = GetStreetNameFromHashKey(GetStreetNameAtCoord(c.x, c.y, c.z))
            local w = GlobalState.gsWeather
            local proximity = LocalPlayer.state.proximity -- [API] pma-voice
            push({
                health = math.max(0, GetEntityHealth(ped) - 100),
                armor = GetPedArmour(ped),
                talking = NetworkIsPlayerTalking(PlayerId()),
                voice = proximity and proximity.mode or nil,
                time = ('%02d:%02d'):format(GetClockHours(), GetClockMinutes()),
                weather = w and (WEATHER_LABELS[w.type] or w.type) or nil,
                street = street,
                zone = GetLabelText(GetNameOfZone(c.x, c.y, c.z)),
                inVehicle = inVeh,
            })
            if inVeh then
                local fuel = Entity(veh).state.fuel or GetVehicleFuelLevel(veh) -- ox_fuel : state bag
                push({
                    speed = math.floor(GetEntitySpeed(veh) * speedFactor),
                    fuel = math.floor(fuel),
                    engine = math.floor(GetVehicleEngineHealth(veh) / 10),
                    gear = GetVehicleCurrentGear(veh),
                })
            end
        end
        Wait(inVeh and Config.TickInVehicle or Config.TickOnFoot)
    end
end)
