-- gs_rumors (serveur) · V8 « La ville parle » : rumeurs nées des vrais événements, indic' des gangs (qui balance).
local Security = exports.gs_security
local Bridge   = exports.gs_bridge

Rumors = { list = {}, gang = {} } -- list = { { text, detail, at, zone } } ; gang[name] = { { text, at } }

local function now() return os.time() end

function Rumors.zone(c)
    if not c then return 'quelque part' end
    local best, bd = Config.Zones[1][1], math.huge
    for _, z in ipairs(Config.Zones) do
        local d = (z[2] - c.x) ^ 2 + (z[3] - c.y) ^ 2
        if d < bd then best, bd = z[1], d end
    end
    return best
end

local function ago(at)
    local m = math.floor((now() - at) / 60)
    if m < 2 then return 'à l\'instant' elseif m < 60 then return ('il y a %d min'):format(m) end
    return ('il y a %d h'):format(math.floor(m / 60))
end

--- Ajoute une rumeur : `text` (version courte, gratuite) et `detail` (version payante, plus précise)
function Rumors.add(text, detail, coords)
    table.insert(Rumors.list, 1, { text = text, detail = detail or text, at = now(), zone = Rumors.zone(coords) })
    Rumors.list[Config.Keep + 1] = nil
end

local function fresh(minAge)
    local out = {}
    for _, r in ipairs(Rumors.list) do
        local age = (now() - r.at) / 60
        if age <= Config.MaxAge and age >= (minAge or 0) then out[#out + 1] = r end
    end
    return out
end

--- Gratuit : une rumeur vague, un peu vieille
function Rumors.free()
    local l = fresh(Config.FreeMinAge)
    if #l == 0 then return 'Calme plat en ce moment. Repasse plus tard.' end
    local r = l[math.random(1, #l)]
    return ('Paraît que %s, du côté de %s.'):format(r.text, r.zone)
end

--- Payant : les 3 dernières, détaillées
function Rumors.paid(src)
    local l = fresh(0)
    if #l == 0 then return false, 'Rien de neuf, garde ton argent.' end
    if not (Bridge:RemoveMoney(src, 'cash', Config.Price) or Bridge:RemoveMoney(src, 'bank', Config.Price)) then return false, 'Ça se paie, ces choses-là.' end
    local out = {}
    for i = 1, math.min(3, #l) do out[#out + 1] = ('%s · %s · %s'):format(l[i].zone, l[i].detail, ago(l[i].at)) end
    return true, out
end

-- Sources de rumeurs -----------------------------------------------------------------------------------------------
AddEventHandler('gs_wanted:server:report', function(r)
    local desc = (r.desc and #r.desc > 0) and (' Les témoins parlent de : ' .. table.concat(r.desc, ', ') .. '.') or ''
    local named = r.named and (' Certains jurent que c\'était ' .. r.named .. '.') or ''
    Rumors.add(('il y a eu du grabuge (%s)'):format(r.label:lower()), r.label .. '.' .. desc .. named, r.coords)
end)
AddEventHandler('gs_police:server:jailed', function(target)
    local name = Bridge:GetName(target)
    if name then Rumors.add('les flics ont coffré quelqu\'un', ('%s dort à Bolingbroke ce soir.'):format(name), GetEntityCoords(GetPlayerPed(target))) end
end)
AddEventHandler('gs_weather:server:eventStarted', function(id)
    if id == 'storm' then Rumors.add('une tempête arrive', 'Les routes de campagne vont être coupées, les dépanneurs vont se faire un paquet.') end
end)

-- L'indic' ---------------------------------------------------------------------------------------------------------
local KIND = {
    fence = function(n) return ('livraison au receleur (%d doses)'):format(n or 0) end,
    craft = function(n) return ('l\'atelier a tourné (%d munitions)'):format(n or 0) end,
    crime = function(label) return 'un coup : ' .. (label or 'crime'):lower() end,
}

function Rumors.gangActivity(gang, kind, coords, info)
    if not gang then return end
    local l = Rumors.gang[gang] or {}
    table.insert(l, 1, { text = KIND[kind] and KIND[kind](info) or kind, at = now(), zone = Rumors.zone(coords) })
    l[Config.Indic.keep + 1] = nil
    Rumors.gang[gang] = l
end

AddEventHandler('gs_gangs:server:activity', function(gang, kind, coords, n) Rumors.gangActivity(gang, kind, coords, n) end)
AddEventHandler('gs_wanted:server:crime', function(src, crimeType, coords)
    if GetResourceState('gs_gangs') ~= 'started' then return end
    local ok, gang = pcall(function() return exports.gs_gangs:GetGang(src) end)
    if ok and gang then
        local okL, label = pcall(function() return exports.gs_wanted:CrimeLabel(crimeType) end)
        Rumors.gangActivity(gang, 'crime', coords, okL and label or (crimeType:gsub('_', ' ')))
    end
end)

local function gangLabel(name)
    local ok, list = pcall(function() return exports.gs_gangs:ListGangs() end)
    if ok then for _, g in ipairs(list or {}) do if g.name == name then return g.label end end end
    return name
end

local function informantAt(src)
    for i, inf in ipairs(Config.Informants) do
        if Security:InRange(src, vec3(inf.coords.x, inf.coords.y, inf.coords.z), 4.0) then return i, inf end
    end
end

--- L'indic' : ce qu'il sait sur un gang (pas le sien). Risque : il balance l'acheteur au gang visé.
function Rumors.indic(src, gang)
    local idx, inf = informantAt(src)
    if not idx then return false, 'Il n\'y a personne ici.' end
    local okG, mine = pcall(function() return exports.gs_gangs:GetGang(src) end)
    mine = okG and mine or nil
    if not gang or gang == mine then return false, '« Tu te renseignes sur ta propre bande ? »' end
    if not (Bridge:RemoveMoney(src, 'cash', Config.Indic.price)) then return false, ('« %d $, en liquide. »'):format(Config.Indic.price) end
    local out = {}
    for _, a in ipairs(Rumors.gang[gang] or {}) do
        if (now() - a.at) / 60 <= Config.Indic.maxAge then out[#out + 1] = ('%s · %s · %s'):format(a.zone, a.text, ago(a.at)) end
        if #out >= 3 then break end
    end
    if #out == 0 then out[1] = 'Ils se tiennent tranquilles en ce moment. Trop tranquilles.' end
    -- le receleur ne voit que les gangs : sa position de la nuit vaut de l'or
    if math.random() < Config.Indic.fenceTip and GetResourceState('gs_gangs') == 'started' then
        local okF, f = pcall(function() return exports.gs_gangs:FenceLocation() end)
        if okF and f then out[#out + 1] = ('Leur receleur traîne du côté de %s cette nuit.'):format(Rumors.zone(f)) end
    end
    -- l'indic' balance aussi
    if math.random() < Config.Indic.leak and GetResourceState('gs_gangs') == 'started' then
        local who = mine and ('quelqu\'un des %s'):format(gangLabel(mine)) or 'un inconnu'
        for _, s in ipairs(Bridge:GetPlayers() or {}) do
            local ok2, g = pcall(function() return exports.gs_gangs:GetGang(s) end)
            if ok2 and g == gang then
                Bridge:Notify(s, ('%s : « %s pose des questions sur vous. »'):format(inf.label, who), 'warning')
            end
        end
    end
    return true, out
end

lib.callback.register('gs_rumors:free', function(src)
    if not Security:RateLimit(src, 'gs_rumors:free', 2, 20000) then return '« Je t\'ai déjà tout dit. »' end
    return Rumors.free()
end)
lib.callback.register('gs_rumors:paid', function(src)
    if not Security:RateLimit(src, 'gs_rumors:paid', 2, 10000) then return false, 'Doucement.' end
    return Rumors.paid(src)
end)
lib.callback.register('gs_rumors:gangs', function(src)
    if not Security:RateLimit(src, 'gs_rumors:gangs', 3, 5000) or GetResourceState('gs_gangs') ~= 'started' then return {} end
    local ok, list = pcall(function() return exports.gs_gangs:ListGangs() end)
    return ok and list or {}
end)
lib.callback.register('gs_rumors:indic', function(src, gang)
    if not Security:RateLimit(src, 'gs_rumors:indic', 2, 10000) then return false, 'Doucement.' end
    return Rumors.indic(src, gang)
end)

exports('Add', Rumors.add)
