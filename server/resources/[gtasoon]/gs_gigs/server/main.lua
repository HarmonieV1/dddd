-- gs_gigs (serveur) : offres tirées ici (points distants), une mission à la fois, étape A puis B vérifiées sur place,
-- temps de trajet crédible, paiement au km (liquide ou argent sale), signalement possible pour le passeur.
local Security = exports.gs_security
local Bridge   = exports.gs_bridge

Gigs = { offers = {}, active = {}, cooldown = {} } -- offers[src] = { at, list }, active[src] = { ... }

local function pay(src, amount, dirty)
    if dirty and Bridge:ItemExists('black_money') and Bridge:AddItem(src, 'black_money', amount) then return end
    Bridge:AddMoney(src, 'cash', amount, 'petit boulot')
end

--- Tire `n` offres : type au hasard, A et B distincts et assez éloignés, paie estimée.
function Gigs.roll(n)
    local types = {}
    for id in pairs(Config.Types) do types[#types + 1] = id end
    table.sort(types)
    local list, P = {}, Config.Points
    for i = 1, n do
        for _ = 1, 50 do
            local a, b = math.random(#P), math.random(#P)
            local d = #(P[a] - P[b])
            if a ~= b and d >= Config.MinDistance then
                local kind = types[math.random(#types)]
                local t = Config.Types[kind]
                list[#list + 1] = { id = i, kind = kind, from = a, to = b, km = math.floor(d / 100) / 10,
                    pay = t.base + math.floor(d / 1000 * t.perKm) }
                break
            end
        end
    end
    return list
end

local function publicOffers(list)
    local out = {}
    for i, o in ipairs(list) do
        local t = Config.Types[o.kind]
        out[i] = { id = o.id, kind = o.kind, label = t.label, icon = t.icon, desc = t.desc, legal = t.legal, km = o.km, pay = o.pay }
    end
    return out
end

local function status(src)
    local g = Gigs.active[src]
    if not g then return nil end
    local t = Config.Types[g.kind]
    return { kind = g.kind, label = t.label, stage = g.stage, pay = g.pay,
             step = g.stage == 1 and t.pickup or t.drop, coords = Config.Points[g.stage == 1 and g.from or g.to] }
end

lib.callback.register('gs_gigs:list', function(src)
    if not Security:RateLimit(src, 'gs_gigs:list', 6, 10000) then return nil end
    local o = Gigs.offers[src]
    if not o or os.time() - o.at >= Config.RefreshSeconds then
        o = { at = os.time(), list = Gigs.roll(Config.OffersPerRefresh) }
        Gigs.offers[src] = o
    end
    return { offers = publicOffers(o.list), active = status(src), cooldown = math.max(0, (Gigs.cooldown[src] or 0) - os.time()),
             refreshIn = Config.RefreshSeconds - (os.time() - o.at) }
end)

lib.callback.register('gs_gigs:accept', function(src, id)
    if not Security:RateLimit(src, 'gs_gigs:accept', 3, 10000) then return false, 'Doucement.' end
    if Gigs.active[src] then return false, 'Termine d\'abord ton boulot en cours.' end
    if (Gigs.cooldown[src] or 0) > os.time() then return false, 'Souffle un peu avant le prochain.' end
    local o = Gigs.offers[src]
    local offer
    for i, x in ipairs(o and o.list or {}) do if x.id == id then offer = x table.remove(o.list, i) break end end
    if not offer then return false, 'Offre expirée.' end
    Gigs.active[src] = { kind = offer.kind, from = offer.from, to = offer.to, pay = offer.pay, stage = 1, startedAt = os.time() }
    return true, status(src)
end)

lib.callback.register('gs_gigs:step', function(src)
    if not Security:RateLimit(src, 'gs_gigs:step', 3, 5000) then return false, 'Doucement.' end
    local g = Gigs.active[src]
    if not g then return false, 'Aucun boulot en cours.' end
    if os.time() - g.startedAt > Config.Timeout then
        Gigs.active[src] = nil
        return false, 'Trop tard, le client a annulé.'
    end
    local point = Config.Points[g.stage == 1 and g.from or g.to]
    if not Security:InRange(src, point, Config.Radius) then return false, 'Ce n\'est pas ici.' end
    local t = Config.Types[g.kind]
    if g.stage == 1 then
        g.stage, g.pickedAt = 2, GetGameTimer()
        if not t.legal and math.random() < (t.reportChance or 0) and GetResourceState('gs_wanted') == 'started' then
            exports.gs_wanted:ReportCrime(src, 'smuggling', point)
        end
        return true, status(src)
    end
    local dist = #(Config.Points[g.to] - Config.Points[g.from])
    if (GetGameTimer() - g.pickedAt) / 1000 < dist / Config.MaxSpeed then
        Gigs.active[src] = nil
        Security:LogStaff(('[Boulots] trajet suspect : %s (%.0f m en %.1f s)'):format(GetPlayerName(src) or src, dist, (GetGameTimer() - g.pickedAt) / 1000))
        return false, 'Livraison refusée : trajet impossible.'
    end
    Gigs.active[src] = nil
    Gigs.cooldown[src] = os.time() + Config.Cooldown
    pay(src, g.pay, t.dirty)
    if GetResourceState('gs_quests') == 'started' then exports.gs_quests:Reward(src, 'job_mission') end
    return true, nil, ('%s terminé : %d $%s.'):format(t.label, g.pay, t.dirty and ' (argent sale)' or '')
end)

lib.callback.register('gs_gigs:cancel', function(src)
    if not Security:RateLimit(src, 'gs_gigs:cancel', 3, 10000) then return false end
    if not Gigs.active[src] then return false end
    Gigs.active[src] = nil
    Gigs.cooldown[src] = os.time() + Config.Cooldown
    return true
end)

AddEventHandler('gs_bridge:server:playerUnloaded', function(src) Gigs.offers[src], Gigs.active[src], Gigs.cooldown[src] = nil, nil, nil end)
