-- gs_blackmarket (serveur) : accès, planque du jour, stock, prix selon la rareté, paiement, signalement éventuel.
local Security = exports.gs_security
local Bridge   = exports.gs_bridge

Market = { day = nil, sold = {}, weapons = {} } -- sold[index] = quantité vendue aujourd'hui ; weapons[cid] = achats d'armes

local function started(res) return GetResourceState(res) == 'started' end

--- Jour de marché (change à Config.RestockHour, heure du serveur).
function Market.today() return os.date('%Y-%m-%d', os.time() - Config.RestockHour * 3600) end

local function refreshDay()
    local d = Market.today()
    if Market.day ~= d then Market.day, Market.sold, Market.weapons = d, {}, {} end
end

--- Planque actuelle (déterministe : tout le monde voit la même).
function Market.location()
    local list = Config.Dealer.locations
    return list[(os.time() // (Config.Dealer.rotateMinutes * 60)) % #list + 1]
end

function Market.isOpen()
    if not started('gs_weather') then return true end
    local h = exports.gs_weather:GetGameTime()
    local from, to = Config.Dealer.hours[1], Config.Dealer.hours[2]
    return h >= from or h < to
end

--- Accès : pas en service de police ; gang ou réputation de rue. Retourne ok, gang|message.
function Market.access(src)
    if started('gs_jobs') and exports.gs_jobs:IsOnDutyAs(src, Config.PoliceJob) then return false, 'Le contact ne parle pas aux flics.' end
    local gang = started('gs_gangs') and exports.gs_gangs:GetGang(src) or nil
    if gang then return true, gang end
    local rep = started('gs_reputation') and exports.gs_reputation:Get(src) or nil
    if rep and (rep.street or 0) >= Config.Access.streetRep then return true, nil end
    return false, ('Personne ne te connaît dans la rue (réputation de rue %d requise, ou rejoins un gang).'):format(Config.Access.streetRep)
end

--- Prix actuel d'une ligne du catalogue (argent sale), rareté + remise de gang sur son territoire.
function Market.price(index, gang)
    local e = Config.Catalog[index]
    local soldShare = (Market.sold[index] or 0) / e.stock
    local p = e.price * (1 + Config.Scarcity * soldShare)
    if gang and started('gs_gangs') then
        local loc = Market.location()
        local zone = exports.gs_gangs:GetTerritoryAt(vec3(loc.x, loc.y, loc.z))
        if zone and exports.gs_gangs:GetTerritoryOwner(zone) == gang then p = p * (1 - Config.GangDiscount) end
    end
    return math.floor(p)
end

local function nearDealer(src)
    local loc = Market.location()
    return Security:InRange(src, vec3(loc.x, loc.y, loc.z), 4.0)
end

lib.callback.register('gs_blackmarket:where', function(src)
    if not Security:RateLimit(src, 'gs_blackmarket:where', 3, 10000) then return nil, 'Doucement.' end
    local ok, msg = Market.access(src)
    if not ok then return nil, msg end
    local loc = Market.location()
    return { x = loc.x, y = loc.y, z = loc.z, w = loc.w, open = Market.isOpen() }
end)

lib.callback.register('gs_blackmarket:catalog', function(src)
    if not Security:RateLimit(src, 'gs_blackmarket:catalog', 5, 10000) then return nil, 'Doucement.' end
    refreshDay()
    local ok, gang = Market.access(src)
    if not ok then return nil, gang end
    if not nearDealer(src) then return nil, 'Personne ici.' end
    if not Market.isOpen() then return nil, 'Reviens la nuit.' end
    if started('gs_wanted') and exports.gs_wanted:GetHeat(src) > Config.Dealer.maxHeat then return nil, 'T\'es trop chaud, dégage avant de me faire tomber.' end
    local list = {}
    for i, e in ipairs(Config.Catalog) do
        if Bridge:ItemExists(e.item) and (not e.gangOnly or gang) then
            list[#list + 1] = { index = i, label = e.label, price = Market.price(i, gang), cashPrice = math.floor(Market.price(i, gang) * Config.CashMarkup),
                left = e.stock - (Market.sold[i] or 0), weapon = e.weapon }
        end
    end
    return list
end)

lib.callback.register('gs_blackmarket:buy', function(src, index, pay)
    if not Security:RateLimit(src, 'gs_blackmarket:buy', 5, 10000) then return false, 'Doucement.' end
    refreshDay()
    local ok, gang = Market.access(src)
    if not ok then return false, gang end
    index = tonumber(index)
    local e = index and Config.Catalog[index]
    if not e or not Bridge:ItemExists(e.item) then return false, 'Invalide.' end
    if e.gangOnly and not gang then return false, 'Réservé aux gangs.' end
    if not nearDealer(src) or not Market.isOpen() then return false, 'Le contact est parti.' end
    if (Market.sold[index] or 0) >= e.stock then return false, 'Plus de stock aujourd\'hui.' end
    local cid = Bridge:GetIdentifier(src)
    if e.weapon and (Market.weapons[cid] or 0) >= 1 then return false, 'Une arme par jour, pas plus : je veux pas d\'ennuis.' end
    local price = Market.price(index, gang)
    local count = e.pack or 1
    local metadata = e.weapon and { registered = false } or (e.fake and Fake and Fake.metadata(src, e.fake)) or nil -- V12 : faux papiers
    if pay == 'cash' then
        price = math.floor(price * Config.CashMarkup)
        if not Bridge:RemoveMoney(src, 'cash', price, 'marché noir') then return false, ('Il te faut %d $ en liquide.'):format(price) end
        if not Bridge:AddItem(src, e.item, count, metadata) then Bridge:AddMoney(src, 'cash', price, 'remboursement') return false, 'Tu ne peux pas porter ça.' end
    else
        if not Bridge:RemoveItem(src, Config.DirtyItem, price) then return false, ('Il te faut %d $ en argent sale.'):format(price) end
        if not Bridge:AddItem(src, e.item, count, metadata) then Bridge:AddItem(src, Config.DirtyItem, price) return false, 'Tu ne peux pas porter ça.' end
    end
    Market.sold[index] = (Market.sold[index] or 0) + 1
    if e.weapon then Market.weapons[cid] = (Market.weapons[cid] or 0) + 1 end
    if started('gs_wanted') and math.random() < Config.Dealer.reportChance then
        exports.gs_wanted:ReportCrime(src, 'black_market', GetEntityCoords(GetPlayerPed(src)))
    end
    if started('gs_reputation') then exports.gs_reputation:Add(src, 'street', 1) end
    Security:LogStaff(('[Marché noir] %s achète %s pour %d $ (%s)'):format(GetPlayerName(src) or src, e.label, price, pay == 'cash' and 'liquide' or 'sale'), 'jobs')
    return true, ('%s pour %d $.'):format(e.label, price)
end)
