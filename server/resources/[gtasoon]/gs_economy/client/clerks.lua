-- gs_economy (client) : vendeurs PNJ derrière les comptoirs (locaux, créés à < 40 m, retirés au-delà de 60 m).
local clerks = {} -- [index] = ped

local function spawn(i, c)
    local hash = GetHashKey(Config.ClerkModel)
    if not IsModelInCdimage(hash) then return end
    lib.requestModel(hash, 5000)
    RequestCollisionAtCoord(c.x, c.y, c.z)
    local found, gz = GetGroundZFor_3dCoord(c.x, c.y, c.z + 1.5, false)
    local ped = CreatePed(4, hash, c.x, c.y, found and gz or (c.z - 1.0), c.w, false, true)
    SetModelAsNoLongerNeeded(hash)
    SetEntityInvincible(ped, true)
    FreezeEntityPosition(ped, true)
    SetBlockingOfNonTemporaryEvents(ped, true)
    SetPedCanRagdoll(ped, false)
    clerks[i] = ped
end

CreateThread(function()
    while true do
        local me = GetEntityCoords(PlayerPedId())
        for i, shop in ipairs(Config.Shops) do
            local c = shop.clerk
            if c then
                local d = #(me - vec3(c.x, c.y, c.z))
                if d < 40.0 and not clerks[i] then spawn(i, c)
                elseif d > 60.0 and clerks[i] then DeleteEntity(clerks[i]) clerks[i] = nil end
            end
        end
        Wait(1000)
    end
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    for _, ped in pairs(clerks) do DeleteEntity(ped) end
end)
