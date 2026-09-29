-- gs_gangs (client) : tags (bombe de peinture), garage du gang, receleur. Boucles seulement à proximité.
local member   -- appartenance courante (même event que client/main.lua)
local fenceBlip

local function notify(ok, msg) if msg then lib.notify({ description = msg, type = ok and 'success' or 'error' }) end end

-- Tags : export appelé par ox_inventory (item spraycan, client.export = 'gs_gangs.spray') --------------------------------
exports('spray', function()
    if not member then return notify(false, 'Il faut être dans un gang pour taguer.') end
    local hit, _, coords, normal = lib.raycast.cam(1, 4, 3.0) -- [API] ox_lib : mur visé à moins de 3 m
    if not hit then return notify(false, 'Vise un mur, tout près.') end
    if not lib.progressBar({ duration = Config.Tags.sprayTime, label = 'Tag en cours…', canCancel = true,
        anim = { scenario = 'WORLD_HUMAN_AA_SMOKE' }, disable = { move = true, car = true, combat = true } }) then return end
    ClearPedTasks(cache.ped)
    local pos = coords + (normal or vec3(0.0, 0.0, 0.0)) * 0.05
    local heading = normal and (math.deg(math.atan(normal.y, normal.x)) + 90.0) or GetEntityHeading(cache.ped)
    notify(lib.callback.await('gs_gangs:tag', false, { x = pos.x, y = pos.y, z = pos.z }, heading))
end)

CreateThread(function()
    local near = {}
    while true do
        local tags = GlobalState.gsTags or {}
        local me = GetEntityCoords(cache.ped)
        near = {}
        for _, t in ipairs(tags) do
            local d = #(me - vec3(t.x, t.y, t.z))
            if d < Config.Tags.drawDistance then near[#near + 1] = { t = t, d = d } end
        end
        if #near == 0 then
            Wait(1000)
        else
            local stop = GetGameTimer() + 1000
            while GetGameTimer() < stop do
                local closest
                for _, n in ipairs(near) do
                    local t = n.t
                    local onScreen, x, y = GetScreenCoordFromWorldCoord(t.x, t.y, t.z)
                    if onScreen then
                        SetTextFont(1) SetTextScale(0.0, math.max(0.35, 1.6 - n.d * 0.045)) SetTextCentre(true)
                        SetTextColour(t.r, t.g, t.b, 235) SetTextDropshadow(2, 0, 0, 0, 200)
                        BeginTextCommandDisplayText('STRING')
                        AddTextComponentSubstringPlayerName(t.label)
                        EndTextCommandDisplayText(x, y)
                    end
                    if n.d < Config.Tags.range and (not closest or n.d < closest.d) then closest = n end
                end
                if closest and not cache.vehicle then
                    SetTextFont(4) SetTextScale(0.0, 0.45) SetTextCentre(true) SetTextOutline() SetTextColour(40, 224, 255, 240)
                    BeginTextCommandDisplayText('STRING')
                    AddTextComponentSubstringPlayerName('[G] Effacer le tag')
                    EndTextCommandDisplayText(0.5, 0.84)
                    if IsControlJustReleased(0, 47) then
                        if lib.progressBar({ duration = Config.Tags.eraseTime, label = 'Nettoyage du tag…', canCancel = true,
                            anim = { scenario = 'WORLD_HUMAN_MAID_CLEAN' }, disable = { move = true, car = true } }) then
                            ClearPedTasks(cache.ped)
                            notify(lib.callback.await('gs_gangs:eraseTag', false, closest.t.id))
                        end
                        break
                    end
                end
                Wait(0)
            end
        end
    end
end)

-- Garage du gang ------------------------------------------------------------------------------------------------------
AddEventHandler('gs_gangs:client:garage', function()
    local g = member and (GlobalState.gsGangGarages or {})[member.gang]
    if not g then return end
    local options = {}
    for i, model in ipairs(g.vehicles) do
        options[#options + 1] = { title = GetLabelText(GetDisplayNameFromVehicleModel(GetHashKey(model))), icon = 'car', onSelect = function()
            notify(lib.callback.await('gs_gangs:garage', false, i))
        end }
    end
    options[#options + 1] = { title = 'Ranger mon véhicule', icon = 'warehouse', onSelect = function()
        notify(lib.callback.await('gs_gangs:garageStore', false))
    end }
    lib.registerContext({ id = 'gs_gang_garage', title = 'Garage · ' .. member.label, options = options })
    lib.showContext('gs_gang_garage')
end)

-- Receleur ------------------------------------------------------------------------------------------------------------
AddEventHandler('gs_gangs:client:fence', function()
    local options = {}
    for _, drug in ipairs({ { id = 'weed', label = 'Cannabis' }, { id = 'coke', label = 'Cocaïne' } }) do
        options[#options + 1] = { title = 'Vendre tout mon ' .. drug.label, icon = 'sack-dollar', onSelect = function()
            notify(lib.callback.await('gs_gangs:fenceSell', false, drug.id))
        end }
    end
    lib.registerContext({ id = 'gs_gang_fence', title = 'Receleur (vente en gros)', options = options })
    lib.showContext('gs_gang_fence')
end)

local function refreshFence()
    if fenceBlip then RemoveBlip(fenceBlip) fenceBlip = nil end
    exports.gs_markers:Remove('gs_gangs:fence')
    local info = member and lib.callback.await('gs_gangs:fenceInfo', false)
    if not info or not info.open then return end
    local c = info.coords
    fenceBlip = AddBlipForCoord(c.x, c.y, c.z)
    SetBlipSprite(fenceBlip, 500)
    SetBlipColour(fenceBlip, 1)
    SetBlipAsShortRange(fenceBlip, true)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentSubstringPlayerName('Receleur')
    EndTextCommandSetBlipName(fenceBlip)
    exports.gs_markers:Add('gs_gangs:fence', { coords = c, style = 'shop', label = 'Receleur', event = 'gs_gangs:client:fence', prompt = 'Parler au receleur' })
end

RegisterNetEvent('gs_gangs:client:membership', function(m)
    member = m
    exports.gs_markers:Remove('gs_gangs:garage')
    local g = m and (GlobalState.gsGangGarages or {})[m.gang]
    if g then
        exports.gs_markers:Add('gs_gangs:garage', { coords = vec3(g.x, g.y, g.z), style = 'entry', label = 'Garage du gang',
            icon = 36, event = 'gs_gangs:client:garage', prompt = 'Garage du gang' })
    end
    refreshFence()
end)

-- Le receleur change de place toutes les heures et n'ouvre que la nuit : vérification toutes les 5 min
CreateThread(function()
    while true do
        Wait(300000)
        if member then refreshFence() end
    end
end)

-- Garage déplacé par le staff : on remet le marqueur à jour
AddStateBagChangeHandler('gsGangGarages', 'global', function()
    SetTimeout(100, function() if member then TriggerEvent('gs_gangs:client:membership', member) end end)
end)
