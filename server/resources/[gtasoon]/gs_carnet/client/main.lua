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

-- V8 · Fausse plaque (objet) : poser / retirer sur le véhicule le plus proche
exports('fakeplate', function()
    local me, best, bestD = GetEntityCoords(cache.ped), 0, Config.FakePlate.range
    for _, v in ipairs(GetGamePool('CVehicle')) do
        local d = #(GetEntityCoords(v) - me)
        if d < bestD then best, bestD = v, d end
    end
    if best == 0 then return lib.notify({ description = 'Approche-toi d\'un véhicule.', type = 'error' }) end
    if not lib.progressBar({ duration = 6000, label = 'Changement de plaque…', canCancel = true, anim = { dict = 'mini@repair', clip = 'fixing_a_ped' },
        disable = { move = true, car = true, combat = true } }) then return ClearPedTasks(cache.ped) end
    ClearPedTasks(cache.ped)
    local ok, msg = lib.callback.await('gs_carnet:fakeplate', false, VehToNet(best))
    lib.notify({ description = msg, type = ok and 'success' or 'error', duration = 8000 })
end)
