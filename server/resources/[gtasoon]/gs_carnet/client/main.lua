-- gs_carnet (client) : /histoire au volant (historique public), et pour la police depuis « Vérifier une plaque ».
local ICONS = { accident = 'car-burst', owner = 'key', paint = 'spray-can', crime = 'handcuffs' }

local function show(plate)
    local d = lib.callback.await('gs_carnet:view', false, plate)
    if not d then return lib.notify({ description = 'Pas de carnet : ce n\'est pas un véhicule de particulier.', type = 'error' }) end
    local options = {
        { title = ('%s · %d km'):format(d.plate, d.km), icon = 'gauge', readOnly = true,
          description = ('%d propriétaire(s)%s'):format(d.owners, d.color and (' · peinture ' .. d.color) or '') },
    }
    for _, e in ipairs(d.events) do
        options[#options + 1] = { title = e.text, description = e.date, icon = ICONS[e.kind] or 'circle', readOnly = true,
            iconColor = e.police == 1 and '#ff4d6d' or nil }
    end
    if #d.events == 0 then options[#options + 1] = { title = 'Aucun incident', icon = 'circle-check', readOnly = true } end
    lib.registerContext({ id = 'gs_carnet', title = 'Carnet du véhicule', options = options })
    lib.showContext('gs_carnet')
end

RegisterCommand('histoire', function()
    if not cache.vehicle then return lib.notify({ description = 'Monte dans le véhicule.', type = 'error' }) end
    show(nil)
end, false)
AddEventHandler('gs_carnet:client:show', show)
