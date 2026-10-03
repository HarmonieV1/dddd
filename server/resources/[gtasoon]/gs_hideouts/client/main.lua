-- gs_hideouts (client) : réception = louer / entrer ; dans la chambre : coffre, garde-robe, sortie.
local function notify(ok, msg) if msg then lib.notify({ description = msg, type = ok and 'success' or 'error' }) end end

AddEventHandler('gs_hideouts:client:desk', function(siteId)
    local site = Config.Sites[siteId]
    local info = lib.callback.await('gs_hideouts:info', false) or {}
    local mine = info.site == siteId and info.expires and info.expires > info.now
    local options = {}
    if mine then
        local days = math.floor((info.expires - info.now) / 86400)
        options[#options + 1] = { title = 'Entrer dans ma chambre', icon = 'door-open', description = ('Encore %d jour(s) de location'):format(days),
            onSelect = function() local ok, msg = lib.callback.await('gs_hideouts:enter', false, siteId) if not ok then notify(false, msg) end end }
    end
    options[#options + 1] = { title = mine and 'Prolonger la location' or ('Louer une chambre · %d $ / semaine'):format(site.price), icon = 'key',
        description = 'Coffre perso, garde-robe. Un vrai logement ? L\'agent immobilier.', onSelect = function()
            local r = lib.inputDialog(site.label, { { type = 'slider', label = 'Semaines (payé en banque)', min = 1, max = Config.MaxWeeks, default = 1 } })
            if r then notify(lib.callback.await('gs_hideouts:rent', false, siteId, r[1])) end
        end }
    lib.registerContext({ id = 'gs_hideouts_desk', title = site.label, options = options })
    lib.showContext('gs_hideouts_desk')
end)

AddEventHandler('gs_hideouts:client:inside', function(kind)
    if kind == 'exit' then return lib.callback.await('gs_hideouts:exit', false) end
    if kind == 'stash' then
        if lib.callback.await('gs_hideouts:stash', false) then exports.ox_inventory:openInventory('stash', 'gs_hideout') end
        return
    end
    TriggerEvent('illenium-appearance:client:openOutfitMenu') -- [API] illenium-appearance : tenues enregistrées
end)

local blips = {}
CreateThread(function()
    for id, site in pairs(Config.Sites) do
        -- logo motel sur la carte (avant : aucun → « motel introuvable »)
        local b = AddBlipForCoord(site.entrance.x, site.entrance.y, site.entrance.z)
        SetBlipSprite(b, 475) SetBlipColour(b, 8) SetBlipScale(b, 0.7) SetBlipAsShortRange(b, true)
        BeginTextCommandSetBlipName('STRING') AddTextComponentSubstringPlayerName(site.label) EndTextCommandSetBlipName(b)
        blips[#blips + 1] = b
        exports.gs_markers:Add('gs_hideouts:' .. id, { coords = site.entrance.xyz, style = 'entry', label = site.label, event = 'gs_hideouts:client:desk',
            args = { id }, prompt = 'Réception : planque à la semaine', distance = 25.0 })
    end
    local i = Config.Interior
    exports.gs_markers:Add('gs_hideouts:exit', { coords = i.xyz, style = 'hidden', event = 'gs_hideouts:client:inside', args = { 'exit' }, prompt = 'Sortir' })
    exports.gs_markers:Add('gs_hideouts:stash', { coords = Config.StashPoint, style = 'hidden', event = 'gs_hideouts:client:inside', args = { 'stash' }, prompt = 'Coffre' })
    exports.gs_markers:Add('gs_hideouts:wardrobe', { coords = Config.WardrobePoint, style = 'hidden', event = 'gs_hideouts:client:inside', args = { 'wardrobe' }, prompt = 'Garde-robe' })
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    exports.gs_markers:RemovePrefix('gs_hideouts:')
    for _, b in ipairs(blips) do RemoveBlip(b) end
end)
