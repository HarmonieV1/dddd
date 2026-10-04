-- gs_justice (client) · V10.1 : /mandat (police : signalements, demander un mandat, perquisitionner ; juge : demandes).
local function notify(ok, msg) if msg then lib.notify({ description = msg, type = ok and 'success' or 'error' }) end end
local function call(...) return lib.callback.await('gs_justice:warrant', false, ...) end

RegisterCommand('mandat', function()
    local d = call('list')
    if not d then return notify(false, 'Réservé à la police et aux juges en service.') end
    local o = {}
    for _, p in ipairs(d.places) do
        local status = p.warrant and ('Mandat valide encore %d min'):format(p.warrant) or (p.pending and 'Demande en attente du juge' or 'Signalé par les voisins')
        o[#o + 1] = { title = p.label, description = ('%s · %s'):format(p.zone or '?', status), icon = p.warrant and 'file-signature' or 'house-circle-exclamation',
            iconColor = p.warrant and '#5aff8c' or '#ffb347', arrow = true, onSelect = function()
                local sub = { { title = 'GPS', icon = 'location-dot', onSelect = function() SetNewWaypoint(p.x, p.y) end } }
                if d.cop and not p.warrant and not p.pending then
                    sub[#sub + 1] = { title = 'Demander un mandat de perquisition', icon = 'gavel', onSelect = function() notify(call('request', p.key)) end }
                end
                if d.cop and p.warrant then
                    sub[#sub + 1] = { title = 'Perquisitionner (sur place)', icon = 'box-open', onSelect = function() notify(call('raid', p.key)) end }
                end
                if d.judge and p.pending then
                    sub[#sub + 1] = { title = 'Accorder le mandat', icon = 'check', onSelect = function() notify(call('decide', p.key, true)) end }
                    sub[#sub + 1] = { title = 'Refuser', icon = 'xmark', onSelect = function() notify(call('decide', p.key, false)) end }
                end
                lib.registerContext({ id = 'gs_mandat_place', title = p.label, menu = 'gs_mandat', options = sub })
                lib.showContext('gs_mandat_place')
            end }
    end
    if #o == 0 then o[1] = { title = 'Aucun signalement en cours', icon = 'circle-check', readOnly = true } end
    lib.registerContext({ id = 'gs_mandat', title = 'Mandats de perquisition', options = o })
    lib.showContext('gs_mandat')
end, false)

RegisterNetEvent('gs_justice:client:warrantRequest', function(key, label, zone, cop)
    local r = lib.alertDialog({ header = 'Demande de mandat', content = ('%s demande un mandat de perquisition pour %s (%s), signalé par les voisins.'):format(cop, label, zone or '?'),
        centered = true, cancel = true, labels = { confirm = 'Accorder', cancel = 'Refuser' } })
    notify(call('decide', key, r == 'confirm'))
end)
