-- gs_weather (client) · V8 « Météo événementielle » : barrières sur les routes fermées, interventions tempête.
local S = Config.Storm
local props, blips = {}, {}

local function clear()
    for _, e in ipairs(props) do if DoesEntityExist(e) then DeleteEntity(e) end end
    for _, b in ipairs(blips) do RemoveBlip(b) end
    props, blips = {}, {}
    exports.gs_markers:RemovePrefix('gs_storm:')
end

local function blip(c, sprite, color, label)
    local b = AddBlipForCoord(c.x, c.y, c.z)
    SetBlipSprite(b, sprite) SetBlipColour(b, color) SetBlipScale(b, 0.8) SetBlipAsShortRange(b, false)
    BeginTextCommandSetBlipName('STRING') AddTextComponentSubstringPlayerName(label) EndTextCommandSetBlipName(b)
    blips[#blips + 1] = b
end

local function place(model, c, heading, offset)
    local h = GetHashKey(model)
    if not lib.requestModel(h, 5000) then return end
    local pos = offset and vec3(c.x + offset.x, c.y + offset.y, c.z) or vec3(c.x, c.y, c.z)
    local o = CreateObject(h, pos.x, pos.y, pos.z, false, false, false)
    SetEntityHeading(o, heading) PlaceObjectOnGroundProperly(o) FreezeEntityPosition(o, true)
    SetModelAsNoLongerNeeded(h)
    props[#props + 1] = o
end

local function apply(state)
    clear()
    if not state then return end
    for _, i in ipairs(state.roads or {}) do
        local r = S.roads[i]
        local c, rad = r.coords, math.rad(r.coords.w)
        local right = vec3(math.cos(rad), math.sin(rad), 0.0)
        for k = -2, 2 do place('prop_barrier_work05', c, c.w, right * (k * 2.6)) end
        blip(c, 650, 1, 'Route fermée (tempête)')
    end
    for id, idx in pairs(state.incidents or {}) do
        local sp = S.spots[idx]
        local c = sp.coords
        if sp.kind == 'tree' then place('prop_tree_fallen_pine_01', c, c.w) else
            local h = GetHashKey('emperor')
            if lib.requestModel(h, 5000) then
                local v = CreateVehicle(h, c.x, c.y, c.z, c.w, false, false)
                SetVehicleOnGroundProperly(v) SetVehicleIndicatorLights(v, 0, true) SetVehicleIndicatorLights(v, 1, true)
                SetVehicleEngineHealth(v, 100.0) FreezeEntityPosition(v, true)
                props[#props + 1] = v
            end
        end
        blip(c, 446, 47, sp.kind == 'tree' and 'Arbre sur la route (tempête)' or 'Véhicule en détresse (tempête)')
        exports.gs_markers:Add('gs_storm:' .. id, { coords = vec3(c.x, c.y, c.z + 0.5), style = 'job', label = 'Intervention',
            event = 'gs_weather:client:stormFix', args = { id }, reach = 6.0, snap = true,
            prompt = sp.kind == 'tree' and 'Dégager l\'arbre (prime tempête)' or 'Remorquer / réparer (prime tempête)' })
    end
end

AddEventHandler('gs_weather:client:stormFix', function(id)
    if not lib.progressBar({ duration = 10000, label = 'Intervention…', canCancel = true, anim = { scenario = 'WORLD_HUMAN_HAMMERING' },
        disable = { move = true, car = true, combat = true } }) then return ClearPedTasks(cache.ped) end
    ClearPedTasks(cache.ped)
    local ok, msg = lib.callback.await('gs_weather:stormFix', false, id)
    lib.notify({ description = msg, type = ok and 'success' or 'error' })
end)

AddStateBagChangeHandler('gsStorm', 'global', function(_, _, value) apply(value) end)
CreateThread(function() Wait(3000) apply(GlobalState.gsStorm) end)
AddEventHandler('onResourceStop', function(res) if res == GetCurrentResourceName() then clear() end end)
