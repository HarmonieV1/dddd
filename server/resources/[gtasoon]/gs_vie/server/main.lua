-- gs_vie (serveur) · V12.57 Vie quotidienne : poubelles (butin et délais côté serveur), passagers bavards (vraies
-- rumeurs de gs_rumors), démarche blessée soignée par un bandage / des antidouleurs (crochet ox_inventory).
local Security, Bridge = exports.gs_security, exports.gs_bridge
Vie = { bins = {}, searches = {} } -- bins[clé] = heure de la dernière fouille ; searches[src] = { heures des fouilles }

local function now() return os.time() end

--- Clé d'une benne : position arrondie au mètre (les bennes de la ville ne bougent pas)
function Vie.binKey(c) return ('%d:%d:%d'):format(math.floor(c.x + 0.5), math.floor(c.y + 0.5), math.floor(c.z + 0.5)) end

--- Tirage pondéré dans Config.Dumpster.loot (rnd injectable pour les tests)
function Vie.roll(rnd)
    rnd = rnd or math.random
    local total = 0
    for _, l in ipairs(Config.Dumpster.loot) do total = total + l.weight end
    local r, acc = rnd(1, total), 0
    for _, l in ipairs(Config.Dumpster.loot) do
        acc = acc + l.weight
        if r <= acc then
            if not l.item then return nil end
            return l.item, rnd(l.min or 1, l.max or 1)
        end
    end
end

function Vie.search(src, c)
    local D = Config.Dumpster
    if type(c) ~= 'table' and type(c) ~= 'vector3' then return false, 'Rien à fouiller ici.' end
    if not (tonumber(c.x) and tonumber(c.y) and tonumber(c.z)) then return false, 'Rien à fouiller ici.' end
    c = vec3(c.x + 0.0, c.y + 0.0, c.z + 0.0)
    if not Security:InRange(src, c, D.range + 1.0) then return false, 'Trop loin de la benne.' end
    local t = now()
    local mine = Vie.searches[src] or {}
    local recent = {}
    for _, at in ipairs(mine) do if t - at < 3600 then recent[#recent + 1] = at end end
    Vie.searches[src] = recent
    if recent[#recent] and t - recent[#recent] < D.playerCooldown then return false, 'Tu viens déjà de fouiller. Souffle un peu.' end
    if #recent >= D.perHour then return false, 'Tu as assez fouillé les poubelles pour cette heure.' end
    local key = Vie.binKey(c)
    if Vie.bins[key] and t - Vie.bins[key] < D.cooldown * 60 then return false, 'Quelqu\'un est déjà passé par là : elle est vide.' end
    Vie.bins[key] = t
    recent[#recent + 1] = t
    local item, n = Vie.roll()
    if not item then return true, 'Rien d\'intéressant, juste des ordures.' end
    if not Bridge:AddItem(src, item, n) then return true, 'Tu trouves quelque chose, mais tes poches sont pleines.' end
    return true, 'Trouvé dans la benne !', item, n
end

lib.callback.register('gs_vie:dumpster', function(src, c)
    if not Security:RateLimit(src, 'gs_vie:dumpster', 3, 10000) then return false, 'Doucement.' end
    return Vie.search(src, c)
end)

-- 120 · Passagers bavards ------------------------------------------------------------------------------------------
function Vie.rumor()
    if GetResourceState('gs_rumors') == 'started' then
        local ok, r = pcall(function() return exports.gs_rumors:Random() end)
        if ok and type(r) == 'string' and math.random() < 0.7 then return r end
    end
    local f = Config.Passengers.fallback
    return f[math.random(1, #f)]
end

lib.callback.register('gs_vie:rumor', function(src)
    if not Security:RateLimit(src, 'gs_vie:rumor', 1, 30000) then return nil end
    return Vie.rumor()
end)

-- 118 · Un soin (bandage, antidouleurs, trousse) enlève la démarche blessée ------------------------------------------
CreateThread(function()
    if GetResourceState('ox_inventory') ~= 'started' then return end
    pcall(function()
        exports.ox_inventory:registerHook('usingItem', function(payload) -- [API] ox_inventory hooks
            TriggerClientEvent('gs_vie:client:cured', payload.source)
        end, { itemFilter = Config.Injured.cures })
    end)
end)

AddEventHandler('playerDropped', function() Vie.searches[source] = nil end)
