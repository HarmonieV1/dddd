-- gs_world (client) · V12.63 « Journée North Yankton » (proposition n° 191). La ville enneigée du prologue de GTA V n'est
-- chargée que les jours où le vol régulier y mène (GlobalState.gsIslandMode = 'yankton') et seulement à l'approche : zéro
-- coût ailleurs. Cayo Perico (mêmes coordonnées) n'est jamais chargée en même temps (client/island.lua). Neige et minimap
-- du prologue pour les voyageurs seulement. [API] natives IPL / minimap du prologue.
local Y = Config.Yankton
local loaded = false
local SNOW = { XMAS = true, SNOW = true, SNOWLIGHT = true, BLIZZARD = true }
GsWorld = GsWorld or {}

local function setYankton(on)
    loaded = on
    for _, ipl in ipairs(Y.ipls) do if on then RequestIpl(ipl) else RemoveIpl(ipl) end end
    SetMinimapInPrologue(on)
    if on then
        if Y.weather then SetOverrideWeather(Y.weather) end
        SetForcePedFootstepsTracks(true) SetForceVehicleTrails(true)
    else
        ClearOverrideWeather() -- retour à la météo de la ville (gs_weather)
        local w = GlobalState.gsWeather
        local snow = w and SNOW[w.type] == true or false
        SetForcePedFootstepsTracks(snow) SetForceVehicleTrails(snow)
    end
end

local function inZone(c)
    local dx, dy = c.x - Y.zone.x, c.y - Y.zone.y
    return dx * dx + dy * dy < Y.loadRadius * Y.loadRadius
end

--- Arrivée sans le vol (reconnexion sur place) : figé le temps que le sol se charge, pour ne pas traverser la carte.
--- Jamais pendant un vol ou un rapatriement (client/island.lua s'en occupe déjà).
local function holdUntilGround()
    if cache.vehicle or GsWorld.flying then return end
    local ped = cache.ped
    FreezeEntityPosition(ped, true)
    local c = GetEntityCoords(ped)
    local t = GetGameTimer() + 8000
    while not HasCollisionLoadedAroundEntity(ped) and GetGameTimer() < t do
        RequestCollisionAtCoord(c.x, c.y, c.z)
        Wait(50)
    end
    if not GsWorld.flying then FreezeEntityPosition(ped, false) end
end

CreateThread(function()
    while true do
        local want = GlobalState.gsIslandMode == 'yankton' and inZone(GetEntityCoords(cache.ped))
        if want ~= loaded then
            setYankton(want)
            if want then holdUntilGround() end
        elseif loaded and Y.weather then
            SetOverrideWeather(Y.weather) -- gs_weather efface la surcharge à chaque changement de temps : on la remet
        end
        Wait(want and 2000 or 3000)
    end
end)

-- Vol vers North Yankton : décor demandé dès que le serveur nous a posés à l'arrivée (il finit de charger pendant le film)
AddEventHandler('gs_world:client:yanktonPreload', function()
    if not loaded and GlobalState.gsIslandMode == 'yankton' then setYankton(true) end
end)

AddEventHandler('onResourceStop', function(res)
    if res == GetCurrentResourceName() and loaded then setYankton(false) end
end)
