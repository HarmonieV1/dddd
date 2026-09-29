-- gs_gigs (client) : point GPS + marqueur de l'étape en cours ; [E] sur place. L'app Boulots du téléphone (gs_phone)
-- appelle les exports List / Accept / Cancel.
local blip
local current

local function clear()
    if blip then RemoveBlip(blip) blip = nil end
    exports.gs_markers:RemovePrefix('gs_gigs:')
    current = nil
end

local function show(st)
    clear()
    if not st then return end
    current = st
    local c = st.coords
    blip = AddBlipForCoord(c.x, c.y, c.z)
    SetBlipSprite(blip, st.stage == 1 and 478 or 501) SetBlipColour(blip, 5) SetBlipRoute(blip, true) SetBlipRouteColour(blip, 5)
    BeginTextCommandSetBlipName('STRING') AddTextComponentSubstringPlayerName(st.label .. ' · ' .. st.step) EndTextCommandSetBlipName(blip)
    exports.gs_markers:Add('gs_gigs:step', { coords = c, style = 'objective', label = st.step, event = 'gs_gigs:client:step',
        prompt = st.step, reach = Config.Radius - 1.0, distance = 60.0 })
end

AddEventHandler('gs_gigs:client:step', function()
    local ok, st, done = lib.callback.await('gs_gigs:step', false)
    if not ok then
        if st == 'Trop tard, le client a annulé.' or st == 'Livraison refusée : trajet impossible.' then clear() end
        return lib.notify({ description = st, type = 'error' })
    end
    if done then clear() return lib.notify({ title = 'Boulot terminé', description = done, type = 'success' }) end
    show(st)
    lib.notify({ description = 'Chargé. Direction : ' .. st.step:lower() .. '.', type = 'inform' })
end)

exports('List', function() return lib.callback.await('gs_gigs:list', false) end)
exports('Accept', function(id)
    local ok, st = lib.callback.await('gs_gigs:accept', false, id)
    if ok then show(st) end
    return ok, ok and 'Boulot accepté : suis le GPS.' or st
end)
exports('Cancel', function()
    local ok = lib.callback.await('gs_gigs:cancel', false)
    if ok then clear() end
    return ok
end)

AddEventHandler('onResourceStop', function(res) if res == GetCurrentResourceName() then clear() end end)
