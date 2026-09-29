-- gs_social (serveur) : Vibe influence la ville. Un hashtag repris par assez d'auteurs différents en peu de temps déclenche
-- un effet en jeu : #rassemblement (point de rendez-vous avec XP), #promo (commerces −15 %), #course (courses gratuites).
local Security = exports.gs_security
local Bridge   = exports.gs_bridge

Trends = { seen = {}, cooldown = {}, gathering = nil, attended = {} } -- seen[tag] = { [cid] = ts }

local function started(res) return GetResourceState(res) == 'started' end

local function announce(msg)
    TriggerClientEvent('gs_social:client:trend', -1, msg)
    Security:LogStaff('[Vibe] tendance : ' .. msg, 'social', true)
end

local EFFECTS = {
    rassemblement = function(t)
        local spot = t.spots[math.random(#t.spots)]
        Trends.gathering = { coords = spot, untilTs = os.time() + t.duration, label = spot.label }
        Trends.attended = {}
        GlobalState.gsVibeGathering = { x = spot.coords.x, y = spot.coords.y, z = spot.coords.z, label = spot.label, untilTs = Trends.gathering.untilTs }
        announce(('#rassemblement : rendez-vous à %s ! (%d min, XP pour les présents)'):format(spot.label, t.duration // 60))
        return true
    end,
    promo = function(t)
        if not started('gs_economy') or not exports.gs_economy:SetPromo(t.factor, t.duration) then return false end
        announce(('#promo : %d %% de réduction dans tous les commerces pendant %d min !'):format(math.floor((1 - t.factor) * 100 + 0.5), t.duration // 60))
        return true
    end,
    course = function(t)
        if not started('gs_races') then return false end
        exports.gs_races:SetFreeEntry(t.duration)
        announce(('#course : courses de rue sans mise pendant %d min, rendez-vous aux lignes de départ !'):format(t.duration // 60))
        return true
    end,
}

--- Appelé à chaque nouveau post. Compte les auteurs distincts par hashtag sur la fenêtre, déclenche l'effet au seuil.
function Trends.onPost(cid, content)
    local now = os.time()
    for raw in (content or ''):gmatch('#([%w_]+)') do
        local tag = raw:lower()
        local t = Config.Trends[tag]
        if t then
            Trends.seen[tag] = Trends.seen[tag] or {}
            local seen = Trends.seen[tag]
            seen[cid] = now
            local n = 0
            for c, ts in pairs(seen) do
                if now - ts > Config.TrendWindow then seen[c] = nil else n = n + 1 end
            end
            if n >= t.authors and (Trends.cooldown[tag] or 0) <= now and EFFECTS[tag](t) then
                Trends.cooldown[tag] = now + t.cooldown
                Trends.seen[tag] = {}
            end
        end
    end
end

lib.callback.register('gs_social:attend', function(src)
    if not Security:RateLimit(src, 'gs_social:attend', 3, 10000) then return false end
    local g = Trends.gathering
    local cid = Bridge:GetIdentifier(src)
    if not g or os.time() > g.untilTs or not cid then return false, 'Aucun rassemblement en cours.' end
    if Trends.attended[cid] then return false, 'Déjà compté.' end
    if not Security:InRange(src, g.coords.coords, Config.Trends.rassemblement.radius) then return false, 'Rejoins le point de rendez-vous.' end
    Trends.attended[cid] = true
    if started('gs_quests') then exports.gs_quests:AddXP(src, Config.Trends.rassemblement.xp, 'rassemblement Vibe') end
    return true, ('Présent au rassemblement : +%d XP.'):format(Config.Trends.rassemblement.xp)
end)

--- Fin du rassemblement : on retire le point de la carte de tout le monde.
function Trends.tick()
    if Trends.gathering and os.time() > Trends.gathering.untilTs then
        Trends.gathering = nil
        GlobalState.gsVibeGathering = nil
    end
end

CreateThread(function()
    while true do
        Wait(60000)
        Trends.tick()
    end
end)
