-- gs_gangs (serveur) · V12.63 « Trêve entre gangs » (proposition n° 152). Proposée et acceptée par des cadres ; rompue par
-- une mise à terre (même détection serveur que les guerres : coup porté + état « à terre », jamais un message du client).
local Security = exports.gs_security
local Bridge   = exports.gs_bridge
local T = Config.Truce

Truce = { list = {}, offers = {} } -- list['a|b'] = { a, b, untilAt } (a < b) ; offers[gang visé] = { from, expires }

local function key(a, b) if a > b then a, b = b, a end return a .. '|' .. b end
local function label(g) return Gangs.list[g] and Gangs.list[g].label or g end
local function save() SetResourceKvp('gs_truces', json.encode(Truce.list)) end
local function notifyGang(g, msg, kind)
    for src, m in pairs(Gangs.online) do if m.gang == g then Bridge:Notify(src, msg, kind or 'inform') end end
end
local function cadre(src)
    local m = Gangs.online[src]
    if not m or not m.gang or not Config.Grades[m.grade] or not Config.Grades[m.grade].manage then return nil end
    return m.gang
end

--- Trêve active entre deux gangs ?
function Truce.active(a, b)
    if not a or not b or a == b then return false end
    local t = Truce.list[key(a, b)]
    if t and t.untilAt <= os.time() then Truce.list[key(a, b)] = nil save() return false end
    return t ~= nil
end

function Truce.offer(src, target)
    local g = cadre(src)
    if not g then return false, 'Réservé aux cadres du gang.' end
    if type(target) ~= 'string' or not Gangs.list[target] or target == g then return false, 'Gang inconnu.' end
    if Truce.active(g, target) then return false, 'Vous êtes déjà en trêve.' end
    for _, w in pairs(Wars.list or {}) do
        if (w.attacker == g and w.defender == target) or (w.attacker == target and w.defender == g) then return false, 'Une guerre est en cours entre vous : finissez-la d\'abord.' end
    end
    Truce.offers[target] = { from = g, expires = os.time() + T.offerMinutes * 60 }
    notifyGang(target, ('%s propose une trêve de %d h (menu Gang → Trêves pour l\'accepter, %d min).'):format(label(g), T.hours, T.offerMinutes), 'warning')
    return true, ('Proposition envoyée à %s.'):format(label(target))
end

function Truce.accept(src, from)
    local g = cadre(src)
    if not g then return false, 'Réservé aux cadres du gang.' end
    local o = Truce.offers[g]
    if not o or o.from ~= from or o.expires < os.time() then return false, 'Aucune proposition de trêve en cours de ce gang.' end
    Truce.offers[g] = nil
    local a, b = g, from
    if a > b then a, b = b, a end
    Truce.list[key(a, b)] = { a = a, b = b, untilAt = os.time() + T.hours * 3600 }
    save()
    local msg = ('TRÊVE : %s et %s ont signé une trêve de %d h.'):format(label(g), label(from), T.hours)
    notifyGang(g, msg, 'success') notifyGang(from, msg, 'success')
    Security:LogStaff('[Gang] ' .. msg, 'jobs')
    return true, msg
end

--- Mise à terre : si l'agresseur et la victime sont de deux gangs en trêve, la trêve est rompue (le gang de l'agresseur paie)
function Truce.onDowned(victim)
    local hit = Wars.lastHit and Wars.lastHit[victim]
    if not hit or os.time() - hit.at > Config.Wars.hitWindow then return false end
    local vm, am = Gangs.online[victim], Gangs.online[hit.attacker]
    if not vm or not am or not vm.gang or not am.gang or vm.gang == am.gang then return false end
    if not Truce.active(vm.gang, am.gang) then return false end
    Truce.list[key(vm.gang, am.gang)] = nil
    save()
    local lost = 0
    for id, t in pairs(Gangs.territories) do
        if (t.influence[am.gang] or 0) > 0 then Gangs.addInfluence(am.gang, id, -T.penalty) lost = lost + 1 end
    end
    local msg = ('TRÊVE ROMPUE : %s a trahi %s. Leur réputation s\'effondre dans toute la ville.'):format(label(am.gang), label(vm.gang))
    notifyGang(am.gang, msg, 'error') notifyGang(vm.gang, msg, 'warning')
    Security:LogStaff(('[Gang] %s (%s [%d] a mis à terre %s [%d], %d quartier(s) touchés)'):format(msg, GetPlayerName(hit.attacker) or '?', hit.attacker, GetPlayerName(victim) or '?', victim, lost), 'jobs')
    if GetResourceState('gs_social') == 'started' then
        pcall(function() exports.gs_social:Newsroom('flash', ('Trêve rompue entre gangs : %s a trahi %s.'):format(label(am.gang), label(vm.gang))) end)
    end
    return true
end

AddStateBagChangeHandler('qbx_medical:deathState', nil, function(bagName, _, value)
    local src = GetPlayerFromStateBagName(bagName)
    if src and src > 0 and (tonumber(value) or 0) >= 2 then Truce.onDowned(src) end
end)

lib.callback.register('gs_gangs:truce', function(src, action, gang)
    if not Security:RateLimit(src, 'gs_gangs:truce', 4, 10000) then return false, 'Doucement.' end
    local m = Gangs.online[src]
    if not m or not m.gang then return false, 'Tu n\'es dans aucun gang.' end
    if action == 'offer' then return Truce.offer(src, gang) end
    if action == 'accept' then return Truce.accept(src, gang) end
    local out = { truces = {}, gangs = {}, offer = nil, canManage = cadre(src) ~= nil }
    for _, t in pairs(Truce.list) do
        if t.untilAt > os.time() and (t.a == m.gang or t.b == m.gang) then
            local other = t.a == m.gang and t.b or t.a
            out.truces[#out.truces + 1] = { gang = other, label = label(other), hours = math.ceil((t.untilAt - os.time()) / 3600) }
        end
    end
    for name, g in pairs(Gangs.list) do if name ~= m.gang then out.gangs[#out.gangs + 1] = { gang = name, label = g.label, truce = Truce.active(m.gang, name) } end end
    table.sort(out.gangs, function(a, b) return a.label < b.label end)
    local o = Truce.offers[m.gang]
    if o and o.expires > os.time() then out.offer = { gang = o.from, label = label(o.from), minutes = math.ceil((o.expires - os.time()) / 60) } end
    return true, out
end)

CreateThread(function()
    local ok, l = pcall(json.decode, GetResourceKvpString('gs_truces') or '{}')
    if ok and type(l) == 'table' then Truce.list = l end
end)
