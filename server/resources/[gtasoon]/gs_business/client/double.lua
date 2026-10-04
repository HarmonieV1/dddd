-- gs_business (client) · V9 « La doublure » : PNJ à l'apparence du patron derrière le comptoir (créé à l'approche),
-- braquable arme en main (ox_target). L'apparence vient du serveur (GlobalState.gsDoubles).
local peds = {} -- [id] = ped

local function remove(id)
    local p = peds[id]
    if p and DoesEntityExist(p) then exports.ox_target:removeLocalEntity(p) DeleteEntity(p) end
    peds[id] = nil
end

local function applyLook(ped, skin)
    if GetResourceState('illenium-appearance') ~= 'started' or type(skin) ~= 'string' then return end
    local ok, look = pcall(json.decode, skin)
    if ok and type(look) == 'table' then pcall(function() exports['illenium-appearance']:setPedAppearance(ped, look) end) end
end

local function spawn(id, d)
    local b = Config.Businesses[id]
    local hash = GetHashKey(d.model or 'mp_m_freemode_01')
    if not IsModelInCdimage(hash) or not lib.requestModel(hash, 5000) then return end
    local c, r = b.craft, b.register
    local ped = CreatePed(4, hash, c.x, c.y, c.z - 1.0, GetHeadingFromVector_2d(r.x - c.x, r.y - c.y), false, false)
    SetModelAsNoLongerNeeded(hash)
    SetEntityInvincible(ped, true) FreezeEntityPosition(ped, true) SetBlockingOfNonTemporaryEvents(ped, true)
    applyLook(ped, d.skin)
    TaskStartScenarioInPlace(ped, 'WORLD_HUMAN_STAND_IMPATIENT', 0, true)
    exports.ox_target:addLocalEntity(ped, { {
        name = 'gs_business_rob_' .. id, icon = 'fas fa-gun', label = ('Braquer la doublure de %s'):format(d.name or '?'), distance = Config.Double.rob.range,
        canInteract = function() return GetSelectedPedWeapon(cache.ped) ~= GetHashKey('WEAPON_UNARMED') end,
        onSelect = function()
            ClearPedTasks(ped)
            lib.requestAnimDict('missminuteman_1ig_2')
            TaskPlayAnim(ped, 'missminuteman_1ig_2', 'handsup_base', 8.0, -8.0, -1, 49, 0, false, false, false)
            local done = lib.progressBar({ duration = Config.Double.rob.time, label = 'Vide la caisse !', canCancel = true,
                disable = { move = true, car = true } })
            local ok, msg = false, 'Braquage interrompu.'
            if done then ok, msg = lib.callback.await('gs_business:double', false, 'rob', id) end
            lib.notify({ description = msg, type = ok and 'success' or 'error' })
            if DoesEntityExist(ped) then ClearPedTasks(ped) TaskStartScenarioInPlace(ped, 'WORLD_HUMAN_STAND_IMPATIENT', 0, true) end
        end,
    } })
    peds[id] = ped
end

CreateThread(function()
    while true do
        local me = GetEntityCoords(cache.ped)
        local list = GlobalState.gsDoubles or {}
        for id in pairs(peds) do if not list[id] then remove(id) end end
        for id, d in pairs(list) do
            local b = Config.Businesses[id]
            if b then
                local dist = #(me - b.craft)
                if dist < 50.0 and not peds[id] then spawn(id, d)
                elseif dist > 70.0 and peds[id] then remove(id) end
            end
        end
        Wait(2000)
    end
end)

AddEventHandler('onResourceStop', function(res)
    if res == GetCurrentResourceName() then for id in pairs(peds) do remove(id) end end
end)
