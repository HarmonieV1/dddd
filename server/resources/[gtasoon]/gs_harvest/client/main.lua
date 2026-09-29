-- gs_harvest (client) : points [E] de récolte, blips, acheteurs, dépeçage des animaux abattus (ox_target).
local function notify(ok, msg) if msg then lib.notify({ description = msg, type = ok and 'success' or 'error' }) end end
local busy = false

AddEventHandler('gs_harvest:client:do', function(id)
    if busy or cache.vehicle then return end
    local a = Config.Activities[id]
    local ok, res = lib.callback.await('gs_harvest:begin', false, id)
    if not ok then return notify(false, res) end
    busy = true
    local done = lib.progressBar({ duration = res, label = a.verb .. '…', canCancel = true,
        anim = a.scenario and { scenario = a.scenario } or a.anim, disable = { move = true, car = true, combat = true } })
    ClearPedTasks(cache.ped)
    busy = false
    if not done then return TriggerServerEvent('gs_harvest:server:cancel') end
    notify(lib.callback.await('gs_harvest:finish', false))
end)

AddEventHandler('gs_harvest:client:licence', function()
    notify(lib.callback.await('gs_harvest:buyLicence', false))
end)

AddEventHandler('gs_harvest:client:sell', function(i)
    notify(lib.callback.await('gs_harvest:sell', false, i))
end)

local blips = {}
local function blip(c, b, label)
    local h = AddBlipForCoord(c.x, c.y, c.z)
    SetBlipSprite(h, b.sprite) SetBlipColour(h, b.color) SetBlipScale(h, 0.7) SetBlipAsShortRange(h, true)
    BeginTextCommandSetBlipName('STRING') AddTextComponentSubstringPlayerName(label) EndTextCommandSetBlipName(h)
    blips[#blips + 1] = h
end

CreateThread(function()
    for id, a in pairs(Config.Activities) do
        blip(a.spots[1], a.blip, a.label)
        for i, c in ipairs(a.spots) do
            exports.gs_markers:Add(('gs_harvest:%s:%d'):format(id, i), { coords = c, style = 'job', label = a.label,
                event = 'gs_harvest:client:do', args = { id }, prompt = a.verb .. (a.tool and (' (' .. a.tool .. ')') or ''), distance = 25.0 })
        end
    end
    for i, b in ipairs(Config.Buyers) do
        blip(b.coords, b.blip, b.label)
        exports.gs_markers:Add('gs_harvest:buyer:' .. i, { coords = b.coords, style = 'shop', label = b.label,
            event = 'gs_harvest:client:sell', args = { i }, prompt = 'Vendre · ' .. b.label, distance = 20.0 })
    end
    blip(Config.Hunting.center, Config.Hunting.blip, Config.Hunting.label)
    exports.gs_markers:Add('gs_harvest:licence', { coords = Config.Hunting.lodge, style = 'shop', label = 'Permis de chasse',
        event = 'gs_harvest:client:licence', prompt = ('Permis de chasse (%d $)'):format(Config.Hunting.licencePrice), distance = 20.0 })

    -- Dépecer : ox_target sur les animaux abattus (le serveur vérifie que c'est bien du gibier de la zone)
    local models = {}
    for m in pairs(Config.Hunting.animals) do models[#models + 1] = m end
    exports.ox_target:addModel(models, { { -- [API] ox_target
        name = 'gs_harvest:skin', icon = 'fa-solid fa-drumstick-bite', label = 'Dépecer', distance = 2.5,
        canInteract = function(ent) return IsEntityDead(ent) end,
        onSelect = function(data)
            if not NetworkGetEntityIsNetworked(data.entity) then return notify(false, 'Rien à dépecer.') end
            if not lib.progressBar({ duration = Config.Hunting.skinTime, label = 'Dépeçage…', canCancel = true,
                anim = { dict = 'amb@medic@standing@kneel@base', clip = 'base' }, disable = { move = true, car = true, combat = true } }) then return end
            ClearPedTasks(cache.ped)
            notify(lib.callback.await('gs_harvest:skin', false, NetworkGetNetworkIdFromEntity(data.entity)))
        end,
    } })
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    exports.gs_markers:RemovePrefix('gs_harvest:')
    for _, b in ipairs(blips) do RemoveBlip(b) end
end)
