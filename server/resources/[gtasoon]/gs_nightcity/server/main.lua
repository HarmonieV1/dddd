-- gs_nightcity (serveur) · V10.2. Achats aux marchés de nuit : sur place, la nuit (heure du jeu), prix de la config.
local Security = exports.gs_security
local Bridge   = exports.gs_bridge

NightCity = {}

function NightCity.hour()
    if GetResourceState('gs_weather') ~= 'started' then return tonumber(os.date('%H')) end
    local ok, h = pcall(function() return exports.gs_weather:GetGameTime() end)
    return ok and tonumber(h) or tonumber(os.date('%H'))
end

local function inRange(h, r) if r.from <= r.to then return h >= r.from and h < r.to end return h >= r.from or h < r.to end
function NightCity.isNight(h) return inRange(h or NightCity.hour(), Config.Night) end

function NightCity.buy(src, market, item, qty)
    local m = Config.Markets[tonumber(market) or 0]
    if not m then return false, 'Stand introuvable.' end
    if not NightCity.isNight() then return false, 'Le stand n\'ouvre que la nuit.' end
    if not Security:InRange(src, vec3(m.coords.x, m.coords.y, m.coords.z), Config.MarketRange) then return false, 'Approche-toi du stand.' end
    qty = math.floor(tonumber(qty) or 0)
    if qty < 1 or qty > 10 then return false, 'Quantité invalide.' end
    local def
    for _, it in ipairs(Config.MarketItems) do if it.item == item then def = it break end end
    if not def then return false, 'Pas au menu.' end
    if not Bridge:CanCarry(src, item, qty) then return false, 'Ton sac est plein.' end
    local total = def.price * qty
    if not Bridge:RemoveMoney(src, 'cash', total, 'marché de nuit') then return false, 'Ça se paie en liquide.' end
    Bridge:AddItem(src, item, qty)
    return true, ('Merci ! (%d $)'):format(total)
end

lib.callback.register('gs_nightcity:buy', function(src, market, item, qty)
    if not Security:RateLimit(src, 'gs_nightcity:buy', 5, 10000) then return false, 'Doucement.' end
    return NightCity.buy(src, market, tostring(item or ''), qty)
end)
