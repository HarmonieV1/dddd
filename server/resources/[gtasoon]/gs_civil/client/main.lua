-- gs_civil (client) : guichet de l'état civil ([E]) et réponse à une demande en mariage.
local function notify(ok, msg) if msg then lib.notify({ description = msg, type = ok and 'success' or 'error', duration = 7000 }) end end

AddEventHandler('gs_civil:client:desk', function()
    local info = lib.callback.await('gs_civil:info', false)
    if not info then return notify(false, 'Guichet indisponible.') end
    local options = { { title = info.spouse and ('Marié(e) à %s'):format(info.spouse) or 'Célibataire', icon = 'heart', readOnly = true } }
    if not info.spouse then
        options[#options + 1] = { title = ('Demander en mariage (%d $ chacun)'):format(info.marriageFee), icon = 'ring', onSelect = function()
            local list = {}
            for _, p in ipairs(lib.getNearbyPlayers(GetEntityCoords(cache.ped), Config.Range, false)) do
                list[#list + 1] = { value = tostring(GetPlayerServerId(p.id)), label = GetPlayerName(p.id) }
            end
            if #list == 0 then return notify(false, 'Personne à côté de toi.') end
            local r = lib.inputDialog('Demande en mariage', { { type = 'select', label = 'À qui ?', options = list, required = true } })
            if r then notify(lib.callback.await('gs_civil:propose', false, tonumber(r[1]))) end
        end }
    else
        options[#options + 1] = { title = ('Divorcer (%d $)'):format(info.divorceFee), icon = 'heart-crack', iconColor = '#ff4d6d', onSelect = function()
            if lib.alertDialog({ header = 'Divorcer ?', content = 'C\'est définitif.', centered = true, cancel = true }) == 'confirm' then
                notify(lib.callback.await('gs_civil:divorce', false))
            end
        end }
    end
    lib.registerContext({ id = 'gs_civil', title = 'État civil', options = options })
    lib.showContext('gs_civil')
end)

RegisterNetEvent('gs_civil:client:proposal', function(from)
    local a = lib.alertDialog({ header = 'Demande en mariage', content = ('**%s** te demande en mariage. Tu acceptes ?'):format(from), centered = true, cancel = true,
        labels = { confirm = 'Oui !', cancel = 'Non' } })
    notify(lib.callback.await('gs_civil:answer', false, a == 'confirm'))
end)

CreateThread(function()
    exports.gs_markers:Add('gs_civil:desk', { coords = Config.Desk, style = 'entry', label = 'État civil', event = 'gs_civil:client:desk',
        prompt = 'État civil (mariage, divorce)', distance = 15.0 })
end)
