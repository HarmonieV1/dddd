-- gs_fightclub (serveur) · V9 « Combats clandestins ». Le serveur choisit l'adresse du jour, ne la révèle qu'aux joueurs
-- qui s'approchent, encaisse les mises et les paris, arbitre le combat (santé, armes, sortie du ring) et paie.
local Security = exports.gs_security
local Bridge   = exports.gs_bridge

FightClub = { match = nil, near = {}, lastRumor = 0 }
-- match = { a, b, stake, phase = 'waiting'|'betting'|'fight', at, bets = { [src] = { side, amount } } }

local UNARMED = GetHashKey('WEAPON_UNARMED')
local function now() return os.time() end
local function notify(src, msg, t) Bridge:Notify(src, msg, t or 'inform') end

local function seed()
    local s = GetResourceKvpInt('seed')
    if s == 0 then s = math.random(1, 9973) SetResourceKvpInt('seed', s) end
    return s
end

--- Ring du jour (change chaque jour réel, ordre propre au serveur)
function FightClub.ring()
    local day = math.floor(now() / 86400)
    local idx = (day * 7 + seed()) % #Config.Rings + 1
    return Config.Rings[idx], idx
end

function FightClub.isOpen()
    if GetResourceState('gs_events') == 'started' then -- V9 : « Nuit des combats » (rendez-vous fixe) = ouvert toute la soirée
        local ok, e = pcall(function() return exports.gs_events:Active() end)
        if ok and e and e.id == 'sat_fight' then return true end
    end
    if GetResourceState('gs_weather') ~= 'started' then return true end
    local ok, h = pcall(function() return exports.gs_weather:GetGameTime() end)
    if not ok or not h then return true end
    return h >= Config.Night.from or h < Config.Night.to
end

local function pedOf(src) return GetPlayerPed(src) end
local function distTo(src, c)
    local ped = pedOf(src)
    return ped ~= 0 and #(GetEntityCoords(ped) - vec3(c.x, c.y, c.z)) or math.huge
end
local function atRing(src, range) local r = FightClub.ring() return distTo(src, r.coords) <= (range or Config.Bet.range) end

local function spectators()
    local out, m = {}, FightClub.match
    for _, s in ipairs(Bridge:GetPlayers() or {}) do
        if atRing(s, Config.Bet.range + 10.0) then out[#out + 1] = s end
    end
    return out, m
end

local function broadcast(msg, t) for _, s in ipairs((spectators())) do notify(s, msg, t) end end
local function name(src) return Bridge:GetName(src) or ('#%d'):format(src) end

--- S'inscrire comme combattant : le premier fixe la mise, le second l'accepte
function FightClub.join(src, stake)
    if not FightClub.isOpen() then return false, '« Reviens à la nuit tombée. »' end
    if not atRing(src, 6.0) then return false, 'Il n\'y a personne ici.' end
    local m = FightClub.match
    if m and (m.a == src or m.b == src) then return false, 'Tu es déjà inscrit.' end
    if m and m.phase ~= 'waiting' then return false, '« Un combat est en cours, attends ton tour. »' end
    stake = m and m.stake or tonumber(stake)
    local valid = false
    for _, s in ipairs(Config.Stakes) do if s == stake then valid = true end end
    if not valid then return false, 'Mise invalide.' end
    if not Bridge:RemoveMoney(src, 'cash', stake, 'combat clandestin') then return false, ('« %d $ en liquide, sinon tu dégages. »'):format(stake) end
    if not m then
        FightClub.match = { a = src, stake = stake, phase = 'waiting', at = now(), bets = {} }
        return true, ('Inscrit avec une mise de %d $. Il te faut un adversaire.'):format(stake)
    end
    m.b, m.phase, m.at = src, 'betting', now()
    broadcast(('Combat : %s contre %s (%d $ chacun). Les paris sont ouverts %d s !'):format(name(m.a), name(m.b), stake, Config.Bet.window), 'warning')
    return true, 'Adversaire trouvé. Les paris sont ouverts.'
end

--- Retirer son inscription tant que personne n'a accepté
function FightClub.leave(src)
    local m = FightClub.match
    if not m or m.a ~= src or m.phase ~= 'waiting' then return false, 'Rien à annuler.' end
    Bridge:AddMoney(src, 'cash', m.stake, 'combat annulé')
    FightClub.match = nil
    return true, 'Inscription annulée, mise rendue.'
end

function FightClub.bet(src, side, amount)
    local m = FightClub.match
    amount = math.floor(tonumber(amount) or 0)
    if not m or m.phase ~= 'betting' then return false, 'Les paris sont fermés.' end
    if src == m.a or src == m.b then return false, '« Les combattants ne parient pas. »' end
    if side ~= 'a' and side ~= 'b' then return false, 'Pari invalide.' end
    if amount < Config.Bet.min or amount > Config.Bet.max then return false, ('Pari entre %d et %d $.'):format(Config.Bet.min, Config.Bet.max) end
    if m.bets[src] then return false, 'Tu as déjà parié.' end
    if not atRing(src) then return false, 'Approche-toi du ring.' end
    if not Bridge:RemoveMoney(src, 'cash', amount, 'pari clandestin') then return false, 'Pas assez de liquide.' end
    m.bets[src] = { side = side, amount = amount }
    return true, ('%d $ sur %s.'):format(amount, name(side == 'a' and m.a or m.b))
end

local function refund(m, why)
    for _, f in ipairs({ m.a, m.b }) do if f then Bridge:AddMoney(f, 'cash', m.stake, why) end end
    for s, b in pairs(m.bets) do Bridge:AddMoney(s, 'cash', b.amount, why) end
end

--- Fin du combat : `side` = 'a' | 'b' | nil (nul)
function FightClub.resolve(side, why)
    local m = FightClub.match
    if not m then return end
    FightClub.match = nil
    for _, f in ipairs({ m.a, m.b }) do if f then TriggerClientEvent('gs_fightclub:client:stop', f) end end
    if not side then
        refund(m, 'combat nul')
        broadcast(('Match nul (%s). Tout le monde est remboursé.'):format(why or 'temps écoulé'), 'inform')
        return
    end
    local winner, loser = side == 'a' and m.a or m.b, side == 'a' and m.b or m.a
    local purse = math.floor(m.stake * 2 * (1 - Config.Cut))
    Bridge:AddMoney(winner, 'cash', purse, 'combat gagné')
    notify(winner, ('Victoire ! +%d $.'):format(purse), 'success')
    TriggerEvent('gs_fightclub:server:won', winner) -- V9 : biographie
    TriggerClientEvent('gs_fightclub:client:ko', loser)
    -- paris mutuels : les gagnants se partagent la cagnotte (moins la part de la maison)
    local pool, onWinner = 0, 0
    for _, b in pairs(m.bets) do pool = pool + b.amount if b.side == side then onWinner = onWinner + b.amount end end
    if onWinner == 0 then
        for s, b in pairs(m.bets) do Bridge:AddMoney(s, 'cash', b.amount, 'pari remboursé') end
    else
        local share = pool * (1 - Config.Cut)
        for s, b in pairs(m.bets) do
            if b.side == side then
                local gain = math.floor(share * b.amount / onWinner)
                Bridge:AddMoney(s, 'cash', gain, 'pari gagné')
                notify(s, ('Pari gagné : +%d $.'):format(gain), 'success')
            end
        end
    end
    broadcast(('%s l\'emporte (%s) !'):format(name(winner), why or 'K.-O.'), 'success')
    if GetResourceState('gs_reputation') == 'started' then pcall(function() exports.gs_reputation:Add(winner, 'illegal', 3) end) end
    if GetResourceState('gs_rumors') == 'started' then
        pcall(function() exports.gs_rumors:Add('il y a eu un sacré combat cette nuit', ('%s a mis %s au tapis.'):format(name(winner), name(loser))) end)
    end
end

--- Arbitrage (toutes les 500 ms pendant un combat)
function FightClub.tick()
    local m = FightClub.match
    if not m then return end
    if m.phase == 'waiting' then
        if not Bridge:IsLoaded(m.a) or now() - m.at > 900 then
            if Bridge:IsLoaded(m.a) then Bridge:AddMoney(m.a, 'cash', m.stake, 'combat annulé') end
            FightClub.match = nil
        end
        return
    end
    -- un combattant parti : forfait
    for _, k in ipairs({ 'a', 'b' }) do
        if not Bridge:IsLoaded(m[k]) then return FightClub.resolve(k == 'a' and 'b' or 'a', 'forfait') end
    end
    if m.phase == 'betting' then
        if now() - m.at >= Config.Bet.window then
            m.phase, m.at = 'fight', now()
            for _, f in ipairs({ m.a, m.b }) do TriggerClientEvent('gs_fightclub:client:start', f, FightClub.ring().coords) end
            broadcast('Les paris sont fermés. Combattez !', 'warning')
        end
        return
    end
    local ring = FightClub.ring()
    local lost = {}
    for _, k in ipairs({ 'a', 'b' }) do
        local src, ped = m[k], pedOf(m[k])
        if GetSelectedPedWeapon(ped) ~= UNARMED then lost[k] = 'arme sortie : disqualifié'
        elseif distTo(src, ring.coords) > Config.Radius then lost[k] = 'sorti du ring'
        elseif Bridge:IsDowned(src) or GetEntityHealth(ped) <= Config.KoHealth then lost[k] = 'K.-O.' end
    end
    if lost.a and lost.b then return FightClub.resolve(nil, 'double K.-O.') end
    if lost.a then return FightClub.resolve('b', lost.a) end
    if lost.b then return FightClub.resolve('a', lost.b) end
    if now() - m.at >= Config.MaxDuration then return FightClub.resolve(nil, 'temps écoulé') end
end

--- Révélation : seul le serveur connaît l'adresse ; il l'envoie aux joueurs qui arrivent sur place
function FightClub.scan()
    local ring, idx = FightClub.ring()
    local open = FightClub.isOpen()
    for _, s in ipairs(Bridge:GetPlayers() or {}) do
        local here = open and distTo(s, ring.coords) <= Config.Reveal * 3
        if here and FightClub.near[s] ~= idx then
            FightClub.near[s] = idx
            TriggerClientEvent('gs_fightclub:client:ring', s, { coords = ring.coords, npc = ring.npc })
        elseif not here and FightClub.near[s] then
            FightClub.near[s] = nil
            TriggerClientEvent('gs_fightclub:client:ring', s, nil)
        end
    end
    if open and GetResourceState('gs_rumors') == 'started' and now() - FightClub.lastRumor >= Config.RumorEvery * 60 then
        FightClub.lastRumor = now()
        pcall(function() exports.gs_rumors:Add('des combats clandestins ont lieu cette nuit', 'Le ring est dans ' .. ring.hint .. '. Mains nues, paris en liquide.', ring.coords) end)
    end
end

function FightClub.status(src)
    local m = FightClub.match
    if not atRing(src) then return nil end
    if not m then return { phase = 'none', stakes = Config.Stakes, open = FightClub.isOpen() } end
    return { phase = m.phase, stake = m.stake, a = name(m.a), b = m.b and name(m.b) or nil, me = (src == m.a or src == m.b), mine = m.a == src,
        bet = m.bets[src], min = Config.Bet.min, max = Config.Bet.max, open = true }
end

lib.callback.register('gs_fightclub:status', function(src)
    if not Security:RateLimit(src, 'gs_fightclub:status', 6, 5000) then return nil end
    return FightClub.status(src)
end)
lib.callback.register('gs_fightclub:join', function(src, stake)
    if not Security:RateLimit(src, 'gs_fightclub:join', 3, 5000) then return false, 'Doucement.' end
    return FightClub.join(src, stake)
end)
lib.callback.register('gs_fightclub:leave', function(src)
    if not Security:RateLimit(src, 'gs_fightclub:leave', 3, 5000) then return false, 'Doucement.' end
    return FightClub.leave(src)
end)
lib.callback.register('gs_fightclub:bet', function(src, side, amount)
    if not Security:RateLimit(src, 'gs_fightclub:bet', 3, 5000) then return false, 'Doucement.' end
    return FightClub.bet(src, side, amount)
end)

AddEventHandler('playerDropped', function() FightClub.near[source] = nil end)
exports('IsOpen', function() return FightClub.isOpen() end) -- V10 : « Que faire ? » (jamais l'adresse)

CreateThread(function()
    while true do
        Wait(FightClub.match and FightClub.match.phase == 'fight' and 500 or 5000)
        FightClub.tick()
    end
end)
CreateThread(function()
    while true do Wait(5000) FightClub.scan() end
end)
