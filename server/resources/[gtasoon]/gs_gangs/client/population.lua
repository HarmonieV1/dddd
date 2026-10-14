-- gs_gangs (client) · V12.40 « rajouter une population (gang) sur les territoires conquis ou qui grossissent, pour la
-- cohérence RP (plus dangereux, affiliée au gang qui contrôle) ». PNJ LOCAUX (chacun les crée chez soi, rien sur le réseau),
-- à l'approche d'un quartier tenu : modèles du gang, armes à la ceinture, scénarios de rue. Nombre = base + perLevel × niveau.
-- Emplacements tirés d'une graine (quartier + gang + niveau) : chaque joueur les voit aux mêmes endroits.
-- Attitude : membres du gang = respect ; gang rival = méfiance, HAINE dès le niveau 2 (ils ouvrent le feu) ; police en
-- service = méfiance ; civils = neutres (ils répondent si on les provoque). Boucle lente unique (2 s), jamais par image.
local P = Config.Population
local Bridge = exports.gs_bridge
local spawned = {}  -- [territoire] = { key, peds = { ped } }
local groups = {}

local function rng(seed)
    local s = seed % 2147483647
    return function(n) s = (s * 48271) % 2147483647 return (s % n) + 1 end
end

local function hash(str) local h = 7 for i = 1, #str do h = (h * 31 + str:byte(i)) % 2147483647 end return h end

local function group(gang)
    if not groups[gang] then local _, g = AddRelationshipGroup('GSGANG_' .. gang:upper()) groups[gang] = g end
    return groups[gang]
end

local function relations(gang, level)
    local g, player = group(gang), GetHashKey('PLAYER')
    local mine, job = GSGangMine and GSGangMine(), Bridge:GetJob()
    local rel = 3 -- neutre
    if mine == gang then rel = 1
    elseif mine then rel = level >= 2 and 5 or 4
    elseif job and job.onduty and (job.name == 'police' or job.name == 'sheriff') then rel = 4 end
    SetRelationshipBetweenGroups(rel, g, player)
    SetRelationshipBetweenGroups(1, g, g)
end

local function clear(id)
    local s = spawned[id]
    if not s then return end
    for _, ped in ipairs(s.peds) do if DoesEntityExist(ped) then DeleteEntity(ped) end end
    spawned[id] = nil
end

local function populate(id, t, st)
    local key = ('%s:%s:%d'):format(id, st.ownerId, st.level or 0)
    if spawned[id] and spawned[id].key == key then return end
    clear(id)
    local models = P.models[st.ownerId] or P.models.default
    local count = math.min(P.max, P.base + P.perLevel * (st.level or 0))
    local r = rng(hash(key))
    local peds = {}
    local radius = (st.radius or t.radius) * 0.6
    for _ = 1, count do
        local angle, dist = r(360) * math.pi / 180, radius * r(100) / 100
        local x, y = t.center.x + math.cos(angle) * dist, t.center.y + math.sin(angle) * dist
        local ok, spot = GetSafeCoordForPed(x, y, t.center.z, false, 16)
        local model = GetHashKey(models[r(#models)])
        if ok and pcall(lib.requestModel, model, 4000) then
            local ped = CreatePed(4, model, spot.x, spot.y, spot.z, r(360) + 0.0, false, true)
            SetModelAsNoLongerNeeded(model)
            if ped and ped ~= 0 then
                SetEntityAsMissionEntity(ped, true, true)
                SetPedRelationshipGroupHash(ped, group(st.ownerId))
                GiveWeaponToPed(ped, GetHashKey(P.weapons[r(#P.weapons)]), 60, false, false)
                SetCurrentPedWeapon(ped, GetHashKey('WEAPON_UNARMED'), true)
                SetPedCombatAttributes(ped, 46, true) SetPedCombatAttributes(ped, 5, true)
                SetPedFleeAttributes(ped, 0, false)
                SetPedDropsWeaponsWhenDead(ped, false)
                SetPedArmour(ped, 25 * (st.level or 0))
                TaskStartScenarioInPlace(ped, P.scenarios[r(#P.scenarios)], 0, true)
                peds[#peds + 1] = ped
            end
        end
    end
    spawned[id] = { key = key, peds = peds }
end

CreateThread(function()
    Wait(5000)
    while true do
        local state = GlobalState.gsTerritories or {}
        local me = GetEntityCoords(cache.ped)
        for id, t in pairs(Config.Territories) do
            local st = state[id]
            local d = #(me - t.center) - ((st and st.radius) or t.radius)
            if st and st.ownerId and d < P.spawnRange then
                relations(st.ownerId, st.level or 0)
                populate(id, t, st)
            elseif spawned[id] and (not st or not st.ownerId or d > P.despawnRange) then
                clear(id)
            end
        end
        Wait(2000)
    end
end)

AddEventHandler('onResourceStop', function(res)
    if res == GetCurrentResourceName() then for id in pairs(spawned) do clear(id) end end
end)
