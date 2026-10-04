-- gs_stats (serveur) · V9 « Récap RoadLine / biographie ». Les autres ressources signalent ce qui arrive (événements
-- serveur, jamais le client) ; les compteurs sont groupés en mémoire puis écrits en une requête toutes les minutes.
local Security = exports.gs_security
local Bridge   = exports.gs_bridge

Bio = { buf = {} } -- buf[cid][stat] = n (pas encore écrit)

local function now() return os.time() end
function Bio.month(ts) return os.date('%Y-%m', ts or now()) end

function Bio.addCid(cid, stat, n)
    if not cid or not n or n == 0 then return end
    Bio.buf[cid] = Bio.buf[cid] or {}
    Bio.buf[cid][stat] = (Bio.buf[cid][stat] or 0) + n
end
function Bio.add(src, stat, n) Bio.addCid(Bridge:GetIdentifier(src), stat, n or 1) end

--- Écriture groupée : mois en cours + « depuis toujours »
function Bio.flush()
    local rows, month = {}, Bio.month()
    for cid, stats in pairs(Bio.buf) do
        for stat, n in pairs(stats) do
            n = math.floor(n)
            if n ~= 0 then rows[#rows + 1] = { cid, month, stat, n } rows[#rows + 1] = { cid, 'all', stat, n } end
        end
    end
    Bio.buf = {}
    Store.addMany(rows)
    return #rows
end

local function fmt(kind, v)
    v = v or 0
    if kind == 'hours' then return ('%d h %02d'):format(v // 60, v % 60) end
    if kind == 'km' then return ('%d km'):format(math.floor(v / 1000)) end
    if kind == 'money' then
        local s = tostring(math.floor(v)):reverse():gsub('(%d%d%d)', '%1 '):reverse():gsub('^ ', '')
        return s .. ' $'
    end
    return tostring(math.floor(v))
end

--- Vue récap d'une période ('YYYY-MM' ou 'all') : lignes, titre, classements
function Bio.view(cid, period)
    local data = Store.get(cid, period)
    for stat, n in pairs(Bio.buf[cid] or {}) do data[stat] = (data[stat] or 0) + n end -- pas encore écrit
    local lines, best, bestScore = {}, nil, 0
    for _, s in ipairs(Config.Stats) do
        local v = data[s.id] or 0
        if v > 0 then
            lines[#lines + 1] = { label = s.label, value = fmt(s.fmt, v) }
            local score = v * s.weight
            if s.title and score > bestScore then best, bestScore = s.title, score end
        end
    end
    local ranks = {}
    for _, stat in ipairs({ 'minutes', 'meters' }) do
        local v = data[stat] or 0
        if v > 0 then
            local better, total = Store.rank(period, stat, v)
            if total >= 5 then ranks[#ranks + 1] = { stat = stat, top = math.max(1, math.ceil((better + 1) / total * 100)) } end
        end
    end
    local label
    if period == 'all' then label = 'Depuis ton arrivée'
    else
        local y, m = period:match('^(%d+)-(%d+)$')
        label = ('%s %s'):format(Config.Months[tonumber(m)] or '?', y)
    end
    return { period = period, label = label, lines = lines, title = best or 'Nouveau visage', ranks = ranks }
end

--- Le mois dernier (pour l'annonce « ton récap est prêt »)
function Bio.lastMonth(ts)
    local t = os.date('*t', ts or now())
    local y, m = t.year, t.month - 1
    if m == 0 then y, m = y - 1, 12 end
    return ('%04d-%02d'):format(y, m)
end

-- Sources ------------------------------------------------------------------------------------------------------
AddEventHandler('QBCore:Server:OnMoneyChange', function(src, moneyType, amount, action) -- [API] qbx_core
    if moneyType ~= 'cash' and moneyType ~= 'bank' then return end
    if action == 'add' then Bio.add(src, 'earned', tonumber(amount) or 0) end
end)
AddEventHandler('gs_wanted:server:crime', function(src) Bio.add(src, 'crimes') end)
AddEventHandler('gs_police:server:jailed', function(target, _, by)
    Bio.add(target, 'jailed')
    if by and tonumber(by) and tonumber(by) > 0 then Bio.add(tonumber(by), 'arrests') end
end)
AddEventHandler('gs_fightclub:server:won', function(src) Bio.add(src, 'fights') end)
AddEventHandler('gs_roadside:server:met', function(src) Bio.add(src, 'encounters') end)
AddEventHandler('gs_evidence:server:photo', function(src) Bio.add(src, 'photos') end)
AddEventHandler('gs_carnet:server:driven', function(_, src, km) if km and km > 0 then Bio.add(src, 'meters', km * 1000) end end)
AddStateBagChangeHandler('qbx_medical:deathState', nil, function(bagName, _, value) -- [API] qbx_medical
    local src = GetPlayerFromStateBagName(bagName)
    if src and src > 0 and (tonumber(value) or 0) >= 2 then Bio.add(src, 'deaths') end
end)

AddEventHandler('gs_bridge:server:playerLoaded', function(src)
    local cid = Bridge:GetIdentifier(src)
    if not cid then return end
    local last = Bio.lastMonth()
    if GetResourceKvpString(('seen:%s:%s'):format(cid, last)) then return end
    local data = Store.get(cid, last)
    if next(data) then
        SetTimeout(20000, function()
            Bridge:Notify(src, ('Ton récap RoadLine de %s est prêt : /recap'):format(Config.Months[tonumber(last:sub(6, 7))]), 'success')
        end)
    end
end)

lib.callback.register('gs_stats:recap', function(src, which)
    if not Security:RateLimit(src, 'gs_stats:recap', 4, 10000) then return nil end
    local cid = Bridge:GetIdentifier(src)
    if not cid then return nil end
    local period = which == 'all' and 'all' or (which == 'last' and Bio.lastMonth() or Bio.month())
    if which == 'last' then SetResourceKvp(('seen:%s:%s'):format(cid, period), '1') end
    local v = Bio.view(cid, period)
    v.name = Bridge:GetName(src)
    if which == 'all' then
        local ok, first = pcall(function() return Retention and Retention.firstOf(src) end)
        v.since = ok and first and os.date('%d/%m/%Y', first) or nil
    end
    return v
end)

exports('Add', Bio.add)

AddEventHandler('playerDropped', function() Bio.flush() end)
CreateThread(function()
    Store.init()
    while true do
        Wait(Config.Flush * 1000)
        for _, s in ipairs(Bridge:GetPlayers() or {}) do Bio.add(s, 'minutes', Config.Flush / 60) end
        Bio.flush()
    end
end)
