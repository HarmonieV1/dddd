-- gs_roadside (client) · V8 « Halloween sur la route » : citrouilles cachées (créées à l'approche), [E] pour ramasser.
local H = Config.Halloween
local props = {}

local function clear()
    for _, o in pairs(props) do if DoesEntityExist(o) then DeleteEntity(o) end end
    props = {}
    exports.gs_markers:RemovePrefix('gs_pumpkin:')
end

AddEventHandler('gs_roadside:client:pumpkin', function(i)
    local ok, msg = lib.callback.await('gs_roadside:pumpkin', false, i)
    lib.notify({ title = 'Halloween', description = msg, type = ok and 'success' or 'error', icon = 'ghost' })
    if ok and props[i] then DeleteEntity(props[i]) props[i] = nil exports.gs_markers:Remove('gs_pumpkin:' .. i) end
end)

CreateThread(function()
    local was = false
    while true do
        local on = GlobalState.gsHalloween == true
        if on and not was then
            lib.notify({ title = 'Halloween sur la route', description = 'Des choses étranges sur les routes la nuit… et 13 citrouilles cachées dans l\'État.', type = 'inform', icon = 'ghost', duration = 10000 })
            for i, c in ipairs(H.pumpkins) do
                exports.gs_markers:Add('gs_pumpkin:' .. i, { coords = c, style = 'hidden', event = 'gs_roadside:client:pumpkin', args = { i }, prompt = 'Ramasser la citrouille', reach = 2.0 })
            end
        elseif not on and was then clear() end
        was = on
        if on then
            local me = GetEntityCoords(cache.ped)
            for i, c in ipairs(H.pumpkins) do
                local d = #(me - c)
                if d < 80.0 and not props[i] then
                    local h = GetHashKey(H.pumpkinModel)
                    if lib.requestModel(h, 5000) then
                        local o = CreateObject(h, c.x, c.y, c.z, false, false, false)
                        PlaceObjectOnGroundProperly(o) FreezeEntityPosition(o, true) SetModelAsNoLongerNeeded(h)
                        props[i] = o
                    end
                elseif d > 120.0 and props[i] then
                    DeleteEntity(props[i]) props[i] = nil
                end
            end
        end
        Wait(2500)
    end
end)

AddEventHandler('onResourceStop', function(res) if res == GetCurrentResourceName() then clear() end end)
