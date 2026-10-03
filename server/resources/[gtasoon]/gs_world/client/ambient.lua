-- gs_world (client) : PNJ d'ambiance (Config.AmbientPeds) créés à l'approche, supprimés au loin.
local spawned = {}

local function groundZ(c)
    local found, gz = GetGroundZFor_3dCoord(c.x, c.y, c.z + 2.0, false)
    if found and math.abs(gz - c.z) < 4.0 then return gz end
    return c.z
end

local function spawn(i, p)
    local hash = GetHashKey(p.model)
    if not IsModelInCdimage(hash) or not lib.requestModel(hash, 5000) then return end
    local c = p.coords
    local ped = CreatePed(4, hash, c.x, c.y, groundZ(c), c.w or 0.0, false, true)
    SetModelAsNoLongerNeeded(hash)
    SetEntityInvincible(ped, true)
    SetBlockingOfNonTemporaryEvents(ped, true)
    SetPedCanRagdoll(ped, false)
    FreezeEntityPosition(ped, true)
    if p.anim and lib.requestAnimDict(p.anim.dict, 5000) then
        TaskPlayAnim(ped, p.anim.dict, p.anim.clip, 8.0, -8.0, -1, 1, 0.0, false, false, false)
    elseif p.scenario then
        TaskStartScenarioInPlace(ped, p.scenario, 0, true)
    end
    spawned[i] = ped
end

CreateThread(function()
    while true do
        local me = GetEntityCoords(cache.ped)
        for i, p in ipairs(Config.AmbientPeds) do
            local d = #(me - p.coords.xyz)
            if d < 60.0 and not spawned[i] then spawn(i, p)
            elseif d > 80.0 and spawned[i] then
                if DoesEntityExist(spawned[i]) then DeletePed(spawned[i]) end
                spawned[i] = nil
            end
        end
        Wait(2000)
    end
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    for _, ped in pairs(spawned) do if DoesEntityExist(ped) then DeletePed(ped) end end
end)
