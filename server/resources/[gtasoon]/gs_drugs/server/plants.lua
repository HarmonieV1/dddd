-- gs_drugs (serveur) : plantations libres. Tout est décidé ici : emplacement (distance, espacement, limite),
-- croissance à la minute, arrosage / engrais, récolte (n'importe qui, plant mûr), destruction (propriétaire / police).
-- Les clients ne reçoivent que { x, y, z, stade } via GlobalState.gsPlants pour afficher les props.
local Security = exports.gs_security
local Bridge   = exports.gs_bridge
local JobsApi  = exports.gs_jobs
local P = Config.Plants

Plants = { list = {}, dirty = false }

local function stageOf(growth) return growth >= 100 and 3 or growth >= 50 and 2 or 1 end

function Plants.publish()
    local out = {}
    for id, p in pairs(Plants.list) do
        out[tostring(id)] = { x = p.x, y = p.y, z = p.z, s = stageOf(p.growth), r = p.growth >= 100 }
    end
    GlobalState.gsPlants = out
end

local function countOf(cid)
    local n = 0
    for _, p in pairs(Plants.list) do if p.owner == cid then n = n + 1 end end
    return n
end

local function near(src, p) return Security:InRange(src, vec3(p.x, p.y, p.z), P.reach + Config.Tolerance) end

local function get(src, id)
    local p = Plants.list[tonumber(id) or -1]
    if not p then return nil, 'Plus de plant ici.' end
    if not near(src, p) then return nil, 'Trop loin.' end
    return p
end

local function remove(p)
    Plants.list[p.id] = nil
    PlantStore.delete(p.id)
    Plants.publish()
end

--- Planter en `coords` (point au sol visé par le client, revérifié : distance au joueur, espacement, limite).
lib.callback.register('gs_drugs:plant', function(src, coords)
    if not Security:RateLimit(src, 'gs_drugs:plant', 3, 10000) then return false, 'Doucement.' end
    local cid = Bridge:GetIdentifier(src)
    if not cid or type(coords) ~= 'table' or type(coords.x) ~= 'number' or type(coords.y) ~= 'number' or type(coords.z) ~= 'number' then
        return false, 'Emplacement invalide.'
    end
    local c = vec3(coords.x, coords.y, coords.z)
    if not Security:InRange(src, c, 3.0) then return false, 'Plante juste devant toi.' end
    if c.z < -20.0 then return false, 'Pas en intérieur.' end -- intérieurs du jeu = sous la map
    for _, p in pairs(Plants.list) do
        if #(vec3(p.x, p.y, p.z) - c) < P.minSpacing then return false, 'Trop près d\'un autre plant.' end
    end
    if countOf(cid) >= P.maxPerPlayer then return false, ('Maximum %d plants par personne.'):format(P.maxPerPlayer) end
    if Bridge:GetItemCount(src, P.pot) < 1 then return false, 'Il te faut un pot de fleurs (quincaillerie).' end
    if not Bridge:RemoveItem(src, P.seed, 1) then return false, 'Il te faut une graine.' end
    if not Bridge:RemoveItem(src, P.pot, 1) then Bridge:AddItem(src, P.seed, 1) return false, 'Il te faut un pot de fleurs.' end
    local id = PlantStore.insert(cid, c)
    if not id then Bridge:AddItem(src, P.seed, 1) Bridge:AddItem(src, P.pot, 1) return false, 'Erreur, matériel rendu.' end
    Plants.list[id] = { id = id, owner = cid, x = c.x, y = c.y, z = c.z, growth = 0.0, water = 0.0, health = 100.0, fert = false }
    Plants.publish()
    return true, 'Graine plantée. Pense à l\'arroser (bouteille d\'eau).'
end)

--- Infos affichées dans le menu du plant.
lib.callback.register('gs_drugs:plantInfo', function(src, id)
    if not Security:RateLimit(src, 'gs_drugs:plantInfo', 10, 10000) then return nil end
    local p = get(src, id)
    if not p then return nil end
    local cid = Bridge:GetIdentifier(src)
    return { growth = math.floor(p.growth), water = math.floor(p.water), health = math.floor(p.health), fert = p.fert,
        mine = p.owner == cid, police = JobsApi:IsOnDutyAs(src, Config.PoliceJob) }
end)

lib.callback.register('gs_drugs:plantAction', function(src, id, action)
    if not Security:RateLimit(src, 'gs_drugs:plantAction', 4, 10000) then return false, 'Doucement.' end
    local p, err = get(src, id)
    if not p then return false, err end
    local cid = Bridge:GetIdentifier(src)
    if action == 'water' then
        if p.water >= 80 then return false, 'La terre est encore humide.' end
        if not Bridge:RemoveItem(src, P.water, 1) then return false, 'Il te faut une bouteille d\'eau.' end
        p.water = 100.0
        PlantStore.update(p)
        return true, 'Plant arrosé.'
    elseif action == 'fertilize' then
        if p.fert then return false, 'Déjà de l\'engrais.' end
        if not Bridge:RemoveItem(src, P.fertilizer, 1) then return false, 'Il te faut de l\'engrais (quincaillerie).' end
        p.fert = true
        PlantStore.update(p)
        return true, 'Engrais ajouté : il poussera plus vite.'
    elseif action == 'harvest' then
        if p.growth < 100 then return false, 'Pas encore mûr.' end
        local n = math.random(P.harvest.amount[1], P.harvest.amount[2])
        if not Bridge:CanCarry(src, P.harvest.item, n) then return false, 'Tu ne peux plus rien porter.' end
        remove(p)
        Bridge:AddItem(src, P.harvest.item, n)
        local seeds = math.random(P.harvest.seeds[1], P.harvest.seeds[2])
        Bridge:AddItem(src, P.seed, seeds)
        if p.owner ~= cid and GetResourceState('gs_wanted') == 'started' then
            exports.gs_wanted:ReportCrime(src, 'drug_sale', vec3(p.x, p.y, p.z)) -- vol de récolte : ça se voit
        end
        return true, ('Récolte : %d feuilles, %d graine(s).'):format(n, seeds)
    elseif action == 'destroy' then
        local police = JobsApi:IsOnDutyAs(src, Config.PoliceJob)
        if p.owner ~= cid and not police then return false, 'Ce n\'est pas ton plant.' end
        remove(p)
        if police and p.owner ~= cid then
            Bridge:AddMoney(src, 'bank', P.policeReward, 'plant saisi')
            return true, ('Plant détruit et saisi (+%d $).'):format(P.policeReward)
        end
        return true, 'Plant arraché.'
    end
    return false, 'Action inconnue.'
end)

--- Une minute de croissance : eau → pousse (×engrais), sans eau → santé baisse jusqu'à la mort.
function Plants.tick()
    local changed = false
    for _, p in pairs(Plants.list) do
        local before = stageOf(p.growth)
        if p.water > 0 then
            if p.growth < 100 then p.growth = math.min(100.0, p.growth + 100.0 / P.growMinutes * (p.fert and P.fertilizerBoost or 1)) end
            p.water = math.max(0.0, p.water - 100.0 / P.waterMinutes)
        elseif p.growth < 100 then
            p.health = p.health - 100.0 / P.dryDeathMinutes
        end
        if p.health <= 0 then
            Plants.list[p.id] = nil
            PlantStore.delete(p.id)
            changed = true
        else
            PlantStore.update(p)
            if stageOf(p.growth) ~= before or p.growth >= 100 then changed = true end
        end
    end
    if changed then Plants.publish() end
end

function Plants.load()
    PlantStore.init()
    for _, r in ipairs(PlantStore.all()) do
        Plants.list[r.id] = { id = r.id, owner = r.owner, x = r.x, y = r.y, z = r.z, growth = r.growth, water = r.water,
            health = r.health, fert = r.fert == 1 or r.fert == true }
    end
    Plants.publish()
end

CreateThread(function()
    Plants.load()
    while true do
        Wait(60000)
        Plants.tick()
    end
end)

-- Vendeur de graines ---------------------------------------------------------------------------------------
lib.callback.register('gs_drugs:buySeeds', function(src, qty)
    if not Security:RateLimit(src, 'gs_drugs:buySeeds', 3, 10000) then return false, 'Doucement.' end
    qty = math.floor(tonumber(qty) or 0)
    if qty < 1 or qty > 10 then return false, 'Quantité invalide (1 à 10).' end
    local s = P.seedShop
    if not Security:InRange(src, vec3(s.coords.x, s.coords.y, s.coords.z), 3.0 + Config.Tolerance) then return false, 'Trop loin.' end
    if not Bridge:CanCarry(src, P.seed, qty) then return false, 'Tu ne peux plus rien porter.' end
    local total = s.price * qty
    if not Bridge:RemoveMoney(src, 'cash', total, 'graines') then return false, ('Il te faut %d $ en liquide.'):format(total) end
    Bridge:AddItem(src, P.seed, qty)
    return true, ('%d graine(s) achetée(s) : %d $.'):format(qty, total)
end)
