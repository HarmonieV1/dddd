-- gs_wanted (client) : détection des tirs / car-jacking, étoiles de chaleur, dispatch police.
-- Aucune boucle par frame hors arme à feu en main ou chaleur > 0.
local heat = 0
local reports = {}

-- Tirs : boucle par frame UNIQUEMENT tant qu'une arme à feu est en main -------------------------
local watchToken = 0

local function watchShots(weapon)
    watchToken = watchToken + 1
    local token = watchToken
    CreateThread(function()
        while cache.weapon == weapon and token == watchToken do
            if IsPedShooting(cache.ped) then
                TriggerServerEvent('gs_wanted:server:shot', IsPedCurrentWeaponSilenced(cache.ped))
                Wait(10000)
            else
                Wait(0)
            end
        end
    end)
end

local function onWeapon(weapon)
    if weapon and GetWeaponDamageType(weapon) == 3 then watchShots(weapon) end -- 3 = balles
end
lib.onCache('weapon', onWeapon)
CreateThread(function() onWeapon(cache.weapon) end) -- arme déjà en main au (re)démarrage

-- Car-jacking : vérif légère 4 fois / seconde
CreateThread(function()
    while true do
        if IsPedJacking(cache.ped) then
            TriggerServerEvent('gs_wanted:server:carjack')
            Wait(20000)
        end
        Wait(250)
    end
end)

-- Étoiles de chaleur (visibles seulement quand on est signalé) ------------------------------------
local drawing = false
local function drawStars()
    if drawing then return end
    drawing = true
    CreateThread(function()
        while heat > 0 do
            local stars = math.ceil(heat / 20)
            SetTextFont(4)
            SetTextScale(0.0, 0.55)
            SetTextColour(255, 46, 136, 230)
            SetTextOutline()
            SetTextRightJustify(true)
            SetTextWrap(0.0, 0.985)
            BeginTextCommandDisplayText('STRING')
            AddTextComponentSubstringPlayerName('RECHERCHÉ ' .. ('★'):rep(stars) .. ('☆'):rep(5 - stars))
            EndTextCommandDisplayText(0.985, 0.03)
            Wait(0)
        end
        drawing = false
    end)
end

RegisterNetEvent('gs_wanted:client:heat', function(value)
    heat = value or 0
    if heat > 0 then drawStars() end
end)

-- Dispatch police ----------------------------------------------------------------------------------
local function describe(r)
    local street = GetStreetNameFromHashKey(GetStreetNameAtCoord(r.coords.x, r.coords.y, r.coords.z))
    local who = r.witnesses == -1 and 'constaté par un agent'
        or (r.witnesses == 0 and 'appel anonyme' or ('%d témoin(s)'):format(r.witnesses))
    local parts = { ('%s · ±%d m'):format(street, r.radius), who }
    if r.model then
        local name = GetLabelText(GetDisplayNameFromVehicleModel(r.model))
        parts[#parts + 1] = ('%s %s'):format(name, r.plate or '')
    end
    return table.concat(parts, ' · ')
end

RegisterNetEvent('gs_wanted:client:dispatch', function(r)
    table.insert(reports, 1, r)
    reports[11] = nil
    lib.notify({ title = 'Central : ' .. r.label, description = describe(r), type = 'warning', icon = 'tower-broadcast', duration = 10000 })
    PlaySoundFrontend(-1, 'Lose_1st', 'GTAO_FM_Events_Soundset', false)

    local area = AddBlipForRadius(r.coords.x, r.coords.y, r.coords.z, r.radius + 0.0)
    SetBlipColour(area, 1)
    SetBlipAlpha(area, 90)
    local blip = AddBlipForCoord(r.coords.x, r.coords.y, r.coords.z)
    SetBlipSprite(blip, 161)
    SetBlipColour(blip, 1)
    SetBlipScale(blip, 1.1)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentSubstringPlayerName(r.label)
    EndTextCommandSetBlipName(blip)
    SetTimeout(Config.Dispatch.blipSeconds * 1000, function()
        RemoveBlip(area)
        RemoveBlip(blip)
    end)
end)

RegisterCommand('dispatch', function()
    local list = lib.callback.await('gs_wanted:history', false) or {}
    local options = {}
    for _, r in ipairs(list) do
        options[#options + 1] = {
            title = r.label, description = describe(r), icon = 'location-crosshairs',
            onSelect = function() SetNewWaypoint(r.coords.x, r.coords.y) end,
        }
    end
    if #options == 0 then options[1] = { title = 'Aucun signalement récent', readOnly = true } end
    lib.registerContext({ id = 'gs_dispatch', title = 'Central LSPD', options = options })
    lib.showContext('gs_dispatch')
end, false)
