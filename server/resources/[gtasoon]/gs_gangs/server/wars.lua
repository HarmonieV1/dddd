-- gs_gangs (serveur) : guerres de territoire déclarées. Les points viennent d'événements SERVEUR (coup d'arme porté par un
-- joueur + état « à terre » de la victime relevé par le serveur), jamais d'un message du client.
local Security = exports.gs_security
local Bridge   = exports.gs_bridge
local W = Config.Wars

Wars = { list = {}, cool = {}, lastHit = {}, victimAt = {}, nextId = 0 } -- list[territoire] = guerre

local function notifyGangs(a, b, msg, t)
    for src, m in pairs(Gangs.online) do
        if m.gang == a or m.gang == b then Bridge:Notify(src, msg, t or 'inform') end
    end
end

local function label(g) return Gangs.list[g] and Gangs.list[g].label or g end

local function publishWars()
    local out, now = {}, os.time()
    for id, w in pairs(Wars.list) do
        out[id] = { attacker = label(w.attacker), defender = label(w.defender), started = now >= w.startsAt, startsAt = w.startsAt,
            endsAt = w.endsAt, a = w.score[w.attacker] or 0, d = w.score[w.defender] or 0 }
    end
    GlobalState.gsWars = out
end

local function busy(gang)
    for _, w in pairs(Wars.list) do if w.attacker == gang or w.defender == gang then return true end end
end

local function onlineCount(gang)
    local n = 0
    for _, m in pairs(Gangs.online) do if m.gang == gang then n = n + 1 end end
    return n
end

--- Déclarer la guerre pour un quartier tenu par un autre gang → true | false, message
function Wars.declare(src, id)
    local m = Gangs.online[src]
    if not m or not m.gang or not Config.Grades[m.grade].manage then return false, 'Réservé aux cadres du gang.' end
    local t = Gangs.territories[id]
    if not t or not Config.Territories[id] then return false, 'Quartier inconnu.' end
    if not t.owner or t.owner == m.gang then return false, 'Il faut viser un quartier tenu par un autre gang.' end
    if Wars.list[id] or busy(m.gang) or busy(t.owner) then return false, 'Une guerre est déjà en cours ou annoncée pour l\'un des gangs.' end
    local left = (Wars.cool[m.gang] or 0) - os.time()
    if left > 0 then return false, ('Ton gang doit se reposer encore %d min.'):format(math.ceil(left / 60)) end
    if (Wars.cool[t.owner] or 0) > os.time() then return false, 'Ce gang vient de se battre, il est protégé quelques temps.' end
    if onlineCount(m.gang) < W.minAttackers then return false, ('Il faut au moins %d des tiens en ligne.'):format(W.minAttackers) end
    if onlineCount(t.owner) < W.minDefenders then return false, 'Personne en face : on ne déclare pas la guerre à des fantômes.' end
    if not Store.removeMoney(m.gang, W.cost) then return false, ('La caisse doit contenir %d $ (frais de guerre).'):format(W.cost) end
    local now = os.time()
    Wars.list[id] = { territory = id, attacker = m.gang, defender = t.owner, startsAt = now + W.notice, endsAt = now + W.notice + W.duration,
        score = {}, announced = false }
    Wars.cool[m.gang] = now + W.cooldown
    local msg = ('GUERRE : %s déclare la guerre à %s pour %s. Début dans %d min.'):format(label(m.gang), label(t.owner), Config.Territories[id].label, W.notice // 60)
    notifyGangs(m.gang, t.owner, msg, 'warning')
    for _, cop in ipairs(exports.gs_jobs:GetOnDutyPlayers(Config.PoliceJob)) do Bridge:Notify(cop, 'Tension : ' .. msg, 'warning') end
    Security:LogStaff('[Gang] ' .. msg, 'jobs')
    publishWars()
    return true, msg
end

--- Points : un membre du camp adverse dans le quartier de la guerre tombe peu après un coup d'un membre de l'autre camp.
function Wars.onDowned(victim)
    local hit = Wars.lastHit[victim]
    if not hit or os.time() - hit.at > W.hitWindow then return end
    local vm, am = Gangs.online[victim], Gangs.online[hit.attacker]
    if not vm or not am or not vm.gang or not am.gang or vm.gang == am.gang then return end
    if (Wars.victimAt[victim] or 0) > os.time() then return end
    local ped = GetPlayerPed(victim)
    local zone = ped ~= 0 and Gangs.territoryAt(GetEntityCoords(ped))
    local w = zone and Wars.list[zone]
    if not w or os.time() < w.startsAt or os.time() >= w.endsAt then return end
    local sides = { [w.attacker] = true, [w.defender] = true }
    if not sides[vm.gang] or not sides[am.gang] then return end
    Wars.victimAt[victim] = os.time() + W.victimCooldown
    w.score[am.gang] = (w.score[am.gang] or 0) + W.killPoints
    publishWars()
end

function Wars.finish(id, w)
    Wars.list[id] = nil
    local a, d = w.score[w.attacker] or 0, w.score[w.defender] or 0
    local attackerWins = a >= d + W.winMargin
    Gangs.awardTerritory(id, attackerWins and w.attacker or w.defender)
    Wars.cool[w.defender] = os.time() + W.defenderCooldown
    local msg = ('FIN DE GUERRE pour %s : %s %d – %d %s. %s tient le quartier.'):format(Config.Territories[id].label, label(w.attacker), a, d,
        label(w.defender), label(attackerWins and w.attacker or w.defender))
    notifyGangs(w.attacker, w.defender, msg, attackerWins and 'inform' or 'inform')
    local winner = attackerWins and w.attacker or w.defender -- V9 : fresque du vainqueur (gs_scars)
    TriggerEvent('gs_gangs:server:warWon', id, winner, label(winner), Config.Territories[id].center, Gangs.list[winner] and Gangs.list[winner].color)
    Security:LogStaff('[Gang] ' .. msg, 'jobs')
    publishWars()
end

--- Une passe par 15 s : annonce du début, fin des guerres échues.
function Wars.tick()
    local now = os.time()
    for id, w in pairs(Wars.list) do
        if now >= w.endsAt then Wars.finish(id, w)
        elseif now >= w.startsAt and not w.announced then
            w.announced = true
            notifyGangs(w.attacker, w.defender, ('La guerre pour %s COMMENCE ! Mettez à terre les adversaires dans le quartier.'):format(Config.Territories[id].label), 'warning')
            publishWars()
        end
    end
end

lib.callback.register('gs_gangs:wars', function(src)
    if not Security:RateLimit(src, 'gs_gangs:wars', 6, 10000) then return nil end
    local m = Gangs.online[src]
    if not m or not m.gang then return false end
    local targets = {}
    for id, t in pairs(Gangs.territories) do
        if t.owner and t.owner ~= m.gang then targets[#targets + 1] = { id = id, label = Config.Territories[id].label, owner = label(t.owner), war = Wars.list[id] ~= nil } end
    end
    table.sort(targets, function(a, b) return a.label < b.label end)
    return { canDeclare = Config.Grades[m.grade].manage == true, cost = W.cost, targets = targets, wars = GlobalState.gsWars or {},
             cooldown = math.max(0, (Wars.cool[m.gang] or 0) - os.time()) }
end)

lib.callback.register('gs_gangs:declareWar', function(src, id)
    if not Security:RateLimit(src, 'gs_gangs:declareWar', 2, 10000) then return false, 'Doucement.' end
    if type(id) ~= 'string' then return false, 'Quartier inconnu.' end
    return Wars.declare(src, id)
end)

-- Détection côté serveur : coup porté (weaponDamageEvent) puis chute de la victime (état qbx_medical)
AddEventHandler('weaponDamageEvent', function(sender, data)
    sender = tonumber(sender) -- FiveM le transmet en chaîne
    if type(data) ~= 'table' or not data.hitGlobalId then return end
    local ent = NetworkGetEntityFromNetworkId(data.hitGlobalId)
    if not ent or ent == 0 or not DoesEntityExist(ent) or not IsPedAPlayer(ent) then return end
    local victim = NetworkGetEntityOwner(ent)
    if victim and victim > 0 and victim ~= sender then Wars.lastHit[victim] = { attacker = sender, at = os.time() } end
end)

AddStateBagChangeHandler('qbx_medical:deathState', nil, function(bagName, _, value)
    local src = GetPlayerFromStateBagName(bagName)
    if src and src > 0 and (tonumber(value) or 0) >= 2 then Wars.onDowned(src) end
end)

AddEventHandler('gs_bridge:server:playerUnloaded', function(src) Wars.lastHit[src], Wars.victimAt[src] = nil, nil end)

CreateThread(function()
    while true do
        Wait(15000)
        Wars.tick()
    end
end)
