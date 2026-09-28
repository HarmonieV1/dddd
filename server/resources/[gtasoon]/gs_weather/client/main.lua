-- gs_weather (client) : applique l'état publié par le serveur. Coût : 1 appel natif / seconde.
local offset          -- heure serveur - horloge locale (secondes)
local paused = false  -- écran de sélection de perso, cinématiques...
local current

local SNOW = { XMAS = true, SNOW = true, SNOWLIGHT = true, BLIZZARD = true }

local function serverNow()
    return offset + GetGameTimer() / 1000
end

local function syncOffset()
    local t = lib.callback.await('gs_weather:now', false)
    if t then offset = t - GetGameTimer() / 1000 end
end

local function applyWeather(w, instant)
    if paused or not w then return end
    if w.type ~= current then
        ClearOverrideWeather()
        ClearWeatherTypePersist()
        if instant or not current then
            SetWeatherTypeNowPersist(w.type)
        else
            SetWeatherTypeOvertimePersist(w.type, w.transition or 45.0)
        end
        current = w.type
    end
    local snow = SNOW[w.type] == true
    SetForceVehicleTrails(snow)
    SetForcePedFootstepsTracks(snow)
    SetWindSpeed(w.wind or 0.0)
    SetArtificialLightsState(w.blackout == true)
    SetArtificialLightsStateAffectsVehicles(false) -- les phares restent allumés pendant un blackout
end

AddStateBagChangeHandler('gsWeather', 'global', function(_, _, value)
    applyWeather(value, false)
end)

-- Horloge : recalculée localement à partir de l'ancrage, aucun trafic réseau.
CreateThread(function()
    syncOffset()
    applyWeather(GlobalState.gsWeather, true)
    local resyncAt = GetGameTimer() + 900000
    while true do
        local anchor = GlobalState.gsClock
        if not paused and anchor and offset then
            NetworkOverrideClockTime(Clock.split(Clock.now(anchor, serverNow())))
        end
        if GetGameTimer() > resyncAt then
            syncOffset()
            resyncAt = GetGameTimer() + 900000
        end
        Wait(1000)
    end
end)

-- Pause / reprise (sélection de personnage, etc.). Compatible avec les appels qb-weathersync.
local function pause()
    paused = true
    ClearOverrideWeather()
    ClearWeatherTypePersist()
    SetWeatherTypeNowPersist('EXTRASUNNY')
    SetArtificialLightsState(false)
    NetworkOverrideClockTime(18, 30, 0)
end

local function resume()
    paused, current = false, nil
    applyWeather(GlobalState.gsWeather, true)
end

AddEventHandler('gs_weather:client:pause', pause)
AddEventHandler('gs_weather:client:resume', resume)
RegisterNetEvent('qb-weathersync:client:DisableSync', pause)
RegisterNetEvent('qb-weathersync:client:EnableSync', resume)

RegisterNetEvent('gs_weather:client:announce', function(data)
    lib.notify({
        title = data.title, description = data.description, icon = data.icon,
        type = 'inform', duration = 12000, position = 'top',
    })
end)
