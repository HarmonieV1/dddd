-- gs_duo (serveur). Un personnage = au plus un duo. Tout est validé ici.
local Security = exports.gs_security
local Bridge   = exports.gs_bridge
local WantedApi = exports.gs_wanted

Duo = {
    byId = {},       -- [id] = { id, a, b, name, xp }
    online = {},     -- [src] = { cid, duoId }
    srcByCid = {},   -- [cid] = src (recherche du partenaire en O(1))
    invites = {},    -- [target] = { from, fromCid, expires }
    lastLeft = {},   -- [cid] = os.time()
    contracts = {},  -- [duoId] = { step, steps, lastPos, lastAt }
    cooldown = {},   -- [duoId] = os.time()
}

--- Vrai si ce personnage a rompu un duo il y a moins de Config.LeaveCooldown.
local function inBreakup(cid)
    local left = Duo.lastLeft[cid]
    return left ~= nil and left + Config.LeaveCooldown > os.time()
end

local function notify(src, msg, t) Bridge:Notify(src, msg, t or 'inform') end
local function dist(a, b) return #(a - b) end
local function coordsOf(src) local ped = GetPlayerPed(src) return ped ~= 0 and GetEntityCoords(ped) or nil end

function Duo.level(xp)
    local lvl = 1
    for i, l in ipairs(Config.Levels) do if xp >= l.xp then lvl = i end end
    return lvl, Config.Levels[lvl]
end

--- Source du partenaire en ligne, ou nil.
function Duo.partner(src)
    local me = Duo.online[src]
    local duo = me and me.duoId and Duo.byId[me.duoId]
    if not duo then return nil end
    local other = duo.a == me.cid and duo.b or duo.a
    return Duo.srcByCid[other], duo
end

local function info(src)
    local me = Duo.online[src]
    local duo = me and me.duoId and Duo.byId[me.duoId]
    if not duo then return nil end
    local partner = Duo.partner(src)
    local lvl, l = Duo.level(duo.xp)
    local nextL = Config.Levels[lvl + 1]
    return {
        name = duo.name, xp = duo.xp, level = lvl, levelLabel = l.label, nextXp = nextL and nextL.xp or nil,
        partnerOnline = partner ~= nil, partnerName = partner and Bridge:GetName(partner) or nil,
        contract = Duo.contracts[duo.id] ~= nil,
    }
end

local function sync(src)
    TriggerClientEvent('gs_duo:client:info', src, info(src))
end

local function syncDuo(duo)
    for s, o in pairs(Duo.online) do
        if o.duoId == duo.id then sync(s) end
    end
end

function Duo.addXp(duo, amount)
    local before = Duo.level(duo.xp)
    duo.xp = duo.xp + amount
    Store.setXp(duo.id, duo.xp)
    local after, l = Duo.level(duo.xp)
    for s, o in pairs(Duo.online) do
        if o.duoId == duo.id and after > before then notify(s, ('Lien renforcé : %s !'):format(l.label), 'success') end
    end
    syncDuo(duo)
end

-- Chargement ----------------------------------------------------------------------------------------

function Duo.load(src)
    local cid = Bridge:GetIdentifier(src)
    if not cid then return end
    local row = Store.find(cid)
    if row then Duo.byId[row.id] = Duo.byId[row.id] or row end
    Duo.online[src] = { cid = cid, duoId = row and row.id or nil }
    Duo.srcByCid[cid] = src
    sync(src)
    local partner = Duo.partner(src)
    if partner then notify(partner, 'Ton partenaire vient d\'arriver en ville.', 'inform') sync(partner) end
end

AddEventHandler('gs_bridge:server:playerLoaded', function(src) Duo.load(src) end)
AddEventHandler('gs_bridge:server:playerUnloaded', function(src)
    local me = Duo.online[src]
    if not me then return end
    local partner, duo = Duo.partner(src)
    Duo.online[src], Duo.invites[src], Duo.srcByCid[me.cid] = nil, nil, nil
    if duo and Duo.contracts[duo.id] then
        Duo.contracts[duo.id] = nil
        if partner then
            TriggerClientEvent('gs_duo:client:contractEnd', partner, 'cancel')
            notify(partner, 'Contrat annulé : ton partenaire a disparu.', 'error')
        end
    end
    if partner then
        TriggerClientEvent('gs_duo:client:partner', partner, nil)
        sync(partner)
    elseif duo then
        Duo.byId[duo.id] = nil -- les deux hors ligne : rechargé depuis la BDD à la prochaine connexion
    end
end)

-- Invitation / rupture / nom ----------------------------------------------------------------------

lib.callback.register('gs_duo:invite', function(src, target)
    if not Security:RateLimit(src, 'gs_duo:invite', 3, 30000) then return false, 'Doucement.' end
    target = tonumber(target)
    local me, other = Duo.online[src], Duo.online[target]
    if not me or not other or target == src then return false, 'Joueur introuvable.' end
    if me.duoId then return false, 'Tu as déjà un duo.' end
    if other.duoId then return false, 'Cette personne a déjà un duo.' end
    if inBreakup(me.cid) then return false, 'Tu sors d\'une rupture, attends un peu.' end
    if not Security:PlayersInRange(src, target, Config.InviteRange) then return false, 'Trop loin.' end
    Duo.invites[target] = { from = src, fromCid = me.cid, expires = os.time() + Config.InviteTimeout }
    TriggerClientEvent('gs_duo:client:invite', target, Bridge:GetName(src) or '?')
    return true, 'Proposition envoyée.'
end)

RegisterNetEvent('gs_duo:server:answer', function(accept)
    local src = source
    if not Security:RateLimit(src, 'gs_duo:answer', 3, 10000) then return end
    local inv = Duo.invites[src]
    Duo.invites[src] = nil
    local me = Duo.online[src]
    if not inv or not me then return end
    if os.time() > inv.expires then return notify(src, 'Proposition expirée.', 'error') end
    local from = Duo.online[inv.from]
    if accept ~= true then return notify(inv.from, 'Proposition de duo refusée.', 'inform') end
    -- Revalidation complète au moment d'accepter
    if not from or from.cid ~= inv.fromCid or from.duoId or me.duoId then return notify(src, 'Proposition plus valable.', 'error') end
    if inBreakup(me.cid) or inBreakup(from.cid) then return notify(src, 'Tu sors d\'une rupture, attends un peu.', 'error') end
    if Store.find(me.cid) or Store.find(from.cid) then return notify(src, 'Proposition plus valable.', 'error') end

    local name = ('%s & %s'):format((Bridge:GetName(inv.from) or '?'):match('^%S+') or '?', (Bridge:GetName(src) or '?'):match('^%S+') or '?')
    local id = Store.create(from.cid, me.cid, name:sub(1, Config.NameMaxLength))
    if not id then return notify(src, 'Erreur, réessaie.', 'error') end
    Duo.byId[id] = { id = id, a = from.cid, b = me.cid, name = name, xp = 0 }
    from.duoId, me.duoId = id, id
    for _, s in ipairs({ src, inv.from }) do notify(s, ('Duo formé : %s.'):format(name), 'success') sync(s) end
    Security:LogStaff(('Duo formé #%d : %s + %s'):format(id, from.cid, me.cid), 'jobs')
end)

RegisterNetEvent('gs_duo:server:leave', function()
    local src = source
    if not Security:RateLimit(src, 'gs_duo:leave', 2, 10000) then return end
    local me = Duo.online[src]
    local partner, duo = Duo.partner(src)
    if not me or not duo then return end
    Store.delete(duo.id)
    Duo.byId[duo.id], Duo.contracts[duo.id], Duo.cooldown[duo.id] = nil, nil, nil
    Duo.lastLeft[duo.a], Duo.lastLeft[duo.b] = os.time(), os.time()
    for s, o in pairs(Duo.online) do
        if o.duoId == duo.id then
            o.duoId = nil
            TriggerClientEvent('gs_duo:client:partner', s, nil)
            TriggerClientEvent('gs_duo:client:contractEnd', s, 'cancel')
            notify(s, s == src and 'Tu as rompu le duo.' or 'Ton partenaire a rompu le duo.', 'error')
            sync(s)
        end
    end
    Security:LogStaff(('Duo dissous #%d par %s'):format(duo.id, me.cid), 'jobs')
end)

lib.callback.register('gs_duo:rename', function(src, name)
    if not Security:RateLimit(src, 'gs_duo:rename', 2, 60000) then return false, 'Doucement.' end
    local _, duo = Duo.partner(src)
    name = Security:Sanitize(name, Config.NameMaxLength)
    if not duo or not name then return false, 'Nom invalide.' end
    duo.name = name
    Store.rename(duo.id, name)
    syncDuo(duo)
    return true, 'Duo renommé.'
end)

lib.callback.register('gs_duo:info', function(src)
    if not Security:RateLimit(src, 'gs_duo:info', 5, 10000) then return nil end
    return info(src)
end)

-- Contrats à deux ---------------------------------------------------------------------------------

local function pick(list, from)
    for _ = 1, 50 do
        local p = list[math.random(#list)]
        if dist(p, from) >= Config.Contract.minStepDistance then return p end
    end
    return nil
end

local function sendStep(duo, c)
    for s, o in pairs(Duo.online) do
        if o.duoId == duo.id then
            TriggerClientEvent('gs_duo:client:contractStep', s, {
                index = c.index, total = #c.steps, coords = c.steps[c.index],
                label = c.index == 1 and 'Récupérer la marchandise' or 'Livrer la marchandise',
                duration = Config.Contract.stepDuration,
            })
        end
    end
end

lib.callback.register('gs_duo:contractStart', function(src)
    if not Security:RateLimit(src, 'gs_duo:contract', 3, 10000) then return false, 'Doucement.' end
    local partner, duo = Duo.partner(src)
    if not duo then return false, 'Il te faut un duo.' end
    if not partner then return false, 'Ton partenaire doit être en ville.' end
    if Duo.contracts[duo.id] then return false, 'Contrat déjà en cours.' end
    if (Duo.cooldown[duo.id] or 0) > os.time() then return false, 'Faites-vous oublier un peu avant le prochain.' end
    if not Security:PlayersInRange(src, partner, Config.Contract.radius) then return false, 'Ton partenaire doit être avec toi.' end
    local pos = coordsOf(src)
    if not pos then return false, 'Réessaie dans un instant.' end
    local pickup = pick(Config.Contract.pickups, pos)
    local drop = pickup and pick(Config.Contract.drops, pickup)
    if not drop then return false, 'Aucun contrat dispo, réessaie.' end
    local c = { index = 1, steps = { pickup, drop }, lastPos = pos, lastAt = GetGameTimer() }
    Duo.contracts[duo.id] = c
    sendStep(duo, c)
    syncDuo(duo)
    return true, 'Contrat accepté. Allez-y ensemble.'
end)

local function endContract(duo, reason)
    Duo.contracts[duo.id] = nil
    Duo.cooldown[duo.id] = os.time() + Config.Contract.cooldown
    for s, o in pairs(Duo.online) do
        if o.duoId == duo.id then TriggerClientEvent('gs_duo:client:contractEnd', s, reason) end
    end
    syncDuo(duo)
end

lib.callback.register('gs_duo:contractStep', function(src)
    if not Security:RateLimit(src, 'gs_duo:step', 3, 5000) then return false, 'Doucement.' end
    local partner, duo = Duo.partner(src)
    local c = duo and Duo.contracts[duo.id]
    if not c then return false, 'Aucun contrat.' end
    if not partner then return false, 'Ton partenaire doit être là.' end
    local target = c.steps[c.index]
    local maxDist = Config.Contract.radius + Config.Contract.tolerance
    local a, b = coordsOf(src), coordsOf(partner)
    if not a or not b or dist(a, target) > maxDist or dist(b, target) > maxDist then
        return false, 'Vous devez être là tous les deux.'
    end
    local travelled = dist(target, c.lastPos)
    local elapsed = (GetGameTimer() - c.lastAt) / 1000
    if elapsed < travelled / Config.Contract.maxSpeed then
        Security:LogStaff(('Contrat duo suspect #%d : %.0f m en %.1f s'):format(duo.id, travelled, elapsed), 'jobs')
        endContract(duo, 'cancel')
        return false, 'Contrat annulé : trajet incohérent.'
    end
    c.lastPos, c.lastAt = target, GetGameTimer()

    if c.index == 1 then
        -- Le vol peut être signalé (témoins, heure, météo) : la police peut débarquer.
        WantedApi:ReportCrime(src, Config.Contract.crime, target)
        c.index = 2
        sendStep(duo, c)
        return true, 'Marchandise récupérée. Direction la livraison.'
    end

    local _, l = Duo.level(duo.xp)
    local pay = math.floor(math.random(Config.Contract.payEach[1], Config.Contract.payEach[2]) * l.pay)
    for _, s in ipairs({ src, partner }) do
        Bridge:AddMoney(s, 'cash', pay, 'contrat duo')
        notify(s, ('Contrat réussi : +%d $ chacun.'):format(pay), 'success')
    end
    endContract(duo, 'done')
    Duo.addXp(duo, Config.Contract.xp)
    return true
end)

RegisterNetEvent('gs_duo:server:contractCancel', function()
    if not Security:RateLimit(source, 'gs_duo:cancel', 2, 10000) then return end
    local _, duo = Duo.partner(source)
    if duo and Duo.contracts[duo.id] then endContract(duo, 'cancel') end
end)

-- Chaleur partagée : le complice proche prend une part de la chaleur -------------------------------------
AddEventHandler('gs_wanted:server:reported', function(src, _, heat)
    local partner, duo = Duo.partner(src)
    if not partner then return end
    local a, b = coordsOf(src), coordsOf(partner)
    if a and b and dist(a, b) <= Config.HeatShareRadius then
        local _, l = Duo.level(duo.xp)
        WantedApi:AddHeat(partner, math.floor(heat * l.heatShare))
    end
end)

-- Boucles légères : position du partenaire (3 s), XP ensemble (5 min) ---------------------------------------
function Duo.pushPositions()
    for src in pairs(Duo.online) do
        local partner = Duo.partner(src)
        if partner then TriggerClientEvent('gs_duo:client:partner', src, coordsOf(partner)) end
    end
end

function Duo.togetherTick()
    local done = {}
    for src, o in pairs(Duo.online) do
        local partner, duo = Duo.partner(src)
        if partner and not done[o.duoId] then
            done[o.duoId] = true
            local a, b = coordsOf(src), coordsOf(partner)
            if a and b and dist(a, b) <= Config.TogetherRadius then Duo.addXp(duo, Config.TogetherXp) end
        end
    end
end

CreateThread(function()
    Store.init()
    for _, src in ipairs(Bridge:GetPlayers()) do Duo.load(src) end
    local together = 0
    while true do
        Wait(Config.PartnerBlipSeconds * 1000)
        Duo.pushPositions()
        together = together + Config.PartnerBlipSeconds
        if together >= Config.TogetherMinutes * 60 then
            together = 0
            Duo.togetherTick()
        end
    end
end)

exports('GetPartner', function(src) return (Duo.partner(src)) end)
exports('GetDuoLevel', function(src)
    local _, duo = Duo.partner(src)
    return duo and (Duo.level(duo.xp)) or 0
end)
