-- gs_quests (serveur). Le client ne fait que proposer : chaque étape est revérifiée ici (distance, véhicule, items,
-- chrono). Une quête en cours est abandonnée à la déconnexion (items et véhicule de quête repris), l'XP est gardée.
local Security = exports.gs_security
local Bridge   = exports.gs_bridge

Progress = { players = {}, active = {} } -- players[src] = { cid, xp, packages, done } ; active[src] = état de quête

local QuestById = {}
for i, q in ipairs(Quests) do q.index = i QuestById[q.id] = q end

local function started(res) return GetResourceState(res) == 'started' end
local function notify(src, msg, t) Bridge:Notify(src, msg, t or 'inform') end
local function guard(src, key, max, window) return Security:RateLimit(src, 'gs_quests:' .. key, max, window) end
local function near(src, coords, radius) return Security:InRange(src, coords, radius + Config.Tolerance) end
local function charCoords(id) local c = Characters[id].coords return vec3(c.x, c.y, c.z) end

-- Niveaux --------------------------------------------------------------------------------------------------

--- Niveau, XP au début du niveau, XP pour le niveau suivant (nil au max).
function Progress.levelOf(xp)
    local level, floor = 1, 0
    while level < Config.MaxLevel and xp >= floor + Config.StepXP(level) do
        floor = floor + Config.StepXP(level)
        level = level + 1
    end
    return level, floor, level < Config.MaxLevel and floor + Config.StepXP(level) or nil
end

--- Ajoute de l'XP (quêtes, métiers, braquages…). Passage de niveau : récompense en banque. Retourne le niveau.
function Progress.addXP(src, amount, reason)
    local p = Progress.players[src]
    amount = math.floor(tonumber(amount) or 0)
    if not p or amount <= 0 or amount > 100000 then return nil end
    if GetResourceState('gs_events') == 'started' then amount = math.floor(amount * (exports.gs_events:GetXpMultiplier() or 1.0)) end -- événement en cours
    local before = Progress.levelOf(p.xp)
    p.xp = p.xp + amount
    local after, floor, nextXp = Progress.levelOf(p.xp)
    Store.save(p.cid, p)
    for lvl = before + 1, after do Bridge:AddMoney(src, 'bank', Config.LevelReward(lvl), 'niveau ' .. lvl) end
    TriggerClientEvent('gs_quests:client:xp', src, { gained = amount, reason = reason, xp = p.xp, level = after,
        floor = floor, nextXp = nextXp, levelUp = after > before, reward = after > before and Config.LevelReward(after) or nil })
    return after
end

-- Titres, badges ---------------------------------------------------------------------------------------------

function Progress.titleFor(level)
    local label = Config.Titles[1].label
    for _, t in ipairs(Config.Titles) do if level >= t.level then label = t.label end end
    return label
end

function Progress.award(src, badge)
    local p = Progress.players[src]
    if not p or p.badges[badge] or not Config.Badges[badge] then return false end
    p.badges[badge] = true
    Store.save(p.cid, p)
    TriggerClientEvent('gs_quests:client:badge', src, Config.Badges[badge].label, Config.Badges[badge].desc)
    return true
end

-- Défis du jour ---------------------------------------------------------------------------------------------------

local function today() return os.date('%Y-%m-%d', os.time()) end

--- Les `count` défis du jour pour ce personnage : tirage fixe pour (citizenid, date), rien à stocker.
function Progress.dailyChoice(cid, date)
    local seed = 0
    for c in (cid .. date):gmatch('.') do seed = (seed * 31 + c:byte()) % 2147483647 end
    local pool, picked = {}, {}
    for i, d in ipairs(Config.Daily.pool) do pool[i] = d end
    for _ = 1, math.min(Config.Daily.count, #pool) do
        seed = (seed * 1103515245 + 12345) % 2147483648
        picked[#picked + 1] = table.remove(pool, seed % #pool + 1)
    end
    return picked
end

local function ensureDaily(p)
    local d = today()
    if p.dailyDate ~= d then p.dailyDate, p.daily = d, {} end
end

function Progress.dailyList(p)
    ensureDaily(p)
    local list = {}
    for _, d in ipairs(Progress.dailyChoice(p.cid, p.dailyDate)) do
        local n = p.daily[d.id] or 0
        list[#list + 1] = { id = d.id, label = d.label, goal = d.goal, n = n, done = n >= d.goal }
    end
    return list
end

--- Une activité a eu lieu (mission, achat, vente…) : fait avancer le défi du jour correspondant.
function Progress.track(src, activity, amount)
    local p = Progress.players[src]
    if not p then return false end
    local changed, allDone = false, true
    for _, d in ipairs(Progress.dailyList(p)) do
        if d.id == activity and not d.done then
            local n = math.min(d.goal, d.n + math.max(1, math.floor(tonumber(amount) or 1)))
            p.daily[d.id] = n
            changed = true
            if n >= d.goal then
                d.done = true
                p.dailyTotal = p.dailyTotal + 1
                TriggerClientEvent('gs_quests:client:daily', src, d.label)
                Progress.addXP(src, Config.Daily.xp, 'Défi du jour')
                if p.dailyTotal >= 10 then Progress.award(src, 'daily10') end
            end
        end
        allDone = allDone and d.done
    end
    if not changed then return false end
    if allDone and not p.daily._all then -- bonus une seule fois par jour
        p.daily._all = 1
        Bridge:AddMoney(src, 'bank', Config.Daily.allCash, 'défis du jour')
        for _, it in ipairs(Config.Daily.allItems or {}) do Bridge:AddItem(src, it[1], it[2]) end
        Progress.addXP(src, Config.Daily.allXp, 'Tous les défis du jour')
    end
    Store.save(p.cid, p)
    return true
end

--- 1re connexion du jour : série de jours d'affilée, XP, bonus hebdo.
function Progress.login(src)
    local p = Progress.players[src]
    local d = today()
    if p.lastLogin == d then return end
    local yesterday = os.date('%Y-%m-%d', os.time() - 86400)
    p.streak = p.lastLogin == yesterday and p.streak + 1 or 1
    p.lastLogin = d
    Store.save(p.cid, p)
    Progress.addXP(src, Config.Streak.xpPerDay * math.min(p.streak, Config.Streak.maxDays), ('Connexion : %d jour(s) d\'affilée'):format(p.streak))
    if p.streak % 7 == 0 then
        Bridge:AddMoney(src, 'bank', Config.Streak.weekCash, 'série de connexions')
        Progress.award(src, 'streak7')
    end
end

--- Toutes les minutes : défi « temps de jeu ».
function Progress.minuteTick()
    for src in pairs(Progress.players) do Progress.track(src, 'playtime', 1) end
end

-- État envoyé au client --------------------------------------------------------------------------------------

local function available(src, q)
    local p = Progress.players[src]
    if p.done[q.id] then return false, 'Déjà terminée.' end
    if q.gender and Bridge:GetGender(src) ~= q.gender then return false, 'Cette histoire n\'est pas pour toi.' end
    if q.requires and not p.done[q.requires] then return false, 'Termine d\'abord : ' .. QuestById[q.requires].title end
    if q.minLevel and Progress.levelOf(p.xp) < q.minLevel then return false, ('Niveau %d requis.'):format(q.minLevel) end
    return true
end

local function isNight()
    if not started('gs_weather') then return true end
    local hour = exports.gs_weather:GetGameTime()
    return hour >= 20 or hour < 5
end

function Progress.state(src)
    local p = Progress.players[src]
    if not p then return nil end
    local level, floor, nextXp = Progress.levelOf(p.xp)
    local quests = {}
    for _, q in ipairs(Quests) do
        local ok, why = available(src, q)
        quests[#quests + 1] = { id = q.id, done = p.done[q.id] == true, available = ok, why = why }
    end
    local a = Progress.active[src]
    local packages, found = {}, 0
    for i in pairs(p.packages) do packages[#packages + 1] = i found = found + 1 end
    return {
        xp = p.xp, level = level, floor = floor, nextXp = nextXp, quests = quests,
        active = a and { id = a.id, step = a.step, collected = a.collected, deadline = a.deadline and (a.deadline - os.time()) or nil } or nil,
        packages = packages, packagesFound = found, packagesTotal = #Config.Packages.points,
        title = Progress.titleFor(level), streak = p.streak, daily = Progress.dailyList(p), badges = Progress.badgeList(p),
    }
end

--- Tous les badges, débloqués ou non (pour le menu).
function Progress.badgeList(p)
    local list = {}
    for id, b in pairs(Config.Badges) do list[#list + 1] = { id = id, label = b.label, desc = b.desc, unlocked = p.badges[id] == true } end
    table.sort(list, function(a, b) return a.label < b.label end)
    return list
end

-- Quête active ---------------------------------------------------------------------------------------------------

local function beginStep(a)
    local step = QuestById[a.id].steps[a.step]
    a.collected = {}
    a.deadline = step.limit and (os.time() + step.limit) or nil
end

--- Fin de quête (réussite ou non) : items de quête et véhicule repris.
function Progress.cleanup(src)
    local a = Progress.active[src]
    Progress.active[src] = nil
    if not a then return end
    local q = QuestById[a.id]
    for _, item in ipairs(q.cleanup or {}) do
        local n = Bridge:GetItemCount(src, item)
        if n > 0 then Bridge:RemoveItem(src, item, n) end
    end
    if a.veh and DoesEntityExist(a.veh) then DeleteEntity(a.veh) end
end

local function complete(src)
    local a = Progress.active[src]
    local q = QuestById[a.id]
    local p = Progress.players[src]
    Progress.cleanup(src)
    p.done[q.id] = true
    Store.markDone(p.cid, q.id)
    if q.reward.cash then Bridge:AddMoney(src, 'cash', q.reward.cash, 'quête ' .. q.id) end
    for _, it in ipairs(q.reward.items or {}) do Bridge:AddItem(src, it[1], it[2]) end
    Progress.addXP(src, q.reward.xp or 0, q.title)
    TriggerClientEvent('gs_quests:client:completed', src, q.id)
    Progress.award(src, 'first_quest')
    if q.badge then Progress.award(src, q.badge) end
    Progress.track(src, 'quest')
    return true, q.outro or 'Quête terminée !'
end

local function fail(src, msg)
    Progress.cleanup(src)
    return false, msg .. ' Quête échouée : retourne voir le personnage pour réessayer.'
end

lib.callback.register('gs_quests:state', function(src)
    if not guard(src, 'state', 10, 10000) then return nil end
    if not Progress.players[src] and Bridge:IsLoaded(src) then Progress.loadPlayer(src) end
    return Progress.state(src)
end)

lib.callback.register('gs_quests:start', function(src, questId)
    if not guard(src, 'start', 3, 10000) then return false, 'Doucement.' end
    local q, p = QuestById[questId], Progress.players[src]
    if not q or not p then return false, 'Quête inconnue.' end
    if Progress.active[src] then return false, 'Termine ou abandonne ta quête en cours (F2).' end
    local ok, why = available(src, q)
    if not ok then return false, why end
    if q.night and not isNight() then return false, 'Reviens ce soir (entre 20 h et 5 h).' end
    if not near(src, charCoords(q.giver), Config.TalkRadius) then return false, 'Trop loin.' end
    for _, it in ipairs(q.give or {}) do
        if not Bridge:CanCarry(src, it[1], it[2]) then return false, 'Libère de la place dans ton inventaire.' end
    end
    local a = { id = q.id, step = 1 }
    Progress.active[src] = a
    for _, it in ipairs(q.give or {}) do Bridge:AddItem(src, it[1], it[2]) end
    if q.vehicle then
        local v = q.vehicle
        a.veh = Bridge:SpawnVehicle(src, v.model, v.type, v.at, v.at.w, 'QUETE', false)
    end
    beginStep(a)
    return true, q.title
end)

--- Le client pense avoir rempli l'étape (point atteint, PNJ, ramassage `point`) : on vérifie.
lib.callback.register('gs_quests:advance', function(src, point)
    if not guard(src, 'advance', 6, 5000) then return false, 'Doucement.' end
    local a = Progress.active[src]
    if not a then return false, 'Aucune quête en cours.' end
    local q = QuestById[a.id]
    local step = q.steps[a.step]
    if a.deadline and os.time() > a.deadline then return fail(src, 'Trop lent !') end

    if step.type == 'talk' then
        if not near(src, charCoords(step.character), Config.TalkRadius) then return false, 'Trop loin.' end
    elseif step.type == 'goto' then
        if not near(src, step.coords, step.radius) then return false, 'Pas encore arrivé.' end
    elseif step.type == 'drive' then
        if not near(src, step.coords, step.radius) then return false, 'Pas encore arrivé.' end
        if GetVehiclePedIsIn(GetPlayerPed(src), false) == 0 then return false, 'Il faut arriver en véhicule.' end
    elseif step.type == 'deliver' then
        local at = step.character and charCoords(step.character) or step.coords
        if not near(src, at, step.character and Config.TalkRadius or (step.radius or 4.0)) then return false, 'Trop loin.' end
        if not Bridge:RemoveItem(src, step.item, step.count) then return false, ('Il te faut %d × %s.'):format(step.count, step.item) end
    elseif step.type == 'collect' then
        point = tonumber(point)
        local c = point and step.points[point]
        if not c then return false, 'Rien ici.' end
        if a.collected[point] then return false, 'Déjà ramassé.' end
        if not near(src, c, 2.0) then return false, 'Trop loin.' end
        if step.item and not Bridge:AddItem(src, step.item, 1) then return false, 'Inventaire plein.' end
        a.collected[point] = true
        local n = 0
        for _ in pairs(a.collected) do n = n + 1 end
        if n < #step.points then return true, ('%d / %d'):format(n, #step.points) end
    end

    if a.step >= #q.steps then return complete(src) end
    a.step = a.step + 1
    beginStep(a)
    return true, q.steps[a.step].label
end)

lib.callback.register('gs_quests:abandon', function(src)
    if not guard(src, 'abandon', 3, 10000) then return false end
    if not Progress.active[src] then return false end
    Progress.cleanup(src)
    return true
end)

-- Paquets cachés ------------------------------------------------------------------------------------------------

lib.callback.register('gs_quests:package', function(src, index)
    if not guard(src, 'package', 3, 5000) then return false, 'Doucement.' end
    local p = Progress.players[src]
    index = tonumber(index)
    local c = index and Config.Packages.points[index]
    if not p or not c then return false, 'Rien ici.' end
    if p.packages[index] then return false, 'Déjà trouvé.' end
    if not near(src, c, 2.0) then return false, 'Trop loin.' end
    p.packages[index] = true
    local found = 0
    for _ in pairs(p.packages) do found = found + 1 end
    Progress.addXP(src, Config.Packages.xp, 'paquet caché')
    Progress.track(src, 'package')
    if found == #Config.Packages.points then
        Bridge:AddMoney(src, 'bank', Config.Packages.allCash, 'paquets cachés')
        Progress.addXP(src, Config.Packages.allXp, 'tous les paquets cachés')
        Progress.award(src, 'collector')
        return true, 'TOUS LES PAQUETS TROUVÉS ! Respect.'
    end
    return true, ('Paquet caché %d / %d'):format(found, #Config.Packages.points)
end)

-- Cycle de vie ------------------------------------------------------------------------------------------------------

--- Charge la progression d'un joueur (connexion, ou rattrapage si la ressource a démarré après lui).
function Progress.loadPlayer(src)
    local cid = Bridge:GetIdentifier(src)
    if not cid then return nil end
    local ok, p = pcall(Store.load, cid)
    if not ok or not p then
        print(('^1[gs_quests] chargement de %s impossible : %s^7'):format(cid, tostring(p)))
        return nil
    end
    p.cid = cid
    Progress.players[src] = p
    Progress.login(src)
    TriggerClientEvent('gs_quests:client:refresh', src)
    return p
end

AddEventHandler('gs_bridge:server:playerLoaded', function(src) Progress.loadPlayer(src) end)

AddEventHandler('gs_bridge:server:playerUnloaded', function(src)
    Progress.cleanup(src)
    Progress.players[src] = nil
end)

CreateThread(function()
    Store.init()
    while true do
        Wait(60000)
        Progress.minuteTick()
    end
end)

exports('AddXP', function(src, amount, reason) return Progress.addXP(src, amount, reason) end)
--- XP prévue par Config.XP pour une activité (job_mission, drug_sale, heist) + défi du jour correspondant.
exports('Reward', function(src, activity)
    Progress.track(src, activity)
    return Progress.addXP(src, Config.XP[activity] or 0, activity)
end)
--- Défi du jour seul (rental, shop_buy, sell…), sans XP directe.
exports('Track', function(src, activity, amount) return Progress.track(src, activity, amount) end)
exports('GetLevel', function(src) local p = Progress.players[src] return p and (Progress.levelOf(p.xp)) or 0 end)
exports('GetTitle', function(src)
    local p = Progress.players[src]
    return p and Progress.titleFor((Progress.levelOf(p.xp))) or nil
end)
--- Résumé pour le panel staff : { level, title, xp, streak, badges = { labels } }
exports('GetSummary', function(src)
    local p = Progress.players[src]
    if not p then return nil end
    local level = Progress.levelOf(p.xp)
    local badges = {}
    for _, b in ipairs(Progress.badgeList(p)) do if b.unlocked then badges[#badges + 1] = b.label end end
    return { level = level, title = Progress.titleFor(level), xp = p.xp, streak = p.streak, badges = badges }
end)
