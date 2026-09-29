-- gs_heists (client) : gros coups en duo. Un marqueur de lancement au site ; ensuite le serveur envoie la phase (pirate : terminal,
-- conducteur : coffres, puis fuite avec compte à rebours et GPS). Le client affiche, le serveur décide.
local phase       -- dernière phase reçue
local blips = {}

local function notify(ok, msg) if msg then lib.notify({ description = msg, type = ok and 'success' or 'error', duration = 7000 }) end end

local function clear()
    exports.gs_markers:RemovePrefix('gs_heists:big:')
    for _, b in ipairs(blips) do RemoveBlip(b) end
    blips = {}
end

local function drawText(text)
    SetTextFont(4) SetTextScale(0.0, 0.55) SetTextCentre(true) SetTextOutline() SetTextColour(255, 196, 0, 235)
    BeginTextCommandDisplayText('STRING') AddTextComponentSubstringPlayerName(text) EndTextCommandDisplayText(0.5, 0.86)
end

AddEventHandler('gs_heists:client:bigAct', function(point)
    if cache.vehicle then return end
    local ok, ms, label = lib.callback.await('gs_heists:bigBegin', false, point)
    if not ok then return notify(false, ms) end
    local done = lib.progressBar({ duration = ms, label = label, canCancel = true, disable = { move = true, car = true, combat = true },
        anim = { dict = 'anim@heists@prison_heiststation@cop_reactions', clip = 'cop_b_idle' } })
    if not done then return TriggerServerEvent('gs_heists:server:cancel') end
    notify(lib.callback.await('gs_heists:bigFinish', false))
end)

RegisterNetEvent('gs_heists:client:bigPhase', function(info, reason, success)
    clear()
    phase = info
    if not info then
        if reason then lib.notify({ title = 'Gros coup', description = reason, type = success and 'success' or 'error', duration = 10000 }) end
        return
    end
    if info.phase == 'escape' then
        local start = GetGameTimer()
        local left = info.timeLeft
        CreateThread(function()
            while phase and phase.phase == 'escape' do
                local d = #(GetEntityCoords(cache.ped) - phase.from)
                drawText(('FUITE · %d m / %d m · %d s'):format(math.floor(d), phase.distance, math.max(0, left - (GetGameTimer() - start) // 1000)))
                Wait(0)
            end
        end)
        return
    end
    for i, c in ipairs(info.coords) do
        local b = AddBlipForCoord(c.x, c.y, c.z)
        SetBlipSprite(b, 1) SetBlipColour(b, info.mine and 5 or 4) SetBlipScale(b, 0.7)
        if info.mine then SetBlipRoute(b, true) end
        blips[#blips + 1] = b
        if info.mine then
            local point = info.phase == 'loot' and (function() for j, v in ipairs(Config.Big[info.site or 'fleeca_legion'].vault) do if #(vec3(v.x, v.y, v.z) - vec3(c.x, c.y, c.z)) < 0.5 then return j end end end)() or nil
            exports.gs_markers:Add('gs_heists:big:' .. i, { coords = c, style = 'objective', label = info.label, event = 'gs_heists:client:bigAct',
                args = { point }, prompt = info.label, reach = 1.8, distance = 40.0 })
        end
    end
    lib.notify({ title = 'Gros coup · ' .. (info.role == 'hacker' and 'Pirate' or 'Conducteur'),
        description = info.mine and info.label or ('Attends : ton partenaire ' .. info.label:lower()), type = 'inform', duration = 8000 })
end)

AddEventHandler('gs_heists:client:bigStart', function(id)
    local r = lib.inputDialog(Config.Big[id].label, { { type = 'select', label = 'Ton rôle (ton partenaire de duo prend l\'autre)', required = true,
        options = { { value = 'hacker', label = 'Pirate informatique : coupe l\'alarme' }, { value = 'driver', label = id == 'cayo' and 'Conducteur : vide la villa et pilote le bateau de fuite' or 'Conducteur : vide les coffres et conduit la fuite' } } } })
    if r then notify(lib.callback.await('gs_heists:bigStart', false, id, r[1])) end
end)

CreateThread(function()
    for id, site in pairs(Config.Big) do
        exports.gs_markers:Add('gs_heists:bigstart:' .. id, { coords = site.start or site.center, style = 'objective', label = site.label, event = 'gs_heists:client:bigStart',
            args = { id }, prompt = site.label .. ' (duo)', reach = 2.5, distance = 25.0 })
    end
end)

-- Repérage (Cayo Perico) : /reperage affiche les points ; [E] sur place pour photographier.
local scouting = false
AddEventHandler('gs_heists:client:scout', function(id, i) notify(lib.callback.await('gs_heists:scout', false, id, i)) end)
RegisterCommand('reperage', function()
    scouting = not scouting
    exports.gs_markers:RemovePrefix('gs_heists:scout:')
    if not scouting then return notify(true, 'Repérage masqué.') end
    for id, site in pairs(Config.Big) do
        for i, c in ipairs(site.scout or {}) do
            exports.gs_markers:Add(('gs_heists:scout:%s:%d'):format(id, i), { coords = c, style = 'objective', label = 'Repérage', event = 'gs_heists:client:scout',
                args = { id, i }, prompt = 'Photographier les lieux', reach = 6.0, distance = 80.0 })
        end
    end
    notify(true, 'Points de repérage affichés (Cayo Perico : vol à l\'aéroport LSIA).')
end, false)

-- Gardes de Cayo Perico : créés par le pirate quand l'alarme saute (entités réseau, visibles par les deux).
local guards = {}
RegisterNetEvent('gs_heists:client:guards', function(id)
    local site = Config.Big[id]
    if not site or not site.guards then return end
    local hash = GetHashKey(site.guardModel)
    lib.requestModel(hash, 10000)
    AddRelationshipGroup('GS_CAYO_GUARDS')
    SetRelationshipBetweenGroups(5, GetHashKey('GS_CAYO_GUARDS'), GetHashKey('PLAYER'))
    for _, g in ipairs(site.guards) do
        local ped = CreatePed(4, hash, g.x, g.y, g.z - 1.0, g.w, true, true)
        SetPedRelationshipGroupHash(ped, GetHashKey('GS_CAYO_GUARDS'))
        GiveWeaponToPed(ped, GetHashKey(site.guardWeapon), 250, false, true)
        SetPedArmour(ped, 50)
        SetPedAccuracy(ped, 35)
        TaskCombatPed(ped, cache.ped, 0, 16)
        guards[#guards + 1] = ped
    end
    SetModelAsNoLongerNeeded(hash)
    lib.notify({ title = 'Alarme !', description = 'Les gardes de la villa arrivent.', type = 'error', duration = 8000 })
end)

local function clearGuards()
    for _, ped in ipairs(guards) do if DoesEntityExist(ped) then SetPedAsNoLongerNeeded(ped) end end
    guards = {}
end
RegisterNetEvent('gs_heists:client:bigPhase', function(info) if not info then clearGuards() end end)

AddEventHandler('onResourceStop', function(res)
    if res == GetCurrentResourceName() then clear() clearGuards() exports.gs_markers:RemovePrefix('gs_heists:bigstart:') exports.gs_markers:RemovePrefix('gs_heists:scout:') end
end)
