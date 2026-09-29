-- gs_tuning (client) : marqueurs des salons, menu néons / plaque, application immédiate sur le véhicule au volant.
local function notify(ok, msg) if msg then lib.notify({ description = msg, type = ok and 'success' or 'error' }) end end

local function applyNeon(rgb)
    local veh = cache.vehicle
    if not veh then return end
    for i = 0, 3 do SetVehicleNeonLightEnabled(veh, i, rgb ~= nil) end
    if rgb then SetVehicleNeonLightsColour(veh, rgb[1], rgb[2], rgb[3]) end
end

AddEventHandler('gs_tuning:client:open', function()
    local info = lib.callback.await('gs_tuning:info', false)
    if not info then return notify(false, 'Salon indisponible.') end
    if not info.ok then return notify(false, info.message) end
    local options = {
        { title = ('Plaque actuelle : %s'):format(info.plate), icon = 'rectangle-list', readOnly = true },
        { title = ('Plaque personnalisée (%d $)'):format(info.platePrice), icon = 'pen', description = '2 à 8 caractères : lettres, chiffres, espaces', onSelect = function()
            local r = lib.inputDialog('Plaque personnalisée', { { type = 'input', label = 'Nouvelle plaque', required = true, max = 8, min = 2 } })
            if not r then return end
            local ok, msg, plate = lib.callback.await('gs_tuning:plate', false, r[1])
            notify(ok, msg)
            if ok and cache.vehicle then SetVehicleNumberPlateText(cache.vehicle, plate) end
        end },
        { title = 'Éteindre les néons', icon = 'lightbulb', onSelect = function()
            local ok, msg = lib.callback.await('gs_tuning:neon', false, 0)
            notify(ok, msg)
            if ok then applyNeon(nil) end
        end },
    }
    for i, c in ipairs(Config.Neon) do
        options[#options + 1] = { title = ('Néons · %s (%d $)'):format(c.label, info.neonPrice), icon = 'bolt', iconColor = ('#%02x%02x%02x'):format(c.rgb[1], c.rgb[2], c.rgb[3]),
            onSelect = function()
                local ok, msg, rgb = lib.callback.await('gs_tuning:neon', false, i)
                notify(ok, msg)
                if ok then applyNeon(rgb) end
            end }
    end
    lib.registerContext({ id = 'gs_tuning_menu', title = 'Personnalisation', options = options })
    lib.showContext('gs_tuning_menu')
end)

CreateThread(function()
    for i, s in ipairs(Config.Shops) do
        exports.gs_markers:Add('gs_tuning:' .. i, { coords = s.coords, style = 'shop', label = s.label .. ' · néons et plaques', event = 'gs_tuning:client:open',
            prompt = 'Néons et plaque personnalisée', distance = 25.0, reach = Config.Range })
    end
end)

AddEventHandler('onResourceStop', function(res)
    if res == GetCurrentResourceName() then exports.gs_markers:RemovePrefix('gs_tuning:') end
end)
