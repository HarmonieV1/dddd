-- gs_harvest (serveur) : récolte en 2 temps (début / fin, durée réelle), outil requis, tirage du butin ici,
-- chasse sur des animaux créés par le serveur (seuls eux se dépècent), revente aux acheteurs.
local Security = exports.gs_security
local Bridge   = exports.gs_bridge

Harvest = { pending = {}, animals = {}, nodes = {} } -- nodes[src][id][i] = { n = récoltes, til = épuisé jusqu'à (os.time) }

--- Le joueur est-il au nœud `c` ? Distance à plat (la hauteur des points est approximative, le client la recale
--- au sol) + écart vertical raisonnable.
local function atNode(src, c, radius)
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 then return false end
    local p = GetEntityCoords(ped)
    local dx, dy = p.x - c.x, p.y - c.y
    return math.sqrt(dx * dx + dy * dy) <= radius + Config.Tolerance and math.abs(p.z - c.z) <= 12.0
end

local function nodeState(src, id, i)
    Harvest.nodes[src] = Harvest.nodes[src] or {}
    Harvest.nodes[src][id] = Harvest.nodes[src][id] or {}
    local n = Harvest.nodes[src][id][i]
    if not n or (n.til and os.time() >= n.til) then n = { n = 0 } Harvest.nodes[src][id][i] = n end
    return n
end

--- Nœuds épuisés de ce joueur pour une activité : { [i] = secondes restantes }
function Harvest.depleted(src, id)
    local out = {}
    for i, n in pairs((Harvest.nodes[src] or {})[id] or {}) do
        if n.til and n.til > os.time() then out[i] = n.til - os.time() end
    end
    return out
end

--- Tirage pondéré dans une table { { item, poids, { min, max } } } → item, quantité
function Harvest.roll(loot)
    local total = 0
    for _, l in ipairs(loot) do total = total + l[2] end
    local r = math.random() * total
    for _, l in ipairs(loot) do
        r = r - l[2]
        if r < 0 then return l[1], math.random(l[3][1], l[3][2]) end
    end
    local l = loot[#loot]
    return l[1], l[3][1]
end

local function maybeBreak(src, tool)
    if tool and math.random() < Config.BreakChance and Bridge:RemoveItem(src, tool, 1) then return ' (ton outil a cassé)' end
    return ''
end

local function label(item) return Config.ItemLabels[item] or item end

lib.callback.register('gs_harvest:begin', function(src, id, node)
    if not Security:RateLimit(src, 'gs_harvest:begin', 6, 10000) then return false, 'Doucement.' end
    local a = Config.Activities[id]
    if not a then return false, 'Indisponible.' end
    if Harvest.pending[src] then return false, 'Déjà occupé.' end
    node = tonumber(node)
    local c = node and a.spots[node]
    if not c or not atNode(src, c, Config.SpotRadius) then return false, 'Trop loin.' end
    if nodeState(src, id, node).til then return false, 'Épuisé ici : va un peu plus loin.' end
    if a.tool and Bridge:GetItemCount(src, a.tool) < 1 then return false, ('Il te faut %s (quincaillerie).'):format(a.toolLabel or a.tool) end
    local ms = math.random(a.duration[1], a.duration[2])
    Harvest.pending[src] = { id = id, spot = node, doneAt = GetGameTimer() + ms - 750 }
    return true, ms
end)

lib.callback.register('gs_harvest:finish', function(src)
    if not Security:RateLimit(src, 'gs_harvest:finish', 6, 10000) then return false, 'Doucement.' end
    local p = Harvest.pending[src]
    Harvest.pending[src] = nil
    if not p or GetGameTimer() < p.doneAt then return false, 'Interrompu.' end
    local a = Config.Activities[p.id]
    if not atNode(src, a.spots[p.spot], Config.SpotRadius) then return false, 'Tu t\'es éloigné.' end
    if a.tool and Bridge:GetItemCount(src, a.tool) < 1 then return false, 'Tu n\'as plus ton outil.' end
    local item, n = Harvest.roll(a.loot)
    if not Bridge:CanCarry(src, item, n) or not Bridge:AddItem(src, item, n) then return false, 'Tu ne peux plus rien porter.' end
    if GetResourceState('gs_quests') == 'started' then exports.gs_quests:Track(src, 'harvest') end
    local st = nodeState(src, p.id, p.spot)
    st.n = st.n + 1
    local depleted = st.n >= (a.perNode or 3)
    if depleted then st.til = os.time() + Config.Regrow end
    local msg = ('+%d %s%s%s'):format(n, label(item), maybeBreak(src, a.tool),
        depleted and ' · épuisé ici, passe au suivant' or '')
    return true, msg, { node = p.spot, depleted = depleted, sell = a.sell }
end)

RegisterNetEvent('gs_harvest:server:cancel', function()
    if Security:RateLimit(source, 'gs_harvest:cancel', 5, 10000) then Harvest.pending[source] = nil end
end)

-- Chasse --------------------------------------------------------------------------------------------------

lib.callback.register('gs_harvest:skin', function(src, netId)
    if not Security:RateLimit(src, 'gs_harvest:skin', 3, 10000) then return false, 'Doucement.' end
    local H = Config.Hunting
    local ent = NetworkGetEntityFromNetworkId(tonumber(netId) or 0)
    local model = ent and Harvest.animals[ent]
    if not model or not DoesEntityExist(ent) then return false, 'Rien à dépecer.' end
    if GetEntityHealth(ent) > 0 then return false, 'Il est encore vivant !' end
    if not Security:EntityInRange(src, ent, 3.0 + Config.Tolerance) then return false, 'Trop loin.' end
    if Bridge:GetItemCount(src, H.tool) < 1 then return false, 'Il te faut un couteau de chasse (quincaillerie).' end
    local gained = {}
    for _, l in ipairs(H.animals[model]) do
        local n = math.random(l[3][1], l[3][2])
        if Bridge:CanCarry(src, l[1], n) and Bridge:AddItem(src, l[1], n) then gained[#gained + 1] = ('%d %s'):format(n, l[1]) end
    end
    if #gained == 0 then return false, 'Tu ne peux plus rien porter.' end
    Harvest.animals[ent] = nil
    DeleteEntity(ent)
    if not (Bridge:GetLicences(src) or {})[H.licence] and GetResourceState('gs_wanted') == 'started' then
        exports.gs_wanted:ReportCrime(src, 'poaching', GetEntityCoords(GetPlayerPed(src)))
        return true, '+' .. table.concat(gained, ', ') .. ' · sans permis : braconnage, la police peut être prévenue.'
    end
    if GetResourceState('gs_quests') == 'started' then exports.gs_quests:Track(src, 'harvest') end
    return true, '+' .. table.concat(gained, ', ')
end)

--- Crée un animal (OneSync) à un point de la zone. Isolé pour les tests.
function Harvest.spawnAnimal(model, c)
    local ent = CreatePed(28, GetHashKey(model), c.x, c.y, c.z, math.random(0, 359) + 0.0, true, true)
    if ent and ent ~= 0 then Harvest.animals[ent] = model end
    return ent
end

local function playersNear(center, radius)
    for _, s in ipairs(GetPlayers()) do
        local ped = GetPlayerPed(tonumber(s))
        if ped ~= 0 and #(GetEntityCoords(ped) - center) < radius then return true end
    end
    return false
end

--- Garde la zone peuplée (seulement si un joueur est dans le coin) et oublie les animaux disparus.
function Harvest.huntTick()
    local H = Config.Hunting
    local alive = 0
    for ent in pairs(Harvest.animals) do
        if DoesEntityExist(ent) then alive = alive + 1 else Harvest.animals[ent] = nil end
    end
    if alive >= H.max or not playersNear(H.center, H.playerRadius) then return end
    local models = {}
    for m in pairs(H.animals) do models[#models + 1] = m end
    table.sort(models)
    Harvest.spawnAnimal(models[math.random(#models)], H.spawns[math.random(#H.spawns)])
end

CreateThread(function()
    while true do
        Wait(Config.Hunting.respawnSeconds * 1000)
        Harvest.huntTick()
    end
end)

lib.callback.register('gs_harvest:buyLicence', function(src)
    if not Security:RateLimit(src, 'gs_harvest:buyLicence', 2, 10000) then return false, 'Doucement.' end
    local H = Config.Hunting
    if not atNode(src, H.lodge, 4.0) then return false, 'Trop loin.' end
    if (Bridge:GetLicences(src) or {})[H.licence] then return false, 'Tu as déjà ton permis de chasse.' end
    if not Bridge:RemoveMoney(src, 'cash', H.licencePrice, 'permis de chasse')
        and not Bridge:RemoveMoney(src, 'bank', H.licencePrice, 'permis de chasse') then
        return false, ('Il te faut %d $.'):format(H.licencePrice)
    end
    Bridge:SetLicence(src, H.licence, true)
    return true, 'Permis de chasse obtenu. Le fusil se vend à l\'armurerie du pavillon.'
end)

-- Revente -------------------------------------------------------------------------------------------------

lib.callback.register('gs_harvest:sell', function(src, index)
    if not Security:RateLimit(src, 'gs_harvest:sell', 2, 5000) then return false, 'Doucement.' end
    local b = Config.Buyers[tonumber(index) or 0]
    if not b then return false, 'Acheteur inconnu.' end
    if not atNode(src, b.coords, 3.0) then return false, 'Trop loin.' end
    local total, sold = 0, 0
    for item, range in pairs(b.items) do
        local n = Bridge:GetItemCount(src, item)
        if n > 0 and Bridge:RemoveItem(src, item, n) then -- (prix par article)
            total = total + n * math.random(range[1], range[2])
            sold = sold + n
        end
    end
    if sold == 0 then return false, 'Tu n\'as rien qui l\'intéresse.' end
    Bridge:AddMoney(src, 'cash', total, 'revente ' .. b.label)
    if GetResourceState('gs_quests') == 'started' then exports.gs_quests:Track(src, 'sell') end
    return true, ('%d article(s) vendu(s) : %d $.'):format(sold, total)
end)

AddEventHandler('gs_bridge:server:playerUnloaded', function(src) Harvest.pending[src] = nil Harvest.nodes[src] = nil end)

lib.callback.register('gs_harvest:depleted', function(src, id)
    if not Security:RateLimit(src, 'gs_harvest:depleted', 10, 10000) or not Config.Activities[id] then return {} end
    return Harvest.depleted(src, id)
end)
AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    for ent in pairs(Harvest.animals) do if DoesEntityExist(ent) then DeleteEntity(ent) end end
end)
