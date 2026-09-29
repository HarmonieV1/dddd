-- gs_seasons (serveur) : saison en cours (dates), points = XP gagnée, paliers réclamables (gratuit / premium),
-- premium donné par la boutique (export GrantPremium), classement et palmarès archivé à la fin de chaque saison.
local Security = exports.gs_security
local Bridge   = exports.gs_bridge

Seasons = {}

local function toTime(date)
    local y, m, d = date:match('^(%d+)-(%d+)-(%d+)$')
    return os.time({ year = tonumber(y), month = tonumber(m), day = tonumber(d), hour = 0 })
end

--- Saison en cours { id, label, theme, startTs, endTs } ou nil ; `now` pour les tests.
function Seasons.current(now)
    now = now or os.time()
    for _, s in ipairs(Config.Seasons) do
        local a = toTime(s.start)
        local b = a + Config.Weeks * 7 * 86400
        if now >= a and now < b then return { id = s.id, label = s.label, theme = s.theme, startTs = a, endTs = b } end
    end
end

local function display(src)
    local h = GetResourceState('gs_social') == 'started' and exports.gs_social:GetHandle(src)
    if h then return '@' .. h end
    local ci = Bridge:GetCharInfo(src) or {}
    return ('%s %s.'):format(ci.firstname or '?', (ci.lastname or '?'):sub(1, 1))
end

AddEventHandler('gs_quests:server:xp', function(src, amount)
    local s = Seasons.current()
    local cid = s and Bridge:GetIdentifier(src)
    if cid and tonumber(amount) and amount > 0 then Store.addPoints(s.id, cid, display(src), math.floor(amount)) end
end)

--- Donne une récompense ; retourne un libellé (ou nil si impossible).
function Seasons.give(src, cid, reward, seasonId)
    if reward.cash then return Bridge:AddMoney(src, 'bank', reward.cash, 'pass de saison') and (reward.cash .. ' $') or nil end
    if reward.item then return Bridge:AddItem(src, reward.item, reward.count or 1) and ('%d × %s'):format(reward.count or 1, reward.item) or nil end
    if reward.title then return 'Titre « ' .. reward.title .. ' »' end
    if reward.outfit then
        if GetResourceState('gs_store') ~= 'started' then return nil end
        return exports.gs_store:UnlockOutfit(cid, reward.outfit, 'saison ' .. seasonId) and 'Tenue débloquée (/boutique)' or nil
    end
end

lib.callback.register('gs_seasons:info', function(src)
    if not Security:RateLimit(src, 'gs_seasons:info', 6, 10000) then return nil end
    local s = Seasons.current()
    local cid = Bridge:GetIdentifier(src)
    if not cid then return nil end
    if not s then return { none = true, hall = Store.hall() } end
    local me = Store.get(s.id, cid)
    local tiers = {}
    for i, t in ipairs(Config.Tiers) do
        tiers[i] = { free = t.free, premium = t.premium, reached = me.points >= i * Config.PointsPerTier,
            freeClaimed = me.claimed['f' .. i] == true, premiumClaimed = me.claimed['p' .. i] == true }
    end
    return { season = s, points = me.points, premium = me.premium, title = me.title, perTier = Config.PointsPerTier, tiers = tiers,
             daysLeft = math.ceil((s.endTs - os.time()) / 86400), top = Store.top(s.id, 10), hall = Store.hall() }
end)

lib.callback.register('gs_seasons:claim', function(src, tier, track)
    if not Security:RateLimit(src, 'gs_seasons:claim', 4, 10000) then return false, 'Doucement.' end
    local s = Seasons.current()
    local cid = Bridge:GetIdentifier(src)
    tier = tonumber(tier)
    local t = tier and Config.Tiers[tier]
    if not s or not cid or not t or (track ~= 'free' and track ~= 'premium') then return false, 'Palier inconnu.' end
    local me = Store.get(s.id, cid)
    if me.points < tier * Config.PointsPerTier then return false, 'Palier pas encore atteint.' end
    if track == 'premium' and not me.premium then return false, 'Piste premium : pass de saison (boutique).' end
    local key = (track == 'free' and 'f' or 'p') .. tier
    if me.claimed[key] then return false, 'Déjà récupéré.' end
    local reward = t[track]
    me.claimed[key] = true
    Store.saveClaims(s.id, cid, me.claimed, reward.title or me.title) -- marqué AVANT de donner : pas de double récompense
    local label = Seasons.give(src, cid, reward, s.id)
    if not label then
        me.claimed[key] = nil
        Store.saveClaims(s.id, cid, me.claimed, me.title)
        return false, 'Impossible de te donner la récompense (sac plein ?).'
    end
    return true, 'Récompense : ' .. label
end)

--- Boutique : piste premium de la saison en cours pour ce personnage.
exports('GrantPremium', function(cid)
    local s = Seasons.current()
    if not s or type(cid) ~= 'string' then return false end
    Store.setPremium(s.id, cid)
    return true
end)

--- Titre de saison affichable (Vibe, panel staff).
exports('GetTitle', function(src)
    local s = Seasons.current()
    local cid = s and Bridge:GetIdentifier(src)
    if not cid then return nil end
    local t = Store.get(s.id, cid).title
    return t ~= '' and t or nil
end)

--- Palmarès : à la fin de chaque saison, archive le podium (une seule fois).
function Seasons.archive(now)
    now = now or os.time()
    for _, s in ipairs(Config.Seasons) do
        local finished = toTime(s.start) + Config.Weeks * 7 * 86400 <= now
        if finished and not Store.hallHas(s.id) then
            for i, r in ipairs(Store.top(s.id, Config.HallSize)) do Store.hallAdd(s.id, i, r.name, r.points) end
        end
    end
end

CreateThread(function()
    Store.init()
    while true do
        Seasons.archive()
        Wait(3600000)
    end
end)
