-- gs_city (client) · V10 « Le quartier évolue » : dans un quartier en déclin, des tas de déchets apparaissent sur les
-- trottoirs autour du joueur (objets locaux, rien de réseau) ; [ox_target] Ramasser = payé par la mairie, le quartier remonte.
local S = Config.Standing
local piles = {} -- { entity, coords }

local function districtAt(coords)
    local p, best, bestD = vec2(coords.x, coords.y), nil, nil
    for _, d in ipairs(Config.Districts) do
        local dist = #(p - d.center)
        if dist <= d.radius and (not bestD or dist < bestD) then best, bestD = d, dist end
    end
    return best
end

local function remove(i)
    local p = piles[i]
    if p and DoesEntityExist(p.entity) then exports.ox_target:removeLocalEntity(p.entity) DeleteEntity(p.entity) end
    table.remove(piles, i)
end

local function spawnNear(me)
    local a, r = math.random() * math.pi * 2, math.random(25, 60)
    local x, y = me.x + math.cos(a) * r, me.y + math.sin(a) * r
    local ok, c = GetSafeCoordForPed(x, y, me.z, true, 16)
    if not ok or #(c - me) < 15.0 then return end
    local model = GetHashKey(S.trashProps[math.random(1, #S.trashProps)])
    if not IsModelInCdimage(model) or not lib.requestModel(model, 3000) then return end
    local e = CreateObject(model, c.x, c.y, c.z, false, false, false)
    SetModelAsNoLongerNeeded(model)
    PlaceObjectOnGroundProperly(e) FreezeEntityPosition(e, true)
    local pile = { entity = e, coords = GetEntityCoords(e) }
    exports.ox_target:addLocalEntity(e, { {
        name = 'gs_city_clean', icon = 'fas fa-broom', label = 'Ramasser les déchets (mairie)', distance = 2.5,
        onSelect = function()
            if not lib.progressBar({ duration = 4000, label = 'Ramassage…', canCancel = true, anim = { dict = 'pickup_object', clip = 'pickup_low' },
                disable = { move = true, car = true, combat = true } }) then return end
            local ok2, msg = lib.callback.await('gs_city:clean', false, pile.coords.x, pile.coords.y, pile.coords.z)
            lib.notify({ description = msg, type = ok2 and 'success' or 'error' })
            if ok2 then for i, p in ipairs(piles) do if p == pile then remove(i) break end end end
        end,
    } })
    piles[#piles + 1] = pile
end

CreateThread(function()
    while true do
        local me = GetEntityCoords(cache.ped)
        local d = districtAt(me)
        local lvl = d and (GlobalState.gsStanding or {})[d.id] or 3
        local want = (not cache.vehicle or GetEntitySpeed(cache.vehicle) < 15.0) and (S.levels[lvl] and S.levels[lvl].trash or 0) or 0
        for i = #piles, 1, -1 do
            if #(piles[i].coords - me) > 120.0 or want == 0 then remove(i) end
        end
        if #piles < want then spawnNear(me) end
        Wait(4000)
    end
end)

AddEventHandler('onResourceStop', function(res)
    if res == GetCurrentResourceName() then for i = #piles, 1, -1 do remove(i) end end
end)
